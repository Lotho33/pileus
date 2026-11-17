import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/config/server_config.dart';
import 'package:pileus/core/db/models/device_session.dart';
import 'package:pileus/core/grpc/server_address.dart';

void main() {
  test('a LAN address with a port keeps the port (it used to probe :8000)',
      () {
    final p = parseServerAddressInput('192.168.1.20:9000');
    expect(p.remote, isFalse);
    expect(p.host, '192.168.1.20');
    expect(p.port, 9000);
  });

  test('httpPort survives a save/load round-trip', () {
    final s = DeviceSession()
      ..grpcHost = '192.168.1.20'
      ..httpPort = 9000;
    final back = DeviceSession.fromJson(s.toJson());
    expect(back.httpPort, 9000);
    expect(back.lanHttpPort, 9000);
  });

  test('no httpPort (auto-discovery, older sessions) means the fixed one', () {
    final back = DeviceSession.fromJson({'grpcHost': '192.168.1.20'});
    expect(back.httpPort, isNull);
    expect(back.lanHttpPort, ServerPorts.http);
  });
}
