import 'package:grpc/grpc.dart';

bool isUnauthenticated(Object e) =>
    e is GrpcError && e.code == StatusCode.unauthenticated;

/// FAILED_PRECONDITION (9) is how mycelium-core reports a resolve that the
/// user simply can't do right now for reasons a retry can't fix — a
/// plugin's own explicit precondition failure (2026-09: no longer the
/// single-device-per-profile lease, see [isPlayingElsewhere] below, which
/// moved to ABORTED once the server started letting the user take over
/// instead of just refusing). The server's `message` is already written for
/// the end user, so it should be shown verbatim and never chased with the
/// retry loop that other resolve failures get: retrying would just fail the
/// same way three more times.
bool isFailedPrecondition(Object e) =>
    e is GrpcError && e.code == StatusCode.failedPrecondition;

/// ABORTED (10) is reserved for exactly one case (contract, "One device
/// playing per profile"): `ResolveStream` refusing because the profile is
/// already playing on another device. Unlike [isFailedPrecondition], this
/// isn't a dead end — the server's `message` names the other device (e.g.
/// "questo profilo è già in riproduzione su «TV salotto»") and the client
/// can offer "Guarda qui", resolving again with `take_over = true` to move
/// playback here immediately. Never retried automatically, same reasoning
/// as FAILED_PRECONDITION: retrying without take_over would just fail the
/// same way again.
bool isPlayingElsewhere(Object e) =>
    e is GrpcError && e.code == StatusCode.aborted;

/// UNAVAILABLE from the downloads RPCs specifically means "the offline-
/// downloads feature isn't active on this server" (contract, "Offline
/// downloads" section) — distinct from the same code elsewhere in the app,
/// where it means a transient/retryable transport problem.
bool isUnavailable(Object e) =>
    e is GrpcError && e.code == StatusCode.unavailable;

/// The message to show the user for a resolve/RPC failure: a [GrpcError]'s
/// own `message` when there is one (the server writes these for display,
/// see [isFailedPrecondition]) rather than `toString()`, which prepends the
/// verbose "GrpcError (code, ...)" wrapper. Falls back to `toString()` for
/// anything else, or if the message is empty.
String grpcMessage(Object e) {
  if (e is GrpcError && (e.message?.isNotEmpty ?? false)) return e.message!;
  return e.toString();
}

/// A profile with a PIN (proto/auth.proto's "Profile PIN" section) can only
/// be used by a device that's either trusted for it or sending a valid
/// "x-profile-session" — every other call carrying that profile's
/// "x-profile-id" fails with PERMISSION_DENIED and this fixed message
/// prefix. Distinct on purpose from [isUnauthenticated]: the JWT/device
/// pairing is still perfectly valid here, only this one profile is
/// inaccessible right now, so this must never trigger the session-expired/
/// re-pairing flow — just a bounce back to the profile picker with the PIN
/// dialog open (see AuthBloc's ProfileLockedEvent). A wrong PIN or a
/// rate-limit response from UnlockProfile/SetProfilePin themselves are
/// different codes (also PERMISSION_DENIED for a wrong PIN, but without this
/// prefix, and RESOURCE_EXHAUSTED for rate-limiting) — the PIN dialog reads
/// those directly off the RPC response, never through this check.
bool isProfileLocked(Object e) =>
    e is GrpcError &&
    e.code == StatusCode.permissionDenied &&
    (e.message ?? '').startsWith('profilo protetto da PIN');

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
