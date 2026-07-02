import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../config/server_config.dart';

class AuthInterceptor extends ClientInterceptor {
  String? _jwt;
  String? _profileId;
  String? _grpcHost;
  final int _httpPort = ServerPorts.http;

  void setGrpcHost(String host) {
    _grpcHost = host;
  }

  void setCredentials(String jwt, String profileId) {
    // debugPrint (unlike assert) isn't stripped in release — this used to
    // log JWT metadata + a full stack trace on every login/profile-switch
    // in production builds too, visible via adb logcat.
    if (kDebugMode) {
      debugPrint(
          '[interceptor] setCredentials jwt.length=${jwt.length} segments=${jwt.split('.').length}\n${StackTrace.current}');
    }
    _jwt = jwt.isNotEmpty ? jwt : _jwt; // never overwrite with empty
    _profileId = profileId.isNotEmpty ? profileId : _profileId;
  }

  void clear() {
    _jwt = null;
    _profileId = null;
  }

  bool get hasCredentials => _jwt != null;
  String? get jwt => _jwt;
  String? get profileId => _profileId;
  String? get httpHost => _grpcHost;
  int get httpPort => _httpPort;

  /// The value sent as `x-http-host` — the host mycelium uses to build its
  /// image-proxy URLs.
  ///
  /// Native: the resolved gRPC host + the fixed HTTP port (8000).
  /// Web: the page is served *by* mycelium, so its HTTP host is exactly the
  /// origin the app loaded from — send that host:port, not the native :8000
  /// default (which pointed every poster/fanart URL at the wrong port on any
  /// web deploy not served on 8000). Mirrors `myceliumHttpBase()`'s web
  /// branch in host_resolver.dart.
  String? get _httpHostHeader {
    if (kIsWeb) {
      final b = Uri.base;
      return b.hasPort ? '${b.host}:${b.port}' : b.host;
    }
    return _grpcHost != null ? '$_grpcHost:$_httpPort' : null;
  }

  /// The value sent as `x-http-scheme`, paired with `x-http-host` so mycelium
  /// can build absolute image-proxy URLs when it sits behind no reverse
  /// proxy (i.e. no `X-Forwarded-Proto` to read).
  ///
  /// Native: the HTTP API on :8000 is plain HTTP by design (the TLS
  /// fingerprint TOFU covers the gRPC channel only). If mycelium ever serves
  /// its REST/asset API over TLS this must follow that.
  /// Web: the actual scheme of the origin the app loaded from.
  String get _httpSchemeHeader => kIsWeb ? Uri.base.scheme : 'http';

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    return invoker(method, request, _inject(options));
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    return invoker(method, requests, _inject(options));
  }

  CallOptions _inject(CallOptions options) {
    // `x-http-host` / `x-http-scheme` tell mycelium which absolute base to
    // build image-proxy URLs against when nothing upstream sets
    // `X-Forwarded-*`; not auth, and the pre-login calls (discovery,
    // pairing) need them too — so they're sent whenever a host is known,
    // independent of the JWT. Only `authorization` / `x-profile-id` gate on
    // a session.
    final httpHost = _httpHostHeader;
    final md = <String, String>{
      if (httpHost != null) 'x-http-host': httpHost,
      if (httpHost != null) 'x-http-scheme': _httpSchemeHeader,
      if (_jwt != null) 'authorization': 'Bearer $_jwt',
      if (_jwt != null && _profileId != null) 'x-profile-id': _profileId!,
    };
    if (md.isEmpty) return options;
    return options.mergedWith(CallOptions(metadata: md));
  }
}
