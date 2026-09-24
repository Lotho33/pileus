import 'package:grpc/grpc.dart';

bool isUnauthenticated(Object e) =>
    e is GrpcError && e.code == StatusCode.unauthenticated;

/// Best-effort heuristic for "the pinned TLS fingerprint no longer matches
/// the server's certificate" (e.g. mycelium was reinstalled/reset and
/// regenerated its self-signed cert while this device stayed "paired") —
/// distinct from a plain unreachable/offline server, which today shows the
/// same generic "check the server is on" message.
///
/// Deliberately loose (a substring match on the exception's own text, case-
/// insensitive) rather than a specific exception type check: `package:grpc`
/// wraps the underlying `dart:io` `HandshakeException`/`CERTIFICATE_VERIFY_
/// FAILED` in ways that weren't possible to pin down exactly from static
/// analysis alone (the vendored package sources weren't readable from this
/// sandbox) — worth revisiting once a real certificate mismatch can be
/// reproduced and the exact exception shape confirmed. A false negative here
/// just falls back to today's generic message, so this is safe either way.
bool looksLikeCertificateMismatch(Object e) {
  final m = e.toString().toLowerCase();
  return m.contains('handshake') ||
      m.contains('certificate') ||
      m.contains('tls');
}
