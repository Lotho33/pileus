import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_lifecycle.dart';
import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' show DetailsResponse;
import '../core/perf_profile.dart';
import '../core/theme/app_theme.dart';
import '../features/media/data/media_repository.dart';
import '../features/player/bloc/playback_bloc.dart';
import '../features/player/bloc/playback_event.dart';
import '../features/player/bloc/playback_state.dart';
import '../features/player/engine/player_engine.dart';
import '../features/player/episode_poster.dart';
import '../features/player/episode_prefetch.dart';
import '../features/player/live_stall_watchdog.dart';
import '../features/player/models/playback_args.dart';
import '../features/player/models/skip_interval.dart';
import '../features/player/player_tuning.dart';
import '../features/player/resume_seek.dart' show resolveStartPositionSec;
import '../features/player/playback_episode_cache.dart';
import '../features/player/presentation/widgets/player_seek_bar.dart';
import '../features/player/presentation/widgets/pointer_skip_button.dart';
import '../features/player/profile_lease_conflict.dart';
import '../features/settings/data/settings_repository.dart';
import '../shared/player/playback_progress.dart';

/// Touch player for the mobile flavor. Landscape-locked while mounted;
/// reuses [PlaybackBloc] (stream fetch + resolve) and [PlayerEngine]
/// (ExoPlayer) unchanged — only the controls are mobile-native.
class MobilePlaybackScreen extends StatelessWidget {
  final String pluginId;
  final String mediaId;
  final Map<String, dynamic>? extra;

  const MobilePlaybackScreen({
    super.key,
    required this.pluginId,
    required this.mediaId,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final args =
        PlaybackArgs.fromExtra(extra, pluginId: pluginId, mediaId: mediaId);
    return BlocProvider(
      create: (_) {
        final bloc = getIt<PlaybackBloc>();
        final directUrl = args.directUrl;
        final direct = args.directStreamId;
        final startPositionSec =
            resolveStartPositionSec(isLive: args.isLive, seekTo: args.seekTo);
        if (directUrl != null && directUrl.isNotEmpty) {
          bloc.add(UseDirectUrlEvent(
              url: directUrl, httpHeaders: args.directUrlHeaders));
        } else if (direct != null && direct.isNotEmpty) {
          bloc.add(SelectStreamEvent(
              pluginId: pluginId,
              streamId: direct,
              startPositionSec: startPositionSec));
        } else {
          bloc.add(InitializeVideoEvent(
            pluginId: pluginId,
            mediaId: mediaId,
            preferredLabel: args.sourceLabel,
            startPositionSec: startPositionSec,
          ));
        }
        return bloc;
      },
      child:
          _MobilePlayerView(pluginId: pluginId, mediaId: mediaId, args: args),
    );
  }
}

class _MobilePlayerView extends StatefulWidget {
  final String pluginId;
  final String mediaId;
  final PlaybackArgs args;
  const _MobilePlayerView({
    required this.pluginId,
    required this.mediaId,
    required this.args,
  });

  @override
  State<_MobilePlayerView> createState() => _MobilePlayerViewState();
}

class _MobilePlayerViewState extends State<_MobilePlayerView> {
  late final PlayerEngine _engine;
  late final SettingsRepository _settings;
  // Not `final`: switching to the next episode in-place rebuilds this
  // around the new episode's mediaId/args (see _resolveEpisodeAt) instead
  // of tearing down and recreating the whole screen.
  late PlaybackProgress _progress;

  bool _controlsVisible = true;
  bool _opened = false;
  // First frame decoded AND (if applicable) the resume seek confirmed
  // landed — see _onEngine's own gate and kResumeCoverSafetyTimeout's doc.
  // Mirrors desktop's identically-named field.
  bool _started = false;
  bool _lastPlaying = false;
  bool _wakelockOn = false; // toggled only on a play/pause transition
  bool _lastBuffering = false;
  String? _playbackError;
  // Non-null shows _TakeoverOverlay instead of every other overlay —
  // contract "One device playing per profile", either the pre-play ABORTED
  // prompt (PlaybackPlayingElsewhere, "Guarda qui") or a mid-playback
  // take-over (_onPlaybackTakenOver, "Riprendi qui"). Never auto-dismissed
  // or retried — only the user's own tap on either button clears it.
  _TakeoverPrompt? _takeoverPrompt;
  Timer? _hideTimer;
  Timer? _errorGrace;
  Timer? _progressTimer;
  // Backstop for _started's own resume-confirmation gate (see _onEngine) —
  // re-armed on every open, cancelled the moment _started flips on its own.
  Timer? _resumeCoverSafetyTimer;
  // Built once — a plain reference in build() so an engine tick (4×/s)
  // never reconciles the platform video surface.
  Widget? _videoView;

  // ── Episode navigation (mutable during the session) ───────────────────────
  // Mirrors the TV player's own episode-nav state (playback_screen/view.dart)
  // — kept separate from widget.args so switching episodes doesn't need a
  // new route/screen instance.
  late int _curEpisodeIndex;
  late int _curSeasonIndex;
  late String _curMediaId;
  late String _curSourceLabel;
  late String? _curTitle;
  late List<String> _curEpisodeList;
  late List<String> _curEpisodeTitles;
  // Parallel to _curEpisodeList — see PlaybackArgs.episodeThumbs and
  // episode_poster.dart's posterForEpisode(). This (not a per-episode
  // getDetails().item.posterUrl fetch, which used to leave _curPoster stuck
  // dragging the very first episode's poster forward forever whenever a
  // later episode's own GetDetails had no posterUrl — the Continue Watching
  // poster bug) is now the source of truth for "what's this episode's
  // cover".
  late List<String> _curEpisodeThumbs;
  // Parallel to _curEpisodeList — the real "S{x} · E{y}" numbers, not the
  // list index. See PlaybackArgs.episodeNumbers/seasonNumbers and
  // episode_poster.dart's numberForEpisode().
  late List<int> _curEpisodeNumbers;
  late List<int> _curSeasonNumbers;
  // Fresh per-episode rating/duration/year once known — null means "nothing
  // fresher than widget.args yet", so _currentArgs() falls back to the
  // original launch value (see PlaybackArgs.copyWith). Plot is deliberately
  // NOT tracked here: Continue Watching always shows the series' synopsis,
  // never an episode's — see PlaybackArgs.copyWith's doc comment.
  double? _curRating;
  int? _curDurationSeconds;
  int? _curYear;
  bool _resolvingEpisode = false;
  // True from the moment _resolveEpisodeAt commits to switching episode
  // until the new stream is confirmed open (markStarted has run for it).
  // Guards the heartbeat/dispose save and maybeClear against firing in that
  // window — same audit finding as desktop/web/TV: a 15s tick
  // landing while _engine.stop() was still mid-reset, or after _progress had
  // already been reassigned to the new episode but the engine hadn't caught
  // up, wrote the wrong identity/position pairing.
  bool _transitioningEpisode = false;
  bool _autoAdvanced = false;
  // Countdown shown in the closing seconds of an episode; null = hidden.
  int? _nextEpisodeSecs;
  bool _nextEpisodeDismissed = false;

  // ── Skip markers (intro/outro/recap) ─────────────────────────────────────
  // Uses the shared helpers also used by desktop/web
  // (parseSkipTimes/activeSkipInterval, PointerSkipButton) rather than a
  // hand-rolled copy per platform.
  List<SkipInterval> _skipIntervals = const [];
  SkipInterval? _activeSkip;
  bool _skipDismissed = false;
  // Never actually D-pad-navigated on mobile (touch-only), but PlayerSeekBar
  // requires one — see the seek bar's own build() below for why reusing that
  // widget (instead of a plain Slider) is what draws the colored
  // skip-interval segments.
  final _seekBarFocusNode = FocusNode(canRequestFocus: false);
  StreamSubscription<Duration>? _posSub;
  bool _engineInitialized = false;
  late final int _bufMiB;

  // Live-only: TV/desktop/web all catch a live stream reporting playing=true
  // (or stuck buffering) with no genuine position advance — ExoPlayer can
  // land there too (e.g. an HLS live-edge blip with no exception ever
  // surfacing) — mobile is the one platform of the four that needs this
  // watchdog wired up explicitly. See live_stall_watchdog.dart for the
  // two-tier recovery this drives.
  LiveStallWatchdog? _liveWatchdog;

  // ── Next-episode prefetch ──────────────────────────────────────────────────
  // Warmed at kPrefetchThreshold through the current episode (see
  // _onPosition) so advancing doesn't cold-resolve (getStreams +
  // resolveStream, which can take several seconds on a slow plugin) with the
  // screen sitting on a spinner. Engine-agnostic and shared verbatim with
  // desktop/TV/web (episode_prefetch.dart) — a shared implementation,
  // including the generation guard, rather than a hand-copied one per
  // platform.
  late final _prefetcher = EpisodePrefetcher(
      repo: getIt<MediaRepository>(), pluginId: widget.args.epPluginId);

  @override
  void initState() {
    super.initState();
    _settings = getIt<SettingsRepository>();
    _progress = PlaybackProgress(
        args: widget.args,
        mediaId: widget.mediaId,
        onPlaybackElsewhere: _onPlaybackTakenOver);

    _curEpisodeIndex = widget.args.episodeList.isEmpty
        ? widget.args.episodeIndex
        : widget.args.episodeIndex.clamp(0, widget.args.episodeList.length - 1);
    _curSeasonIndex = widget.args.seasonIndex;
    _curMediaId = widget.mediaId;
    _curSourceLabel = widget.args.sourceLabel;
    _curTitle = widget.args.title;
    _curEpisodeList = widget.args.episodeList;
    _curEpisodeTitles = widget.args.episodeTitles;
    _curEpisodeThumbs = widget.args.episodeThumbs;
    _curEpisodeNumbers = widget.args.episodeNumbers;
    _curSeasonNumbers = widget.args.seasonNumbers;

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    var bufMiB = widget.args.isLive
        ? _settings.getLiveBufferMiB()
        : _settings.getPlayerBufferMiB();
    if (lowPowerUi) bufMiB = bufMiB.clamp(4, widget.args.isLive ? 10 : 16);
    _bufMiB = bufMiB;

    _engine = PlayerEngine.create();
    _engine.onError = _onEngineError;
    _engine.addListener(_onEngine);
    _posSub = _engine.positionStream.listen(_onPosition);
    if (widget.args.isLive) {
      _liveWatchdog = LiveStallWatchdog(
        isHealthy: () =>
            mounted &&
            _playbackError == null &&
            (_errorGrace?.isActive != true) &&
            _engine.playing,
        isBuffering: () => _engine.buffering,
        onStallTier1: () {
          _engine.pause();
          _engine.play();
        },
        onStallTier2: () {
          if (!mounted) return;
          setState(() => _opened = false);
          context.read<PlaybackBloc>().add(InitializeVideoEvent(
                pluginId: widget.pluginId,
                mediaId: _curMediaId,
                preferredLabel: _curSourceLabel,
              ));
        },
      )..arm();
    }
    // Native controller creation deferred to _ensureEngineInitialized(),
    // called right before the first engine.open() — not here. Mirrors the TV
    // player's own fix for a reported whole-screen freeze on weak hardware:
    // a native player view sitting mounted-but-idle for the whole
    // resolve/spinner window (which can be several seconds on a slow plugin)
    // is worse than not existing yet. buildView() already renders
    // SizedBox.shrink() until initialize() has run.

    // Persist watch progress so Continue Watching stays in sync with the TV
    // (same 15s heartbeat + dispose save the TV player uses). Live has no
    // resume point — and, separately, skips this on purpose even for the
    // single-device-lease heartbeat's sake, see PlaybackProgress's class doc
    // ("Why every screen's 15s heartbeat still skips live streams").
    if (!widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _saveProgressGuarded());
    }

    // One-shot background fetch: a launch path that only knows a single
    // episode (Continue Watching, a search/quick-play deep link) carries no
    // episodeList — this fills it in so "episodio successivo" still shows up
    // a beat after playback starts instead of never.
    _resolveEpisodeListIfMissing();

    _armAutoHide();
    // On Android the ExoPlayer engine already pauses decoding natively when
    // backgrounded — this only gates the 15s heartbeat above (a wasted gRPC
    // round-trip while the app can't be seen), same as desktop/web.
    AppLifecycleReactor.instance.state.addListener(_onLifecycle);
  }

  void _onLifecycle() {
    if (!mounted) return;
    if (AppLifecycleReactor.instance.isBackgrounded) {
      if (_progressTimer != null) {
        _progressTimer!.cancel();
        _progressTimer = null;
        if (!widget.args.isLive) {
          try {
            _saveProgressGuarded();
          } catch (_) {}
        }
      }
    } else if (_progressTimer == null && !widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _saveProgressGuarded());
    }
  }

  // See _transitioningEpisode's doc — the one guard every heartbeat/
  // dispose/backgrounding save site below goes through, instead of each
  // repeating the check.
  void _saveProgressGuarded() {
    if (_transitioningEpisode) return;
    _progress.save(_engine);
  }

  void _ensureEngineInitialized() {
    if (_engineInitialized) return;
    _engineInitialized = true;
    _engine.initialize(
      PlayerSubtitleStyle(
        fontSize: _settings.getSubtitleFontSize(),
        color: _settings.getSubtitleColor(),
        backgroundEnabled: _settings.getSubtitleBgEnabled(),
        bottomPadding: _settings.getSubtitleBottomPadding(),
      ),
      isLive: widget.args.isLive,
      bufferMiB: _bufMiB,
    );
    // The `??=` in build() cached the SizedBox.shrink() placeholder from
    // every build before this ran — drop it and force a rebuild so the next
    // build picks up the real buildView() now that the engine actually has
    // a controller. Without this the platform view would never mount:
    // nothing else is guaranteed to clear the cached placeholder promptly.
    if (mounted) setState(() => _videoView = null);
  }

  @override
  void dispose() {
    // Restore portrait + chrome FIRST — if the engine teardown below throws
    // (platform-view races on some devices) the screen must still not leave
    // the whole app stuck landscape / fullscreen.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AppLifecycleReactor.instance.state.removeListener(_onLifecycle);
    _hideTimer?.cancel();
    _errorGrace?.cancel();
    _progressTimer?.cancel();
    _resumeCoverSafetyTimer?.cancel();
    _posSub?.cancel();
    _liveWatchdog?.disarm();
    _seekBarFocusNode.dispose();
    // Final save while the engine is still alive — catches everything since
    // the last heartbeat (e.g. the user backs out 8s after the last tick).
    if (!widget.args.isLive) {
      try {
        _saveProgressGuarded();
      } catch (_) {}
    }
    // Best-effort, never blocks teardown — see ReleasePlaybackRequest's own
    // doc (contract "One device playing per profile"): frees this device's
    // hold on the lease at once instead of leaving it to lapse by itself
    // ~90s later, so switching to another device never has to wait. Not
    // called on an episode switch (playback stays on this same device).
    getIt<MediaRepository>().releasePlayback();
    WakelockPlus.disable();
    try {
      _engine.removeListener(_onEngine);
      _engine.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _onEngine() {
    if (!mounted) return;
    final playing = _engine.playing;
    var needsRebuild = false;

    // Wakelock is a platform-channel call — flip it only on an actual
    // play/pause change, not on every 4 Hz engine tick.
    if (playing != _wakelockOn) {
      _wakelockOn = playing;
      playing ? WakelockPlus.enable() : WakelockPlus.disable();
    }

    if (playing) {
      if (_playbackError != null) {
        _errorGrace?.cancel();
        _playbackError = null;
        needsRebuild = true;
      }
      _progress.maybeApplyAudioPref(_engine);
    }

    _progress.maybeResumeSeek(_engine);

    // Gated on the resume seek being done too (confirmed landed, or never
    // applicable), not just "playing/position arrived" — otherwise the
    // loading cover could lift on a tick that's still ~0 while the resume
    // seek above is in flight, flashing frame 0 right before it jumps
    // forward. _resumeCoverSafetyTimer is the backstop if the resume seek
    // itself never lands.
    if (!_started &&
        (playing || _engine.position > Duration.zero) &&
        _progress.isResumeDone) {
      _resumeCoverSafetyTimer?.cancel();
      _started = true;
      needsRebuild = true;
    }

    // Guarded like the heartbeat above: mid-transition the engine can still
    // report the outgoing episode's high position against a _progress
    // already reassigned to the incoming one, which would immediately roll
    // it forward again and skip an episode in Continue Watching — the same
    // failure mode as the web player's equivalent bug.
    if (playing && !_transitioningEpisode) _progress.maybeClear(_engine);

    if (playing != _lastPlaying) {
      _lastPlaying = playing;
      needsRebuild = true;
    }
    final buffering = _engine.buffering;
    if (buffering != _lastBuffering) {
      _lastBuffering = buffering;
      needsRebuild = true;
    }
    // Only real state changes rebuild the screen. The seek bar tracks the
    // position on its own via engine.positionStream (see _controls()), so a
    // 4 Hz position tick no longer rebuilds the transport UI.
    if (needsRebuild) setState(() {});
  }

  // Engine reported a playback error (bad URL, codec, repeated segment
  // failures). Many are transient and recover — hold for a grace window
  // before surfacing a blocking overlay.
  void _onEngineError(String msg) {
    // See profile_lease_conflict.dart: a lease held by another device
    // surfaces here as generic proxy-409 error text. Unlike a transient
    // decode/network error, this never self-recovers on its own (the lease
    // stays elsewhere until someone explicitly takes it back), so it skips
    // the grace window entirely and goes straight to the take-over prompt —
    // no "Riprova", no watchdog, ever, for this one.
    if (looksLikeProfileLeaseConflict(msg)) {
      _onPlaybackTakenOver('');
      return;
    }
    _errorGrace?.cancel();
    _errorGrace = Timer(kErrorGraceDuration, () {
      if (mounted && !_engine.playing) {
        setState(() => _playbackError = msg);
      }
    });
  }

  // Contract "One device playing per profile": another device took over.
  // Learned either via a 409 from the proxy (_onEngineError above) or via
  // playback_elsewhere on this device's own next UpdateProgress
  // (PlaybackProgress.onPlaybackElsewhere, every 15s heartbeat). No
  // automatic retry/watchdog/take-back, ever — only the user's own explicit
  // "Riprendi qui" gets playback back on this device.
  void _onPlaybackTakenOver(String playingOn) {
    if (!mounted || _takeoverPrompt != null) return;
    _errorGrace?.cancel();
    _liveWatchdog?.disarm();
    final resumePos = _engine.position;
    _engine.pause();
    // Best-effort — records exactly where this device stopped (mainly
    // matters for the 409 path, which never got to save anything; the
    // playback_elsewhere path already saved this same position as part of
    // the very heartbeat that revealed it).
    _saveProgressGuarded();
    setState(() {
      _playbackError = null;
      _takeoverPrompt = _TakeoverPrompt(
        message: playingOn.isNotEmpty
            ? 'Riproduzione spostata su «$playingOn».'
            : 'Questo profilo è ora in riproduzione su un altro dispositivo.',
        actionLabel: 'Riprendi qui',
        backLabel: 'Esci',
        onAction: () {
          // A fresh _progress (same episode, but re-armed to resume-seek at
          // resumePos instead of wherever _resumeSeek's own target already
          // landed/confirmed long ago) — same reasoning as an episode
          // switch's own _progress rebuild, just with this position instead
          // of 0.
          _progress = PlaybackProgress(
              args: _currentArgs(seekTo: resumePos.inSeconds),
              mediaId: _curMediaId,
              onPlaybackElsewhere: _onPlaybackTakenOver);
          setState(() {
            _takeoverPrompt = null;
            _opened = false;
            _started = false;
          });
          _armResumeCoverSafetyTimer();
          context.read<PlaybackBloc>().add(InitializeVideoEvent(
                pluginId: widget.args.epPluginId,
                mediaId: _curMediaId,
                preferredLabel: _curSourceLabel,
                startPositionSec: resolveStartPositionSec(
                    isLive: widget.args.isLive, seekTo: resumePos.inSeconds),
                takeOver: true,
              ));
        },
      );
    });
  }

  // Backstop for _onEngine's own resume-confirmation gate on _started: if
  // the resume seek/confirmation never lands (dropped seek, no more
  // position ticks), don't leave the loading cover up forever. Cancelled
  // early in _onEngine the moment _started actually flips on its own.
  void _armResumeCoverSafetyTimer() {
    _resumeCoverSafetyTimer?.cancel();
    _resumeCoverSafetyTimer = Timer(kResumeCoverSafetyTimeout, () {
      if (mounted && !_started) setState(() => _started = true);
    });
  }

  Future<void> _onReady(PlaybackReady s) async {
    if (_opened) return;
    _opened = true;
    _ensureEngineInitialized();
    _skipIntervals = parseSkipTimes(s.extra['skip_times']);
    _activeSkip = null;
    _skipDismissed = false;
    _progress.onStreamOpened();
    _armResumeCoverSafetyTimer();
    await _engine.open(s.resolvedUrl,
        headers: s.httpHeaders, startPosition: _progress.pendingStartPosition);
    _progress.markStarted(_engine);
    // The cold path's counterpart to the warm path's own clear in
    // _resolveEpisodeAt — this is the "new stream confirmed open" signal
    // for whichever path actually ran.
    _transitioningEpisode = false;
  }

  void _retry() {
    _errorGrace?.cancel();
    final bloc = context.read<PlaybackBloc>();
    _progress.resetForRetry();
    setState(() {
      _playbackError = null;
      _opened = false;
    });
    // A direct-stream deep link (or an offline-downloads directUrl) only
    // applies to the title the screen was opened with — once the user has
    // moved to a later episode, retry has to re-resolve that episode's own
    // sources instead.
    final sameTitle = _curMediaId == widget.mediaId;
    final directUrl = sameTitle ? widget.args.directUrl : null;
    final direct = sameTitle ? widget.args.directStreamId : null;
    final startPositionSec = sameTitle
        ? resolveStartPositionSec(
            isLive: widget.args.isLive, seekTo: widget.args.seekTo)
        : 0.0;
    if (directUrl != null && directUrl.isNotEmpty) {
      bloc.add(UseDirectUrlEvent(
          url: directUrl, httpHeaders: widget.args.directUrlHeaders));
    } else if (direct != null && direct.isNotEmpty) {
      bloc.add(SelectStreamEvent(
          pluginId: widget.pluginId,
          streamId: direct,
          startPositionSec: startPositionSec));
    } else {
      bloc.add(InitializeVideoEvent(
        pluginId: widget.pluginId,
        mediaId: _curMediaId,
        preferredLabel: _curSourceLabel,
        startPositionSec: startPositionSec,
      ));
    }
  }

  void _seekBy(int secs) {
    final d = _engine.duration;
    var t = _engine.position + Duration(seconds: secs);
    if (t < Duration.zero) t = Duration.zero;
    if (d > Duration.zero && t > d) t = d;
    _engine.seek(t);
    _armAutoHide();
  }

  // ── Episode navigation ─────────────────────────────────────────────────────

  bool get _hasNextEpisode =>
      _curEpisodeIndex < _curEpisodeList.length - 1 ||
      (_curSeasonIndex < widget.args.allSeasonIds.length - 1 &&
          widget.args.allSeasonIds.isNotEmpty);

  bool get _hasPreviousEpisode =>
      _curEpisodeIndex > 0 ||
      (_curSeasonIndex > 0 && widget.args.allSeasonIds.isNotEmpty);

  // One-shot: rebuild the episode list when the launch path didn't pass one
  // — a Continue Watching tap carries only the single episode (parentId +
  // its own title), same gap the TV player already backfills for (see
  // playback_screen/view.dart's _resolveEpisodeListIfMissing). _curMediaId
  // here can be a resolved stream id rather than a bare episode id, so a
  // direct id match isn't guaranteed — falls back to title, then a loose
  // substring match.
  Future<void> _resolveEpisodeListIfMissing() async {
    if (widget.args.isLive ||
        _curEpisodeList.isNotEmpty ||
        widget.args.parentId.isEmpty) {
      return;
    }
    final target = (_curTitle ?? '').trim().toLowerCase();
    final cacheKey = '${widget.args.epPluginId} ${widget.args.parentId}';
    final cached = playbackEpisodeCache[cacheKey];
    if (cached != null && cached.length >= 2) {
      _applyResolvedEpisodes(cached, target);
      return;
    }
    try {
      final repo = getIt<MediaRepository>();
      final res =
          await repo.browse(widget.args.epPluginId, widget.args.parentId, '');
      if (!mounted) return;

      var eps = <({
        String id,
        String title,
        String thumb,
        int episodeNumber,
        int seasonNumber
      })>[];
      if (res.episodes.isNotEmpty) {
        eps = [
          for (final e in res.episodes)
            (
              id: e.id,
              title: e.title,
              thumb: e.thumbnailUrl,
              episodeNumber: e.episodeNumber,
              seasonNumber: e.seasonNumber,
            )
        ];
      } else {
        eps = [
          for (final e in res.items)
            if (!e.isDir)
              (
                id: e.id,
                title: e.title,
                thumb: e.posterUrl,
                episodeNumber: e.episodeNumber,
                seasonNumber: e.seasonNumber,
              ),
        ];
      }

      // The parent may itself be a list of season directories — walk a
      // bounded number of them looking for one whose episode titles match.
      if (eps.length < 2) {
        final seasonDirs = res.items.where((i) => i.isDir).toList();
        for (final s in seasonDirs.take(8)) {
          if (!mounted) return;
          final sr = await repo.browse(widget.args.epPluginId, s.id, '');
          final se = sr.episodes.isNotEmpty
              ? [
                  for (final e in sr.episodes)
                    (
                      id: e.id,
                      title: e.title,
                      thumb: e.thumbnailUrl,
                      episodeNumber: e.episodeNumber,
                      seasonNumber: e.seasonNumber,
                    )
                ]
              : [
                  for (final e in sr.items)
                    if (!e.isDir)
                      (
                        id: e.id,
                        title: e.title,
                        thumb: e.posterUrl,
                        episodeNumber: e.episodeNumber,
                        seasonNumber: e.seasonNumber,
                      ),
                ];
          if (se.length > 1 &&
              (target.isEmpty ||
                  se.any((e) => e.title.trim().toLowerCase() == target))) {
            eps = se;
            break;
          }
        }
      }

      if (!mounted || eps.length < 2) return;
      playbackEpisodeCache[cacheKey] = eps;
      _applyResolvedEpisodes(eps, target);
    } catch (_) {
      // ignore — no next-episode nav this session
    }
  }

  void _applyResolvedEpisodes(
      List<
              ({
                String id,
                String title,
                String thumb,
                int episodeNumber,
                int seasonNumber
              })>
          eps,
      String target) {
    if (!mounted) return;
    var idx = eps.indexWhere((e) => e.id == _curMediaId);
    if (idx < 0 && target.isNotEmpty) {
      idx = eps.indexWhere((e) => e.title.trim().toLowerCase() == target);
    }
    if (idx < 0) {
      idx =
          eps.indexWhere((e) => e.id.length >= 8 && _curMediaId.contains(e.id));
    }
    if (idx < 0) return;
    setState(() {
      _curEpisodeList = [for (final e in eps) e.id];
      _curEpisodeTitles = [for (final e in eps) e.title];
      _curEpisodeThumbs = [for (final e in eps) e.thumb];
      _curEpisodeNumbers = [for (final e in eps) e.episodeNumber];
      _curSeasonNumbers = [for (final e in eps) e.seasonNumber];
      _curEpisodeIndex = idx;
    });
  }

  void _onPosition(Duration pos) {
    if (!mounted) return;
    _liveWatchdog?.recordProgress();
    if (widget.args.isLive) return;

    final active = activeSkipInterval(_skipIntervals, pos);
    if (active != _activeSkip) {
      setState(() {
        _activeSkip = active;
        if (active != null) _skipDismissed = false;
      });
    }

    final dur = _engine.duration;
    if (dur.inSeconds <= kMinDurationForEndOfEpisodeLogicSec) return;

    // Warm the next episode (stream + fresh metadata) once we're most of
    // the way through this one — same-season only, a season-boundary next
    // still resolves cold (rarer, and finding it needs its own browse()).
    _prefetcher.maybeStart(
      position: pos,
      duration: dur,
      nextEpisodeId: _curEpisodeIndex + 1 < _curEpisodeList.length
          ? _curEpisodeList[_curEpisodeIndex + 1]
          : null,
      currentSourceLabel: _curSourceLabel,
      nextEpisodeFallbackTitle: _curEpisodeIndex + 1 < _curEpisodeTitles.length
          ? _curEpisodeTitles[_curEpisodeIndex + 1]
          : null,
    );

    if (!_hasNextEpisode) return;
    final remaining = dur.inSeconds - pos.inSeconds;
    if (remaining > 0 &&
        remaining <= kNextEpisodeBannerWindowSec &&
        !_nextEpisodeDismissed) {
      if (_nextEpisodeSecs != remaining) {
        setState(() => _nextEpisodeSecs = remaining);
      }
    } else if (_nextEpisodeSecs != null) {
      setState(() => _nextEpisodeSecs = null);
    }
    if (remaining <= 0 && !_autoAdvanced && !_resolvingEpisode) {
      _autoAdvanced = true;
      _goToNextEpisode();
    }
  }

  Future<void> _goToNextEpisode() async {
    if (_resolvingEpisode || !_hasNextEpisode) return;
    _errorGrace?.cancel();
    setState(() {
      _resolvingEpisode = true;
      _nextEpisodeSecs = null;
    });
    try {
      await _resolveEpisodeAt(_curEpisodeIndex + 1, _curEpisodeList,
          _curEpisodeTitles, _curSeasonIndex);
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvingEpisode = false;
          _playbackError = 'Impossibile cambiare episodio: $e';
        });
      }
    }
  }

  Future<void> _goToPreviousEpisode() async {
    if (_resolvingEpisode || !_hasPreviousEpisode) return;
    _errorGrace?.cancel();
    setState(() {
      _resolvingEpisode = true;
      _nextEpisodeSecs = null;
    });
    try {
      await _resolveEpisodeAt(_curEpisodeIndex - 1, _curEpisodeList,
          _curEpisodeTitles, _curSeasonIndex);
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvingEpisode = false;
          _playbackError = 'Impossibile cambiare episodio: $e';
        });
      }
    }
  }

  Future<void> _resolveEpisodeAt(
    int newIndex,
    List<String> episodeList,
    List<String> episodeTitles,
    int seasonIndex,
  ) async {
    final repo = getIt<MediaRepository>();

    if (newIndex < 0 || newIndex >= episodeList.length) {
      // Season boundary, either direction: newIndex < 0 steps back a season
      // (landing on its last episode), past the end steps forward one.
      final allSeasonIds = widget.args.allSeasonIds;
      final newSeasonIndex = newIndex < 0 ? seasonIndex - 1 : seasonIndex + 1;
      if (allSeasonIds.isEmpty ||
          newSeasonIndex < 0 ||
          newSeasonIndex >= allSeasonIds.length) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      // Timeout: this await isn't inside its own try/catch, only the outer
      // one in _goToNextEpisode/_goToPreviousEpisode — which catches a
      // thrown error fine, but not a hang (nothing would ever throw, the
      // spinner would just never clear). Same reasoning as the calls below.
      final browseRes = await repo
          .browse(widget.args.epPluginId, allSeasonIds[newSeasonIndex], '')
          .timeout(const Duration(seconds: 20));
      // Same episodes-first, items-as-fallback pattern the TV player uses
      // (playback_screen/view.dart) — a season-directory browse returns real
      // episode data (title, thumbnail, …) in `episodes`; mycelium only
      // routes media tagged as an episode there (see mycelium-core's
      // lua_pipeline.go:Browse), `items` holds everything else. Reading
      // `items` directly (as this used to) got an empty-or-wrong list for a
      // properly-tagged season, producing a Continue Watching entry with a
      // generic title and no poster once the auto-advance/roll-forward write
      // fired for it. This path only became reachable once
      // mobile_details_screen.dart started actually populating
      // allSeasonIds/allSeasonLabels, so it went unnoticed until a
      // multi-season binge crossed a season boundary for the first time.
      final newEpisodes = browseRes.episodes.isNotEmpty
          ? [
              for (final e in browseRes.episodes)
                (
                  id: e.id,
                  title: e.title,
                  thumb: e.thumbnailUrl,
                  episodeNumber: e.episodeNumber,
                  seasonNumber: e.seasonNumber,
                )
            ]
          : [
              for (final i in browseRes.items)
                if (!i.isDir)
                  (
                    id: i.id,
                    title: i.title,
                    thumb: i.posterUrl,
                    episodeNumber: i.episodeNumber,
                    seasonNumber: i.seasonNumber,
                  ),
            ];
      if (newEpisodes.isEmpty) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      final newIds = newEpisodes.map((e) => e.id).toList();
      final newTitles = newEpisodes.map((e) => e.title).toList();
      final newThumbs = newEpisodes.map((e) => e.thumb).toList();
      final newEpNums = newEpisodes.map((e) => e.episodeNumber).toList();
      final newSeasonNums = newEpisodes.map((e) => e.seasonNumber).toList();
      if (mounted) {
        setState(() {
          _curEpisodeList = newIds;
          _curEpisodeTitles = newTitles;
          _curEpisodeThumbs = newThumbs;
          _curEpisodeNumbers = newEpNums;
          _curSeasonNumbers = newSeasonNums;
          _curSeasonIndex = newSeasonIndex;
        });
      }
      final targetIndex = newIndex < 0 ? newIds.length - 1 : 0;
      await _resolveEpisodeAt(targetIndex, newIds, newTitles, newSeasonIndex);
      return;
    }

    final newMediaId = episodeList[newIndex];
    final newTitle =
        newIndex < episodeTitles.length ? episodeTitles[newIndex] : null;

    // Warm path: this exact episode was already resolved in the background
    // near the end of the previous one (see episode_prefetch.dart) — skip
    // getStreams/resolveStream entirely and open the cached URL directly,
    // bypassing PlaybackBloc so there's no ResolvingMediaStream spinner
    // flash in between.
    final prefetched = _prefetcher.cached;
    if (prefetched != null && prefetched.mediaId == newMediaId) {
      final url = prefetched.resolvedUrl;
      final headers = prefetched.httpHeaders;
      final sourceLabel = prefetched.sourceLabel;
      final title = prefetched.title;
      final rating = prefetched.rating;
      final durationSeconds = prefetched.durationSeconds;
      final year = prefetched.year;
      final skipTimes = prefetched.skipTimesJson;
      _prefetcher.clear();
      // Final save for the outgoing episode, using the engine's position
      // exactly as it still is right now — must run before stop() (which
      // zeroes it) and before _progress gets reassigned below. See
      // _transitioningEpisode's doc: set right after, not any earlier, so
      // the normal heartbeat keeps covering the outgoing episode for as long
      // as it's genuinely still playing (this warm path is fast, but the
      // cold path below can spend up to ~20s resolving before it gets here).
      _saveProgressGuarded();
      _transitioningEpisode = true;
      _engine.stop();
      setState(() {
        _curEpisodeIndex = newIndex;
        _curMediaId = newMediaId;
        _curSourceLabel = sourceLabel;
        _curTitle = title ?? newTitle ?? _curTitle;
        _curRating = rating;
        _curDurationSeconds = durationSeconds;
        _curYear = year;
        // This path bypasses PlaybackReady entirely (see the comment above),
        // which is the only other place these get set — without this, skip
        // markers would either keep showing the previous episode's markers
        // or (worse) silently do nothing for every prefetched transition.
        _skipIntervals = parseSkipTimes(skipTimes);
        _activeSkip = null;
        _skipDismissed = false;
        _opened = true;
        _started = false;
        _resolvingEpisode = false;
        _autoAdvanced = false;
        _nextEpisodeDismissed = false;
        _playbackError = null;
      });
      _progress = PlaybackProgress(
          args: _currentArgs(),
          mediaId: newMediaId,
          onPlaybackElsewhere: _onPlaybackTakenOver);
      _progress.onStreamOpened();
      _armResumeCoverSafetyTimer();
      await _engine.open(url,
          headers: headers, startPosition: _progress.pendingStartPosition);
      if (mounted) _progress.markStarted(_engine);
      _transitioningEpisode = false;
      return;
    }
    _prefetcher.clear();

    // Cold path: fetch the stream sources and this episode's own rating/
    // duration/year in parallel — those still come from GetDetails (poster
    // is now episodeThumbs[index]/seriesPoster, see episode_poster.dart;
    // plot is always the series' own, see PlaybackArgs.copyWith).
    //
    // Both timed: `.timeout()` on streamsFuture surfaces as a thrown
    // TimeoutException, caught by the try/catch around this whole call in
    // _goToNextEpisode/_goToPreviousEpisode (clears _resolvingEpisode, shows
    // an error) — without it, a hang here (not a thrown error, the RPC just
    // never returning) left the spinner on those buttons forever, nothing
    // in the call chain able to time it out on its own. urgent: true on
    // getDetails for the same reason as episode_popup.dart: a live Android
    // TV trace showed the non-urgent dedup/cache path stall
    // for 15-30+s past when the RPC itself had already answered — this is
    // the same "user is actively waiting" shape that fix targeted.
    final streamsFuture = repo
        .getStreams(widget.args.epPluginId, newMediaId)
        .timeout(const Duration(seconds: 20));
    DetailsResponse? details;
    try {
      details = await repo
          .getDetails(widget.args.epPluginId, newMediaId, urgent: true)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // metadata is a nice-to-have — a stream that still resolves is what
      // actually matters here. Already catches a timeout too.
    }
    final streamsRes = await streamsFuture;
    final sources = streamsRes.sources;

    // Prefer the same source label already playing; fall back to the first
    // source rather than bouncing out to an episode picker mid-binge.
    final match = (_curSourceLabel.isEmpty
            ? null
            : sources
                .where((s) =>
                    s.label.toLowerCase() == _curSourceLabel.toLowerCase())
                .firstOrNull) ??
        (sources.isNotEmpty ? sources.first : null);

    if (!mounted) return;

    if (match != null) {
      final ep =
          (details != null && details.hasEpisode()) ? details.episode : null;
      // Same reasoning as the warm path above — final save + set the flag
      // right before stop(), not any earlier (the getStreams/getDetails
      // fetches just above can take up to ~20s, during which the outgoing
      // episode is still genuinely playing and should keep being
      // heartbeat-saved normally).
      _saveProgressGuarded();
      _transitioningEpisode = true;
      _engine.stop();
      setState(() {
        _curEpisodeIndex = newIndex;
        _curMediaId = newMediaId;
        _curSourceLabel = match.label;
        _curTitle = (details != null && details.item.title.isNotEmpty)
            ? details.item.title
            : (newTitle ?? _curTitle);
        _curRating = (ep != null && ep.vote > 0) ? ep.vote : null;
        _curDurationSeconds =
            (ep != null && ep.duration > 0) ? ep.duration * 60 : null;
        _curYear = (details != null && details.item.year > 0)
            ? details.item.year
            : null;
        // The upcoming PlaybackReady's own _onReady handler repopulates
        // these from that episode's own extra['skip_times'] — reset now so
        // the previous episode's markers can't briefly linger/mismatch.
        _skipIntervals = const [];
        _activeSkip = null;
        _skipDismissed = false;
        _opened = false;
        _resolvingEpisode = false;
        _autoAdvanced = false;
        _nextEpisodeDismissed = false;
        _playbackError = null;
      });
      _progress = PlaybackProgress(
          args: _currentArgs(),
          mediaId: newMediaId,
          onPlaybackElsewhere: _onPlaybackTakenOver);
      context.read<PlaybackBloc>().add(
            SelectStreamEvent(
                pluginId: widget.args.epPluginId, streamId: match.id),
          );
    } else {
      setState(() => _resolvingEpisode = false);
      _engine.stop();
      context.pushReplacement(
        '/episode/${widget.args.epPluginId}/${Uri.encodeComponent(newMediaId)}',
        extra: {
          'episodeList': episodeList,
          'episodeTitles': episodeTitles,
          'episodeThumbs': _curEpisodeThumbs,
          'episodeNumbers': _curEpisodeNumbers,
          'seasonNumbers': _curSeasonNumbers,
          'episodeIndex': newIndex,
          'allSeasonIds': widget.args.allSeasonIds,
          'allSeasonLabels': widget.args.allSeasonLabels,
          'seasonIndex': _curSeasonIndex,
          'sourceLabel': _curSourceLabel,
          'showTitle': widget.args.showTitle,
          'parentId': widget.args.parentId,
        },
      );
    }
  }

  /// [widget.args] rebuilt around the episode currently playing — so
  /// [_progress]'s continue-watching / remembered-audio-language logic
  /// (which reads `args.episodeIndex`/`episodeList`/`mediaId`) stays correct
  /// after switching episodes in place. `plot` has no override here at all
  /// (see PlaybackArgs.copyWith) — Continue Watching always shows the
  /// series' own synopsis.
  ///
  /// [seekTo] defaults to 0 (a new episode always starts from the top); the
  /// one exception is _onPlaybackTakenOver's "Riprendi qui", which passes
  /// the position playback stopped at — same episode, so [_progress] must
  /// still resume-seek there instead of opening at 0.
  PlaybackArgs _currentArgs({int seekTo = 0}) => widget.args.copyWith(
        title: _curTitle,
        episodeList: _curEpisodeList,
        episodeTitles: _curEpisodeTitles,
        episodeThumbs: _curEpisodeThumbs,
        episodeNumbers: _curEpisodeNumbers,
        seasonNumbers: _curSeasonNumbers,
        episodeIndex: _curEpisodeIndex,
        sourceLabel: _curSourceLabel,
        seasonIndex: _curSeasonIndex,
        seekTo: seekTo,
        poster: posterForEpisode(
          episodeThumbs: _curEpisodeThumbs,
          index: _curEpisodeIndex,
          seriesCoverUrl: widget.args.seriesCoverUrl,
          seriesPoster: widget.args.seriesPoster,
          fallback: widget.args.poster,
        ),
        rating: _curRating,
        durationSeconds: _curDurationSeconds,
        year: _curYear,
      );

  void _armAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _armAutoHide();
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocListener<PlaybackBloc, PlaybackState>(
        listener: (context, s) {
          if (s is PlaybackReady) _onReady(s);
          // A resolve failure after _resolveEpisodeAt's cold path already
          // set _transitioningEpisode (stream resolution errored out before
          // ever reaching PlaybackReady/_onReady, which is otherwise the
          // only place that clears it) must not leave the heartbeat/dispose
          // save disabled for the rest of the session.
          if (s is PlaybackFailed) _transitioningEpisode = false;
          if (s is PlaybackPlayingElsewhere) {
            _transitioningEpisode = false;
            setState(() {
              _takeoverPrompt = _TakeoverPrompt(
                message: s.message,
                actionLabel: 'Guarda qui',
                backLabel: 'Annulla',
                onAction: () {
                  setState(() => _takeoverPrompt = null);
                  context.read<PlaybackBloc>().add(SelectStreamEvent(
                        pluginId: s.pluginId,
                        streamId: s.streamId,
                        startPositionSec: s.startPositionSec,
                        takeOver: true,
                      ));
                },
              );
            });
          }
        },
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Center(
                  child: _videoView ??= _engine.buildView(),
                ),
              ),
              BlocBuilder<PlaybackBloc, PlaybackState>(
                builder: (context, s) {
                  final Widget child;
                  if (_takeoverPrompt != null) {
                    child = KeyedSubtree(
                      key: const ValueKey('takeover'),
                      child: _TakeoverOverlay(
                          prompt: _takeoverPrompt!, onBack: _exit),
                    );
                  } else if (_playbackError != null) {
                    child = KeyedSubtree(
                      key: const ValueKey('error'),
                      child: _ErrorOverlay(
                        message: _playbackError!,
                        onBack: _exit,
                        onRetry: _retry,
                      ),
                    );
                  } else if (s is PlaybackFailed) {
                    child = KeyedSubtree(
                      key: const ValueKey('error'),
                      child: _ErrorOverlay(
                        message: s.errorMessage,
                        onBack: _exit,
                        onRetry: _retry,
                      ),
                    );
                  } else if (s is! PlaybackReady || !_started) {
                    // Loading: only the spinner (dead-centre) + a back
                    // button — no transport controls competing for the
                    // centre of the screen. Stays up through the open()/
                    // first-decode gap (which now also covers the resume
                    // seek landing, not just the first decoded frame — see
                    // _onEngine's own _started gate).
                    child = KeyedSubtree(
                      key: const ValueKey('loading'),
                      child: _LoadingOverlay(state: s, onBack: _exit),
                    );
                  } else {
                    // One key ('ready') for both sub-states below — toggling
                    // _controlsVisible must stay the instant show/hide it
                    // always was, not get pulled into the cover-reveal
                    // crossfade this AnimatedSwitcher exists for.
                    child = KeyedSubtree(
                      key: const ValueKey('ready'),
                      child: _controlsVisible
                          ? _controls()
                          : const SizedBox.shrink(),
                    );
                  }
                  // One crossfade for the whole cover→ready transition
                  // (loading/error → controls) — see kResumeCoverSafetyTimeout
                  // and _onEngine's _started gate for what "ready" waits on.
                  return Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: child,
                    ),
                  );
                },
              ),
              if (_activeSkip != null && !_skipDismissed)
                Positioned(
                  right: 16,
                  bottom: 84,
                  child: SafeArea(
                    child: Builder(builder: (_) {
                      final outroToNext = _activeSkip!.type == SkipType.ed &&
                          _hasNextEpisode &&
                          !_resolvingEpisode;
                      return PointerSkipButton(
                        label: outroToNext
                            ? 'Prossimo episodio'
                            : _activeSkip!.label,
                        icon: outroToNext
                            ? Icons.skip_next_rounded
                            : Icons.fast_forward_rounded,
                        onSkip: () {
                          if (outroToNext) {
                            setState(() => _skipDismissed = true);
                            _autoAdvanced = true;
                            _goToNextEpisode();
                          } else {
                            _engine.seek(Duration(
                                milliseconds:
                                    (_activeSkip!.end * 1000).toInt()));
                            setState(() => _skipDismissed = true);
                          }
                        },
                        onDismiss: () => setState(() => _skipDismissed = true),
                      );
                    }),
                  ),
                ),
              if (_nextEpisodeSecs != null)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    child: _MobileNextEpisodeBanner(
                      secondsRemaining: _nextEpisodeSecs!,
                      onSkip: () {
                        _autoAdvanced = true;
                        _goToNextEpisode();
                      },
                      onDismiss: () => setState(() {
                        _nextEpisodeDismissed = true;
                        _nextEpisodeSecs = null;
                      }),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    final title = widget.args.showTitle.isNotEmpty
        ? '${widget.args.showTitle} · ${_curTitle ?? ''}'
        : (_curTitle ?? '');

    return Container(
      color: Colors.black38,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _exit,
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                if (_hasPreviousEpisode)
                  IconButton(
                    icon: _resolvingEpisode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.skip_previous_rounded,
                            color: Colors.white),
                    tooltip: 'Episodio precedente',
                    onPressed: _resolvingEpisode ? null : _goToPreviousEpisode,
                  ),
                if (_hasNextEpisode)
                  IconButton(
                    icon: _resolvingEpisode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.skip_next_rounded,
                            color: Colors.white),
                    tooltip: 'Episodio successivo',
                    onPressed: _resolvingEpisode
                        ? null
                        : () {
                            _autoAdvanced = true;
                            _goToNextEpisode();
                          },
                  ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  tooltip: 'Video, audio e sottotitoli',
                  onPressed: _showTracksSheet,
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!widget.args.isLive)
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.replay_10_rounded,
                        color: Colors.white),
                    onPressed: () => _seekBy(-10),
                  ),
                IconButton(
                  iconSize: 64,
                  icon: Icon(
                    _engine.playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _engine.playOrPause();
                    _armAutoHide();
                  },
                ),
                if (!widget.args.isLive)
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.forward_10_rounded,
                        color: Colors.white),
                    onPressed: () => _seekBy(10),
                  ),
              ],
            ),
            const Spacer(),
            if (!widget.args.isLive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // Scoped rebuild: only the seek bar tracks the ~4 Hz
                // position tick, not the whole transport UI.
                child: StreamBuilder<Duration>(
                  stream: _engine.positionStream,
                  initialData: _engine.position,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = _engine.duration;
                    return PlayerSeekBar(
                      posSec: pos.inMilliseconds / 1000.0,
                      durSec: dur.inMilliseconds > 0
                          ? dur.inMilliseconds / 1000.0
                          : 1.0,
                      skipIntervals: _skipIntervals,
                      focusNode: _seekBarFocusNode,
                      onSeek: (v) {
                        _engine
                            .seek(Duration(milliseconds: (v * 1000).round()));
                        _armAutoHide();
                      },
                      onActivity: _armAutoHide,
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTracksSheet() {
    _hideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141428),
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // The player route can be torn down (session expiry) while this
          // sheet is open — don't call into a disposed engine.
          if (!mounted) return const SizedBox.shrink();
          final video = _engine.videoTracks;
          final audio = _engine.audioTracks;
          final subs = _engine.subtitleTracks;
          Widget tile(String label, bool selected, VoidCallback onTap) =>
              ListTile(
                dense: true,
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppTheme.primary : Colors.white38,
                  size: 20,
                ),
                title: Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () {
                  onTap();
                  setSheet(() {});
                },
              );
          final nothing = video.length < 2 && audio.length < 2 && subs.isEmpty;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (nothing)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nessuna traccia alternativa per questo stream.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                if (video.length > 1) ...[
                  const _SheetHeader('Qualità video'),
                  for (final t in video)
                    tile(t.label, t.id == _engine.activeVideoTrack?.id,
                        () => _engine.selectVideoTrack(t)),
                ],
                if (audio.length > 1) ...[
                  const _SheetHeader('Audio'),
                  for (final t in audio)
                    tile(t.label, t.id == _engine.activeAudioTrack?.id, () {
                      _engine.selectAudioTrack(t);
                      // Remember this choice so a later resume (or the next
                      // episode) keeps the same language instead of falling
                      // back to the device locale.
                      _progress.rememberAudioTrack(t.label);
                    }),
                ],
                if (subs.isNotEmpty) ...[
                  const _SheetHeader('Sottotitoli'),
                  tile('Nessuno', _engine.activeSubtitleTrack == null,
                      () => _engine.selectSubtitleTrack(null)),
                  for (final t in subs)
                    tile(t.label, t.id == _engine.activeSubtitleTrack?.id,
                        () => _engine.selectSubtitleTrack(t)),
                ],
              ],
            ),
          );
        },
      ),
    ).whenComplete(_armAutoHide);
  }
}

class _SheetHeader extends StatelessWidget {
  final String text;
  const _SheetHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .8)),
      );
}

class _LoadingOverlay extends StatelessWidget {
  final PlaybackState state;
  final VoidCallback onBack;
  const _LoadingOverlay({required this.state, required this.onBack});

  @override
  Widget build(BuildContext context) {
    String label = 'Caricamento…';
    if (state is FetchingStreams) label = 'Ricerca sorgenti…';
    if (state is ResolvingMediaStream) label = 'Risoluzione stream…';
    if (state is PlaybackResolveProgress) {
      label = (state as PlaybackResolveProgress).message;
    }
    if (state is PlaybackRetrying) {
      final r = state as PlaybackRetrying;
      label = 'Nuovo tentativo ${r.attempt}/${r.of}…';
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  final VoidCallback? onRetry;
  const _ErrorOverlay(
      {required this.message, required this.onBack, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFF5252), size: 48),
              const SizedBox(height: 14),
              const Text(
                'Riproduzione non riuscita',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white),
                      child: const Text('Indietro')),
                  if (onRetry != null) ...[
                    const SizedBox(width: 10),
                    FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Riprova')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Playback taken over by another device (contract "One device playing
// per profile") ──────────────────────────────────────────────────────────
// Pre-play ABORTED ("Guarda qui"/"Annulla") and mid-playback take-over
// ("Riprendi qui"/"Esci") share this one overlay, only the message/labels
// differ — see _onPlaybackTakenOver and the PlaybackPlayingElsewhere
// BlocListener branch above.

class _TakeoverPrompt {
  final String message;
  final String actionLabel;
  final String backLabel;
  final VoidCallback onAction;
  const _TakeoverPrompt({
    required this.message,
    required this.actionLabel,
    required this.backLabel,
    required this.onAction,
  });
}

class _TakeoverOverlay extends StatelessWidget {
  final _TakeoverPrompt prompt;
  final VoidCallback onBack;
  const _TakeoverOverlay({required this.prompt, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.devices_rounded,
                  color: Colors.white70, size: 48),
              const SizedBox(height: 14),
              Text(prompt.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white),
                      child: Text(prompt.backLabel)),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                      onPressed: prompt.onAction,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(prompt.actionLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNextEpisodeBanner extends StatelessWidget {
  final int secondsRemaining;
  final VoidCallback onSkip;
  final VoidCallback onDismiss;
  const _MobileNextEpisodeBanner({
    required this.secondsRemaining,
    required this.onSkip,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF2141428),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Prossimo episodio tra ${secondsRemaining}s',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onSkip,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Salta'),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
