import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/live_sync.dart';

Duration _s(num s) => Duration(milliseconds: (s * 1000).round());

void main() {
  test('the first check sets the target, nothing changes', () {
    final l = LiveSync();
    final r = l.step(_s(12));
    expect(l.target, _s(12));
    expect(r.rate, 1.0);
    expect(r.jumpTo, isNull);
  });

  test('within a segment of the target: nothing', () {
    final l = LiveSync()..step(_s(12));
    expect(l.step(_s(15)).rate, 1.0);
    expect(l.step(_s(9)).rate, 1.0);
  });

  test('behind: faster until back near the target', () {
    final l = LiveSync()..step(_s(12));
    expect(l.step(_s(20)).rate, LiveSync.fastRate);
    expect(l.step(_s(15)).rate, LiveSync.fastRate, reason: 'not there yet');
    expect(l.step(_s(12.5)).rate, 1.0);
  });

  test('ahead: slower until back near the target', () {
    final l = LiveSync()..step(_s(12));
    expect(l.step(_s(5)).rate, LiveSync.slowRate);
    expect(l.step(_s(10)).rate, LiveSync.slowRate);
    expect(l.step(_s(11.5)).rate, 1.0);
  });

  test('far behind (long buffering): jump back to the target', () {
    final l = LiveSync()..step(_s(12));
    final r = l.step(_s(30));
    expect(r.jumpTo, _s(12));
    expect(r.rate, 1.0);
  });

  test('a small target still waits at least minJump before jumping', () {
    final l = LiveSync()..step(_s(2));
    expect(l.step(_s(10)).jumpTo, isNull);
    expect(l.step(_s(15)).jumpTo, _s(2));
  });

  test('reset measures the target again', () {
    final l = LiveSync()..step(_s(12));
    l.reset();
    l.step(_s(20));
    expect(l.target, _s(20));
  });
}
