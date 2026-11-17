import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/remote_seek.dart';

void main() {
  final t0 = DateTime(2026, 11, 17, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
  const pos = Duration(minutes: 5);
  const dur = Duration(minutes: 20);

  test('a press moves the target 10 s and release returns it', () {
    final s = RemoteSeek();
    expect(s.press(1, pos, dur, now: at(0)), isTrue);
    expect(s.target, const Duration(minutes: 5, seconds: 10));
    expect(s.release(), const Duration(minutes: 5, seconds: 10));
    expect(s.active, isFalse);
  });

  test('held: 10 s steps, then 30 s after six', () {
    final s = RemoteSeek();
    for (var i = 0; i < 8; i++) {
      s.press(1, pos, dur, now: at(i * 150));
    }
    // 6 × 10 s + 2 × 30 s.
    expect(s.target, pos + const Duration(seconds: 120));
  });

  test('repeats faster than the step pace are dropped', () {
    final s = RemoteSeek();
    s.press(-1, pos, dur, now: at(0));
    expect(s.press(-1, pos, dur, now: at(40)), isFalse);
    expect(s.target, pos - const Duration(seconds: 10));
  });

  test('clamped to the stream', () {
    final s = RemoteSeek();
    s.press(-1, const Duration(seconds: 4), dur, now: at(0));
    expect(s.target, Duration.zero);
    s.release();
    s.press(1, dur - const Duration(seconds: 3), dur, now: at(500));
    expect(s.target, dur - const Duration(seconds: 1));
  });

  test('turning around starts from the playhead again', () {
    final s = RemoteSeek();
    s.press(1, pos, dur, now: at(0));
    s.press(-1, pos, dur, now: at(200));
    expect(s.target, pos - const Duration(seconds: 10));
  });
}
