import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:pileus/core/grpc/generated/auth.pb.dart';
import 'package:pileus/core/grpc/native_grpcweb_channel.dart';

/// A real local HTTP/1.1 server speaking the exact gRPC-Web wire format
/// mycelium-core's `internal/pileus/grpcweb.go` does — not a mock of
/// [NativeGrpcWebClientChannel]'s own internals, so these tests exercise
/// the actual framing/parsing against a real socket, the same way the bug
/// this channel exists for (Cloudflare Tunnel eating HTTP/2 trailers) only
/// ever showed up against a real connection.
Future<HttpServer> _startServer(
    Future<void> Function(HttpRequest request) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    // Drain the request body (every test here cares about the response
    // shape, not the request framing — that's package:grpc's own `frame()`,
    // unmodified by this channel) before handing off to the handler.
    await request.drain<void>();
    await handler(request);
  });
  return server;
}

Uint8List _rawFrame(int flag, List<int> payload) {
  final header = ByteData(5)
    ..setUint8(0, flag)
    ..setUint32(1, payload.length);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...payload]);
}

Uint8List _dataFrame(List<int> payload) => _rawFrame(0x00, payload);
Uint8List _trailerFrame(String text) => _rawFrame(0x80, utf8.encode(text));

final _method = ClientMethod<AuthorizeDeviceRequest, AuthorizeDeviceResponse>(
  '/mycelium.AuthService/AuthorizeDevice',
  (AuthorizeDeviceRequest r) => r.writeToBuffer(),
  (List<int> bytes) => AuthorizeDeviceResponse.fromBuffer(bytes),
);

void main() {
  late HttpServer server;
  late NativeGrpcWebClientChannel channel;

  tearDown(() async {
    await channel.shutdown();
    await server.close(force: true);
  });

  test('single message: one data frame + an OK trailer', () async {
    server = await _startServer((request) async {
      request.response.statusCode = 200;
      request.response.headers
          .set('content-type', 'application/grpc-web+proto');
      final body = AuthorizeDeviceResponse(
        deviceJwt: 'jwt-123',
      ).writeToBuffer();
      request.response.add(_dataFrame(body));
      request.response.add(_trailerFrame('grpc-status: 0\r\n'));
      await request.response.close();
    });
    channel = NativeGrpcWebClientChannel('http://127.0.0.1:${server.port}');

    final call = channel.createCall(
      _method,
      Stream.value(AuthorizeDeviceRequest(deviceId: 'd1', pinHash: 'ABC123')),
      CallOptions(),
    );

    final responses = await call.response.toList();
    expect(responses, hasLength(1));
    expect(responses.single.deviceJwt, 'jwt-123');
  });

  test(
      'Trailers-Only error response (e.g. a wrong pairing code) — just a '
      'trailer frame, no data frame — surfaces as a GrpcError with the '
      'right code and message, not a generic transport failure', () async {
    server = await _startServer((request) async {
      request.response.statusCode = 200;
      request.response.headers
          .set('content-type', 'application/grpc-web+proto');
      request.response.add(_trailerFrame(
          'grpc-status: 16\r\ngrpc-message: codice non valido\r\n'));
      await request.response.close();
    });
    channel = NativeGrpcWebClientChannel('http://127.0.0.1:${server.port}');

    final call = channel.createCall(
      _method,
      Stream.value(AuthorizeDeviceRequest(deviceId: 'd1', pinHash: 'WRONG')),
      CallOptions(),
    );

    await expectLater(
      call.response.toList(),
      throwsA(isA<GrpcError>()
          .having((e) => e.code, 'code', StatusCode.unauthenticated)
          .having((e) => e.message, 'message', 'codice non valido')),
    );
  });

  test(
      'server-streaming: multiple data frames arrive as separate messages, '
      'in order, before the trailer closes the call', () async {
    server = await _startServer((request) async {
      request.response.statusCode = 200;
      request.response.headers
          .set('content-type', 'application/grpc-web+proto');
      for (final jwt in ['progress-1', 'progress-2', 'final']) {
        request.response.add(_dataFrame(
            AuthorizeDeviceResponse(deviceJwt: jwt).writeToBuffer()));
        // Flush each frame as its own chunk rather than buffering the whole
        // response — this is what actually exercises the decoder's
        // incremental, chunk-by-chunk parsing (GrpcWebDecoder) instead of
        // handing it one single blob that happens to contain every frame.
        await request.response.flush();
      }
      request.response.add(_trailerFrame('grpc-status: 0\r\n'));
      await request.response.close();
    });
    channel = NativeGrpcWebClientChannel('http://127.0.0.1:${server.port}');

    final call = channel.createCall(
      _method,
      Stream.value(AuthorizeDeviceRequest(deviceId: 'd1', pinHash: 'ABC123')),
      CallOptions(),
    );

    final responses = await call.response.toList();
    expect(responses.map((r) => r.deviceJwt),
        ['progress-1', 'progress-2', 'final']);
  });

  test('a server that never answers times out as DEADLINE_EXCEEDED',
      () async {
    server = await _startServer((request) async {
      // Deliberately never writes/closes a response — simulates a tunnel
      // hop that accepted the connection but never got (or forwarded) an
      // answer. request.response is left open on purpose.
    });
    channel = NativeGrpcWebClientChannel('http://127.0.0.1:${server.port}');

    final call = channel.createCall(
      _method,
      Stream.value(AuthorizeDeviceRequest(deviceId: 'd1', pinHash: 'ABC123')),
      CallOptions(timeout: const Duration(milliseconds: 200)),
    );

    await expectLater(
      call.response.toList(),
      throwsA(isA<GrpcError>()
          .having((e) => e.code, 'code', StatusCode.deadlineExceeded)),
    );
  });
}
