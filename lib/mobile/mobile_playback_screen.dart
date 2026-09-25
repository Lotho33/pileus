import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_lifecycle.dart';
import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart'
    show DetailsResponse, ResolveResponse;
import '../core/perf_profile.dart';
import '../core/theme/app_theme.dart';
import '../features/media/data/media_repository.dart';
import '../features/player/bloc/playback_bloc.dart';
import '../features/player/bloc/playback_event.dart';
import '../features/player/bloc/playback_state.dart';
import '../features/player/engine/player_engine.dart';
import '../features/player/episode_poster.dart';
import '../features/player/models/playback_args.dart';
import '../features/player/models/skip_interval.dart';
import '../features/player/playback_episode_cache.dart';
import '../features/player/presentation/widgets/pointer_skip_button.dart';
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
        final direct = args.directStreamId;
        if (direct != null && direct.isNotEmpty) {
          bloc.add(SelectStreamEvent(pluginId: pluginId, streamId: direct));
        } else {
          bloc.add(InitializeVideoEvent(
            pluginId: pluginId,
            mediaId: mediaId,
            preferredLabel: args.sourceLabel,
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
  bool _lastPlaying = false;
  bool _wakelockOn = false; // toggled only on a play/pause transition
  bool _lastBuffering = false;
  String? _playbackError;
  Timer? _hideTimer;
  Timer? _errorGrace;
  Timer? _progressTimer;
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
  // Fresh per-episode rating/duration/year once known — null means "nothing
  // fresher than widget.args yet", so _currentArgs() falls back to the
  // original launch value (see PlaybackArgs.copyWith). Plot is deliberately
  // NOT tracked here: Continue Watching always shows the series' synopsis,
  // never an episode's — see PlaybackArgs.copyWith's doc comment.
  double? _curRating;
  int? _curDurationSeconds;
  int? _curYear;
  bool _resolvingEpisode = false;
  bool _autoAdvanced = false;
  // Countdown shown in the closing seconds of an episode; null = hidden.
  int? _nextEpisodeSecs;
  bool _nextEpisodeDismissed = false;

  // ── AniSkip (intro/outro/recap skip) ────────────────────────────────────
  // TV has had this since the beginning; mobile never did (2026-09-25
  // finding — the same `extra['skip_times']` blob PlaybackReady already
  // carries here, just never read). Ported using the same shared helpers
  // Lotto B put desktop/web on (parseSkipTimes/activeSkipInterval,
  // PointerSkipButton) rather than a 4th hand-rolled copy.
  List<SkipInterval> _skipIntervals = const [];
  SkipInterval? _activeSkip;
  bool _skipDismissed = false;
  StreamSubscription<Duration>? _posSub;
  bool _engineInitialized = false;
  late final int _bufMiB;

  // ── Next-episode prefetch ──────────────────────────────────────────────────
  // Warmed at ~80% through the current episode (see _onPosition) so
  // advancing doesn't cold-resolve (getStreams + resolveStream, which can
  // take several seconds on a slow plugin) with the screen sitting on a
  // spinner. _prefetchedMediaId is null whenever nothing is cached, or
  // doesn't match the episode actually being switched to (e.g. the user
  // hit "previous" instead) — _resolveEpisodeAt falls back to a cold
  // resolve in that case, same as before this existed.
  bool _prefetching = false;
  String? _prefetchedMediaId;
  String? _prefetchedUrl;
  Map<String, String>? _prefetchedHeaders;
  String? _prefetchedSourceLabel;
  String? _prefetchedTitle;
  double? _prefetchedRating;
  int? _prefetchedDurationSeconds;
  int? _prefetchedYear;
  // Raw `extra['skip_times']` from the prefetch's own resolveStream call —
  // the prefetch-bypass path in _resolveEpisodeAt below opens the cached URL
  // directly without ever going through PlaybackReady, so this is the only
  // way that episode's AniSkip markers reach _skipIntervals at all.
  String? _prefetchedSkipTimes;

  @override
  void initState() {
    super.initState();
    _settings = getIt<SettingsRepository>();
    _progress = PlaybackProgress(args: widget.args, mediaId: widget.mediaId);

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
    // Native controller creation deferred to _ensureEngineInitialized(),
    // called right before the first engine.open() — not here. Mirrors the TV
    // player's own fix for a reported whole-screen freeze on weak hardware:
    // a native player view sitting mounted-but-idle for the whole
    // resolve/spinner window (which can be several seconds on a slow plugin)
    // is worse than not existing yet. buildView() already renders
    // SizedBox.shrink() until initialize() has run.

    // Persist watch progress so Continue Watching stays in sync with the TV
    // (same 15s heartbeat + dispose save the TV player uses). Live has no
    // resume point.
    if (!widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _progress.save(_engine));
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
            _progress.save(_engine);
          } catch (_) {}
        }
      }
    } else if (_progressTimer == null && !widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _progress.save(_engine));
    }
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
    _posSub?.cancel();
    // Final save while the engine is still alive — catches everything since
    // the last heartbeat (e.g. the user backs out 8s after the last tick).
    if (!widget.args.isLive) {
      try {
        _progress.save(_engine);
      } catch (_) {}
    }
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

    if (playing) _progress.maybeClear(_engine);

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
    _errorGrace?.cancel();
    _errorGrace = Timer(const Duration(seconds: 6), () {
      if (mounted && !_engine.playing) {
        setState(() => _playbackError = msg);
      }
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
    await _engine.open(s.resolvedUrl, headers: s.httpHeaders);
    _progress.markStarted(_engine);
  }

  void _retry() {
    _errorGrace?.cancel();
    final bloc = context.read<PlaybackBloc>();
    _progress.resetForRetry();
    setState(() {
      _playbackError = null;
      _opened = false;
    });
    // A direct-stream deep link only applies to the title the screen was
    // opened with — once the user has moved to a later episode, retry has
    // to re-resolve that episode's own sources instead.
    final direct =
        _curMediaId == widget.mediaId ? widget.args.directStreamId : null;
    if (direct != null && direct.isNotEmpty) {
      bloc.add(SelectStreamEvent(pluginId: widget.pluginId, streamId: direct));
    } else {
      bloc.add(InitializeVideoEvent(
        pluginId: widget.pluginId,
        mediaId: _curMediaId,
        preferredLabel: _curSourceLabel,
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

      var eps = <({String id, String title, String thumb})>[];
      if (res.episodes.isNotEmpty) {
        eps = [
          for (final e in res.episodes)
            (id: e.id, title: e.title, thumb: e.thumbnailUrl)
        ];
      } else {
        eps = [
          for (final e in res.items)
            if (!e.isDir) (id: e.id, title: e.title, thumb: e.posterUrl),
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
                    (id: e.id, title: e.title, thumb: e.thumbnailUrl)
                ]
              : [
                  for (final e in sr.items)
                    if (!e.isDir)
                      (id: e.id, title: e.title, thumb: e.posterUrl),
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
      List<({String id, String title, String thumb})> eps, String target) {
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
      _curEpisodeIndex = idx;
    });
  }

  void _onPosition(Duration pos) {
    if (!mounted || widget.args.isLive) return;

    final active = activeSkipInterval(_skipIntervals, pos);
    if (active != _activeSkip) {
      setState(() {
        _activeSkip = active;
        if (active != null) _skipDismissed = false;
      });
    }

    final dur = _engine.duration;
    if (dur.inSeconds <= 60) return;

    // Warm the next episode (stream + fresh metadata) once we're most of
    // the way through this one — same-season only, a season-boundary next
    // still resolves cold (rarer, and finding it needs its own browse()).
    if (!_prefetching &&
        _curEpisodeIndex + 1 < _curEpisodeList.length &&
        _prefetchedMediaId != _curEpisodeList[_curEpisodeIndex + 1] &&
        pos.inSeconds / dur.inSeconds >= 0.80) {
      _prefetchNextEpisode();
    }

    if (!_hasNextEpisode) return;
    final remaining = dur.inSeconds - pos.inSeconds;
    if (remaining > 0 && remaining <= 30 && !_nextEpisodeDismissed) {
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

  /// Best-effort: resolves the next episode's stream + fetches its own
  /// rating/duration/year ahead of time and caches it, so _resolveEpisodeAt
  /// can open it directly instead of cold-resolving
  /// (getStreams + resolveStream, which on a slow plugin is several
  /// seconds spent staring at a spinner right when the episode you were
  /// watching just ended). Any failure here is silent — the actual switch
  /// just falls back to the normal cold path.
  Future<void> _prefetchNextEpisode() async {
    if (_curEpisodeIndex + 1 >= _curEpisodeList.length) return;
    final nextId = _curEpisodeList[_curEpisodeIndex + 1];
    if (_prefetchedMediaId == nextId) return;
    _prefetching = true;
    try {
      final repo = getIt<MediaRepository>();
      final nextTitle = _curEpisodeIndex + 1 < _curEpisodeTitles.length
          ? _curEpisodeTitles[_curEpisodeIndex + 1]
          : null;

      // Timeout, not just the outer try/catch: a hang here (not a thrown
      // error) would leave `_prefetching` stuck true forever — the
      // `finally` below never runs on a stuck await — silently disabling
      // prefetch for the rest of the session and pushing every "next
      // episode" onto the cold path in _resolveEpisodeAt instead.
      final streamsRes = await repo
          .getStreams(widget.args.epPluginId, nextId)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final sources = streamsRes.sources;
      final match = (_curSourceLabel.isEmpty
              ? null
              : sources
                  .where((s) =>
                      s.label.toLowerCase() == _curSourceLabel.toLowerCase())
                  .firstOrNull) ??
          (sources.isNotEmpty ? sources.first : null);
      if (match == null) return;

      ResolveResponse? resolved;
      await for (final ev in repo
          .resolveStream(widget.args.epPluginId, match.id)
          .timeout(const Duration(seconds: 25))) {
        if (ev.hasResult()) {
          resolved = ev.result;
          break;
        }
      }
      if (!mounted || resolved == null || resolved.resolvedUrl.isEmpty) {
        return;
      }

      DetailsResponse? details;
      try {
        details = await repo
            .getDetails(widget.args.epPluginId, nextId)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // metadata is a bonus — a resolved stream with no fresh
        // rating/duration/year is still a win over cold-resolving later.
        // Already catches a timeout too, not just a thrown error.
      }
      if (!mounted) return;

      final ep =
          (details != null && details.hasEpisode()) ? details.episode : null;
      _prefetchedMediaId = nextId;
      _prefetchedUrl = resolved.resolvedUrl;
      _prefetchedHeaders = resolved.httpHeaders;
      _prefetchedSourceLabel = match.label;
      _prefetchedTitle = (details != null && details.item.title.isNotEmpty)
          ? details.item.title
          : nextTitle;
      _prefetchedRating = (ep != null && ep.vote > 0) ? ep.vote : null;
      _prefetchedDurationSeconds =
          (ep != null && ep.duration > 0) ? ep.duration * 60 : null;
      _prefetchedYear =
          (details != null && details.item.year > 0) ? details.item.year : null;
      _prefetchedSkipTimes = resolved.extra['skip_times'];
    } catch (_) {
      // ignore — falls back to a cold resolve when actually switching
    } finally {
      _prefetching = false;
    }
  }

  void _clearPrefetch() {
    _prefetchedMediaId = null;
    _prefetchedUrl = null;
    _prefetchedHeaders = null;
    _prefetchedSourceLabel = null;
    _prefetchedTitle = null;
    _prefetchedRating = null;
    _prefetchedDurationSeconds = null;
    _prefetchedYear = null;
    _prefetchedSkipTimes = null;
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
                (id: e.id, title: e.title, thumb: e.thumbnailUrl)
            ]
          : [
              for (final i in browseRes.items)
                if (!i.isDir) (id: i.id, title: i.title, thumb: i.posterUrl),
            ];
      if (newEpisodes.isEmpty) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      final newIds = newEpisodes.map((e) => e.id).toList();
      final newTitles = newEpisodes.map((e) => e.title).toList();
      final newThumbs = newEpisodes.map((e) => e.thumb).toList();
      if (mounted) {
        setState(() {
          _curEpisodeList = newIds;
          _curEpisodeTitles = newTitles;
          _curEpisodeThumbs = newThumbs;
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
    // near the end of the previous one (see _prefetchNextEpisode) — skip
    // getStreams/resolveStream entirely and open the cached URL directly,
    // bypassing PlaybackBloc so there's no ResolvingMediaStream spinner
    // flash in between.
    if (_prefetchedMediaId == newMediaId && _prefetchedUrl != null) {
      final url = _prefetchedUrl!;
      final headers = _prefetchedHeaders ?? const <String, String>{};
      final sourceLabel = _prefetchedSourceLabel;
      final title = _prefetchedTitle;
      final rating = _prefetchedRating;
      final durationSeconds = _prefetchedDurationSeconds;
      final year = _prefetchedYear;
      final skipTimes = _prefetchedSkipTimes;
      _clearPrefetch();
      _engine.stop();
      setState(() {
        _curEpisodeIndex = newIndex;
        _curMediaId = newMediaId;
        _curSourceLabel = sourceLabel ?? _curSourceLabel;
        _curTitle = title ?? newTitle ?? _curTitle;
        _curRating = rating;
        _curDurationSeconds = durationSeconds;
        _curYear = year;
        // This path bypasses PlaybackReady entirely (see the comment above),
        // which is the only other place these get set — without this,
        // AniSkip would either keep showing the previous episode's markers
        // or (worse) silently do nothing for every prefetched transition.
        _skipIntervals = parseSkipTimes(skipTimes);
        _activeSkip = null;
        _skipDismissed = false;
        _opened = true;
        _resolvingEpisode = false;
        _autoAdvanced = false;
        _nextEpisodeDismissed = false;
        _playbackError = null;
      });
      _progress = PlaybackProgress(args: _currentArgs(), mediaId: newMediaId);
      _progress.onStreamOpened();
      await _engine.open(url, headers: headers);
      if (mounted) _progress.markStarted(_engine);
      return;
    }
    _clearPrefetch();

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
    // getDetails for the same reason as episode_popup.dart (2026-09):
    // a live Android TV trace showed the non-urgent dedup/cache path stall
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
      _progress = PlaybackProgress(args: _currentArgs(), mediaId: newMediaId);
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
  PlaybackArgs _currentArgs() => widget.args.copyWith(
        title: _curTitle,
        episodeList: _curEpisodeList,
        episodeTitles: _curEpisodeTitles,
        episodeThumbs: _curEpisodeThumbs,
        episodeIndex: _curEpisodeIndex,
        sourceLabel: _curSourceLabel,
        seasonIndex: _curSeasonIndex,
        seekTo: 0,
        poster: posterForEpisode(
          episodeThumbs: _curEpisodeThumbs,
          index: _curEpisodeIndex,
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
                  if (_playbackError != null) {
                    return Positioned.fill(
                      child: _ErrorOverlay(
                        message: _playbackError!,
                        onBack: _exit,
                        onRetry: _retry,
                      ),
                    );
                  }
                  if (s is PlaybackFailed) {
                    return Positioned.fill(
                      child: _ErrorOverlay(
                        message: s.errorMessage,
                        onBack: _exit,
                        onRetry: _retry,
                      ),
                    );
                  }
                  if (s is! PlaybackReady) {
                    // Loading: only the spinner (dead-centre) + a back
                    // button — no transport controls competing for the
                    // centre of the screen.
                    return Positioned.fill(
                      child: _LoadingOverlay(state: s, onBack: _exit),
                    );
                  }
                  return _controlsVisible
                      ? Positioned.fill(child: _controls())
                      : const SizedBox.shrink();
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
                    final maxMs = dur.inMilliseconds > 0
                        ? dur.inMilliseconds.toDouble()
                        : 1.0;
                    return Row(
                      children: [
                        Text(_fmt(pos),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: pos.inMilliseconds
                                .clamp(0, maxMs.toInt())
                                .toDouble(),
                            max: maxMs,
                            activeColor: AppTheme.primary,
                            onChanged: (v) {
                              _engine.seek(Duration(milliseconds: v.toInt()));
                              _armAutoHide();
                            },
                          ),
                        ),
                        Text(_fmt(dur),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
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

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
