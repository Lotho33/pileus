import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../core/di/injection.dart';
import '../core/perf_profile.dart';
import '../core/theme/app_theme.dart';
import '../features/player/bloc/playback_bloc.dart';
import '../features/player/bloc/playback_event.dart';
import '../features/player/bloc/playback_state.dart';
import '../features/player/engine/player_engine.dart';
import '../features/player/models/playback_args.dart';
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
    _armAutoHide();
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
  void dispose() {
    windowManager.removeListener(this);
    _hideTimer?.cancel();
    _errorGrace?.cancel();
    _progressTimer?.cancel();
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
    _progress.onStreamOpened();
    await _engine.open(s.resolvedUrl, headers: s.httpHeaders);
    _progress.markStarted(_engine);
  }

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
