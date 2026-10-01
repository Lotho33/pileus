/// mycelium-core now allows a profile to play on only one device at a time.
/// While another device holds the 90s lease, the proxy answers every
/// `/proxy/playlist.m3u8`, `/segment.ts` and `/key.key` request with HTTP 409
/// (see mycelium-core's proxy handler) — the engine backends never see a
/// structured status code, so it reaches Dart wrapped in each backend's own
/// generic playback-error text: mpv reports "HTTP error 409", ExoPlayer wraps
/// it as `InvalidResponseCodeException: ... responseCode=409`. A resolve that
/// fails outright for the same reason instead surfaces as a gRPC
/// FAILED_PRECONDITION (see grpc_errors.dart's isFailedPrecondition) — this
/// is the mid-playback counterpart, once a stream had already opened.
///
/// A plain substring match on the error text is deliberately loose (same
/// reasoning as grpc_errors.dart's looksLikeCertificateMismatch): neither
/// backend exposes a real status code to this layer, and a false negative
/// here just falls back to the generic "Errore riproduzione" message, which
/// is safe.
bool looksLikeProfileLeaseConflict(String message) => message.contains('409');

/// Shown instead of the raw engine error text when
/// [looksLikeProfileLeaseConflict] matches. Retrying automatically (the live
/// stall watchdog, or any other auto-recovery) would just fail again with the
/// same 409 for as long as the other device keeps the lease — the "Riprova"
/// button stays available for the user to retry by hand once they've stopped
/// playback there.
const profileLeaseConflictMessage =
    'Questo profilo è ora in riproduzione su un altro dispositivo.';
