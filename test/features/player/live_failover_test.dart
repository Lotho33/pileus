import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/live_failover.dart';

void main() {
  test('each node once, in order, wrapping; then null', () {
    final f = LiveFailover(['a', 'b', 'c'], current: 'b');
    expect(f.next(), 'c');
    expect(f.next(), 'a');
    expect(f.next(), isNull); // b, c, a all failed
  });

  test('a single node never fails over', () {
    final f = LiveFailover(['a'], current: 'a');
    expect(f.enabled, isFalse);
    expect(f.next(), isNull);
  });

  test('a manual switch is followed', () {
    final f = LiveFailover(['a', 'b', 'c'], current: 'a');
    f.switchedTo('c');
    expect(f.next(), 'a');
  });

  test('unknown starting stream (launched by media id): first node next', () {
    final f = LiveFailover(['a', 'b'], current: 'event-id');
    expect(f.next(), 'a');
    expect(f.next(), 'b');
    expect(f.next(), isNull);
  });

  test('playing briefly does not forgive failed nodes', () {
    final f = LiveFailover(['a', 'b'], current: 'a');
    expect(f.next(), 'b');
    f.playing();
    expect(f.next(), isNull);
  });

  test('labels', () {
    final f = LiveFailover(['a', 'b'], current: 'a');
    expect(f.labelOf('b', ['Nodo 1', 'Nodo 2']), 'Nodo 2');
    expect(f.labelOf('b', const []), 'Sorgente 2');
  });

  test('after a minute of good playback every node is fair game again', () {
    var t = DateTime(2026);
    final f = LiveFailover(['a', 'b'], current: 'a', clock: () => t);
    expect(f.next(), 'b'); // a failed
    f.playing();
    t = t.add(const Duration(seconds: 61));
    f.playing();
    expect(f.next(), 'a'); // a is back in the rotation
  });
}
