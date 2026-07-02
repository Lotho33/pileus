import 'dart:io';

import 'package:crypto/crypto.dart';
import '../config/server_config.dart';
import 'package:grpc/grpc.dart';

/// [tlsFingerprint]: SHA-256 (hex, case-insensitive) of the server's
/// self-signed gRPC cert, as pinned from /pileus/info's grpc_tls_fingerprint
/// during discovery (see server_discovery_screen.dart). The cert has no
/// public CA behind it on purpose (mycelium-core internal/pileus/tls.go —
/// private-network deployment) — TLS's default trust-store validation would
/// always fail against it, so a matching fingerprint IS the trust check
/// (trust-on-first-use), not an addition on top of one.
///
/// Null/empty falls back to a plaintext channel — either the server reports
/// TLS off (grpc_tls: false), or no /pileus/info round-trip has happened
/// yet for this host (e.g. resolveGrpcHost's plain TCP reachability probe
/// never calls it). This mirrors the server's own rollout: mycelium-core
/// still accepts a plaintext connection so older/unpaired clients aren't
/// locked out mid-migration.
ClientChannel createGrpcChannel({
  String host = 'mycelium.local',
  int grpcPort = ServerPorts.grpc,
  int httpPort = ServerPorts.http,
  String? tlsFingerprint,
}) {
  final credentials = (tlsFingerprint != null && tlsFingerprint.isNotEmpty)
      ? ChannelCredentials.secure(
          onBadCertificate: (X509Certificate cert, String _) =>
              sha256.convert(cert.der).toString().toLowerCase() ==
              tlsFingerprint.toLowerCase(),
        )
      : const ChannelCredentials.insecure();

  return ClientChannel(
    host,
    port: grpcPort,
    options: ChannelOptions(
      credentials: credentials,
      // 30s was long enough that ordinary browsing (open a title, read the
      // synopsis, go back, pick another) routinely let the HTTP/2
      // connection go idle and paid a fresh TCP + TLS handshake on the next
      // call — noticeable lag on a weak box over Wi-Fi. 5 min keeps it warm
      // across those pauses without holding a socket open through a whole
      // movie (the player has no plugin traffic; PluginBloc's poll, when
      // not paused, refreshes it anyway).
      idleTimeout: const Duration(minutes: 5),
      connectTimeout: const Duration(seconds: 5),
    ),
  );
}
