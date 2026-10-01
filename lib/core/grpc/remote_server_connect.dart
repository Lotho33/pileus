import 'dart:convert';

import 'package:http/http.dart' as http;

import '../di/injection.dart';
import '../../features/auth/data/auth_repository.dart';
import 'grpc_errors.dart';
import 'server_address.dart';

/// Result of probing + committing a remote server address — shared by every
/// discovery screen's manual-entry flow (TV/mobile/desktop; see
/// [ParsedServerAddress]'s own doc for what "remote" means and why web
/// never needs this). On success the device session, `AuthInterceptor` and
/// gRPC channel are already updated — the caller just moves on to whatever
/// its own "connected" state does next (each screen's is slightly
/// different).
class RemoteConnectResult {
  final bool ok;
  final String? error;
  const RemoteConnectResult._(this.ok, this.error);
  const RemoteConnectResult.success() : this._(true, null);
  const RemoteConnectResult.failure(String message) : this._(false, message);
}

/// Probes `<remoteBaseUrl>/pileus/info` over HTTPS (standard system CA
/// validation — no pinning, see [ParsedServerAddress]'s doc) and, on
/// success, saves the session and rebuilds the gRPC channel in remote mode.
///
/// `grpc_port` and `grpc_tls_fingerprint` from the response are
/// deliberately never read here — contract point 1: they describe the
/// server's own internal/LAN network, not the public endpoint this device
/// is actually talking to.
Future<RemoteConnectResult> connectToRemoteServer(
  ParsedServerAddress parsed, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final base = parsed.remoteBaseUrl;
  try {
    final res =
        await http.get(Uri.parse('$base/pileus/info')).timeout(timeout);
    if (res.statusCode != 200) {
      return RemoteConnectResult.failure(
          'Il server ha risposto HTTP ${res.statusCode} su $base.');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return RemoteConnectResult.failure('Risposta non valida da $base.');
    }
    if (json['name'] != 'Mycelium') {
      return RemoteConnectResult.failure('$base non è un server Mycelium.');
    }

    await getIt<AuthRepository>().saveHostInfo(
      parsed.host,
      null, // no TLS fingerprint pinning in remote mode — see the doc above
      remote: true,
      remotePort: parsed.port,
    );
    await rebuildGrpcClients(
      parsed.host,
      tlsFingerprint: null,
      remote: true,
      remotePort: parsed.port,
    );
    return const RemoteConnectResult.success();
  } catch (e) {
    // Reuses the same loose, best-effort classification grpc_errors.dart's
    // looksLikeCertificateMismatch already uses for the gRPC channel's own
    // handshake failures — this is the exact same dart:io HandshakeException
    // family, just reached through package:http instead of package:grpc.
    if (looksLikeCertificateMismatch(e)) {
      return RemoteConnectResult.failure(
          'Certificato non valido per ${parsed.host}.');
    }
    if (e is Exception && e.toString().toLowerCase().contains('timeout')) {
      return RemoteConnectResult.failure(
          'Il server non risponde (timeout) su $base.');
    }
    return RemoteConnectResult.failure('Server non raggiungibile a $base.');
  }
}
