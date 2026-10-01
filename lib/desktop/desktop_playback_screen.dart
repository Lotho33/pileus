import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

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
import '../features/player/episode_nav.dart';
import '../features/player/episode_poster.dart';
import '../features/player/episode_prefetch.dart';
import '../features/player/live_stall_watchdog.dart';
import '../features/player/models/playback_args.dart';
import '../features/player/models/skip_interval.dart';
import '../features/player/player_tuning.dart';
import '../features/player/resume_seek.dart' show resolveStartPositionSec;
import '../features/player/presentation/widgets/player_seek_bar.dart';
import '../features/player/presentation/widgets/pointer_next_episode_banner.dart';
import '../features/player/presentation/widgets/pointer_skip_button.dart';
import '../features/player/profile_lease_conflict.dart';
import '../features/settings/data/settings_repository.dart';
import '../shared/player/playback_progress.dart';

/// Desktop player: full-window video with a mouse-reveal control bar, a
/// right-side track panel and keyboard shortcuts. Reuses [PlaybackBloc] +
/// [PlayerEngine] (media_kit/libmpv on desktop) unchanged.
class DesktopPlaybackScreen extends StatelessWidget {
  final String pluginId;
  final String mediaId;
  final Map<String, dynamic>? extra;

  const DesktopPlaybackScreen({
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
      child: _View(pluginId: pluginId, mediaId: mediaId, args: args),
    );
  }
}

class _View extends StatefulWidget {
  final String pluginId;
  final String mediaId;
  final PlaybackArgs args;
  const _View(
      {required this.pluginId, required this.mediaId, required this.args});

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> with WindowListener {
  late final PlayerEngine _engine;
  late final SettingsRepository _settings;
  // NOT final — see _openEpisode below, which reassigns this around the new
  // episode's own args/mediaId on every switch (same as mobile). A stray
  // `final` here would throw a LateInitializationError the instant this
  // got reassigned, the moment episodes are switched on desktop.
  late PlaybackProgress _progress;
  final _focus = FocusNode();
  // Never actually keyboard-navigated on desktop today (mouse-driven), but
  // PlayerSeekBar requires one — see _ControlsLayer's build() for why reusing
  // that widget (instead of a plain Slider) is what draws the colored
  // skip-interval segments. canRequestFocus: false keeps arrow keys routed
  // to _focus's own ±10s seek shortcut exactly as before, never to this bar.
  final _seekBarFocusNode = FocusNode(canRequestFocus: false);

  bool _controls = true;
  bool _tracksPanel = false;
  bool _opened = false;
  bool _started = false; // first frame decoded — stop showing the spinner
  bool _fullscreen = false;
  bool _lastPlaying = false;
  bool _wakelockOn = false; // toggled only on a play/pause transition
  bool _lastBuffering = false;
  double _lastVolume = 100;
  DateTime? _lastWake;
  String? _error;
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
  // see kResumeCoverSafetyTimeout's doc. Re-armed on every open, cancelled
  // the moment _started actually flips on its own.
  Timer? _resumeCoverSafetyTimer;
  Widget? _videoView;

  // ── episode navigation / skip markers / prefetch / live watchdog ─────────
  // See episode_nav.dart/skip_interval.dart/live_stall_watchdog.dart. TV and
  // mobile keep their own separate copies of the same logic.
  late String _curMediaId = widget.mediaId;
  late String _curSourceLabel = widget.args.sourceLabel;
  late String _curTitle = widget.args.title ?? '';
  late final EpisodeNavState _nav = EpisodeNavState.fromArgs(widget.args);
  bool _resolvingEpisode = false;
  // True from the moment _openEpisode starts switching to a new episode
  // until the new stream is confirmed open (markStarted has run for it).
  // Guards the heartbeat/dispose save and maybeClear against firing in that
  // window: without it, a 15s tick or a dispose-on-exit landing while
  // _engine.stop() was still mid-reset — or _progress had already been
  // reassigned to the new episode but the engine hadn't caught up — wrote
  // the wrong identity/position pairing (audit finding).
  bool _transitioningEpisode = false;
  bool _autoAdvanced = false;
  bool _nextEpisodeDismissed = false;
  int? _nextEpisodeSecs;
  StreamSubscription<Duration>? _posSub;

  List<SkipInterval> _skipIntervals = const [];
  SkipInterval? _activeSkip;
  bool _skipDismissed = false;

  // Engine-agnostic and shared verbatim with mobile/TV/web — see
  // episode_prefetch.dart. Used to be a hand-copied algorithm per platform
  // (this file's own copy was the only one with the generation guard mobile
  // was missing, until that file was ported onto this same shared class).
  late final _prefetcher = EpisodePrefetcher(
      repo: getIt<MediaRepository>(), pluginId: widget.pluginId);

  // Fresh per-episode rating/duration/year once known — null means "nothing
  // fresher than widget.args yet", so _currentArgs() falls back to the
  // original launch value. Mirrors mobile_playback_screen.dart's
  // _curRating/_curDurationSeconds/_curYear — without these, every
  // continue-watching write past the first episode of a session would keep
  // reporting the *first* episode's rating/year forever.
  double? _curRating;
  int? _curDurationSeconds;
  int? _curYear;

  LiveStallWatchdog? _liveWatchdog;

  // ── lifecycle gating ─────────────────────────────────────────────────────
  // AppLifecycleReactor's class doc has long described this as the intended
  // behaviour ("the playback screens gate their heartbeat and keep-awake on
  // state") but no player screen actually did it. Desktop also has its own
  // WindowListener signal (window minimized) since AppLifecycleState isn't
  // reliably delivered on minimize under every Linux/Wayland compositor —
  // belt and suspenders, same _onLifecycle handles both.
  bool _windowMinimized = false;

  bool get _backgrounded =>
      _windowMinimized || AppLifecycleReactor.instance.isBackgrounded;

  void _onLifecycle() {
    if (!mounted) return;
    if (_backgrounded) {
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

  @override
  void initState() {
    super.initState();
    // Keep _fullscreen in sync when the WM/OS changes it out from under us
    // (F11, the title-bar button, a compositor shortcut) — otherwise the
    // fullscreen toggle icon and the Esc handling below drift out of step.
    windowManager.addListener(this);
    _settings = getIt<SettingsRepository>();
    _progress = PlaybackProgress(
        args: widget.args,
        mediaId: widget.mediaId,
        onPlaybackElsewhere: _onPlaybackTakenOver);

    var bufMiB = widget.args.isLive
        ? _settings.getLiveBufferMiB()
        : _settings.getPlayerBufferMiB();
    if (lowPowerUi) bufMiB = bufMiB.clamp(4, widget.args.isLive ? 10 : 16);

    _engine = PlayerEngine.create();
    _engine.onError = _onEngineError;
    _engine.addListener(_onEngine);
    _engine.initialize(
      PlayerSubtitleStyle(
        fontSize: _settings.getSubtitleFontSize(),
        color: _settings.getSubtitleColor(),
        backgroundEnabled: _settings.getSubtitleBgEnabled(),
        bottomPadding: _settings.getSubtitleBottomPadding(),
      ),
      isLive: widget.args.isLive,
      bufferMiB: bufMiB,
    );

    // isLive skips this on purpose even for the single-device-lease
    // heartbeat's sake — see PlaybackProgress's class doc
    // ("Why every screen's 15s heartbeat still skips live streams").
    if (!widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _saveProgressGuarded());
    }
    _posSub = _engine.positionStream.listen(_onPosition);
    if (widget.args.isLive) {
      _liveWatchdog = LiveStallWatchdog(
        isHealthy: () =>
            mounted &&
            _error == null &&
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
    _armAutoHide();
    AppLifecycleReactor.instance.state.addListener(_onLifecycle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void onWindowEnterFullScreen() {
    if (!_fullscreen && mounted) setState(() => _fullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (_fullscreen && mounted) setState(() => _fullscreen = false);
  }

  @override
  void onWindowMinimize() {
    _windowMinimized = true;
    _onLifecycle();
  }

  @override
  void onWindowRestore() {
    _windowMinimized = false;
    _onLifecycle();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    AppLifecycleReactor.instance.state.removeListener(_onLifecycle);
    _hideTimer?.cancel();
    _errorGrace?.cancel();
    _progressTimer?.cancel();
    _resumeCoverSafetyTimer?.cancel();
    _posSub?.cancel();
    _liveWatchdog?.disarm();
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
    _focus.dispose();
    _seekBarFocusNode.dispose();
    if (_fullscreen) {
      windowManager.setFullScreen(false).ignore();
    }
    try {
      _engine.removeListener(_onEngine);
      _engine.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ── engine ───────────────────────────────────────────────────────────────

  void _onEngine() {
    if (!mounted) return;
    final playing = _engine.playing;
    var rebuild = false;

    // Wakelock is a platform-channel call — flip it only when play/pause
    // actually changes, not on every 4 Hz engine tick.
    if (playing != _wakelockOn) {
      _wakelockOn = playing;
      playing ? WakelockPlus.enable() : WakelockPlus.disable();
    }

    if (playing) {
      if (_error != null) {
        _errorGrace?.cancel();
        _error = null;
        rebuild = true;
      }
      _progress.maybeApplyAudioPref(_engine);
      // Guarded like the heartbeat above: mid-transition the engine can
      // still report the outgoing episode's high position against a
      // _progress already reassigned to the incoming one, which would
      // immediately roll it forward again and skip an episode in Continue
      // Watching — the same failure mode as the web player's equivalent bug.
      if (!_transitioningEpisode) _progress.maybeClear(_engine);
    }
    _progress.maybeResumeSeek(_engine);

    // Gated on the resume seek being done too (confirmed landed, or never
    // applicable), not just "some position/playing arrived" — otherwise the
    // spinner cover could lift on a tick that's still ~0 while the resume
    // seek above is in flight, flashing frame 0 right before it jumps
    // forward. _resumeCoverSafetyTimer (armed in _onReady/the episode-switch
    // paths) is the backstop if the resume seek itself never lands.
    if (!_started &&
        (playing || _engine.position > Duration.zero) &&
        _progress.isResumeDone) {
      _resumeCoverSafetyTimer?.cancel();
      _started = true;
      rebuild = true;
    }
    if (playing != _lastPlaying) {
      _lastPlaying = playing;
      rebuild = true;
    }
    final buffering = _engine.buffering;
    if (buffering != _lastBuffering) {
      _lastBuffering = buffering;
      rebuild = true;
    }
    // Only real state changes rebuild the screen. The seek bar tracks the
    // position on its own via engine.positionStream (see _ControlsLayer),
    // so a 4 Hz position tick no longer rebuilds the whole control tree.
    if (rebuild) setState(() {});
  }

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
      if (mounted && !_engine.playing) setState(() => _error = msg);
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
      _error = null;
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
  // position ticks), don't leave the spinner cover up forever. Cancelled
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
    // Fires for both the very first stream and every subsequent episode
    // (see _openEpisode's cold path, which dispatches SelectStreamEvent and
    // resets _opened) — so skip markers refresh per-episode for free.
    setState(() {
      _skipIntervals = parseSkipTimes(s.extra['skip_times']);
      _activeSkip = null;
      _skipDismissed = false;
    });
    _progress.onStreamOpened();
    _armResumeCoverSafetyTimer();
    await _engine.open(s.resolvedUrl,
        headers: s.httpHeaders, startPosition: _progress.pendingStartPosition);
    _progress.markStarted(_engine);
    // The cold path's counterpart to the warm path's own clear in
    // _openEpisode — this is the "new stream confirmed open" signal for
    // whichever path actually ran.
    _transitioningEpisode = false;
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

    // Warm the next episode once we're most of the way through this one —
    // same-season only; a season-boundary next still resolves cold.
    _prefetcher.maybeStart(
      position: pos,
      duration: dur,
      nextEpisodeId: _nav.episodeIndex + 1 < _nav.episodeList.length
          ? _nav.episodeList[_nav.episodeIndex + 1]
          : null,
      currentSourceLabel: _curSourceLabel,
      nextEpisodeFallbackTitle:
          _nav.episodeIndex + 1 < _nav.episodeTitles.length
              ? _nav.episodeTitles[_nav.episodeIndex + 1]
              : null,
    );

    if (!_nav.hasNext) return;
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

  // ── episode navigation ─────────────────────────────────────────────────

  Future<void> _goToNextEpisode() async {
    if (_resolvingEpisode || !_nav.hasNext) return;
    _errorGrace?.cancel();
    setState(() {
      _resolvingEpisode = true;
      _nextEpisodeSecs = null;
    });
    try {
      final target = await _nav.resolveNext(getIt<MediaRepository>());
      if (target == null) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      await _openEpisode(target);
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvingEpisode = false;
          _error = 'Impossibile cambiare episodio: $e';
        });
      }
    }
  }

  Future<void> _goToPreviousEpisode() async {
    if (_resolvingEpisode || !_nav.hasPrevious) return;
    _errorGrace?.cancel();
    setState(() {
      _resolvingEpisode = true;
      _nextEpisodeSecs = null;
    });
    try {
      final target = await _nav.resolvePrevious(getIt<MediaRepository>());
      if (target == null) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      await _openEpisode(target);
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvingEpisode = false;
          _error = 'Impossibile cambiare episodio: $e';
        });
      }
    }
  }

  Future<void> _openEpisode(EpisodeNavTarget target) async {
    final repo = getIt<MediaRepository>();
    final newMediaId = target.mediaId;

    // Warm path: this exact episode was already resolved in the background
    // near the end of the previous one — open the cached URL directly,
    // bypassing PlaybackBloc so there's no spinner flash in between.
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
        _curMediaId = newMediaId;
        _curSourceLabel = sourceLabel;
        _curTitle =
            title ?? (target.title.isNotEmpty ? target.title : _curTitle);
        _curRating = rating;
        _curDurationSeconds = durationSeconds;
        _curYear = year;
        _skipIntervals = parseSkipTimes(skipTimes);
        _activeSkip = null;
        _skipDismissed = false;
        _opened = true;
        _started = false;
        _resolvingEpisode = false;
        _autoAdvanced = false;
        _nextEpisodeDismissed = false;
        _error = null;
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

    // Cold path: fetch sources + this episode's own metadata, pick the same
    // source label already playing (fall back to the first one), then hand
    // the picked stream id to PlaybackBloc — same SelectStreamEvent path the
    // "Riprova" retry already uses when a direct stream id is known.
    final streamsFuture = repo
        .getStreams(widget.pluginId, newMediaId)
        .timeout(kPrefetchGetStreamsTimeout);
    DetailsResponse? details;
    try {
      details = await repo
          .getDetails(widget.pluginId, newMediaId, urgent: true)
          .timeout(kPrefetchGetDetailsTimeout);
    } catch (_) {
      // Metadata is a nice-to-have — a stream that still resolves matters.
    }
    final streamsRes = await streamsFuture;
    final sources = streamsRes.sources;
    final match = (_curSourceLabel.isEmpty
            ? null
            : sources
                .where((s) =>
                    s.label.toLowerCase() == _curSourceLabel.toLowerCase())
                .firstOrNull) ??
        (sources.isNotEmpty ? sources.first : null);

    if (!mounted) return;

    if (match != null) {
      // Same episode-own metadata mobile_playback_screen.dart's cold path
      // extracts — rating/duration are per-EPISODE fields (vary between
      // episodes, unlike the series-level ones widget.args carries), so a
      // fresh look-up here on every switch is what keeps _currentArgs()
      // (and, in turn, every continue-watching write past this point) from
      // reporting the *first* episode's values forever.
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
        _curMediaId = newMediaId;
        _curSourceLabel = match.label;
        _curTitle = (details != null && details.item.title.isNotEmpty)
            ? details.item.title
            : (target.title.isNotEmpty ? target.title : _curTitle);
        _curRating = (ep != null && ep.vote > 0) ? ep.vote : null;
        _curDurationSeconds =
            (ep != null && ep.duration > 0) ? ep.duration * 60 : null;
        _curYear = (details != null && details.item.year > 0)
            ? details.item.year
            : null;
        _opened = false;
        _resolvingEpisode = false;
        _autoAdvanced = false;
        _nextEpisodeDismissed = false;
        _error = null;
      });
      _progress = PlaybackProgress(
          args: _currentArgs(),
          mediaId: newMediaId,
          onPlaybackElsewhere: _onPlaybackTakenOver);
      context.read<PlaybackBloc>().add(
            SelectStreamEvent(pluginId: widget.pluginId, streamId: match.id),
          );
      // _transitioningEpisode cleared in _onReady, once the new stream
      // (dispatched above) actually attaches and markStarted runs for it.
    } else {
      setState(() {
        _resolvingEpisode = false;
        _error = 'Nessuna sorgente disponibile per il prossimo episodio.';
      });
      _engine.stop();
    }
  }

  /// [widget.args] rebuilt around the episode currently playing, so
  /// [_progress]'s continue-watching/remembered-audio-language logic (which
  /// reads args.episodeIndex/episodeList/mediaId) stays correct after
  /// switching episodes in place. Same pattern as mobile_playback_screen.dart.
  /// `plot` has no override here at all (see PlaybackArgs.copyWith) —
  /// Continue Watching always shows the series' own synopsis.
  ///
  /// [seekTo] defaults to 0 (a new episode always starts from the top); the
  /// one exception is _onPlaybackTakenOver's "Riprendi qui", which passes
  /// the position playback stopped at — same episode, so [_progress] must
  /// still resume-seek there instead of opening at 0.
  PlaybackArgs _currentArgs({int seekTo = 0}) => widget.args.copyWith(
        title: _curTitle,
        episodeList: _nav.episodeList,
        episodeTitles: _nav.episodeTitles,
        episodeThumbs: _nav.episodeThumbs,
        episodeNumbers: _nav.episodeNumbers,
        seasonNumbers: _nav.seasonNumbers,
        episodeIndex: _nav.episodeIndex,
        sourceLabel: _curSourceLabel,
        seasonIndex: _nav.seasonIndex,
        seekTo: seekTo,
        poster: posterForEpisode(
          episodeThumbs: _nav.episodeThumbs,
          index: _nav.episodeIndex,
          seriesCoverUrl: _nav.seriesCoverUrl,
          seriesPoster: _nav.seriesPoster,
          fallback: widget.args.poster,
        ),
        rating: _curRating,
        durationSeconds: _curDurationSeconds,
        year: _curYear,
      );

  void _retry() {
    _errorGrace?.cancel();
    final bloc = context.read<PlaybackBloc>();
    _progress.resetForRetry();
    setState(() {
      _error = null;
      _opened = false;
    });
    final directUrl = widget.args.directUrl;
    final direct = widget.args.directStreamId;
    final startPositionSec = resolveStartPositionSec(
        isLive: widget.args.isLive, seekTo: widget.args.seekTo);
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
        mediaId: widget.mediaId,
        preferredLabel: widget.args.sourceLabel,
        startPositionSec: startPositionSec,
      ));
    }
  }

  // ── controls ─────────────────────────────────────────────────────────────

  void _armAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _engine.playing && !_tracksPanel) {
        setState(() => _controls = false);
      }
    });
  }

  void _wake() {
    if (!_controls) {
      setState(() => _controls = true);
      _armAutoHide();
      _lastWake = DateTime.now();
      return;
    }
    // Controls already visible: mouse-move fires onHover ~60 Hz — don't
    // cancel/recreate the auto-hide timer on every one, just often enough.
    final now = DateTime.now();
    if (_lastWake == null ||
        now.difference(_lastWake!) > const Duration(milliseconds: 250)) {
      _lastWake = now;
      _armAutoHide();
    }
  }

  void _togglePlay() {
    _engine.playOrPause();
    _wake();
  }

  void _seekBy(int secs) {
    final d = _engine.duration;
    var t = _engine.position + Duration(seconds: secs);
    if (t < Duration.zero) t = Duration.zero;
    if (d > Duration.zero && t > d) t = d;
    _engine.seek(t);
    _wake();
  }

  void _setVolume(double v) {
    final clamped = v.clamp(0.0, _engine.maxVolume);
    if (clamped > 0) _lastVolume = clamped;
    _engine.setVolume(clamped);
    // The control tree no longer rebuilds on the engine tick, so refresh it
    // here for the volume slider/label + icon.
    if (mounted) setState(() {});
    _wake();
  }

  void _toggleMute() => _setVolume(
      _engine.volume > 0 ? 0 : (_lastVolume <= 0 ? 100 : _lastVolume));

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    await windowManager.setFullScreen(_fullscreen);
    if (mounted) setState(() {});
    _wake();
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyK) {
      _togglePlay();
    } else if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.keyL) {
      _seekBy(10);
    } else if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.keyJ) {
      _seekBy(-10);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _setVolume(_engine.volume + 10);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _setVolume(_engine.volume - 10);
    } else if (k == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (k == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (k == LogicalKeyboardKey.escape) {
      if (_tracksPanel) {
        setState(() => _tracksPanel = false);
      } else if (_fullscreen) {
        _toggleFullscreen();
      } else {
        _exit();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: BlocListener<PlaybackBloc, PlaybackState>(
          listener: (context, s) {
            if (s is PlaybackReady) _onReady(s);
            // A resolve failure after _openEpisode's cold path already set
            // _transitioningEpisode (stream resolution errored out before
            // ever reaching PlaybackReady/_onReady, which is otherwise the
            // only place that clears it) must not leave the heartbeat/
            // dispose save disabled for the rest of the session.
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
          child: MouseRegion(
            onHover: (_) => _wake(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _togglePlay,
                    child: Center(child: _videoView ??= _engine.buildView()),
                  ),
                ),
                BlocBuilder<PlaybackBloc, PlaybackState>(
                  builder: (context, s) {
                    if (_takeoverPrompt != null) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: KeyedSubtree(
                          key: const ValueKey('takeover'),
                          child: _TakeoverOverlay(
                              prompt: _takeoverPrompt!, onBack: _exit),
                        ),
                      );
                    }
                    if (_error != null) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: KeyedSubtree(
                          key: const ValueKey('error'),
                          child: _ErrorOverlay(
                              message: _error!, onBack: _exit, onRetry: _retry),
                        ),
                      );
                    }
                    if (s is PlaybackFailed) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: KeyedSubtree(
                          key: const ValueKey('error'),
                          child: _ErrorOverlay(
                              message: s.errorMessage,
                              onBack: _exit,
                              onRetry: _retry),
                        ),
                      );
                    }
                    // Spinner from the moment the screen mounts right through
                    // the open()/first-decode gap (which now also covers the
                    // resume seek landing, not just the first decoded frame —
                    // see _onEngine's own _started gate) — no bare black
                    // screen, and a brief crossfade rather than a hard cut
                    // once it's finally lifted.
                    if (s is! PlaybackReady || !_started) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: KeyedSubtree(
                          key: const ValueKey('loading'),
                          child: _LoadingOverlay(
                              state: s is PlaybackReady ? null : s,
                              onBack: _exit),
                        ),
                      );
                    }
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: KeyedSubtree(
                        key: const ValueKey('ready'),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_engine.buffering)
                              const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white70),
                              ),
                            if (_controls)
                              _ControlsLayer(
                                engine: _engine,
                                args: widget.args,
                                skipIntervals: _skipIntervals,
                                seekBarFocusNode: _seekBarFocusNode,
                                isFullscreen: _fullscreen,
                                onBack: _exit,
                                onPlayPause: _togglePlay,
                                onSeekBy: _seekBy,
                                onSeek: (d) {
                                  _engine.seek(d);
                                  _wake();
                                },
                                onSeekActivity: _wake,
                                onVolume: _setVolume,
                                onToggleMute: _toggleMute,
                                onFullscreen: _toggleFullscreen,
                                onTracks: () {
                                  setState(() => _tracksPanel = true);
                                  _hideTimer?.cancel();
                                },
                                hasPrevEpisode: _nav.hasPrevious,
                                hasNextEpisode: _nav.hasNext,
                                resolvingEpisode: _resolvingEpisode,
                                onPrevEpisode: _goToPreviousEpisode,
                                onNextEpisode: _goToNextEpisode,
                              ),
                            if (_activeSkip != null && !_skipDismissed)
                              Positioned(
                                right: 28,
                                bottom: 110,
                                child: Builder(builder: (_) {
                                  final outroToNext =
                                      _activeSkip!.type == SkipType.ed &&
                                          _nav.hasNext &&
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
                                        _goToNextEpisode();
                                      } else {
                                        _engine.seek(Duration(
                                            milliseconds:
                                                (_activeSkip!.end * 1000)
                                                    .toInt()));
                                        setState(() => _skipDismissed = true);
                                      }
                                    },
                                    onDismiss: () =>
                                        setState(() => _skipDismissed = true),
                                  );
                                }),
                              ),
                            if (_nextEpisodeSecs != null)
                              Positioned(
                                right: 28,
                                bottom: 190,
                                child: PointerNextEpisodeBanner(
                                  secsRemaining: _nextEpisodeSecs!,
                                  nextTitle: _nav.episodeIndex + 1 <
                                          _nav.episodeTitles.length
                                      ? _nav
                                          .episodeTitles[_nav.episodeIndex + 1]
                                      : null,
                                  onPlay: () {
                                    setState(() => _nextEpisodeSecs = null);
                                    _goToNextEpisode();
                                  },
                                  onDismiss: () => setState(() {
                                    _nextEpisodeSecs = null;
                                    _nextEpisodeDismissed = true;
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_tracksPanel)
                  _TracksPanel(
                    engine: _engine,
                    onClose: () {
                      setState(() => _tracksPanel = false);
                      _armAutoHide();
                    },
                    onPickAudio: (t) {
                      _engine.selectAudioTrack(t);
                      _progress.rememberAudioTrack(t.label);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── controls layer ─────────────────────────────────────────────────────────

class _ControlsLayer extends StatelessWidget {
  final PlayerEngine engine;
  final PlaybackArgs args;
  final List<SkipInterval> skipIntervals;
  final FocusNode seekBarFocusNode;
  final bool isFullscreen;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final void Function(int) onSeekBy;
  final void Function(Duration) onSeek;
  // Fired on every drag/hold tick the seek bar handles, not just a committed
  // seek — keeps the controls awake for the whole interaction (see
  // PlayerSeekBar's own onActivity doc).
  final VoidCallback onSeekActivity;
  final void Function(double) onVolume;
  final VoidCallback onToggleMute;
  final VoidCallback onFullscreen;
  final VoidCallback onTracks;
  final bool hasPrevEpisode;
  final bool hasNextEpisode;
  final bool resolvingEpisode;
  final VoidCallback onPrevEpisode;
  final VoidCallback onNextEpisode;

  const _ControlsLayer({
    required this.engine,
    required this.args,
    required this.skipIntervals,
    required this.seekBarFocusNode,
    required this.isFullscreen,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeekBy,
    required this.onSeek,
    required this.onSeekActivity,
    required this.onVolume,
    required this.onToggleMute,
    required this.onFullscreen,
    required this.onTracks,
    required this.hasPrevEpisode,
    required this.hasNextEpisode,
    required this.resolvingEpisode,
    required this.onPrevEpisode,
    required this.onNextEpisode,
  });

  @override
  Widget build(BuildContext context) {
    final title = args.showTitle.isNotEmpty
        ? '${args.showTitle}  ·  ${args.title ?? ''}'
        : (args.title ?? '');

    return Column(
      children: [
        // top bar
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 24),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        // bottom bar
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!args.isLive)
                  // Scoped rebuild: only this row tracks the position tick
                  // (~4 Hz), not the whole control tree.
                  StreamBuilder<Duration>(
                    stream: engine.positionStream,
                    initialData: engine.position,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      final dur = engine.duration;
                      return PlayerSeekBar(
                        posSec: pos.inMilliseconds / 1000.0,
                        durSec: dur.inMilliseconds > 0
                            ? dur.inMilliseconds / 1000.0
                            : 1.0,
                        skipIntervals: skipIntervals,
                        focusNode: seekBarFocusNode,
                        onSeek: (v) =>
                            onSeek(Duration(milliseconds: (v * 1000).round())),
                        onActivity: onSeekActivity,
                      );
                    },
                  ),
                Row(
                  children: [
                    _CtlBtn(
                      icon: engine.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 40,
                      onTap: onPlayPause,
                    ),
                    if (!args.isLive) ...[
                      _CtlBtn(
                          icon: Icons.replay_10_rounded,
                          onTap: () => onSeekBy(-10)),
                      _CtlBtn(
                          icon: Icons.forward_10_rounded,
                          onTap: () => onSeekBy(10)),
                    ],
                    if (!args.isLive && hasPrevEpisode) ...[
                      const SizedBox(width: 4),
                      _CtlBtn(
                        icon: Icons.skip_previous_rounded,
                        tooltip: 'Episodio precedente',
                        onTap: resolvingEpisode ? () {} : onPrevEpisode,
                      ),
                    ],
                    if (!args.isLive && hasNextEpisode) ...[
                      const SizedBox(width: 4),
                      _CtlBtn(
                        icon: Icons.skip_next_rounded,
                        tooltip: 'Episodio successivo',
                        onTap: resolvingEpisode ? () {} : onNextEpisode,
                      ),
                    ],
                    const SizedBox(width: 8),
                    _VolumeControl(
                      volume: engine.volume,
                      maxVolume: engine.maxVolume,
                      onChanged: onVolume,
                      onToggleMute: onToggleMute,
                    ),
                    const Spacer(),
                    _CtlBtn(
                      icon: Icons.tune_rounded,
                      tooltip: 'Tracce',
                      onTap: onTracks,
                    ),
                    _CtlBtn(
                      icon: isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      tooltip: 'Schermo intero (F)',
                      onTap: onFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CtlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final String? tooltip;
  final VoidCallback onTap;
  const _CtlBtn(
      {required this.icon, required this.onTap, this.size = 28, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final b = IconButton(
      icon: Icon(icon, color: Colors.white, size: size),
      onPressed: onTap,
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

class _VolumeControl extends StatelessWidget {
  final double volume;
  final double maxVolume;
  final void Function(double) onChanged;
  final VoidCallback onToggleMute;
  const _VolumeControl({
    required this.volume,
    required this.maxVolume,
    required this.onChanged,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    final muted = volume <= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CtlBtn(
          icon: muted
              ? Icons.volume_off_rounded
              : volume <= 100
                  ? Icons.volume_up_rounded
                  : Icons.graphic_eq_rounded,
          size: 24,
          onTap: onToggleMute,
        ),
        SizedBox(
          width: 110,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: volume.clamp(0, maxVolume),
              max: maxVolume,
              activeColor: volume > 100 ? AppTheme.secondary : Colors.white,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
        ),
        if (maxVolume > 100)
          SizedBox(
            width: 38,
            child: Text('${volume.round()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
      ],
    );
  }
}

// ── tracks side panel ──────────────────────────────────────────────────────

class _TracksPanel extends StatefulWidget {
  final PlayerEngine engine;
  final VoidCallback onClose;
  final void Function(MediaTrack) onPickAudio;
  const _TracksPanel({
    required this.engine,
    required this.onClose,
    required this.onPickAudio,
  });

  @override
  State<_TracksPanel> createState() => _TracksPanelState();
}

class _TracksPanelState extends State<_TracksPanel> {
  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final video = e.videoTracks;
    final audio = e.audioTracks;
    final subs = e.subtitleTracks;

    Widget tile(String label, bool sel, VoidCallback onTap) => ListTile(
          dense: true,
          leading: Icon(
              sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: sel ? AppTheme.primary : Colors.white38,
              size: 20),
          title: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          onTap: () {
            onTap();
            setState(() {});
          },
        );

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: const Color(0xF2101018),
        child: SizedBox(
          width: 340,
          height: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Video, audio e sottotitoli',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (video.length > 1) ...[
                      const _PanelHeader('Qualità video'),
                      for (final t in video)
                        tile(t.label, t.id == e.activeVideoTrack?.id,
                            () => e.selectVideoTrack(t)),
                    ],
                    if (audio.length > 1) ...[
                      const _PanelHeader('Audio'),
                      for (final t in audio)
                        tile(t.label, t.id == e.activeAudioTrack?.id,
                            () => widget.onPickAudio(t)),
                    ],
                    if (subs.isNotEmpty) ...[
                      const _PanelHeader('Sottotitoli'),
                      tile('Nessuno', e.activeSubtitleTrack == null,
                          () => e.selectSubtitleTrack(null)),
                      for (final t in subs)
                        tile(t.label, t.id == e.activeSubtitleTrack?.id,
                            () => e.selectSubtitleTrack(t)),
                    ],
                    if (video.length < 2 && audio.length < 2 && subs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                            'Nessuna traccia alternativa per questo stream.',
                            style: TextStyle(color: Colors.white54)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String text;
  const _PanelHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .8)),
      );
}

// ── overlays ───────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  final PlaybackState? state;
  final VoidCallback onBack;
  const _LoadingOverlay({required this.state, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final s = state;
    var label = 'Avvio riproduzione…';
    if (s is FetchingStreams) label = 'Ricerca sorgenti…';
    if (s is ResolvingMediaStream) label = 'Risoluzione stream…';
    if (s is PlaybackResolveProgress) label = s.message;
    if (s is PlaybackRetrying) {
      label = 'Nuovo tentativo ${s.attempt}/${s.of}…';
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
                Text(label, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFF5252), size: 48),
              const SizedBox(height: 14),
              const Text('Riproduzione non riuscita',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
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
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Indietro'),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Riprova'),
                    ),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
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
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(prompt.backLabel),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: prompt.onAction,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(prompt.actionLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
