/// Turns a raw gRPC/exception message (`Object.toString()`, e.g.
/// `"GrpcError: 14, UNAVAILABLE: ..."`) into a short, translated message a
/// non-technical user can act on.
///
/// Extracted from the (until now) byte-identical classification duplicated
/// in mobile_pairing_screen.dart and desktop_pairing_screen.dart — the TV
/// pairing screen (device_pairing_screen.dart) used to show the raw message
/// instead, which meant the D-pad-only platform — the one where re-pairing
/// is the most awkward to redo — had the worst error diagnostics of the
/// three.
///
/// Tuned for the pairing flow (network-unreachable vs. bad/expired code);
/// [genericUnreachableMessage] covers the same "unreachable" family for
/// other flows (e.g. profile management) without implying a pairing code.
String friendlyPairingErrorMessage(String rawMessage) {
  if (_looksUnreachable(rawMessage)) {
    return 'Server non raggiungibile (gRPC :50051). Controlla IP e porta.';
  }
  return 'Codice non valido o scaduto.';
}

/// Same "is this a network problem?" classification as
/// [friendlyPairingErrorMessage], for call sites (profile create/rename/
/// avatar/delete) where a bad-input explanation wouldn't make sense — only
/// the network case gets rewritten, anything else keeps whatever message the
/// server/exception actually produced.
String friendlyOperationErrorMessage(String rawMessage) {
  if (_looksUnreachable(rawMessage)) {
    return 'Operazione non riuscita: server non raggiungibile.';
  }
  return rawMessage;
}

bool _looksUnreachable(String rawMessage) {
  final m = rawMessage.toLowerCase();
  return m.contains('unavailable') ||
      m.contains('deadline') ||
      m.contains('socket') ||
      m.contains('connection');
}
