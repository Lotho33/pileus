import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pileus/core/config/server_config.dart';
import 'package:pileus/features/auth/data/server_connector.dart';

/// The /pileus/info probe and the gRPC port check shared by the four
/// discovery screens.
http.Client _answer(int status, Object body, {List<Uri>? seen}) =>
    MockClient((req) async {
      seen?.add(req.url);
      return http.Response(body is String ? body : jsonEncode(body), status);
    });

void main() {
  group('parseServerInfo', () {
    test('fingerprint and gRPC port', () {
      final i = parseServerInfo(jsonEncode({
        'name': 'Mycelium',
        'grpc_tls_fingerprint': 'AB:CD',
        'grpc_port': 50052,
      }))!;
      expect(i.tlsFingerprint, 'AB:CD');
      expect(i.grpcPort, 50052);
      expect(i.httpPort, isNull);
    });

    test('TLS off, older server without grpc_port, bad port', () {
      final i = parseServerInfo(jsonEncode(
          {'name': 'Mycelium', 'grpc_tls_fingerprint': '', 'grpc_port': 0}))!;
      expect(i.tlsFingerprint, isNull);
      expect(i.grpcPort, isNull);
      expect(i.effectiveGrpcPort, ServerPorts.grpc);
    });

    test('the default HTTP port is not saved, another one is', () {
      const body = '{"name":"Mycelium"}';
      expect(
          parseServerInfo(body, httpPort: ServerPorts.http)!.httpPort, isNull);
      expect(parseServerInfo(body, httpPort: 9000)!.httpPort, 9000);
    });

    test('not Mycelium, or not JSON', () {
      expect(parseServerInfo('{"name":"Jellyfin"}'), isNull);
      expect(parseServerInfo('<html>'), isNull);
      expect(parseServerInfo('[1]'), isNull);
    });
  });

  group('fetchServerInfo', () {
    Future<ServerProbeException> failure(http.Client c) async {
      try {
        await fetchServerInfo('10.0.0.5', 8000, client: c);
      } on ServerProbeException catch (e) {
        return e;
      }
      fail('expected a ServerProbeException');
    }

    test('asks /pileus/info on the given port', () async {
      final seen = <Uri>[];
      final info = await fetchServerInfo('10.0.0.5', 9000,
          httpPort: 9000,
          client: _answer(200, {'name': 'Mycelium'}, seen: seen));
      expect(seen.single.toString(), 'http://10.0.0.5:9000/pileus/info');
      expect(info.httpPort, 9000);
    });

    test('an explicit url wins (web: the page origin)', () async {
      final seen = <Uri>[];
      await fetchServerInfo('srv', 8000,
          url: Uri.parse('https://srv/pileus/info'),
          client: _answer(200, {'name': 'Mycelium'}, seen: seen));
      expect(seen.single.toString(), 'https://srv/pileus/info');
    });

    test('each failure has its reason and message', () async {
      var e = await failure(_answer(503, ''));
      expect(e.kind, ServerProbeFailure.httpStatus);
      expect(e.statusCode, 503);
      expect(
          e.message, 'Il server a "10.0.0.5" ha risposto HTTP 503 su :8000.');

      e = await failure(_answer(200, '<html>'));
      expect(e.kind, ServerProbeFailure.invalidResponse);
      expect(e.message, 'Risposta non valida da "10.0.0.5:8000".');

      e = await failure(_answer(200, {'name': 'Jellyfin'}));
      expect(e.kind, ServerProbeFailure.notMycelium);
      expect(e.message, '"10.0.0.5:8000" non è un server Mycelium.');

      e = await failure(MockClient((_) => throw const SocketException('no')));
      expect(e.kind, ServerProbeFailure.unreachable);
      expect(e.message, 'Nessun server Mycelium raggiungibile a "10.0.0.5".');
    });

    testWidgets('times out', (t) async {
      final never = MockClient((_) => Completer<http.Response>().future);
      Object? error;
      fetchServerInfo('h', 8000,
              timeout: const Duration(seconds: 2), client: never)
          .catchError((Object e) {
        error = e;
        return const ServerInfo();
      });
      await t.pump(const Duration(seconds: 3));
      expect(
          (error as ServerProbeException).kind, ServerProbeFailure.unreachable);
    });
  });

  group('probeLanServer', () {
    test('null instead of an error', () async {
      expect(await probeLanServer('h', client: _answer(404, '')), isNull);
      expect(
          await probeLanServer('h',
                  client: _answer(200, {'name': 'Mycelium', 'grpc_port': 7}))
              .then((i) => i!.grpcPort),
          7);
    });
  });

  group('checkGrpcReachable', () {
    test('a listening port passes, a closed one says which', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((s) => s.destroy());
      await checkGrpcReachable('127.0.0.1', server.port, httpPort: 8000);
      final closed = server.port;
      await server.close();
      try {
        await checkGrpcReachable('127.0.0.1', closed, httpPort: 8000);
        fail('expected a ServerProbeException');
      } on ServerProbeException catch (e) {
        expect(e.kind, ServerProbeFailure.grpcUnreachable);
        expect(e.message, contains(':$closed (gRPC)'));
      }
    });
  });
}
