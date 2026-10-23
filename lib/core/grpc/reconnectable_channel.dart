import 'dart:async';

import 'package:grpc/grpc.dart'
    show ClientCall, ConnectionState, GrpcError, StatusCode;
import 'package:grpc/service_api.dart';

import '../utils/perf_log.dart';

/// A [ClientChannel] whose underlying connection can be thrown away and
/// replaced without touching the clients built on top of it.
///
/// Why: native gRPC is ONE long-lived HTTP/2 socket, and grpc-dart only
/// abandons it when the OS reports an error on it. After a system suspend
/// (TV box standby, laptop lid, desktop sleep) the socket often comes back
/// half-open — the server or a firewall forgot it while we slept, but no
/// RST ever reaches us — so grpc-dart keeps calling it `ready` and writes
/// every new RPC into the void. Each one then dies on its own deadline
/// (20/50 s), none is retried (only UNAVAILABLE is), and the 30 s plugin
/// poll keeps the connection from ever going idle: search and details stay
/// broken until the kernel gives up on the socket, ~15 min later. Android
/// phones mostly escape this because Doze tears sockets down with an error.
///
/// [reconnect] swaps in a fresh channel for new calls; the old one is shut
/// down gracefully (calls still on it finish or hit their deadline) and
/// force-closed after [_drainGrace] so a dead socket can't linger.
class ReconnectableChannel implements ClientChannel {
  ReconnectableChannel(this._factory, {Duration? drainGrace})
      : _inner = _factory(),
        _drainGrace = drainGrace ?? const Duration(seconds: 60);

  final ClientChannel Function() _factory;
  ClientChannel _inner;
  bool _closed = false;
  DateTime? _lastReconnect;

  // Longer than the longest per-RPC deadline (50 s, media_client.dart):
  // anything still running on the old channel by then is never answering.
  final Duration _drainGrace;

  // Several triggers can fire together (wake + resume + a burst of timed-out
  // calls): one fresh connection is enough.
  static const _minInterval = Duration(seconds: 10);

  void reconnect(String reason) {
    if (_closed) return;
    final now = DateTime.now();
    final last = _lastReconnect;
    if (last != null && now.difference(last) < _minInterval) return;
    _lastReconnect = now;
    perf('grpc reconnect ($reason)');
    final old = _inner;
    _inner = _factory();
    unawaited(old.shutdown().catchError((_) {}));
    Timer(_drainGrace, () => unawaited(old.terminate().catchError((_) {})));
  }

  @override
  ClientCall<Q, R> createCall<Q, R>(
          ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options) =>
      _inner.createCall(method, requests, options);

  @override
  Future<void> shutdown() {
    _closed = true;
    return _inner.shutdown();
  }

  @override
  Future<void> terminate() {
    _closed = true;
    return _inner.terminate();
  }

  @override
  Stream<ConnectionState> get onConnectionStateChanged =>
      _inner.onConnectionStateChanged;
}

/// Treats a unary call dying on its deadline as a hint that the connection
/// under it may be the half-open kind described on [ReconnectableChannel],
/// and asks for a fresh one. Cheap when wrong (one new TCP+TLS handshake;
/// in-flight calls keep the old channel), and it covers the cases the wake
/// detector in AppLifecycleReactor can't see — a Wi-Fi roam or DHCP change
/// with no suspend at all. The call's own error still reaches the caller.
class StaleConnectionInterceptor extends ClientInterceptor {
  StaleConnectionInterceptor(this._onStale);

  final void Function(String reason) _onStale;

  @override
  ResponseFuture<R> interceptUnary<Q, R>(ClientMethod<Q, R> method, Q request,
      CallOptions options, ClientUnaryInvoker<Q, R> invoker) {
    final response = invoker(method, request, options);
    response.then<void>((_) {}, onError: (Object e) {
      if (e is GrpcError && e.code == StatusCode.deadlineExceeded) {
        _onStale('deadline ${method.path}');
      }
    });
    return response;
  }
}
