import 'dart:async';
import 'dart:io' show Platform;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import '../../../core/utils/perf_log.dart';

/// One selectable playback track (audio language, subtitle language, video
/// quality). Backend-agnostic: [raw] holds the native handle the concrete
/// engine needs to actually switch to it.
@immutable
class MediaTrack {
  final String id;
  final String label;

  /// The "no subtitles" pseudo-track. Only ever set on subtitle entries.
  final bool isOff;
  final Object? raw;

  const MediaTrack({
    required this.id,
    required this.label,
    this.isOff = false,
    this.raw,
  });

  @override
  bool operator ==(Object other) =>
      other is MediaTrack && other.id == id && other.isOff == isOff;

  @override
  int get hashCode => Object.hash(id, isOff);
}

/// Subtitle rendering style, read once from settings and baked into the
/// engine's video view at construction (neither backend restyles live).
@immutable
class PlayerSubtitleStyle {
  final double fontSize;
  final Color color;
  final bool backgroundEnabled;
  final double bottomPadding;

  const PlayerSubtitleStyle({
    required this.fontSize,
    required this.color,
    required this.backgroundEnabled,
    required this.bottomPadding,
  });
}

/// Backend-neutral player facade. The playback screen, overlays and settings
/// panel talk only to this — never to media_kit or better_player types.
///
/// It is a [ChangeNotifier]: listeners are pinged on every underlying state
/// change (position tick, play/pause, buffering, track list). The three
/// [Stream] getters exist only for the overlay's existing `StreamBuilder`s.
abstract class PlayerEngine extends ChangeNotifier {
  /// Picks ExoPlayer on Android/iOS (real zero-copy MediaCodec HW decode on
  /// weak TV boxes), libmpv everywhere else (desktop dev, web) — the only
  /// backend that runs there.
  factory PlayerEngine.create() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return _ExoPlayerEngine();
    }
    return _MpvPlayerEngine();
  }

  PlayerEngine._();

  bool _disposed = false;

  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();

  Duration _lastEmittedPos = Duration.zero;
  Duration _lastEmittedDur = Duration.zero;
  bool _lastEmittedPlaying = false;

  /// Called by the concrete engine after any underlying value may have
  /// changed. Fans out to the streams (deduped) and notifies listeners.
  void _emit() {
    if (_disposed) return;
    final p = position;
    if (p != _lastEmittedPos) {
      _lastEmittedPos = p;
      _positionCtrl.add(p);
    }
    final d = duration;
    if (d != _lastEmittedDur) {
      _lastEmittedDur = d;
      _durationCtrl.add(d);
    }
    final pl = playing;
    if (pl != _lastEmittedPlaying) {
      _lastEmittedPlaying = pl;
      _playingCtrl.add(pl);
    }
    notifyListeners();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Build the native controller. [bufferMiB] is a rough cushion hint (mpv
  /// sizes its demuxer cache by bytes; ExoPlayer buffers by time and this is
  /// mapped to a millisecond window).
  Future<void> initialize(
    PlayerSubtitleStyle subtitleStyle, {
    required bool isLive,
    required int bufferMiB,
  });

  /// Open [url] and start decoding. Safe to call again to switch stream
  /// (episode change, live source swap) on the same engine.
  Future<void> open(String url, {required Map<String, String> headers});

  Future<void> stop();

  @override
  void dispose() {
    _disposed = true;
    _positionCtrl.close();
    _durationCtrl.close();
    _playingCtrl.close();
    super.dispose();
  }

  // ── Transport ──────────────────────────────────────────────────────────────

  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration to);

  /// [percent] is 0..[maxVolume]. ExoPlayer's own `setVolume` hard-brackets
  /// to [0,1] natively (`BetterPlayer.kt`) — no software gain stage exists
  /// there, so anything above 100 is silently dropped. mpv amplifies
  /// digitally past unity (softvol), so the desktop backend raises its own
  /// ceiling.
  Future<void> setVolume(double percent);
  double get volume; // 0..maxVolume

  /// Top of the volume range this backend can actually reach. 100 unless
  /// overridden.
  double get maxVolume => 100;

  // ── State snapshot ─────────────────────────────────────────────────────────

  Duration get position;
  Duration get duration; // Duration.zero when unknown
  bool get playing;
  bool get buffering;

  /// 0..100 cache/buffer fill for the loading ring, or 0 when not
  /// meaningful.
  double get bufferedPercent;

  Size? get videoSize;

  // ── Streams (overlay StreamBuilders only) ──────────────────────────────────

  Stream<Duration> get positionStream => _positionCtrl.stream;
  Stream<Duration> get durationStream => _durationCtrl.stream;
  Stream<bool> get playingStream => _playingCtrl.stream;

  // ── Discrete callback ──────────────────────────────────────────────────────

  /// Fatal-looking playback error text. The screen debounces it behind a
  /// grace timer (many are transient segment fetch failures that recover).
  void Function(String message)? onError;

  // ── Tracks ─────────────────────────────────────────────────────────────────

  List<MediaTrack> get audioTracks;
  MediaTrack? get activeAudioTrack;
  Future<void> selectAudioTrack(MediaTrack track);

  /// Real subtitle tracks only — the "off" entry is synthesised by the panel.
  List<MediaTrack> get subtitleTracks;

  /// null == subtitles off.
  MediaTrack? get activeSubtitleTrack;

  /// Pass null to turn subtitles off.
  Future<void> selectSubtitleTrack(MediaTrack? track);

  List<MediaTrack> get videoTracks;
  MediaTrack? get activeVideoTrack;
  Future<void> selectVideoTrack(MediaTrack track);

  // ── View ───────────────────────────────────────────────────────────────────

  /// The video render surface. Style is fixed at [initialize] time.
  Widget buildView();
}

// ═════════════════════════════════════════════════════════════════════════════
// ExoPlayer / Media3 backend (Android, iOS)
// ═════════════════════════════════════════════════════════════════════════════

class _ExoPlayerEngine extends PlayerEngine {
  _ExoPlayerEngine() : super._();

  BetterPlayerController? _controller;
  VoidCallback? _valueListener;
  bool _isLive = false;
  BetterPlayerBufferingConfiguration _bufferingConfig =
      const BetterPlayerBufferingConfiguration();

  bool _buffering = false;
  String? _lastError;
  MediaTrack? _selectedVideo;

  @override
  Future<void> initialize(
    PlayerSubtitleStyle style, {
    required bool isLive,
    required int bufferMiB,
  }) async {
    _isLive = isLive;

    // ExoPlayer buffers by time. On weak Amlogic boxes (Tanix W2) a brief
    // network dip at an HLS segment boundary was underrunning the audio —
    // too short to stall, long enough to hear a hitch. Bumped the floor and
    // especially the after-rebuffer cushion so it refills properly before
    // resuming. Kept moderate: ~1 GB shared RAM, buffer is decoded/muxed
    // media held in memory. Live stays a touch tighter to hold the edge.
    //
    // [bufferMiB] used to be read and threaded all the way here from the
    // Impostazioni "buffer" slider and then silently dropped — only the mpv
    // desktop/web backend ever honoured it (as raw bytes); on Android
    // (TV+mobile) the live/VOD buffer setting was a no-op, so bumping it on
    // a spotty mobile connection did nothing and a live stream that fell
    // behind just stalled outright instead of riding out the dip (reported
    // 2026-09-11). Scale the ms windows against it instead, anchored so the
    // Impostazioni *default* MiB reproduces the exact ms values above
    // (bufferMiB == baseMiB ⇒ scale == 1, zero behaviour change for anyone
    // who never touched the setting).
    final baseMiB = isLive ? 16 : 32; // must match SettingsRepository's
    // live/playerBufferMiBDefault.
    final scale = bufferMiB / baseMiB;
    int scaled(int baseMs, {required int minMs, required int maxMs}) =>
        (baseMs * scale).round().clamp(minMs, maxMs);
    _bufferingConfig = BetterPlayerBufferingConfiguration(
      minBufferMs:
          scaled(isLive ? 16000 : 20000, minMs: 4000, maxMs: 90000),
      maxBufferMs:
          scaled(isLive ? 24000 : 35000, minMs: 8000, maxMs: 150000),
      bufferForPlaybackMs: 2500,
      bufferForPlaybackAfterRebufferMs: scaled(6000, minMs: 3000, maxMs: 20000),
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        // Match libmpv's open(): start decoding immediately. Resume-seek is
        // handled by the screen (_issueResumeSeek / _maybeResumeSeek) rather
        // than BetterPlayerConfiguration.startAt, because startAt is
        // re-applied on every setupDataSource — an episode change would then
        // seek back to the previous episode's resume point.
        autoPlay: true,
        looping: false,
        // Our own overlay draws every control; better_player's must be
        // fully out of the way (no gestures, no auto-show).
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
          showControlsOnInitialize: false,
        ),
        subtitlesConfiguration: BetterPlayerSubtitlesConfiguration(
          fontSize: style.fontSize,
          fontColor: style.color,
          backgroundColor: style.backgroundEnabled
              ? const Color(0xAA000000)
              : Colors.transparent,
          outlineEnabled: !style.backgroundEnabled,
          outlineColor: const Color(0xCC000000),
          outlineSize: 2,
          bottomPadding: style.bottomPadding,
        ),
        fit: BoxFit.contain,
        expandToFill: true,
        handleLifecycle: true,
        autoDispose: false,
        allowedScreenSleep: false,
        errorBuilder: (context, msg) => const SizedBox.shrink(),
      ),
    );
    _controller!.addEventsListener(_onEvent);
  }

  BetterPlayerController get _c => _controller!;

  void _onEvent(BetterPlayerEvent e) {
    switch (e.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        perf('exo: initialized (live=$_isLive)');
        // videoPlayerController exists now — attach the per-frame listener.
        final vpc = _c.videoPlayerController;
        if (vpc != null && _valueListener == null) {
          _valueListener = () {
            final err = vpc.value.errorDescription;
            if (err != null && err != _lastError) {
              _lastError = err;
              perf('exo: player value error: $err');
              onError?.call(err);
            }
            _emit();
          };
          vpc.addListener(_valueListener!);
        }
        _emit();
      case BetterPlayerEventType.bufferingStart:
        // The line right before a freeze report is almost always the
        // interesting one — this is the only place that sees a rebuffer
        // ExoPlayer decided to do on its own (ABR downshift, HLS
        // discontinuity/decoder reconfigure), not one the UI requested.
        perf('exo: bufferingStart pos=${position.inMilliseconds}ms');
        _buffering = true;
        _emit();
      case BetterPlayerEventType.bufferingEnd:
        perf('exo: bufferingEnd pos=${position.inMilliseconds}ms');
        _buffering = false;
        _emit();
      case BetterPlayerEventType.exception:
        final msg = e.parameters?['exception']?.toString() ?? 'Errore sconosciuto';
        perf('exo: exception: $msg');
        if (msg != _lastError) {
          _lastError = msg;
          onError?.call(msg);
        }
      case BetterPlayerEventType.changedResolution:
        perf('exo: changedResolution pos=${position.inMilliseconds}ms');
        _emit();
      case BetterPlayerEventType.changedTrack:
        perf('exo: changedTrack');
        _emit();
      case BetterPlayerEventType.progress:
      case BetterPlayerEventType.play:
      case BetterPlayerEventType.pause:
      case BetterPlayerEventType.seekTo:
      case BetterPlayerEventType.setVolume:
      case BetterPlayerEventType.finished:
      case BetterPlayerEventType.changedSubtitles:
        _emit();
      default:
        break;
    }
  }

  static final _progressiveExt = RegExp(r'\.(mp4|mkv|webm|mov|avi|m4v)(\?|$)',
      caseSensitive: false);

  @override
  Future<void> open(String url, {required Map<String, String> headers}) async {
    perf('exo: open (live=$_isLive)');
    _lastError = null;
    _selectedVideo = null;
    // mycelium serves HLS by default; only skip the hint for a URL that
    // clearly points at a progressive container. Without a correct hint
    // ExoPlayer picks the wrong extractor and fails with a bare
    // "Source error".
    final format = _progressiveExt.hasMatch(url)
        ? null
        : BetterPlayerVideoFormat.hls;
    try {
      await _c.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          url,
          headers: headers,
          liveStream: _isLive,
          videoFormat: format,
          useAsmsTracks: true,
          useAsmsAudioTracks: true,
          useAsmsSubtitles: true,
          bufferingConfiguration: _bufferingConfig,
        ),
      );
    } catch (e) {
      // setupDataSource can reject (bad URL, cleartext blocked, 4xx). Route
      // it through onError like a mid-stream failure instead of letting it
      // surface as an unhandled async exception — open() is called
      // fire-and-forget from the screen.
      final msg = e.toString();
      _lastError = msg;
      onError?.call(msg);
    }
    _emit();
  }

  @override
  Future<void> stop() async {
    if (_controller == null) return;
    try {
      await _c.pause();
      await _c.seekTo(Duration.zero);
    } catch (_) {}
  }

  @override
  void dispose() {
    final vpc = _controller?.videoPlayerController;
    if (vpc != null && _valueListener != null) {
      vpc.removeListener(_valueListener!);
    }
    _controller?.removeEventsListener(_onEvent);
    _controller?.dispose(forceDispose: true);
    _controller = null;
    super.dispose();
  }

  @override
  Future<void> play() => _c.play();

  @override
  Future<void> pause() => _c.pause();

  @override
  Future<void> playOrPause() =>
      (_c.isPlaying() ?? false) ? _c.pause() : _c.play();

  @override
  Future<void> seek(Duration to) => _c.seekTo(to);

  @override
  Future<void> setVolume(double percent) =>
      _c.setVolume((percent / 100.0).clamp(0.0, 1.0));

  @override
  double get volume =>
      ((_controller?.videoPlayerController?.value.volume ?? 1.0) * 100).clamp(0, 100);

  @override
  Duration get position =>
      _controller?.videoPlayerController?.value.position ?? Duration.zero;

  @override
  Duration get duration =>
      _controller?.videoPlayerController?.value.duration ?? Duration.zero;

  @override
  bool get playing =>
      _controller?.videoPlayerController?.value.isPlaying ?? false;

  @override
  bool get buffering =>
      _buffering ||
      (_controller?.videoPlayerController?.value.isBuffering ?? false);

  @override
  double get bufferedPercent {
    final vpc = _controller?.videoPlayerController;
    if (vpc == null) return 0;
    final dur = vpc.value.duration?.inMilliseconds ?? 0;
    if (dur <= 0) return 0;
    final ranges = vpc.value.buffered;
    if (ranges.isEmpty) return 0;
    final end = ranges.last.end.inMilliseconds;
    return (end / dur * 100).clamp(0, 100);
  }

  @override
  Size? get videoSize => _controller?.videoPlayerController?.value.size;

  // ── Tracks ──

  @override
  List<MediaTrack> get audioTracks {
    final list = _controller?.betterPlayerAsmsAudioTracks ?? const [];
    return [
      for (var i = 0; i < list.length; i++)
        MediaTrack(
          id: '${list[i].id ?? i}',
          label: _audioLabel(list[i], i),
          raw: list[i],
        ),
    ];
  }

  static String _audioLabel(BetterPlayerAsmsAudioTrack t, int i) {
    final parts = <String>[];
    if ((t.language ?? '').isNotEmpty) parts.add(t.language!.toUpperCase());
    if ((t.label ?? '').isNotEmpty && t.label != t.language) parts.add(t.label!);
    return parts.isEmpty ? 'Traccia ${i + 1}' : parts.join(' · ');
  }

  @override
  MediaTrack? get activeAudioTrack {
    final cur = _controller?.betterPlayerAsmsAudioTrack;
    if (cur == null) return audioTracks.isNotEmpty ? audioTracks.first : null;
    final all = _controller?.betterPlayerAsmsAudioTracks ?? const [];
    final idx = all.indexOf(cur);
    return audioTracks.firstWhere(
      (t) => t.id == '${cur.id ?? idx}',
      orElse: () => audioTracks.isNotEmpty ? audioTracks.first : _noneTrack,
    );
  }

  @override
  Future<void> selectAudioTrack(MediaTrack track) async {
    final raw = track.raw;
    if (raw is BetterPlayerAsmsAudioTrack) {
      _c.setAudioTrack(raw);
      _emit();
    }
  }

  @override
  List<MediaTrack> get subtitleTracks {
    final list = _controller?.betterPlayerSubtitlesSourceList ?? const [];
    final out = <MediaTrack>[];
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      if (s.type == BetterPlayerSubtitlesSourceType.none) continue;
      out.add(MediaTrack(
        id: '${s.name ?? 'sub'}#$i',
        label: (s.name ?? '').isEmpty || s.name == 'Default subtitles'
            ? 'Sottotitoli ${i + 1}'
            : s.name!,
        raw: s,
      ));
    }
    return out;
  }

  @override
  MediaTrack? get activeSubtitleTrack {
    final cur = _controller?.betterPlayerSubtitlesSource;
    if (cur == null || cur.type == BetterPlayerSubtitlesSourceType.none) {
      return null;
    }
    final list = _controller?.betterPlayerSubtitlesSourceList ?? const [];
    final idx = list.indexOf(cur);
    return MediaTrack(
      id: '${cur.name ?? 'sub'}#$idx',
      label: (cur.name ?? '').isEmpty ? 'Sottotitoli' : cur.name!,
      raw: cur,
    );
  }

  @override
  Future<void> selectSubtitleTrack(MediaTrack? track) async {
    final list = _controller?.betterPlayerSubtitlesSourceList ?? const [];
    if (track == null) {
      final off = list.firstWhere(
        (s) => s.type == BetterPlayerSubtitlesSourceType.none,
        orElse: () => BetterPlayerSubtitlesSource(
            type: BetterPlayerSubtitlesSourceType.none),
      );
      await _c.setupSubtitleSource(off);
    } else if (track.raw is BetterPlayerSubtitlesSource) {
      await _c.setupSubtitleSource(track.raw as BetterPlayerSubtitlesSource);
    }
    _emit();
  }

  @override
  List<MediaTrack> get videoTracks {
    final list = _controller?.betterPlayerAsmsTracks ?? const [];
    // Real variants only (better_player seeds a 0x0 "auto" placeholder).
    final real = list.where((t) => (t.height ?? 0) > 0).toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    if (real.isEmpty) return const [];
    return [
      const MediaTrack(id: 'auto', label: 'Automatica'),
      for (final t in real)
        MediaTrack(
          id: '${t.height}p@${t.bitrate}',
          label: _videoLabel(t),
          raw: t,
        ),
    ];
  }

  static String _videoLabel(BetterPlayerAsmsTrack t) {
    final parts = <String>['${t.height}p'];
    if ((t.frameRate ?? 0) > 0) parts.add('${t.frameRate} fps');
    if ((t.bitrate ?? 0) > 0) {
      parts.add('${(t.bitrate! / 1000000).toStringAsFixed(1)} Mbps');
    }
    return parts.join(' · ');
  }

  @override
  MediaTrack? get activeVideoTrack {
    if (videoTracks.isEmpty) return null;
    return _selectedVideo ?? videoTracks.first;
  }

  @override
  Future<void> selectVideoTrack(MediaTrack track) async {
    if (track.id == 'auto') {
      await _c.setTrack(BetterPlayerAsmsTrack.defaultTrack());
      _selectedVideo = track;
    } else if (track.raw is BetterPlayerAsmsTrack) {
      await _c.setTrack(track.raw as BetterPlayerAsmsTrack);
      _selectedVideo = track;
    }
    _emit();
  }

  @override
  Widget buildView() =>
      _controller == null ? const SizedBox.shrink() : BetterPlayer(controller: _c);

  static const _noneTrack = MediaTrack(id: '', label: '');
}

// ═════════════════════════════════════════════════════════════════════════════
// libmpv backend (desktop dev, web)
// ═════════════════════════════════════════════════════════════════════════════

class _MpvPlayerEngine extends PlayerEngine {
  _MpvPlayerEngine() : super._() {
    // Android/iOS always take the ExoPlayer path (see PlayerEngine.create).
    // The Android release builds strip libmpv.so from the APK
    // (-PpileusExcludeMpv), so reaching here would `dlopen`-crash — fail
    // loud on the Dart side instead if a regression ever routes here.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      throw StateError(
        '_MpvPlayerEngine constructed on ${Platform.operatingSystem} — '
        'PlayerEngine.create() must return _ExoPlayerEngine there.',
      );
    }
    if (!_mkReady) {
      mk.MediaKit.ensureInitialized();
      _mkReady = true;
    }
  }

  static bool _mkReady = false;

  late final mk.Player _player;
  // _player is assigned inside the async initialize(); a screen torn down
  // before initialize() runs (fast back-navigation) reaches dispose() with
  // _player still unset — touching a `late final` there throws
  // LateInitializationError. Gate every _player access that can happen before
  // initialize() on this.
  bool _playerCreated = false;
  mkv.VideoController? _videoController;
  final List<StreamSubscription> _subs = [];

  mk.Tracks _tracks = const mk.Tracks();
  mk.Track _track = const mk.Track();
  double _volume = 100;
  bool _buffering = false;
  double _bufferPct = 0;
  PlayerSubtitleStyle _style = const PlayerSubtitleStyle(
    fontSize: 32,
    color: Colors.white,
    backgroundEnabled: true,
    bottomPadding: 80,
  );

  bool get _swRender => !kIsWeb && Platform.isLinux;

  // libmpv digitally amplifies past unity gain (softvol) instead of just
  // hard-capping like ExoPlayer; a browser <video> element's `.volume`
  // can't go past 1.0 at all, so the boost only exists on the real desktop
  // build.
  @override
  double get maxVolume => kIsWeb ? 100 : 200;

  @override
  Future<void> initialize(
    PlayerSubtitleStyle style, {
    required bool isLive,
    required int bufferMiB,
  }) async {
    _style = style;
    _player = mk.Player(
      configuration: mk.PlayerConfiguration(
        bufferSize: bufferMiB * 1024 * 1024,
      ),
    );
    _playerCreated = true;
    if (!kIsWeb) {
      // mpv's own softvol ceiling (`volume-max`) defaults to 130, which
      // would silently clamp `setVolume(200)` well short of `maxVolume`.
      //
      // Verified in media_kit's own source (native/player/real.dart): `ctx`
      // (the mpv handle) starts as `nullptr` and is only set once the
      // Player constructor's fire-and-forget `_create()` finishes — it is
      // NOT ready synchronously right after construction (an earlier
      // version of this comment wrongly assumed it was). Calling
      // `setProperty(..., waitForInitialization: false)` here — which
      // skips every wait and goes straight to `mpv_set_property_string`
      // with whatever `ctx` currently holds — handed the native mpv C API
      // a null handle and crashed the whole process on desktop (segfault,
      // not a catchable Dart exception).
      //
      // The fix is `waitForPlayerInitialization` specifically, not
      // `setProperty`'s own `waitForInitialization: true` (which also
      // awaits `waitForVideoControllerInitializationIfAttached` — that one
      // only resolves once a real video attaches, i.e. after `open()`,
      // which is the exact deadlock this facade avoids elsewhere, see
      // PILEUS_PATCHES notes / [[mediakit_setproperty_deadlock]]).
      // `waitForPlayerInitialization` alone only waits for the mpv handle
      // itself — independent of `open()` — so there's no deadlock risk.
      // `dynamic`, not `as mk.NativePlayer`: this whole block is already
      // gated on `!kIsWeb` so it never runs on web, but the CFE still
      // type-checks it for the web target, where `media_kit`'s
      // NativePlayer is a stub without `setProperty` /
      // `waitForPlayerInitialization` — which fails `flutter build web`.
      // The cast erases those references for the web compile; on native
      // the dynamic dispatch resolves to the exact same calls.
      final dynamic native = _player.platform;
      unawaited((native.waitForPlayerInitialization as Future<void>).then((_) {
        native.setProperty(
          'volume-max',
          maxVolume.toInt().toString(),
          waitForInitialization: false,
        );
      }));
    }
    _videoController = mkv.VideoController(
      _player,
      configuration: mkv.VideoControllerConfiguration(
        enableHardwareAcceleration: !_swRender,
      ),
    );

    _subs.add(_player.stream.tracks.listen((t) {
      _tracks = t;
      _emit();
    }));
    _subs.add(_player.stream.track.listen((t) {
      _track = t;
      _emit();
    }));
    _subs.add(_player.stream.volume.listen((v) {
      if ((v - _volume).abs() > 0.5) {
        _volume = v;
        _emit();
      }
    }));
    _subs.add(_player.stream.buffering.listen((b) {
      _buffering = b;
      _emit();
    }));
    _subs.add(_player.stream.bufferingPercentage.listen((p) {
      _bufferPct = p;
      _emit();
    }));
    _subs.add(_player.stream.position.listen((_) => _emit()));
    _subs.add(_player.stream.duration.listen((_) => _emit()));
    _subs.add(_player.stream.playing.listen((_) => _emit()));
    _subs.add(_player.stream.error.listen((err) => onError?.call(err)));
  }

  @override
  Future<void> open(String url, {required Map<String, String> headers}) async {
    await _player.open(mk.Media(url, httpHeaders: headers));
    _emit();
  }

  @override
  Future<void> stop() => _playerCreated ? _player.stop() : Future.value();

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    if (_playerCreated) _player.dispose();
    super.dispose();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  @override
  Future<void> setVolume(double percent) {
    _volume = percent.clamp(0, maxVolume);
    return _player.setVolume(_volume);
  }

  @override
  double get volume => _volume;

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  bool get playing => _player.state.playing;

  @override
  bool get buffering => _buffering;

  @override
  double get bufferedPercent => _bufferPct;

  @override
  Size? get videoSize {
    final w = _player.state.width, h = _player.state.height;
    if (w == null || h == null || w == 0 || h == 0) return null;
    return Size(w.toDouble(), h.toDouble());
  }

  // ── Tracks ──

  @override
  List<MediaTrack> get audioTracks => [
        for (final t in _tracks.audio)
          if (t != mk.AudioTrack.no() && t != mk.AudioTrack.auto())
            MediaTrack(id: t.id, label: _audioLabel(t), raw: t),
      ];

  static String _audioLabel(mk.AudioTrack t) {
    final parts = <String>[];
    if ((t.language ?? '').isNotEmpty) parts.add(t.language!.toUpperCase());
    if ((t.title ?? '').isNotEmpty) parts.add(t.title!);
    return parts.isEmpty ? 'Traccia ${t.id}' : parts.join(' · ');
  }

  @override
  MediaTrack? get activeAudioTrack {
    final a = _track.audio;
    if (a == mk.AudioTrack.no()) return null;
    return MediaTrack(id: a.id, label: _audioLabel(a), raw: a);
  }

  @override
  Future<void> selectAudioTrack(MediaTrack track) async {
    if (track.raw is mk.AudioTrack) {
      await _player.setAudioTrack(track.raw as mk.AudioTrack);
    }
  }

  @override
  List<MediaTrack> get subtitleTracks => [
        for (final t in _tracks.subtitle)
          if (t != mk.SubtitleTrack.no() && t != mk.SubtitleTrack.auto())
            MediaTrack(id: t.id, label: _subLabel(t), raw: t),
      ];

  static String _subLabel(mk.SubtitleTrack t) {
    final parts = <String>[];
    if ((t.language ?? '').isNotEmpty) parts.add(t.language!.toUpperCase());
    if ((t.title ?? '').isNotEmpty) parts.add(t.title!);
    return parts.isEmpty ? 'Sub ${t.id}' : parts.join(' — ');
  }

  @override
  MediaTrack? get activeSubtitleTrack {
    final s = _track.subtitle;
    if (s == mk.SubtitleTrack.no()) return null;
    return MediaTrack(id: s.id, label: _subLabel(s), raw: s);
  }

  @override
  Future<void> selectSubtitleTrack(MediaTrack? track) async {
    if (track == null) {
      await _player.setSubtitleTrack(mk.SubtitleTrack.no());
    } else if (track.raw is mk.SubtitleTrack) {
      await _player.setSubtitleTrack(track.raw as mk.SubtitleTrack);
    }
  }

  @override
  List<MediaTrack> get videoTracks => [
        for (final t in _tracks.video)
          if (t != mk.VideoTrack.no() && t != mk.VideoTrack.auto())
            MediaTrack(id: t.id, label: _videoLabel(t), raw: t),
      ];

  static String _videoLabel(mk.VideoTrack t) {
    final parts = <String>[];
    if ((t.title ?? '').isNotEmpty) parts.add(t.title!);
    if ((t.h ?? 0) > 0) parts.add('${t.h}p');
    if ((t.fps ?? 0) > 0) parts.add('${t.fps!.round()} fps');
    return parts.isEmpty ? 'Traccia ${t.id}' : parts.join(' — ');
  }

  @override
  MediaTrack? get activeVideoTrack {
    final v = _track.video;
    if (v == mk.VideoTrack.no()) return null;
    return MediaTrack(id: v.id, label: _videoLabel(v), raw: v);
  }

  @override
  Future<void> selectVideoTrack(MediaTrack track) async {
    if (track.raw is mk.VideoTrack) {
      await _player.setVideoTrack(track.raw as mk.VideoTrack);
    }
  }

  @override
  Widget buildView() {
    final vc = _videoController;
    if (vc == null) return const SizedBox.shrink();
    return mkv.Video(
      controller: vc,
      controls: null,
      subtitleViewConfiguration: mkv.SubtitleViewConfiguration(
        style: TextStyle(
          fontSize: _style.fontSize,
          color: _style.color,
          backgroundColor: _style.backgroundEnabled
              ? const Color(0xAA000000)
              : Colors.transparent,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        padding: EdgeInsets.only(bottom: _style.bottomPadding),
      ),
    );
  }
}
