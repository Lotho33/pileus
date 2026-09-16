import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/di/injection.dart';
import '../core/perf_profile.dart';
import '../core/theme/app_theme.dart';
import '../features/media/data/media_repository.dart';
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
  bool _resolvingEpisode = false;
  bool _autoAdvanced = false;
  // Countdown shown in the closing seconds of an episode; null = hidden.
  int? _nextEpisodeSecs;
  bool _nextEpisodeDismissed = false;
  StreamSubscription<Duration>? _posSub;
  // Brief ±10s flash shown after a double-tap seek; null = hidden. Sign
  // says which side/direction, not a duration.
  int? _seekFeedback;
  Timer? _seekFeedbackTimer;

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
    _posSub = _engine.positionStream.listen(_onPosition);
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
    _posSub?.cancel();
    _seekFeedbackTimer?.cancel();
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

  void _onPosition(Duration pos) {
    if (!mounted || widget.args.isLive || !_hasNextEpisode) return;
    final dur = _engine.duration;
    if (dur.inSeconds <= 60) return;
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

  Future<void> _resolveEpisodeAt(
    int newIndex,
    List<String> episodeList,
    List<String> episodeTitles,
    int seasonIndex,
  ) async {
    final repo = getIt<MediaRepository>();

    if (newIndex < 0 || newIndex >= episodeList.length) {
      // Season boundary: only forward, mobile has no "previous episode" nav.
      final allSeasonIds = widget.args.allSeasonIds;
      final newSeasonIndex = seasonIndex + 1;
      if (allSeasonIds.isEmpty || newSeasonIndex >= allSeasonIds.length) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      final browseRes = await repo.browse(
          widget.args.epPluginId, allSeasonIds[newSeasonIndex], '');
      final newEpisodes = browseRes.items;
      if (newEpisodes.isEmpty) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      final newIds = newEpisodes.map((e) => e.id).toList();
      final newTitles = newEpisodes.map((e) => e.title).toList();
      if (mounted) {
        setState(() {
          _curEpisodeList = newIds;
          _curEpisodeTitles = newTitles;
          _curSeasonIndex = newSeasonIndex;
        });
      }
      await _resolveEpisodeAt(0, newIds, newTitles, newSeasonIndex);
      return;
    }

    final newMediaId = episodeList[newIndex];
    final newTitle =
        newIndex < episodeTitles.length ? episodeTitles[newIndex] : null;
    final streamsRes =
        await repo.getStreams(widget.args.epPluginId, newMediaId);
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
      _engine.stop();
      setState(() {
        _curEpisodeIndex = newIndex;
        _curMediaId = newMediaId;
        _curSourceLabel = match.label;
        _curTitle = newTitle ?? _curTitle;
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
  /// after switching episodes in place.
  PlaybackArgs _currentArgs() => widget.args.copyWith(
        title: _curTitle,
        episodeList: _curEpisodeList,
        episodeTitles: _curEpisodeTitles,
        episodeIndex: _curEpisodeIndex,
        sourceLabel: _curSourceLabel,
        seasonIndex: _curSeasonIndex,
        seekTo: 0,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Center(
                child: _videoView ??= _engine.buildView(),
              ),
            ),
            // Below the controls (added later, so they get first crack at
            // any tap that lands on an actual button) but above the video —
            // a single tap toggles the transport controls, a double tap on
            // either half seeks ±10s. Not something ExoPlayer/better_player
            // gives for free; this is the same gesture split YouTube/Netflix
            // use, done here at the Flutter layer.
            Positioned.fill(child: _tapZones()),
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
            if (_seekFeedback != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: _seekFeedback! < 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _SeekFeedback(forward: _seekFeedback! > 0),
                    ),
                  ),
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
    );
  }

  /// Full-screen tap layer: single tap toggles the controls, double tap on
  /// the left/right half seeks ±10s. Live streams only get the single tap
  /// (no seeking).
  Widget _tapZones() {
    if (widget.args.isLive) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
      );
    }
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: () => _seekWithFeedback(-10),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: () => _seekWithFeedback(10),
          ),
        ),
      ],
    );
  }

  void _seekWithFeedback(int delta) {
    _seekBy(delta);
    _seekFeedbackTimer?.cancel();
    setState(() => _seekFeedback = delta);
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
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

class _SeekFeedback extends StatelessWidget {
  final bool forward;
  const _SeekFeedback({required this.forward});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: Icon(
        forward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}
