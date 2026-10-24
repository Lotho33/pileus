import 'dart:async';
import 'dart:io' show Platform;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import '../../../core/utils/metrics.dart';
import '../../../core/utils/perf_log.dart';
import 'buffer_policy.dart';
import 'decoder_capability_fallback.dart';
import 'media_track.dart';
import 'stream_format.dart';
import 'video_view_mode.dart';

export 'buffer_policy.dart' show appliedReserveSec;
export 'media_track.dart';
export 'stream_format.dart';
export 'video_view_mode.dart';

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

  /// Device-level Android video options (Preferenze → Player), read when
  /// the next native player is created. No effect on the mpv backend.
  /// [maxVideoHeight]: 0 = no cap. [stats]: periodic decoder counters in
  /// the `pileus/perf` log (field diagnostics).
  static void configureAndroidVideo({
    required bool softwareDecoder,
    required bool compatSurface,
    required int maxVideoHeight,
    required bool stats,
  }) {
    BetterPlayerAndroidOptions.preferSoftwareVideoDecoder = softwareDecoder;
    BetterPlayerAndroidOptions.legacySurfaceTexture = compatSurface;
    BetterPlayerAndroidOptions.maxVideoHeight = maxVideoHeight;
    BetterPlayerAndroidOptions.statsIntervalMs = stats ? 10000 : 0;
  }

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
    Metrics.playbackTick(p, playing: pl, buffering: buffering);
    notifyListeners();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Build the native controller. [bufferSeconds]: the playback reserve —
  /// seconds of media to keep buffered ahead (see buffer_policy.dart for
  /// each backend's mapping).
  Future<void> initialize(
    PlayerSubtitleStyle subtitleStyle, {
    required bool isLive,
    required int bufferSeconds,
  });

  /// Open [url] and start decoding. Safe to call again to switch stream
  /// (episode change, live source swap) on the same engine.
  ///
  /// [startPosition]: open the media already at this position (mycelium
  /// contract "Resume from Continue Watching") instead of decoding frame 0
  /// and seeking on the first position tick — that's what shows the first
  /// frame before jumping. One-shot: never carries over to a later
  /// open() call on the same engine (episode switch, live source swap), so
  /// callers don't need to remember to pass null themselves.
  /// ResumeSeekController (resume_seek.dart) remains the safety net if the
  /// backend doesn't manage to honour this.
  ///
  /// [format]: see [StreamFormat]. Only the ExoPlayer backend needs it (it
  /// picks the HLS or the progressive pipeline up front); mpv probes the
  /// content itself.
  Future<void> open(String url,
      {required Map<String, String> headers,
      Duration? startPosition,
      StreamFormat format = StreamFormat.auto});

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

  /// The picture stopped updating while playback (audio, position) goes on,
  /// and the backend's own cheap recovery didn't fix it. Only the ExoPlayer
  /// backend detects this (patched better_player_plus). The screen decides
  /// how hard to recover — a fresh engine is the reliable fix.
  VoidCallback? onVideoFrozen;

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

  /// The video render surface. Style is fixed at [initialize] time; the
  /// picture follows [videoViewMode] live.
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
  // Consumed (and cleared) by the next `initialized` event — see open()'s
  // own doc for why this can never leak into a later episode/source.
  Duration? _pendingStartPosition;

  // ExoPlayer leaves playWhenReady set after a fatal error (the player just
  // drops to IDLE), so the Dart-side isPlaying stays true. Without this the
  // screens' grace timers read "still playing" and never surface the error.
  // Every onPlayerError is fatal in ExoPlayer; cleared by the next open().
  bool _failed = false;

  // Decoder-capability fallback (see decoder_capability_fallback.dart).
  // _lastUrl/_lastHeaders: what to reopen. _capTried: indices into the
  // current source's asms tracks already used as a fallback — reset only by
  // an external open(), so one source never loops through the same quality.
  String? _lastUrl;
  Map<String, String> _lastHeaders = const {};
  StreamFormat _lastFormat = StreamFormat.auto;
  final Set<int> _capTried = {};
  bool _capRecovering = false;

  @override
  Future<void> initialize(
    PlayerSubtitleStyle style, {
    required bool isLive,
    required int bufferSeconds,
  }) async {
    _isLive = isLive;

    // [bufferSeconds] is the Preferenze "Riserva di riproduzione" — see
    // buffer_policy.dart for how it maps onto ExoPlayer's windows.
    final b = exoBufferMs(bufferSeconds);
    perf('exo: buffer reserve ${bufferSeconds}s → min=${b.minBuffer ~/ 1000}s '
        'max=${b.maxBuffer ~/ 1000}s afterRebuffer=${b.afterRebuffer / 1000}s '
        'forPlayback=${b.forPlayback / 1000}s (live=$isLive)');
    _bufferingConfig = BetterPlayerBufferingConfiguration(
      minBufferMs: b.minBuffer,
      maxBufferMs: b.maxBuffer,
      bufferForPlaybackMs: b.forPlayback,
      bufferForPlaybackAfterRebufferMs: b.afterRebuffer,
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        // NOT true, and BetterPlayerConfiguration.startAt is never used
        // either — both are controller-level config, re-applied verbatim on
        // every setupDataSource call, so a per-episode startAt would just
        // seek every later episode back to the FIRST one's resume point.
        // play() is instead called explicitly from _onEvent's `initialized`
        // case below, once any pending open()-time startPosition has been
        // seeked to — see open()'s own doc. Same effective behaviour as
        // autoPlay:true for the common "no resume point" case, just under
        // this engine's own control instead of the plugin's internal check.
        autoPlay: false,
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
            if (err != null) _handleError(err, source: 'player value');
            _emit();
          };
          vpc.addListener(_valueListener!);
        }
        // One-shot: seek to the pending resume point (if any) before
        // starting playback ourselves — autoPlay is deliberately off (see
        // initialize()'s own doc), so nothing else will call play() here.
        // Cleared immediately regardless of outcome so it can never apply
        // to a later open() (episode switch, live source swap, retry).
        final target = _pendingStartPosition;
        _pendingStartPosition = null;
        if (target != null && target > Duration.zero) {
          perf('exo: seeking to resume point ${target.inSeconds}s before play');
          _c.seekTo(target).then((_) => _c.play());
        } else {
          _c.play();
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
        final msg =
            e.parameters?['exception']?.toString() ?? 'Errore sconosciuto';
        _handleError(msg, source: 'exception');
        _emit();
      case BetterPlayerEventType.changedResolution:
        perf('exo: changedResolution pos=${position.inMilliseconds}ms');
        _emit();
      case BetterPlayerEventType.changedTrack:
        perf('exo: changedTrack');
        _emit();
      case BetterPlayerEventType.decoderStalled:
        _onDecoderStalled(e.parameters);
      case BetterPlayerEventType.videoStats:
        _logVideoStats(e.parameters);
      case BetterPlayerEventType.videoFrozen:
        final p = e.parameters;
        perf(
            'exo: video frozen at ${(p?['position'] as Duration?)?.inSeconds}s '
            '(rendered=${p?['rendered']} dropped=${p?['dropped']}), '
            'surface re-attach did not help');
        onVideoFrozen?.call();
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

  // Previous videoStats counters, to log per-interval deltas. Reset when
  // the native counters restart (new decoder instance).
  int _statsRendered = 0;
  int _statsDropped = 0;

  /// One `pileus/perf` line per stats interval (field diagnostics only):
  /// frames shown/dropped in that interval, the variant playing, buffer
  /// ahead. Dropped frames with a healthy buffer = the box can't keep up;
  /// a buffer near 0 = the network/server can't.
  void _logVideoStats(Map<String, dynamic>? p) {
    if (p == null) return;
    final rendered = (p['rendered'] as int?) ?? 0;
    final dropped = (p['dropped'] as int?) ?? 0;
    if (rendered < _statsRendered || dropped < _statsDropped) {
      _statsRendered = 0;
      _statsDropped = 0;
    }
    final pos = p['position'] as Duration?;
    final bitrate = (p['bitrate'] as int?) ?? -1;
    perf('exo: stats pos=${pos?.inSeconds}s '
        '${p['width']}x${p['height']}'
        '@${bitrate > 0 ? '${(bitrate / 1000).round()}k' : '?'} '
        'shown=+${rendered - _statsRendered} dropped=+${dropped - _statsDropped} '
        '(tot $dropped) buffer=${((p['bufferedMs'] as int?) ?? 0) ~/ 1000}s '
        'playing=${p['playing']}');
    _statsRendered = rendered;
    _statsDropped = dropped;
  }

  // Native "decoderStalled" (patched better_player_plus): no exception, the
  // player just never leaves buffering with a full buffer — the decoder
  // can't take this video. Same recovery as an explicit capability error.
  void _onDecoderStalled(Map<String, dynamic>? p) {
    int? known(Object? v) => (v is int && v > 0) ? v : null;
    final failed = FailedVideoFormat(
      width: known(p?['width']),
      height: known(p?['height']),
      bitrate: known(p?['bitrate']),
    );
    perf('exo: decoder stalled on ${failed.sizeLabel ?? '?'}'
        '@${failed.bitrate ?? '?'} (full buffer, no frames)');
    if (_capRecovering) return;
    if (_tryDecoderFallback(failed)) return;
    _buffering = false;
    _failed = true;
    final size = failed.sizeLabel;
    onError?.call('Il dispositivo non riesce a riprodurre questo video'
        '${size == null ? '' : ' ($size)'}');
    _emit();
  }

  /// Both error paths (the `exception` event and the value listener's
  /// errorDescription) carry the same native onPlayerError text, so this
  /// sees most errors twice — deduped on [_lastError].
  void _handleError(String msg, {required String source}) {
    if (msg == _lastError) return;
    final failed = parseDecoderCapabilityError(msg);
    // The same failure again (its second error path, or the old value
    // replayed while the source is swapped) — already being handled, and
    // must not mark the reopened player as failed.
    if (failed != null && _capRecovering) return;
    _lastError = msg;
    perf('exo: $source error: $msg');
    // An exception very often arrives mid-bufferingStart (the stall that
    // precedes it) — without clearing the flag here it stays stuck true
    // until a later open() cycles through a fresh bufferingStart/End
    // pair, reading as "the spinner never went away" even once the
    // screen's own error handling has moved on.
    _buffering = false;
    _failed = true;

    if (failed == null) {
      onError?.call(msg);
      return;
    }
    if (_tryDecoderFallback(failed)) return;
    final size = failed.sizeLabel;
    onError?.call('Risoluzione video non supportata da questo dispositivo'
        '${size == null ? '' : ' ($size)'}');
  }

  /// Reopens the current source capped to a lower HLS variant after the
  /// decoder refused the one ExoPlayer picked. False when there is no lower
  /// variant left to try (single-quality playlist, or all tried already).
  bool _tryDecoderFallback(FailedVideoFormat failed) {
    final url = _lastUrl;
    if (url == null) return false;
    final tracks = _c.betterPlayerAsmsTracks;
    final variants = [
      for (final t in tracks) (height: t.height ?? 0, bitrate: t.bitrate ?? 0),
    ];
    final idx = pickDecoderFallback(variants, failed, _capTried);
    if (idx == null) return false;
    _capTried.add(idx);
    final track = tracks[idx];
    // Not started yet (the usual case: MediaCodec fails on the first frame)
    // → the resume point open() was given is still pending; otherwise pick
    // up where playback died. Live just rejoins the edge.
    final pos = position;
    final resumeAt = _isLive
        ? null
        : (_pendingStartPosition ?? (pos > Duration.zero ? pos : null));
    perf('exo: decoder refused ${failed.sizeLabel ?? '?'}'
        '@${failed.bitrate ?? '?'} → reopening capped to '
        '${track.height ?? '?'}p@${track.bitrate ?? '?'} at '
        '${resumeAt?.inSeconds ?? 0}s');
    _capRecovering = true;
    // Next event-loop turn: lets the rest of this error's dispatch (it
    // reaches us twice) finish against the failed player first.
    Future(() async {
      if (_disposed || _controller == null) {
        _capRecovering = false;
        return;
      }
      try {
        // Pinned *before* the reopen: the cap must be on the track selector
        // when the source is prepared. Applied afterwards (as it was), the
        // player had already picked the top variant again on a fast LAN —
        // the same decoder error a second later, and a needless drop to an
        // even lower quality (seen on the Mi TV Stick with Monster).
        _c.pinTrackForNextSource(track);
        await _open(url,
            headers: _lastHeaders,
            startPosition: resumeAt,
            format: _lastFormat);
        if (_controller == null) return; // disposed meanwhile
        // Built here, not looked up: setupDataSource re-parses the playlist
        // asynchronously, so videoTracks may still be empty. Same id scheme
        // as videoTracks, so the settings panel highlights it.
        if ((track.height ?? 0) > 0) {
          _selectedVideo = MediaTrack(
            id: '${track.height}p@${track.bitrate}',
            label: _videoLabel(track),
            raw: track,
          );
        }
        _emit();
      } catch (e) {
        perf('exo: decoder fallback reopen failed: $e');
      } finally {
        _capRecovering = false;
      }
    });
    return true;
  }

  static final _progressiveExt =
      RegExp(r'\.(mp4|mkv|webm|mov|avi|m4v)(\?|$)', caseSensitive: false);

  @override
  Future<void> open(String url,
      {required Map<String, String> headers,
      Duration? startPosition,
      StreamFormat format = StreamFormat.auto}) {
    _capTried.clear();
    return _open(url,
        headers: headers, startPosition: startPosition, format: format);
  }

  Future<void> _open(String url,
      {required Map<String, String> headers,
      Duration? startPosition,
      required StreamFormat format}) async {
    perf('exo: open (live=$_isLive, format=${format.name}, '
        'startPosition=$startPosition)');
    _lastUrl = url;
    _lastHeaders = headers;
    _lastFormat = format;
    _lastError = null;
    _failed = false;
    _selectedVideo = null;
    _pendingStartPosition = startPosition;
    // ExoPlayer needs the pipeline up front: a wrong one fails with a bare
    // "Source error". An explicit format (offline downloads, from
    // DownloadInfo.container) wins; otherwise mycelium serves HLS unless the
    // URL clearly names a progressive container. Progressive is always
    // passed as `other`, never left null: with no hint the plugin infers the
    // type from the path's extension and throws on a path without a dot
    // (`/downloads/file?…` used to be exactly that).
    final progressive = switch (format) {
      StreamFormat.progressive => true,
      StreamFormat.hls => false,
      StreamFormat.auto => _progressiveExt.hasMatch(url),
    };
    final videoFormat = progressive
        ? BetterPlayerVideoFormat.other
        : BetterPlayerVideoFormat.hls;
    try {
      await _c.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          url,
          headers: headers,
          liveStream: _isLive,
          videoFormat: videoFormat,
          // HLS master-playlist tracks; a progressive file has none.
          useAsmsTracks: !progressive,
          useAsmsAudioTracks: !progressive,
          useAsmsSubtitles: !progressive,
          bufferingConfiguration: _bufferingConfig,
        ),
      );
    } catch (e) {
      // setupDataSource can reject (bad URL, cleartext blocked, 4xx). Route
      // it through onError like a mid-stream failure instead of letting it
      // surface as an unhandled async exception — open() is called
      // fire-and-forget from the screen.
      _handleError(e.toString(), source: 'setupDataSource');
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
  Future<void> playOrPause() => playing ? _c.pause() : _c.play();

  @override
  Future<void> seek(Duration to) {
    Metrics.seekBegin(to);
    return _c.seekTo(to);
  }

  @override
  Future<void> setVolume(double percent) =>
      _c.setVolume((percent / 100.0).clamp(0.0, 1.0));

  @override
  double get volume =>
      ((_controller?.videoPlayerController?.value.volume ?? 1.0) * 100)
          .clamp(0, 100);

  @override
  Duration get position =>
      _controller?.videoPlayerController?.value.position ?? Duration.zero;

  @override
  Duration get duration =>
      _controller?.videoPlayerController?.value.duration ?? Duration.zero;

  /// Follows ExoPlayer's playWhenReady (our patched better_player_plus, see
  /// third_party/better_player_plus/PILEUS_PATCHES.md), so it stays true
  /// through a rebuffer — what the screens' stall watchdogs rely on.
  @override
  bool get playing =>
      !_failed &&
      (_controller?.videoPlayerController?.value.isPlaying ?? false);

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
    if ((t.label ?? '').isNotEmpty && t.label != t.language) {
      parts.add(t.label!);
    }
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

  // better_player lays its picture out in an AspectRatio box that defaults
  // to a fixed 16:9 (we never set one) — on a 20:9 phone the video never
  // used the whole screen, and zoom/fill would have been confined to that
  // box. Here the box is the whole area (or the forced-ratio box), and the
  // mode picks the fit of the picture inside it. Subtitles are drawn in the
  // same box, so they stay on screen in every mode.
  @override
  Widget buildView() {
    if (_controller == null) return const SizedBox.shrink();
    return ValueListenableBuilder<VideoViewMode>(
      valueListenable: videoViewMode,
      builder: (context, mode, _) => LayoutBuilder(builder: (context, c) {
        var area = c.biggest;
        if (!area.isFinite) area = MediaQuery.sizeOf(context);
        final forced = mode.forcedAspect;
        final box = forced == null ? area : containAspect(area, forced);
        final fit = switch (mode) {
          VideoViewMode.fit => BoxFit.contain,
          VideoViewMode.zoom => BoxFit.cover,
          // Forced ratios: the box already has the target proportions.
          VideoViewMode.stretch ||
          VideoViewMode.ratio16x9 ||
          VideoViewMode.ratio4x3 =>
            BoxFit.fill,
        };
        // Read by better_player's own build, which runs right after this.
        if (box.width > 0 && box.height > 0) {
          _c.setOverriddenAspectRatio(box.width / box.height);
        }
        if (_c.getFit() != fit) _c.setOverriddenFit(fit);
        return Center(
          child: SizedBox.fromSize(
            size: box,
            child: BetterPlayer(controller: _c),
          ),
        );
      }),
    );
  }

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
    required int bufferSeconds,
  }) async {
    _style = style;
    // The reserve is time-based (demuxer-readahead-secs / cache-secs, set
    // below once mpv is up); bufferSize (→ demuxer-max-bytes) is only a
    // safety ceiling now, not the user's choice — see buffer_policy.dart.
    final capBytes = mpvBufferCapBytes(bufferSeconds);
    _player = mk.Player(
      configuration: mk.PlayerConfiguration(bufferSize: capBytes),
    );
    perf('mpv: buffer reserve ${bufferSeconds}s '
        '(readahead/cache-secs=$bufferSeconds, '
        'max-bytes cap=${capBytes ~/ (1024 * 1024)} MiB, live=$isLive)');
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
        // Same safe point (mpv handle up, independent of open()).
        native.setProperty('demuxer-readahead-secs', '$bufferSeconds',
            waitForInitialization: false);
        native.setProperty('cache-secs', '$bufferSeconds',
            waitForInitialization: false);
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
  Future<void> open(String url,
      {required Map<String, String> headers,
      Duration? startPosition,
      StreamFormat format = StreamFormat.auto}) async {
    // mk.Media.start (media_kit's own contract-level "open at position"
    // hook — verified against the installed media_kit 1.2.6's native
    // player: it sets mpv's own `start` property reactively, off the
    // start-file event fired for that playlist entry, before mpv begins
    // decoding it) covers the positive case entirely on its own. It only
    // ever *sets* that property when Media.start is non-null, though — it
    // never resets it back for a Media with none of its own, so a resume
    // position from an earlier open() call on this same long-lived _player
    // would otherwise silently leak into every later episode/source with no
    // start of its own. Clear it explicitly first whenever this open() has
    // nothing to seek to.
    if ((startPosition == null || startPosition <= Duration.zero) && !kIsWeb) {
      try {
        final dynamic native = _player.platform;
        // Same handle-not-ready-yet race initialize() already hit and fixed
        // for 'volume-max' (see that doc comment for the full story) — the
        // mpv handle (`ctx`) is still `nullptr` until Player's fire-and-
        // forget _create() finishes, independently of how soon open() is
        // called after initialize(). Usually plenty of time passes before a
        // screen actually calls open() (the plugin's own stream-resolve
        // RPC), but a plugin that resolves near-instantly (a direct_stream
        // URL with nothing to look up) could call this before the handle
        // existed, handing mpv's C API a null `ctx` — segfault, not a
        // catchable Dart exception. `waitForPlayerInitialization` (not
        // setProperty's own `waitForInitialization: true`, which also waits
        // for a video controller — only attaches post-open(), the exact
        // deadlock this facade avoids elsewhere) only waits for that handle,
        // so it's safe to await here, ahead of _player.open() below.
        await (native.waitForPlayerInitialization as Future<void>);
        native.setProperty('start', 'none', waitForInitialization: false);
      } catch (_) {
        // Best-effort — a failure here just means ResumeSeekController's
        // safety net (or, worse, the stale property) decides instead;
        // never worth failing the whole open() over.
      }
    }
    // Web + HLS: media_kit's web player never applies Media.start on its
    // hls.js path (only as a `#t=` fragment on a plain `src`), yet its
    // timeupdate handler still clamps the reported position to >= start —
    // so the stream played from 0 while `position` read the resume point,
    // ResumeSeekController took that as "already landed" and never seeked,
    // and every progress save wrote the resume point back unchanged
    // (Continue Watching "always restarts from the beginning" on Tizen/
    // webOS). Leave start out there; ResumeSeekController's seek on the
    // first real position tick does the resume instead.
    final hlsOnWeb = kIsWeb && url.toLowerCase().contains('m3u8');
    await _player.open(mk.Media(url,
        httpHeaders: headers,
        start: (startPosition != null &&
                startPosition > Duration.zero &&
                !hlsOnWeb)
            ? startPosition
            : null));
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
  Future<void> seek(Duration to) {
    Metrics.seekBegin(to);
    return _player.seek(to);
  }

  @override
  Future<void> setVolume(double percent) {
    _volume = percent.clamp(0, maxVolume);
    return _player.setVolume(_volume);
  }

  @override
  double get volume => _volume;

  // initialize() is now called lazily (right before the first open(), not
  // eagerly in initState — see _ensureEngineInitialized() in the TV/desktop
  // player screens) so every state getter below can be read from an overlay
  // rebuild that happens *before* _player exists (the whole
  // FetchingStreams/ResolvingMediaStream/PlaybackResolveProgress window).
  // Touching the `late final` field directly threw LateInitializationError
  // on every single one of those rebuilds — reported mpv/desktop
  // backend, spamming "Another exception was thrown" throughout the loading
  // spinner. _playerCreated is the same guard stop()/dispose() already used.
  @override
  Duration get position =>
      _playerCreated ? _player.state.position : Duration.zero;

  @override
  Duration get duration =>
      _playerCreated ? _player.state.duration : Duration.zero;

  @override
  bool get playing => _playerCreated && _player.state.playing;

  @override
  bool get buffering => _buffering;

  @override
  double get bufferedPercent => _bufferPct;

  @override
  Size? get videoSize {
    if (!_playerCreated) return null;
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
    return ValueListenableBuilder<VideoViewMode>(
      valueListenable: videoViewMode,
      builder: (context, mode, _) => _mkVideo(vc, mode),
    );
  }

  Widget _mkVideo(mkv.VideoController vc, VideoViewMode mode) {
    return mkv.Video(
      controller: vc,
      controls: null,
      // media_kit's aspectRatio forces the picture's proportions; fit places
      // it in the viewport.
      fit: switch (mode) {
        VideoViewMode.zoom => BoxFit.cover,
        VideoViewMode.stretch => BoxFit.fill,
        _ => BoxFit.contain,
      },
      aspectRatio: mode.forcedAspect,
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
