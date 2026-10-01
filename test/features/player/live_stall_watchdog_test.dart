import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/live_stall_watchdog.dart';

void main() {
  // Fake async clock: LiveStallWatchdog measures wall-clock DateTime.now()
  // differences, so these tests drive fake_async-style behaviour by hand —
  // arm() with a very short checkEvery and real (but tiny) Durations, using
  // Future.delayed to let the periodic Timer actually fire. Kept well under
  // flutter_test's default timeout.
  group('LiveStallWatchdog', () {
    test('healthy + no buffering: tier1 nudge, then tier2 on the next strike',
        () async {
      var healthy = true;
      var buffering = false;
      var tier1Calls = 0;
      var tier2Calls = 0;

      final watchdog = LiveStallWatchdog(
        isHealthy: () => healthy,
        isBuffering: () => buffering,
        onStallTier1: () => tier1Calls++,
        onStallTier2: () => tier2Calls++,
        checkEvery: const Duration(milliseconds: 20),
        stallThreshold: const Duration(milliseconds: 50),
        bufferingStallThreshold: const Duration(milliseconds: 100),
      );
      addTearDown(watchdog.disarm);

      watchdog.recordProgress();
      watchdog.arm();

      // First strike: past stallThreshold, still under 2 strikes → tier1.
      await Future.delayed(const Duration(milliseconds: 80));
      expect(tier1Calls, 1);
      expect(tier2Calls, 0);

      // recordProgress() is reset internally after acting, so the second
      // strike needs another full stallThreshold to elapse.
      await Future.delayed(const Duration(milliseconds: 80));
      expect(tier1Calls, 1);
      expect(tier2Calls, 1);
    });

    test('recordProgress() before the threshold suppresses both tiers',
        () async {
      var tier1Calls = 0;
      var tier2Calls = 0;

      final watchdog = LiveStallWatchdog(
        isHealthy: () => true,
        isBuffering: () => false,
        onStallTier1: () => tier1Calls++,
        onStallTier2: () => tier2Calls++,
        checkEvery: const Duration(milliseconds: 20),
        stallThreshold: const Duration(milliseconds: 60),
      );
      addTearDown(watchdog.disarm);
      watchdog.arm();

      // Keep "resetting the clock" faster than stallThreshold, like a
      // genuinely healthy stream ticking position updates.
      for (var i = 0; i < 5; i++) {
        watchdog.recordProgress();
        await Future.delayed(const Duration(milliseconds: 30));
      }
      expect(tier1Calls, 0);
      expect(tier2Calls, 0);
    });

    test('not healthy (e.g. a pending playback error): never fires', () async {
      var tier1Calls = 0;
      var tier2Calls = 0;

      final watchdog = LiveStallWatchdog(
        isHealthy: () => false,
        isBuffering: () => false,
        onStallTier1: () => tier1Calls++,
        onStallTier2: () => tier2Calls++,
        checkEvery: const Duration(milliseconds: 20),
        stallThreshold: const Duration(milliseconds: 30),
      );
      addTearDown(watchdog.disarm);
      watchdog.recordProgress();
      watchdog.arm();

      await Future.delayed(const Duration(milliseconds: 100));
      expect(tier1Calls, 0);
      expect(tier2Calls, 0);
    });

    test(
        'stuck buffering past bufferingStallThreshold: goes straight to '
        'tier2, skipping the tier1 nudge entirely — this is the fix for a '
        'live stream that stays in buffering forever never recovering',
        () async {
      var tier1Calls = 0;
      var tier2Calls = 0;

      final watchdog = LiveStallWatchdog(
        isHealthy: () => true,
        isBuffering: () => true,
        onStallTier1: () => tier1Calls++,
        onStallTier2: () => tier2Calls++,
        checkEvery: const Duration(milliseconds: 20),
        // A short stallThreshold that would fire almost immediately if the
        // buffering branch didn't use its own (longer) threshold — proves
        // the buffering path is actually being taken, not the plain one.
        stallThreshold: const Duration(milliseconds: 10),
        bufferingStallThreshold: const Duration(milliseconds: 80),
      );
      addTearDown(watchdog.disarm);
      watchdog.recordProgress();
      watchdog.arm();

      // Still under bufferingStallThreshold: nothing yet, even though it's
      // already well past the (shorter) plain stallThreshold.
      await Future.delayed(const Duration(milliseconds: 40));
      expect(tier1Calls, 0);
      expect(tier2Calls, 0);

      // Past bufferingStallThreshold now.
      await Future.delayed(const Duration(milliseconds: 60));
      expect(tier1Calls, 0);
      expect(tier2Calls, 1);
    });

    test('disarm() stops the timer for good', () async {
      var calls = 0;
      final watchdog = LiveStallWatchdog(
        isHealthy: () => true,
        isBuffering: () => false,
        onStallTier1: () => calls++,
        onStallTier2: () => calls++,
        checkEvery: const Duration(milliseconds: 10),
        stallThreshold: const Duration(milliseconds: 20),
      );
      watchdog.recordProgress();
      watchdog.arm();
      watchdog.disarm();

      await Future.delayed(const Duration(milliseconds: 100));
      expect(calls, 0);
    });
  });
}
