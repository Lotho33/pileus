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
    return 'Server non raggiungibile. Controlla IP e porta.';
  }
  // INVALID_ARGUMENT (mycelium rejects an empty/too-long/non-ASCII
  // device_id) is a client-side bug, not a wrong code — the server never
  // even looks at the pairing code in that case, so it's still unused and
  // the same code can be retried once the app restarts with a fresh
  // device_id. Distinct on purpose from the generic "wrong/expired code"
  // below so this doesn't read as "type it again", which would just fail
  // the same way.
  if (rawMessage.toLowerCase().contains('invalid_argument')) {
    return 'Dispositivo non riconosciuto dal server. Il codice non è stato '
        'usato: riavvia l\'app e riprova con lo stesso codice.';
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
