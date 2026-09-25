import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

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
import '../features/player/episode_nav.dart';
import '../features/player/episode_poster.dart';
import '../features/player/live_stall_watchdog.dart';
import '../features/player/models/playback_args.dart';
import '../features/player/models/skip_interval.dart';
import '../features/player/presentation/widgets/pointer_next_episode_banner.dart';
import '../features/player/presentation/widgets/pointer_skip_button.dart';
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
  late final PlaybackProgress _progress;
  final _focus = FocusNode();

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
  Timer? _hideTimer;
  Timer? _errorGrace;
  Timer? _progressTimer;
  Widget? _videoView;

  // ── episode navigation / AniSkip / prefetch / live watchdog ──────────────
  // Ported from the mobile player (episode-nav + prefetch) and the TV player
  // (AniSkip + live-stall watchdog) — see episode_nav.dart/skip_interval.dart/
  // live_stall_watchdog.dart. Desktop didn't have any of this before; TV and
  // mobile keep their own separate, already-proven copies untouched.
  late String _curMediaId = widget.mediaId;
  late String _curSourceLabel = widget.args.sourceLabel;
  late String _curTitle = widget.args.title ?? '';
  late final EpisodeNavState _nav = EpisodeNavState.fromArgs(widget.args);
  bool _resolvingEpisode = false;
  bool _autoAdvanced = false;
  bool _nextEpisodeDismissed = false;
  int? _nextEpisodeSecs;
  StreamSubscription<Duration>? _posSub;

  List<SkipInterval> _skipIntervals = const [];
  SkipInterval? _activeSkip;
  bool _skipDismissed = false;

  // Prefetch: same algorithm as mobile_playback_screen.dart, plus a
  // generation token (mobile's version doesn't have one — see the audit note
  // on M5) so a stale in-flight prefetch can never overwrite a fresher one.
  bool _prefetching = false;
  int _prefetchGeneration = 0;
  String? _prefetchedMediaId;
  String? _prefetchedUrl;
  Map<String, String>? _prefetchedHeaders;
  String? _prefetchedSourceLabel;
  String? _prefetchedTitle;
  String? _prefetchedSkipTimes;

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
            _progress.save(_engine);
          } catch (_) {}
        }
      }
    } else if (_progressTimer == null && !widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _progress.save(_engine));
    }
  }

  @override
  void initState() {
    super.initState();
    // Keep _fullscreen in sync when the WM/OS changes it out from under us
    // (F11, the title-bar button, a compositor shortcut) — otherwise the
    // fullscreen toggle icon and the Esc handling below drift out of step.
    windowManager.addListener(this);
    _settings = getIt<SettingsRepository>();
    _progress = PlaybackProgress(args: widget.args, mediaId: widget.mediaId);

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

    if (!widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _progress.save(_engine));
    }
    _posSub = _engine.positionStream.listen(_onPosition);
    if (widget.args.isLive) {
      _liveWatchdog = LiveStallWatchdog(
        isHealthy: () =>
            mounted &&
            _error == null &&
            (_errorGrace?.isActive != true) &&
            _engine.playing &&
            !_engine.buffering,
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
    _posSub?.cancel();
    _liveWatchdog?.disarm();
    if (!widget.args.isLive) {
      try {
        _progress.save(_engine);
      } catch (_) {}
    }
    WakelockPlus.disable();
    _focus.dispose();
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
      _progress.maybeClear(_engine);
    }
    _progress.maybeResumeSeek(_engine);

    if (!_started && (playing || _engine.position > Duration.zero)) {
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
    _errorGrace?.cancel();
    _errorGrace = Timer(const Duration(seconds: 6), () {
      if (mounted && !_engine.playing) setState(() => _error = msg);
    });
  }

  Future<void> _onReady(PlaybackReady s) async {
    if (_opened) return;
    _opened = true;
    // Fires for both the very first stream and every subsequent episode
    // (see _openEpisode's cold path, which dispatches SelectStreamEvent and
    // resets _opened) — so AniSkip markers refresh per-episode for free.
    setState(() {
      _skipIntervals = parseSkipTimes(s.extra['skip_times']);
      _activeSkip = null;
      _skipDismissed = false;
    });
    _progress.onStreamOpened();
    await _engine.open(s.resolvedUrl, headers: s.httpHeaders);
    _progress.markStarted(_engine);
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
    if (dur.inSeconds <= 60) return;

    // Warm the next episode once we're most of the way through this one —
    // same-season only, same 80% threshold as mobile_playback_screen.dart.
    if (!_prefetching &&
        _nav.episodeIndex + 1 < _nav.episodeList.length &&
        _prefetchedMediaId != _nav.episodeList[_nav.episodeIndex + 1] &&
        pos.inSeconds / dur.inSeconds >= 0.80) {
      _prefetchNextEpisode();
    }

    if (!_nav.hasNext) return;
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
    if (_prefetchedMediaId == newMediaId && _prefetchedUrl != null) {
      final url = _prefetchedUrl!;
      final headers = _prefetchedHeaders ?? const <String, String>{};
      final sourceLabel = _prefetchedSourceLabel;
      final title = _prefetchedTitle;
      final skipTimes = _prefetchedSkipTimes;
      _clearPrefetch();
      _engine.stop();
      setState(() {
        _curMediaId = newMediaId;
        _curSourceLabel = sourceLabel ?? _curSourceLabel;
        _curTitle =
            title ?? (target.title.isNotEmpty ? target.title : _curTitle);
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
      _progress = PlaybackProgress(args: _currentArgs(), mediaId: newMediaId);
      _progress.onStreamOpened();
      await _engine.open(url, headers: headers);
      if (mounted) _progress.markStarted(_engine);
      return;
    }
    _clearPrefetch();

    // Cold path: fetch sources + this episode's own metadata, pick the same
    // source label already playing (fall back to the first one), then hand
    // the picked stream id to PlaybackBloc — same SelectStreamEvent path the
    // "Riprova" retry already uses when a direct stream id is known.
    final streamsFuture = repo
        .getStreams(widget.pluginId, newMediaId)
        .timeout(const Duration(seconds: 20));
    DetailsResponse? details;
    try {
      details = await repo
          .getDetails(widget.pluginId, newMediaId, urgent: true)
          .timeout(const Duration(seconds: 8));
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
      _engine.stop();
      setState(() {
        _curMediaId = newMediaId;
        _curSourceLabel = match.label;
        _curTitle = (details != null && details.item.title.isNotEmpty)
            ? details.item.title
            : (target.title.isNotEmpty ? target.title : _curTitle);
        _opened = false;
        _resolvingEpisode = false;
        _autoAdvanced = false;
        _nextEpisodeDismissed = false;
        _error = null;
      });
      _progress = PlaybackProgress(args: _currentArgs(), mediaId: newMediaId);
      context.read<PlaybackBloc>().add(
            SelectStreamEvent(pluginId: widget.pluginId, streamId: match.id),
          );
    } else {
      setState(() {
        _resolvingEpisode = false;
        _error = 'Nessuna sorgente disponibile per il prossimo episodio.';
      });
      _engine.stop();
    }
  }

  /// Best-effort: resolves the next episode's stream (+ its own metadata)
  /// ahead of time, same algorithm as mobile_playback_screen.dart's
  /// _prefetchNextEpisode. [_prefetchGeneration] guards against a stale
  /// in-flight prefetch overwriting a fresher one (or one already consumed/
  /// cleared) once its awaits finally resolve.
  Future<void> _prefetchNextEpisode() async {
    if (_nav.episodeIndex + 1 >= _nav.episodeList.length) return;
    final nextId = _nav.episodeList[_nav.episodeIndex + 1];
    if (_prefetchedMediaId == nextId) return;
    final generation = ++_prefetchGeneration;
    _prefetching = true;
    try {
      final repo = getIt<MediaRepository>();
      final nextTitle = _nav.episodeIndex + 1 < _nav.episodeTitles.length
          ? _nav.episodeTitles[_nav.episodeIndex + 1]
          : null;
      final streamsRes = await repo
          .getStreams(widget.pluginId, nextId)
          .timeout(const Duration(seconds: 20));
      if (!mounted || generation != _prefetchGeneration) return;
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
          .resolveStream(widget.pluginId, match.id)
          .timeout(const Duration(seconds: 25))) {
        if (ev.hasResult()) {
          resolved = ev.result;
          break;
        }
      }
      if (!mounted ||
          generation != _prefetchGeneration ||
          resolved == null ||
          resolved.resolvedUrl.isEmpty) {
        return;
      }

      DetailsResponse? details;
      try {
        details = await repo
            .getDetails(widget.pluginId, nextId)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // metadata is a bonus
      }
      if (!mounted || generation != _prefetchGeneration) return;

      _prefetchedMediaId = nextId;
      _prefetchedUrl = resolved.resolvedUrl;
      _prefetchedHeaders = resolved.httpHeaders;
      _prefetchedSourceLabel = match.label;
      _prefetchedTitle = (details != null && details.item.title.isNotEmpty)
          ? details.item.title
          : nextTitle;
      _prefetchedSkipTimes = resolved.extra['skip_times'];
    } catch (_) {
      // ignore — falls back to a cold resolve
    } finally {
      if (generation == _prefetchGeneration) _prefetching = false;
    }
  }

  void _clearPrefetch() {
    _prefetchedMediaId = null;
    _prefetchedUrl = null;
    _prefetchedHeaders = null;
    _prefetchedSourceLabel = null;
    _prefetchedTitle = null;
    _prefetchedSkipTimes = null;
    // Invalidates any prefetch still in flight — its awaits will see a
    // mismatched generation and drop their result instead of writing it.
    _prefetchGeneration++;
    _prefetching = false;
  }

  /// [widget.args] rebuilt around the episode currently playing, so
  /// [_progress]'s continue-watching/remembered-audio-language logic (which
  /// reads args.episodeIndex/episodeList/mediaId) stays correct after
  /// switching episodes in place. Same pattern as mobile_playback_screen.dart.
  /// `plot` has no override here at all (see PlaybackArgs.copyWith) —
  /// Continue Watching always shows the series' own synopsis.
  PlaybackArgs _currentArgs() => widget.args.copyWith(
        title: _curTitle,
        episodeList: _nav.episodeList,
        episodeTitles: _nav.episodeTitles,
        episodeThumbs: _nav.episodeThumbs,
        episodeNumbers: _nav.episodeNumbers,
        seasonNumbers: _nav.seasonNumbers,
        episodeIndex: _nav.episodeIndex,
        sourceLabel: _curSourceLabel,
        seasonIndex: _nav.seasonIndex,
        seekTo: 0,
        poster: posterForEpisode(
          episodeThumbs: _nav.episodeThumbs,
          index: _nav.episodeIndex,
          seriesCoverUrl: _nav.seriesCoverUrl,
          seriesPoster: _nav.seriesPoster,
          fallback: widget.args.poster,
        ),
      );

  void _retry() {
    _errorGrace?.cancel();
    final bloc = context.read<PlaybackBloc>();
    _progress.resetForRetry();
    setState(() {
      _error = null;
      _opened = false;
    });
    final direct = widget.args.directStreamId;
    if (direct != null && direct.isNotEmpty) {
      bloc.add(SelectStreamEvent(pluginId: widget.pluginId, streamId: direct));
    } else {
      bloc.add(InitializeVideoEvent(
        pluginId: widget.pluginId,
        mediaId: widget.mediaId,
        preferredLabel: widget.args.sourceLabel,
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
                    if (_error != null) {
                      return _ErrorOverlay(
                          message: _error!, onBack: _exit, onRetry: _retry);
                    }
                    if (s is PlaybackFailed) {
                      return _ErrorOverlay(
                          message: s.errorMessage,
                          onBack: _exit,
                          onRetry: _retry);
                    }
                    // Spinner from the moment the screen mounts right through
                    // the open()/first-decode gap — no bare black screen.
                    if (s is! PlaybackReady || !_started) {
                      return _LoadingOverlay(
                          state: s is PlaybackReady ? null : s, onBack: _exit);
                    }
                    return Stack(
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
                            isFullscreen: _fullscreen,
                            onBack: _exit,
                            onPlayPause: _togglePlay,
                            onSeekBy: _seekBy,
                            onSeek: (d) {
                              _engine.seek(d);
                              _wake();
                            },
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
                                            (_activeSkip!.end * 1000).toInt()));
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
                                  ? _nav.episodeTitles[_nav.episodeIndex + 1]
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
  final bool isFullscreen;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final void Function(int) onSeekBy;
  final void Function(Duration) onSeek;
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
    required this.isFullscreen,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeekBy,
    required this.onSeek,
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

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

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
                      final maxMs = dur.inMilliseconds > 0
                          ? dur.inMilliseconds.toDouble()
                          : 1.0;
                      return Row(
                        children: [
                          Text(_fmt(pos),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                overlayShape: SliderComponentShape.noOverlay,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                              ),
                              child: Slider(
                                value: pos.inMilliseconds
                                    .clamp(0, maxMs.toInt())
                                    .toDouble(),
                                max: maxMs,
                                activeColor: AppTheme.primary,
                                inactiveColor: Colors.white24,
                                onChanged: (v) =>
                                    onSeek(Duration(milliseconds: v.toInt())),
                              ),
                            ),
                          ),
                          Text(_fmt(dur),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
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
