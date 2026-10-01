import 'dart:async';

/// Detects a live stream silently stalled — either "playing" with no error
/// but the position hasn't actually advanced in a while, or stuck buffering
/// indefinitely — and recovers in two tiers. Extracted from the TV player's
/// `_armLiveStallWatchdog` (`presentation/playback_screen/view.dart`) into
/// closures so desktop (backed by `PlayerEngine`) and web (backed by an
/// `HTMLVideoElement`) can both use it with their own glue, instead of
/// duplicating the timer/strike logic per platform.
///
/// [isHealthy] should return true when the stream should be evaluated at all
/// right now (mounted, no pending fatal error) — it deliberately does *not*
/// gate on "not buffering" any more (see [isBuffering]'s doc: a stream stuck
/// buffering forever is exactly the case this watchdog needs to catch).
/// [recordProgress] resets the staleness clock; call it whenever the
/// position actually moves.
class LiveStallWatchdog {
  final bool Function() isHealthy;

  /// True while the engine is buffering right now. A live stream that stays
  /// in this state past [bufferingStallThreshold] — the typical shape of a
  /// dead upstream feed or an HLS live-edge the player fell behind — goes
  /// straight to [onStallTier2] (a fresh resolve): the pause/play nudge
  /// [onStallTier1] does for the other, "reports playing but frozen" stall
  /// doesn't make sense mid-buffer and won't fix a genuinely dead feed.
  /// Before this, `isHealthy` required `!buffering`, so a live stream stuck
  /// buffering forever was never recovered at all — reported as "a dead
  /// live channel with an unstable line just freezes on the spinner".
  final bool Function() isBuffering;
  final void Function() onStallTier1;
  final void Function() onStallTier2;
  final Duration checkEvery;
  final Duration stallThreshold;
  final Duration bufferingStallThreshold;

  Timer? _timer;
  DateTime? _lastProgressAt;
  int _strikes = 0;

  LiveStallWatchdog({
    required this.isHealthy,
    required this.isBuffering,
    required this.onStallTier1,
    required this.onStallTier2,
    this.checkEvery = const Duration(seconds: 4),
    this.stallThreshold = const Duration(seconds: 9),
    this.bufferingStallThreshold = const Duration(seconds: 18),
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
      final buffering = isBuffering();
      final threshold = buffering ? bufferingStallThreshold : stallThreshold;
      if (stalledFor < threshold) return;

      if (buffering) {
        // Stuck buffering, not merely "playing but frozen" — skip the nudge
        // tier and go straight for a fresh resolve.
        _strikes = 0;
        onStallTier2();
      } else {
        _strikes++;
        if (_strikes <= 1) {
          onStallTier1();
        } else {
          _strikes = 0;
          onStallTier2();
        }
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
