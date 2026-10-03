// package:grpc/src/... is intentional here, not an oversight — see the
// import block's own note below for why package:grpc/grpc.dart's public
// surface isn't enough on its own.
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
// Deep imports: package:grpc/grpc.dart's public surface is written for
// consumers of the generated stubs + its own HTTP/2 ClientChannel, not for
// providing an alternative transport under those same stubs — it doesn't
// re-export the lower transport-plumbing types below. Pinned against grpc
// 5.1.0 (pubspec.yaml); re-check these paths on a version bump.
import 'package:grpc/src/client/channel.dart' show ClientChannelBase;
import 'package:grpc/src/client/connection.dart' show ClientConnection;
import 'package:grpc/src/client/transport/transport.dart'
    show ErrorHandler, GrpcTransportStream;
import 'package:grpc/src/client/transport/web_streams.dart'
    show GrpcWebDecoder;
import 'package:grpc/src/shared/message.dart' show frame;
import 'package:grpc/src/shared/status.dart'
    show validateHttpStatusAndContentType;

/// Native (Android/desktop) gRPC-Web transport — the client-side half of
/// mycelium-core's `internal/pileus/grpcweb.go`.
///
/// Exists only for remote mode (server_address.dart): a mycelium reached
/// through a reverse tunnel/proxy (e.g. Cloudflare Tunnel) that doesn't
/// reliably forward HTTP/2 trailers. Plain gRPC needs those for the
/// grpc-status an RPC actually finished with — every call failed
/// client-side with "server closed the stream without sending trailers"
/// even though the server had already answered correctly (pairing
/// succeeded server-side; the client just never found out). gRPC-Web
/// sidesteps this by encoding the status as one more frame in the response
/// BODY instead of a real HTTP trailer, over plain HTTP/1.1 — which is also
/// all `dart:io`'s HttpClient speaks, so an HTTP/1.1-only tunnel/proxy hop
/// stops being a problem by construction.
///
/// `package:grpc` only ships a gRPC-Web transport for the browser
/// (`GrpcWebClientChannel.xhr`, grpc_web.dart) — XHR doesn't exist outside
/// one. This reimplements just the transport layer (ClientConnection +
/// GrpcTransportStream) on `dart:io`'s HttpClient, mirroring that XHR
/// transport's own structure (xhr_transport.dart) and reusing its
/// platform-agnostic frame decoder (web_streams.dart's GrpcWebDecoder —
/// pure dart:convert/typed_data, no browser dependency) rather than
/// re-deriving the wire format. Everything above the transport — ClientCall,
/// the generated service stubs, AuthInterceptor — is reused completely
/// unchanged: see ClientChannelBase's own doc, a channel only has to
/// provide `createConnection()`.
///
/// LAN mode is untouched (grpc_channel_io.dart's plain native ClientChannel,
/// real HTTP/2) — this only ever backs `createGrpcChannel(..., remote:
/// true)`.
class NativeGrpcWebClientChannel extends ClientChannelBase {
  final String _origin;
  final HttpClient _httpClient;

  /// [origin]: `scheme://host[:port]`, no trailing slash, no path — e.g.
  /// `https://demo.example.com` or `https://demo.example.com:8443`.
  NativeGrpcWebClientChannel(String origin)
      : _origin = origin,
        _httpClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
  // Deliberately no badCertificateCallback override: remote mode means a
  // publicly-reachable mycelium with a real CA-issued certificate (see
  // grpc_channel_io.dart's own doc on this split) — standard system
  // trust-store validation is exactly right here, same as the LAN channel's
  // ChannelCredentials.secure() for remote.

  @override
  ClientConnection createConnection() =>
      _NativeGrpcWebConnection(_origin, _httpClient);
}

class _NativeGrpcWebConnection implements ClientConnection {
  final String _origin;
  final HttpClient _httpClient;
  final Uri _originUri;

  _NativeGrpcWebConnection(this._origin, this._httpClient)
      : _originUri = Uri.parse(_origin);

  @override
  String get authority => _originUri.authority;

  @override
  String get scheme => _originUri.scheme;

  @override
  void dispatchCall(ClientCall call) => call.onConnectionReady(this);

  @override
  GrpcTransportStream makeRequest(
    String path,
    Duration? timeout,
    Map<String, String> metadata,
    ErrorHandler onRequestFailure, {
    required CallOptions callOptions,
  }) {
    metadata['content-type'] = 'application/grpc-web+proto';
    metadata['x-grpc-web'] = '1';
    metadata.putIfAbsent('x-user-agent', () => 'pileus-grpc-web-native/1');
    if (timeout != null) {
      metadata['grpc-timeout'] = toTimeoutString(timeout);
    }

    // NOT Uri.resolve(path): ClientMethod.path is always absolute
    // ("/mycelium.Service/Method"), and resolving an absolute-path
    // reference against a base URI replaces the base's whole path —
    // dropping the "/grpc" prefix mycelium-core's grpcweb.go is mounted
    // under. Plain string concatenation is what actually lands on
    // ".../grpc/mycelium.Service/Method" — see grpc_channel_web.dart's
    // identical caveat for the browser transport (which works around the
    // same underlying quirk the other way, by having mycelium match at the
    // origin root instead of under /grpc).
    final uri = Uri.parse('$_origin/grpc$path');

    return _NativeGrpcWebTransportStream(
      httpClient: _httpClient,
      uri: uri,
      metadata: metadata,
      onError: onRequestFailure,
    );
  }

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> terminate() async => _httpClient.close(force: true);

  @override
  set onStateChanged(void Function(ConnectionState) cb) {
    // No persistent connection to report on — every RPC is its own
    // independent HTTP/1.1 request/response, same as the browser XHR
    // transport this mirrors (xhr_transport.dart does the same).
  }
}

class _NativeGrpcWebTransportStream implements GrpcTransportStream {
  final HttpClient _httpClient;
  final Uri _uri;
  final Map<String, String> _metadata;
  final ErrorHandler _onError;

  final _incomingMessages = StreamController<GrpcMessage>();
  final _outgoingMessages = StreamController<List<int>>();
  StreamSubscription<GrpcMessage>? _responseSub;
  bool _closed = false;

  _NativeGrpcWebTransportStream({
    required HttpClient httpClient,
    required Uri uri,
    required Map<String, String> metadata,
    required ErrorHandler onError,
  })  : _httpClient = httpClient,
        _uri = uri,
        _metadata = metadata,
        _onError = onError {
    _send();
  }

  @override
  Stream<GrpcMessage> get incomingMessages => _incomingMessages.stream;

  @override
  StreamSink<List<int>> get outgoingMessages => _outgoingMessages.sink;

  Future<void> _send() async {
    final HttpClientRequest request;
    try {
      request = await _httpClient.postUrl(_uri);
      _metadata.forEach((key, value) => request.headers.set(key, value));
    } catch (e, st) {
      _fail(e, st);
      return;
    }

    // Every RPC here is a single client-side message — mycelium has no
    // client-streaming method, only unary and server-streaming — so this
    // forwards the one frame ClientCall._sendRequest adds, then reacts to
    // it closing. Still listen-based rather than "await the first item":
    // if that ever changes, multiple frames are still forwarded correctly.
    _outgoingMessages.stream.listen(
      (bytes) => request.add(frame(bytes)),
      onError: (Object e, StackTrace st) => _fail(e, st),
      onDone: () async {
        try {
          final response = await request.close();
          _handleResponse(response);
        } catch (e, st) {
          _fail(e, st);
        }
      },
      cancelOnError: true,
    );
  }

  void _handleResponse(HttpClientResponse response) {
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(', ');
    });

    try {
      // mycelium-core's grpcweb.go always answers HTTP 200 with
      // content-type application/grpc-web+proto — the actual RPC outcome
      // (including an error like UNAUTHENTICATED) is carried in a trailer
      // FRAME inside the body, read below, never in the HTTP status line.
      // This only rejects a response that isn't even that shape (wrong
      // content-type, a non-200 from something ahead of mycelium in the
      // chain — a proxy/tunnel error page, say).
      validateHttpStatusAndContentType(response.statusCode, headers);
    } catch (e, st) {
      unawaited(response.drain());
      _fail(e, st);
      return;
    }

    if (_closed) return;
    // The real HTTP headers, standing in for gRPC's "headers" frame —
    // ClientCall._onResponseData expects exactly one GrpcMetadata before
    // any GrpcData, which this provides regardless of what the body turns
    // out to contain (a data frame + trailer, or a Trailers-Only response
    // with nothing but a single trailer frame — e.g. an immediate
    // UNAUTHENTICATED on a bad pairing code).
    _incomingMessages.add(GrpcMetadata(headers));

    _responseSub = response
        .map((chunk) => Uint8List.fromList(chunk).buffer)
        .transform(GrpcWebDecoder())
        .transform(grpcDecompressor())
        .listen(
          (message) {
            if (!_closed) _incomingMessages.add(message);
          },
          onError: (Object e, StackTrace st) => _fail(e, st),
          onDone: () {
            if (!_closed) _incomingMessages.close();
          },
          cancelOnError: true,
        );
  }

  void _fail(Object e, StackTrace st) {
    if (_closed) return;
    _onError(e is GrpcError ? e : GrpcError.unavailable('$e'), st);
  }

  @override
  Future<void> terminate() async {
    if (_closed) return;
    _closed = true;
    await _responseSub?.cancel();
    if (!_outgoingMessages.isClosed) await _outgoingMessages.close();
    if (!_incomingMessages.isClosed) await _incomingMessages.close();
  }
}
