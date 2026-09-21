import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/request_gate.dart';

void main() {
  test('never runs more than `limit` tasks at once, FIFO, and drains',
      () async {
    final gate = RequestGate(2);
    var running = 0;
    var peak = 0;
    final order = <int>[];
    final releases = <Completer<void>>[];

    Future<int> task(int i) => gate.run(() async {
          order.add(i);
          running++;
          peak = peak < running ? running : peak;
          final c = Completer<void>();
          releases.add(c);
          await c.future;
          running--;
          return i;
        });

    final results = [for (var i = 0; i < 5; i++) task(i)];
    await Future<void>.delayed(Duration.zero);
    expect(order, [0, 1]); // 2 admitted, 3 waiting

    while (releases.isNotEmpty) {
      releases.removeAt(0).complete();
      await Future<void>.delayed(Duration.zero);
    }
    expect(await Future.wait(results), [0, 1, 2, 3, 4]);
    expect(order, [0, 1, 2, 3, 4]);
    expect(peak, 2);
  });

  test('a failing task frees its slot', () async {
    final gate = RequestGate(1);
    final failed = gate.run<void>(() async => throw StateError('boom'));
    final next = gate.run(() async => 'ok');
    await expectLater(failed, throwsStateError);
    expect(await next, 'ok');
  });

  test('after a group switch the newest group is served first', () async {
    final gate = RequestGate(1);
    final order = <String>[];
    final hold = Completer<void>();
    final running = gate.run(() => hold.future, group: 'old');
    final futures = [
      gate.run(() async => order.add('old-1'), group: 'old'),
      gate.run(() async => order.add('old-2'), group: 'old'),
      gate.run(() async => order.add('new-1'), group: 'new'),
      gate.run(() async => order.add('new-2'), group: 'new'),
    ];
    hold.complete();
    await Future.wait([running, ...futures]);
    expect(order, ['new-1', 'new-2', 'old-1', 'old-2']);
  });
}
