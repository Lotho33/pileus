import 'dart:io';

import 'package:crypto/crypto.dart';
import '../config/server_config.dart';
// package:grpc/grpc.dart's own `ClientChannel` is the CONCRETE HTTP/2 one
// (http2_channel.dart) — a different class from the abstract `ClientChannel`
// interface this function actually promises as its return type (the one
// `package:grpc/service_api.dart` exports, and injection.dart stores
// results as). Both NativeGrpcWebClientChannel and the concrete HTTP/2 one
// satisfy that abstract interface; neither satisfies the other's own
// concrete type, hence importing both under their real names here.
import 'package:grpc/grpc.dart' hide ClientChannel;
import 'package:grpc/grpc.dart' as http2 show ClientChannel;
import 'package:grpc/service_api.dart' show ClientChannel;

import 'native_grpcweb_channel.dart';

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
///
/// [remote] (see server_address.dart): a mycelium published on the public
/// internet. Returns a [NativeGrpcWebClientChannel] instead of a plain
/// HTTP/2 one — see that class's own doc for why — which validates the
/// server's certificate the standard way (real CA-issued, no pinning);
/// [tlsFingerprint] is ignored entirely. Pinning by fingerprint only makes
/// sense for the self-signed cert a LAN mycelium generates for itself.
ClientChannel createGrpcChannel({
  String host = '127.0.0.1',
  int grpcPort = ServerPorts.grpc,
  int httpPort = ServerPorts.http,
  String? tlsFingerprint,
  bool remote = false,
}) {
  // Remote mode goes over gRPC-Web, not plain HTTP/2 — see
  // native_grpcweb_channel.dart's own doc for why: a reverse tunnel/proxy
  // in front of a publicly-reachable mycelium (the whole point of remote
  // mode) can silently drop HTTP/2 trailers, which plain gRPC needs for the
  // final grpc-status. LAN mode is untouched below.
  if (remote) {
    final suffix = grpcPort == ServerPorts.remoteHttps ? '' : ':$grpcPort';
    return NativeGrpcWebClientChannel('https://$host$suffix');
  }

  // Only the LAN, self-signed-cert case reaches here now — remote already
  // returned above.
  final credentials = (tlsFingerprint != null && tlsFingerprint.isNotEmpty)
      ? ChannelCredentials.secure(
          onBadCertificate: (X509Certificate cert, String _) =>
              sha256.convert(cert.der).toString().toLowerCase() ==
              tlsFingerprint.toLowerCase(),
        )
      : const ChannelCredentials.insecure();

  return http2.ClientChannel(
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
