import 'package:grpc/grpc_web.dart';

import '../config/server_config.dart';

// tlsFingerprint is accepted for signature parity with grpc_channel_io.dart
// but unused here — gRPC-Web goes through the browser's own fetch/XHR stack,
// which validates TLS itself against its trust store and offers no hook for
// custom cert pinning; self-signed-cert trust in a browser is a manual
// "accept the security warning" action, out of scope for this app's primary
// TV/desktop target.
GrpcWebClientChannel createGrpcChannel({
  String host = 'mycelium.local',
  int grpcPort = ServerPorts.grpc,
  int httpPort = ServerPorts.http,
  String? tlsFingerprint,
}) {
  final origin = _webOrigin(host, httpPort);
  // Trailing slash on purpose: `grpc`'s web transport builds the request URL
  // with `Uri.resolve(methodPath)` (xhr_transport.dart). Without it, a base
  // of `$origin/grpc` treats `grpc` as a file and drops it on resolve.
  //
  // ⚠️ grpc 5.1.0 caveat: the generated `ClientMethod.path` is
  // ABSOLUTE (`/mycelium.MediaPipeline/GetCatalog`), and `Uri.resolve` of an
  // absolute-path reference replaces the whole base path — so even with the
  // slash the request goes to `$origin/mycelium.<Service>/<Method>`, NOT
  // `$origin/grpc/...`. Mycelium's gRPC-Web handler must therefore match at
  // the origin root (`POST /mycelium.*`), or the deployment must rewrite
  // `/mycelium.* -> /grpc/mycelium.*` in a reverse proxy. Revisit here if a
  // future grpc release makes the method path relative.
  return GrpcWebClientChannel.xhr(Uri.parse('$origin/grpc/'));
}

String _webOrigin(String host, int port) {
  try {
    final href = Uri.base;
    // Same-origin — the normal "page served by mycelium itself" deployment
    // (resolveGrpcHost's web branch seeds `host` from Uri.base.host at
    // startup, so this is also true on a fresh launch before any explicit
    // choice has been made). Stick to the page's own scheme/host/port so a
    // reverse-proxied HTTPS deployment isn't bounced to a bare
    // http://host:grpcPort that CORS/mixed-content would then block.
    if (host.isEmpty || host == href.host) {
      return '${href.scheme}://${href.host}${href.hasPort ? ":${href.port}" : ""}';
    }
    // An explicit different host — WebDiscoveryScreen's manual override
    // ("for the case where the app is hosted somewhere else"), or `host`
    // arriving via rebuildGrpcClients() after one. Before this, that
    // override had literally no effect: every gRPC-Web call kept hitting
    // Uri.base regardless of what was saved, which is also what breaks
    // local dev (`flutter run -d web-server` serves the page itself, not
    // mycelium — Uri.base is the Flutter dev server's own port, not the
    // server being pointed at) — reported 2026-09-14.
    return 'http://$host:$port';
  } catch (_) {
    return 'http://$host:$port';
  }
}
