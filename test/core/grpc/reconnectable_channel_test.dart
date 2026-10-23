import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' hide ClientChannel;
import 'package:grpc/service_api.dart' show ClientChannel;
import 'package:pileus/core/grpc/reconnectable_channel.dart';

class _FakeChannel implements ClientChannel {
  int shutdowns = 0;
  int terminates = 0;

  @override
  Future<void> shutdown() async => shutdowns++;

  @override
  Future<void> terminate() async => terminates++;

  @override
  ClientCall<Q, R> createCall<Q, R>(
          ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options) =>
      throw UnimplementedError();

  @override
  Stream<ConnectionState> get onConnectionStateChanged =>
      const Stream.empty();
}

void main() {
  test('reconnect swaps the channel, drains the old one, then closes it',
      () async {
    final made = <_FakeChannel>[];
    final ch = ReconnectableChannel(() {
      final c = _FakeChannel();
      made.add(c);
      return c;
    }, drainGrace: const Duration(milliseconds: 20));
    expect(made, hasLength(1));

    ch.reconnect('test');
    await Future<void>.delayed(Duration.zero);
    expect(made, hasLength(2));
    expect(made[0].shutdowns, 1);
    expect(made[0].terminates, 0);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(made[0].terminates, 1);
    expect(made[1].shutdowns, 0);
  });

  test('back-to-back triggers open only one new connection', () {
    var made = 0;
    final ch = ReconnectableChannel(() {
      made++;
      return _FakeChannel();
    }, drainGrace: Duration.zero);
    ch.reconnect('wake');
    ch.reconnect('resumed');
    ch.reconnect('deadline');
    expect(made, 2);
  });

  test('no reconnect after the channel was shut down', () async {
    var made = 0;
    final ch = ReconnectableChannel(() {
      made++;
      return _FakeChannel();
    });
    await ch.shutdown();
    ch.reconnect('late');
    expect(made, 1);
  });
}
