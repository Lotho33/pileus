/// Keeps a live stream at the same distance from the live edge on every
/// device, so two screens on the same match stay within a segment of each
/// other.
///
/// The server stamps every live playlist with the shared target
/// (`EXT-X-START` / `HOLD-BACK`, three segments): players that read it start
/// there. Where the player itself steers back to it — ExoPlayer (the fork's
/// live configuration) and hls.js (its live-sync config) — this isn't used.
/// The others (mpv on desktop, media_kit on the TV-web build, Safari's own
/// HLS on iOS) report only how far they are from the edge; this decides what
/// to do every few seconds:
///
///  - within [tolerance] of the target: nothing;
///  - further behind: 1.04× until back near it (pitch is preserved);
///  - ahead (rare): 0.97×;
///  - more than one extra target behind (at least [minJump], typically
///    after a long buffering): jump straight back to it.
///
/// The target is the distance measured at the first check after the stream
/// starts — where the player put it, i.e. the shared target — so each
/// player's own idea of "the edge" doesn't matter, only how it drifts.
class LiveSync {
  static const checkEvery = Duration(seconds: 5);
  static const tolerance = Duration(seconds: 4);
  static const minJump = Duration(seconds: 12);
  static const fastRate = 1.04;
  static const slowRate = 0.97;
  // Back to normal speed this close to the target.
  static const _settled = Duration(seconds: 1);
  static const _maxTarget = Duration(seconds: 30);

  Duration? _target;
  double _rate = 1.0;

  Duration? get target => _target;

  /// A new stream (or a source swap): measure the target again.
  void reset() {
    _target = null;
    _rate = 1.0;
  }

  /// [behind]: how far the playing position is from the player's live edge.
  /// Call only while playing (not paused, not buffering).
  LiveSyncStep step(Duration behind) {
    final target = _target;
    if (target == null) {
      _target = behind < Duration.zero
          ? Duration.zero
          : (behind > _maxTarget ? _maxTarget : behind);
      return const LiveSyncStep(rate: 1.0);
    }
    final drift = behind - target;
    final jumpAfter = target > minJump ? target : minJump;
    if (drift > jumpAfter) {
      _rate = 1.0;
      return LiveSyncStep(rate: 1.0, jumpTo: target);
    }
    if (drift > tolerance || (_rate > 1.0 && drift > _settled)) {
      _rate = fastRate;
    } else if (drift < -tolerance || (_rate < 1.0 && drift < -_settled)) {
      _rate = slowRate;
    } else {
      _rate = 1.0;
    }
    return LiveSyncStep(rate: _rate);
  }
}

/// What [LiveSync.step] asks for: play at [rate]; when [jumpTo] is set, first
/// seek to that distance from the live edge (edge − jumpTo).
class LiveSyncStep {
  final double rate;
  final Duration? jumpTo;

  const LiveSyncStep({required this.rate, this.jumpTo});
}
