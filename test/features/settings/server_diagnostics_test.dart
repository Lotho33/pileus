import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pileus/core/db/models/device_session.dart';
import 'package:pileus/core/di/injection.dart';
import 'package:pileus/features/settings/server_diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await DeviceSession.writeTo(
        prefs,
        DeviceSession()
          ..grpcHost = '192.168.1.50'
          ..grpcPort = 50051
          ..tlsFingerprint =
              'f280b851b780aa25e78f3c1d44651327e8697dbe1297f22bf1e4904c10875ecd'
          ..deviceId = 'dev-1');
    if (getIt.isRegistered<SharedPreferences>()) {
      getIt.unregister<SharedPreferences>();
    }
    getIt.registerSingleton<SharedPreferences>(prefs);
  });
  tearDown(() => getIt.unregister<SharedPreferences>());

  Future<ServerDiagnostics> load(http.Client c) => loadServerDiagnostics(
      client: c,
      localIps: () async => ['192.168.68.20'],
      appVersion: () async => '1.8.7');

  test('a server that answers: address, ports, version, this device', () async {
    final seen = <Uri>[];
    final d = await load(MockClient((r) async {
      seen.add(r.url);
      return http.Response('{"name":"Mycelium","version":"1.9.8"}', 200);
    }));
    expect(seen.single.toString(), 'http://192.168.1.50:8000/pileus/info');
    final rows = Map.fromEntries(d.rows.map((r) => MapEntry(r.$1, r.$2)));
    expect(rows['Stato'], startsWith('Raggiungibile'));
    expect(rows['Server'], '192.168.1.50');
    expect(rows['Collegamento'], 'Rete locale');
    expect(rows['Porta gRPC'], '50051');
    expect(rows['Cifratura'], 'TLS · F2:80:B8:51…5E:CD');
    expect(rows['Versione Mycelium'], '1.9.8');
    expect(rows['IP di questo dispositivo'], '192.168.68.20');
    expect(rows['Versione Pileus'], '1.8.7');
  });

  test('a server that does not answer says why', () async {
    var d = await load(MockClient((_) async => throw Exception('down')));
    expect(d.reachable, isFalse);
    expect(d.rows.first.$2, 'Non risponde: nessuna risposta');
    d = await load(MockClient((_) async => http.Response('', 502)));
    expect(d.rows.first.$2, 'Non risponde: HTTP 502');
    d = await load(MockClient((_) async => http.Response('{"name":"x"}', 200)));
    expect(d.rows.first.$2, 'Non risponde: non è un server Mycelium');
  });
}
