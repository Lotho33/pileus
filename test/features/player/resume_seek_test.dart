import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/resume_seek.dart';

void main() {
  group('resolveStartPositionSec', () {
    test('live: always 0, no matter how large seekTo is', () {
      expect(resolveStartPositionSec(isLive: true, seekTo: 600), 0);
    });

    test('not live, seekTo at/below kResumeSeekMinTargetSec: 0', () {
      expect(resolveStartPositionSec(isLive: false, seekTo: 0), 0);
      expect(resolveStartPositionSec(isLive: false, seekTo: 2), 0);
    });

    test('not live, seekTo above the threshold: seekTo itself', () {
      expect(resolveStartPositionSec(isLive: false, seekTo: 3), 3.0);
      expect(resolveStartPositionSec(isLive: false, seekTo: 1830), 1830.0);
    });
  });

  group('resumeStartPosition', () {
    test('mirrors resolveStartPositionSec\'s own "not applicable" cases as '
        'null, not Duration.zero', () {
      expect(resumeStartPosition(isLive: true, seekTo: 600), isNull);
      expect(resumeStartPosition(isLive: false, seekTo: 2), isNull);
    });

    test('otherwise, the resume point as a Duration', () {
      expect(resumeStartPosition(isLive: false, seekTo: 125),
          const Duration(seconds: 125));
    });
  });

  group('ResumeSeekController.isDone / pendingStartPosition — before any '
      'onPosition call', () {
    test('live: done immediately, nothing to open at', () {
      final c = ResumeSeekController(targetSec: 300, isLive: true);
      expect(c.isDone, isTrue);
      expect(c.pendingStartPosition, isNull);
    });

    test('below kResumeSeekMinTargetSec: done immediately, nothing to open '
        'at', () {
      final c = ResumeSeekController(targetSec: 1, isLive: false);
      expect(c.isDone, isTrue);
      expect(c.pendingStartPosition, isNull);
    });

    test('a real target: not done yet, pendingStartPosition is the target',
        () {
      final c = ResumeSeekController(targetSec: 120, isLive: false);
      expect(c.isDone, isFalse);
      expect(c.pendingStartPosition, const Duration(seconds: 120));
    });

    test(
        'episode switch: a fresh instance built with targetSec 0 (every '
        'screen\'s own pattern — TV/mobile/desktop/web all rebuild their '
        'ResumeSeekController with targetSec: 0 on episode switch, never '
        'reusing the outgoing episode\'s target) never carries the previous '
        'episode\'s resume point over', () {
      final outgoing = ResumeSeekController(targetSec: 900, isLive: false);
      expect(outgoing.pendingStartPosition, const Duration(seconds: 900));

      // What every screen does on episode switch: a brand new instance, not
      // a mutation of `outgoing`.
      final incoming = ResumeSeekController(targetSec: 0, isLive: false);
      expect(incoming.isDone, isTrue);
      expect(incoming.pendingStartPosition, isNull);
    });
  });

  group('ResumeSeekController.onPosition — first call', () {
    test(
        'engine already opened at/near the target (PlayerEngine.open\'s own '
        'startPosition worked): confirms without ever calling seek', () {
      final c = ResumeSeekController(targetSec: 120, isLive: false);
      var seekCalls = 0;
      // Within kResumeSeekLandedToleranceSec (8s) of the 120s target.
      c.onPosition(const Duration(seconds: 118), (_) => seekCalls++);
      expect(seekCalls, 0);
      expect(c.isDone, isTrue);
    });

    test(
        'engine opened at frame 0 (startPosition ignored/unsupported): '
        'falls back to seeking once', () {
      final c = ResumeSeekController(targetSec: 120, isLive: false);
      final seeked = <Duration>[];
      c.onPosition(Duration.zero, seeked.add);
      expect(seeked, [const Duration(seconds: 120)]);
      // Not confirmed yet — landing is only checked on a *later* tick.
      expect(c.isDone, isFalse);
    });
  });

  group('ResumeSeekController.onPosition — confirm/retry after the first '
      'call', () {
    test('a later tick landed at/past the target: confirms, no more seeks',
        () {
      final c = ResumeSeekController(targetSec: 120, isLive: false);
      var seekCalls = 0;
      c.onPosition(Duration.zero, (_) => seekCalls++); // issues the seek
      expect(seekCalls, 1);
      c.onPosition(const Duration(seconds: 119), (_) => seekCalls++);
      expect(seekCalls, 1); // landed — no retry needed
      expect(c.isDone, isTrue);
    });

    test(
        'still stuck well below target but the retry gap has not elapsed '
        'yet: no retry', () async {
      final c = ResumeSeekController(
        targetSec: 120,
        isLive: false,
        retryGap: const Duration(milliseconds: 200),
      );
      var seekCalls = 0;
      c.onPosition(Duration.zero, (_) => seekCalls++); // issues the seek
      expect(seekCalls, 1);
      c.onPosition(Duration.zero, (_) => seekCalls++); // immediately after
      expect(seekCalls, 1);
      expect(c.isDone, isFalse);
    });

    test(
        'still stuck well below target once the retry gap elapses: retries',
        () async {
      final c = ResumeSeekController(
        targetSec: 120,
        isLive: false,
        retryGap: const Duration(milliseconds: 20),
      );
      var seekCalls = 0;
      c.onPosition(Duration.zero, (_) => seekCalls++); // issues the seek
      await Future.delayed(const Duration(milliseconds: 30));
      c.onPosition(Duration.zero, (_) => seekCalls++); // retry #1
      expect(seekCalls, 2);
      expect(c.isDone, isFalse);
    });

    test(
        'between the landed and give-up tolerances: neither confirms nor '
        'retries (close enough that re-seeking risks a visible jump)',
        () async {
      final c = ResumeSeekController(
        targetSec: 120,
        isLive: false,
        retryGap: const Duration(milliseconds: 20),
      );
      var seekCalls = 0;
      c.onPosition(Duration.zero, (_) => seekCalls++); // issues the seek
      await Future.delayed(const Duration(milliseconds: 30));
      // 108s: short of the 112s landed threshold (120-8) but past the 105s
      // give-up threshold (120-15).
      c.onPosition(const Duration(seconds: 108), (_) => seekCalls++);
      expect(seekCalls, 1);
      expect(c.isDone, isFalse);
    });

    test('gives up after kResumeSeekMaxRetries — the retry loop stops '
        'issuing seeks, but never confirms a position it never actually '
        'saw land', () async {
      final c = ResumeSeekController(
        targetSec: 120,
        isLive: false,
        retryGap: const Duration(milliseconds: 10),
      );
      var seekCalls = 0;
      c.onPosition(Duration.zero, (_) => seekCalls++); // initial issue

      for (var i = 0; i < 4; i++) {
        await Future.delayed(const Duration(milliseconds: 15));
        c.onPosition(Duration.zero, (_) => seekCalls++);
      }
      // Initial + kResumeSeekMaxRetries (4) retries.
      expect(seekCalls, 5);

      // One more tick past the retry gap: retries budget is exhausted, so
      // no further seek — the user can still seek by hand from here.
      await Future.delayed(const Duration(milliseconds: 15));
      c.onPosition(Duration.zero, (_) => seekCalls++);
      expect(seekCalls, 5);
      expect(c.isDone, isFalse);
    });
  });
}
