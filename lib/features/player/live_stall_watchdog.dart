import 'dart:async';

/// Detects a live stream silently stalled — "playing" with no error, but the
/// position hasn't actually advanced in a while — and recovers in two tiers.
/// Extracted from the TV player's `_armLiveStallWatchdog`
/// (`presentation/playback_screen/view.dart`) into closures so desktop
/// (backed by `PlayerEngine`) and web (backed by an `HTMLVideoElement`) can
/// both use it with their own glue, instead of duplicating the timer/strike
/// logic per platform.
///
/// [isHealthy] should return true when the stream looks fine right now
/// (playing, not buffering, no pending error) — the watchdog only measures
/// staleness while this is true, same as the original. [recordProgress]
/// resets the staleness clock; call it whenever the position actually moves.
class LiveStallWatchdog {
  final bool Function() isHealthy;
  final void Function() onStallTier1;
  final void Function() onStallTier2;
  final Duration checkEvery;
  final Duration stallThreshold;

  Timer? _timer;
  DateTime? _lastProgressAt;
  int _strikes = 0;

  LiveStallWatchdog({
    required this.isHealthy,
    required this.onStallTier1,
    required this.onStallTier2,
    this.checkEvery = const Duration(seconds: 4),
    this.stallThreshold = const Duration(seconds: 9),
  });

  /// Call once whenever the position actually advances (e.g. from the
  /// engine's/video element's position stream) — this is what "no progress
  /// for N seconds" is measured against.
  void recordProgress() => _lastProgressAt = DateTime.now();

  void arm() {
    _timer?.cancel();
    _timer = Timer.periodic(checkEvery, (_) {
      if (!isHealthy()) return;
      final last = _lastProgressAt;
      if (last == null) return;
      final stalledFor = DateTime.now().difference(last);
      if (stalledFor < stallThreshold) return;

      _strikes++;
      if (_strikes <= 1) {
        onStallTier1();
      } else {
        _strikes = 0;
        onStallTier2();
      }
      // Give a full interval before the next tick can trigger/escalate
      // again, same as the TV original.
      _lastProgressAt = DateTime.now();
    });
  }

  void disarm() {
    _timer?.cancel();
    _timer = null;
  }
}
