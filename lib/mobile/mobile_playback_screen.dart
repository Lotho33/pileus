import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
      child: _MobilePlayerView(
          pluginId: pluginId, mediaId: mediaId, args: args),
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
  late final PlaybackProgress _progress;

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

  @override
  void initState() {
    super.initState();
    _settings = getIt<SettingsRepository>();
    _progress =
        PlaybackProgress(args: widget.args, mediaId: widget.mediaId);

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

    // Persist watch progress so Continue Watching stays in sync with the TV
    // (same 15s heartbeat + dispose save the TV player uses). Live has no
    // resume point.
    if (!widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _progress.save(_engine));
    }

    _armAutoHide();
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
    _hideTimer?.cancel();
    _errorGrace?.cancel();
    _progressTimer?.cancel();
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
    _progress.onStreamOpened();
    await _engine.open(s.resolvedUrl, headers: s.httpHeaders);
  }

  void _retry() {
    _errorGrace?.cancel();
    final bloc = context.read<PlaybackBloc>();
    _progress.resetForRetry();
    setState(() {
      _playbackError = null;
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    final title = widget.args.showTitle.isNotEmpty
        ? '${widget.args.showTitle} · ${widget.args.title ?? ''}'
        : (widget.args.title ?? '');

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
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  tooltip: 'Video, audio e sottotitoli',
                  onPressed: _showTracksSheet,
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: IconButton(
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
                              _engine
                                  .seek(Duration(milliseconds: v.toInt()));
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
          final nothing = video.length < 2 &&
              audio.length < 2 &&
              subs.isEmpty;
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
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
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
