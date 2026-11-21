import 'dart:convert';
import 'dart:io' show Socket;

import 'package:http/http.dart' as http;

import '../../../core/config/server_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/grpc/host_resolver.dart';
import 'auth_repository.dart';

/// What a Mycelium server says about itself on `GET /pileus/info`.
class ServerInfo {
  /// SHA-256 of the gRPC TLS certificate (trust-on-first-use pinning: the
  /// cert is self-signed, so a matching fingerprint IS the trust check);
  /// null when the server reports TLS off.
  final String? tlsFingerprint;

  /// The server's real gRPC port; null on an older server that doesn't
  /// report it ([ServerPorts.grpc] applies then).
  final int? grpcPort;

  /// The HTTP port that answered, when it isn't [ServerPorts.http] — saved
  /// with the host.
  final int? httpPort;

  const ServerInfo({this.tlsFingerprint, this.grpcPort, this.httpPort});

  int get effectiveGrpcPort => grpcPort ?? ServerPorts.grpc;
}

enum ServerProbeFailure {
  /// No answer at all (refused, timeout, DNS…).
  unreachable,

  /// Answered with a status other than 200.
  httpStatus,

  /// Answered 200 with something that isn't the info JSON.
  invalidResponse,

  /// Valid JSON, but not a Mycelium server.
  notMycelium,

  /// /pileus/info answers but the gRPC port doesn't accept connections.
  grpcUnreachable,
}

/// Why a server couldn't be used. [message] is the text the mobile and
/// desktop screens show for a LAN address.
class ServerProbeException implements Exception {
  final ServerProbeFailure kind;
  final String message;
  final int? statusCode;

  const ServerProbeException(this.kind, this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// The HTTP port to save with a host: null for the default one.
int? nonDefaultHttpPort(int? port) =>
    (port != null && port != ServerPorts.http) ? port : null;

/// Parses a `/pileus/info` body; null when it isn't a Mycelium server's.
/// [httpPort] is carried through as [ServerInfo.httpPort] (non-default only).
ServerInfo? parseServerInfo(String body, {int? httpPort}) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (json is! Map<String, dynamic> || json['name'] != 'Mycelium') return null;
  final fp = json['grpc_tls_fingerprint'];
  final grpc = json['grpc_port'];
  final grpcPort = grpc is num ? grpc.toInt() : null;
  return ServerInfo(
    tlsFingerprint: (fp is String && fp.isNotEmpty) ? fp : null,
    grpcPort: (grpcPort != null && grpcPort > 0) ? grpcPort : null,
    httpPort: nonDefaultHttpPort(httpPort),
  );
}

/// `GET http://[host]:[port]/pileus/info` (or [url] when given) and its
/// [ServerInfo]; throws [ServerProbeException] with the reason, worded for
/// [host]/[port]. [httpPort] is what to carry as [ServerInfo.httpPort]: the
/// port the user typed / the UDP reply announced, null for the default.
///
/// Own client, closed in `finally`: closing is what actually aborts a
/// request the timeout gave up on — on web a dangling XHR per dead address
/// would otherwise pile up against the browser's socket cap.
Future<ServerInfo> fetchServerInfo(
  String host,
  int port, {
  Uri? url,
  int? httpPort,
  Duration timeout = const Duration(seconds: 6),
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  final http.Response res;
  try {
    res = await c
        .get(url ?? Uri.http('$host:$port', '/pileus/info'))
        .timeout(timeout);
  } catch (_) {
    throw ServerProbeException(ServerProbeFailure.unreachable,
        'Nessun server Mycelium raggiungibile a "$host".');
  } finally {
    if (client == null) c.close();
  }
  if (res.statusCode != 200) {
    throw ServerProbeException(ServerProbeFailure.httpStatus,
        'Il server a "$host" ha risposto HTTP ${res.statusCode} su :$port.',
        statusCode: res.statusCode);
  }
  Object? json;
  try {
    json = jsonDecode(res.body);
  } catch (_) {}
  if (json is! Map<String, dynamic>) {
    throw ServerProbeException(ServerProbeFailure.invalidResponse,
        'Risposta non valida da "$host:$port".');
  }
  final info = parseServerInfo(res.body, httpPort: httpPort);
  if (info == null) {
    throw ServerProbeException(ServerProbeFailure.notMycelium,
        '"$host:$port" non è un server Mycelium.');
  }
  return info;
}

/// Quiet probe of a LAN [host] on [port] (the default HTTP port when null):
/// its [ServerInfo], or null when it isn't a reachable Mycelium. What the
/// TV scan and its LAN sweep fire at every candidate.
Future<ServerInfo?> probeLanServer(
  String host, {
  int? port,
  Duration timeout = const Duration(seconds: 2),
  http.Client? client,
}) async {
  final p = port ?? ServerPorts.http;
  try {
    return await fetchServerInfo(host, p,
        httpPort: port, timeout: timeout, client: client);
  } on ServerProbeException {
    return null;
  }
}

/// Fails with [ServerProbeFailure.grpcUnreachable] unless [host]'s gRPC
/// port accepts a TCP connection — pairing and every catalog call go there,
/// and it's often bound/published separately from the HTTP side: better to
/// fail loudly now than to hang on the pairing screen later. A plain TCP
/// connect is enough even when the port speaks TLS. Not for web (no
/// sockets there).
Future<void> checkGrpcReachable(
  String host,
  int grpcPort, {
  required int httpPort,
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    final sock = await Socket.connect(host, grpcPort, timeout: timeout);
    sock.destroy();
  } catch (_) {
    throw ServerProbeException(
        ServerProbeFailure.grpcUnreachable,
        'Il server risponde su :$httpPort ma non su '
        ':$grpcPort (gRPC). Apri/pubblica quella porta e '
        'assicurati che Mycelium sia in ascolto su 0.0.0.0.');
  }
}

/// Makes [host] the server: saves it to the device session and rebuilds
/// every gRPC client against it.
Future<void> useServer(String host, ServerInfo info) async {
  await getIt<AuthRepository>().saveHostInfo(host, info.tlsFingerprint,
      grpcPort: info.grpcPort, httpPort: info.httpPort);
  await rebuildGrpcClients(host,
      tlsFingerprint: info.tlsFingerprint,
      grpcPort: info.grpcPort,
      httpPort: info.httpPort);
}

/// A LAN address entered by hand (or found again by [rediscoverLanServer])
/// on mobile/desktop: `/pileus/info`, then the gRPC port, then [useServer].
/// [httpPort]: typed as "ip:port"; the default one when null. Throws
/// [ServerProbeException].
Future<ServerInfo> connectLanServer(String host,
    {int? httpPort, http.Client? client}) async {
  final port = httpPort ?? ServerPorts.http;
  final info =
      await fetchServerInfo(host, port, httpPort: httpPort, client: client);
  await checkGrpcReachable(host, info.effectiveGrpcPort, httpPort: port);
  await useServer(host, info);
  return info;
}

/// Re-runs the UDP broadcast + TCP candidate race (resolveGrpcHost) — the
/// first-launch scan otherwise only ever runs once, in
/// configureDependencies(). The host found, with the HTTP port its UDP
/// reply announced (null for the default); null when nothing answered.
Future<({String host, int? httpPort})?> rediscoverLanServer() async {
  final String host;
  try {
    host = await resolveGrpcHost();
  } catch (_) {
    return null;
  }
  return (host: host, httpPort: nonDefaultHttpPort(lanHttpPortFor(host)));
}
