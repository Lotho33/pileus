import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/auth/friendly_error.dart';

void main() {
  group('friendlyPairingErrorMessage', () {
    test('an unreachable-looking error mentions the server, not the code',
        () {
      final msg = friendlyPairingErrorMessage(
          'GrpcError (code: 14, codeName: UNAVAILABLE, message: null, ...)');
      expect(msg, contains('non raggiungibile'));
    });

    test(
        'INVALID_ARGUMENT (mycelium rejects a malformed '
        'device_id) is distinguished from a wrong/expired pairing code — the '
        'code was never even consumed', () {
      final msg = friendlyPairingErrorMessage(
          'GrpcError (code: 3, codeName: INVALID_ARGUMENT, message: device_id non valido, ...)');
      expect(msg, isNot(contains('scaduto')));
      expect(msg.toLowerCase(), contains('non'));
    });

    test('anything else falls back to "wrong/expired code"', () {
      final msg = friendlyPairingErrorMessage(
          'GrpcError (code: 16, codeName: UNAUTHENTICATED, message: codice errato, ...)');
      expect(msg, 'Codice non valido o scaduto.');
    });
  });

  group('friendlyOperationErrorMessage', () {
    test('an unreachable-looking error is rewritten', () {
      final msg = friendlyOperationErrorMessage('SocketException: failed');
      expect(msg, contains('non raggiungibile'));
    });

    test('anything else is passed through verbatim', () {
      expect(friendlyOperationErrorMessage('nome già in uso'), 'nome già in uso');
    });
  });
}
