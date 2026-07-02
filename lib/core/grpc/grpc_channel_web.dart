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
    return '${href.scheme}://${href.host}${href.hasPort ? ":${href.port}" : ""}';
  } catch (_) {
    return 'http://$host:$port';
  }
}
