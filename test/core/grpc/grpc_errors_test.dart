import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:pileus/core/grpc/grpc_errors.dart';

void main() {
  group('isFailedPrecondition', () {
    test('true for a FAILED_PRECONDITION GrpcError (a plugin\'s own '
        'precondition failure — the single-device lease moved to ABORTED, '
        'see isPlayingElsewhere below)', () {
      const e = GrpcError.custom(
        StatusCode.failedPrecondition,
        'questo plugin richiede un abbonamento attivo',
      );
      expect(isFailedPrecondition(e), isTrue);
    });

    test('false for other GrpcError codes (e.g. UNAVAILABLE)', () {
      const e = GrpcError.unavailable('server non raggiungibile');
      expect(isFailedPrecondition(e), isFalse);
    });

    test('false for ABORTED (the two must not be conflated)', () {
      const e = GrpcError.custom(StatusCode.aborted, 'in riproduzione altrove');
      expect(isFailedPrecondition(e), isFalse);
    });

    test('false for a non-GrpcError object', () {
      expect(isFailedPrecondition(Exception('boom')), isFalse);
    });
  });

  group('isPlayingElsewhere', () {
    test('true for an ABORTED GrpcError (contract "One device playing per '
        'profile")', () {
      const e = GrpcError.custom(
        StatusCode.aborted,
        'questo profilo è già in riproduzione su «TV salotto»',
      );
      expect(isPlayingElsewhere(e), isTrue);
    });

    test('false for FAILED_PRECONDITION (the two must not be conflated)', () {
      const e = GrpcError.custom(
          StatusCode.failedPrecondition, 'questo plugin richiede...');
      expect(isPlayingElsewhere(e), isFalse);
    });

    test('false for other GrpcError codes (e.g. UNAVAILABLE)', () {
      const e = GrpcError.unavailable('server non raggiungibile');
      expect(isPlayingElsewhere(e), isFalse);
    });

    test('false for a non-GrpcError object', () {
      expect(isPlayingElsewhere(Exception('boom')), isFalse);
    });
  });

  group('isUnauthenticated', () {
    test('true for an UNAUTHENTICATED GrpcError', () {
      const e = GrpcError.unauthenticated('sessione scaduta');
      expect(isUnauthenticated(e), isTrue);
    });

    test('false for FAILED_PRECONDITION (the two must not be conflated)', () {
      const e = GrpcError.custom(StatusCode.failedPrecondition, 'x');
      expect(isUnauthenticated(e), isFalse);
    });
  });

  group('grpcMessage', () {
    test('returns the GrpcError.message verbatim, not toString()', () {
      const e = GrpcError.custom(
        StatusCode.failedPrecondition,
        'questo profilo è già in riproduzione su «TV salotto»: interrompi lì '
            'la visione (o attendi 90 secondi) e riprova',
      );
      final msg = grpcMessage(e);
      expect(
        msg,
        'questo profilo è già in riproduzione su «TV salotto»: interrompi lì '
        'la visione (o attendi 90 secondi) e riprova',
      );
      // The point of grpcMessage: no "GrpcError (..." wrapper leaking through.
      expect(msg.contains('GrpcError'), isFalse);
    });

    test('falls back to toString() for a GrpcError with no message', () {
      const e = GrpcError.custom(StatusCode.unknown, null);
      expect(grpcMessage(e), e.toString());
    });

    test('falls back to toString() for a non-GrpcError object', () {
      final e = Exception('plain failure');
      expect(grpcMessage(e), e.toString());
    });
  });

  group('isProfileLocked', () {
    test(
        'true for PERMISSION_DENIED with the "profilo protetto da PIN" '
        'prefix', () {
      const e = GrpcError.custom(
        StatusCode.permissionDenied,
        'profilo protetto da PIN: inserisci il PIN per usarlo',
      );
      expect(isProfileLocked(e), isTrue);
    });

    test('false for PERMISSION_DENIED with a different message (wrong PIN)',
        () {
      const e = GrpcError.custom(StatusCode.permissionDenied, 'PIN errato');
      expect(isProfileLocked(e), isFalse);
    });

    test('false for RESOURCE_EXHAUSTED (PIN rate-limit lockout)', () {
      const e = GrpcError.resourceExhausted(
          'troppi PIN errati: riprova tra 2 minuti');
      expect(isProfileLocked(e), isFalse);
    });

    test('false for UNAUTHENTICATED (the two must not be conflated)', () {
      const e = GrpcError.unauthenticated('sessione scaduta');
      expect(isProfileLocked(e), isFalse);
    });

    test('false for a non-GrpcError object', () {
      expect(isProfileLocked(Exception('boom')), isFalse);
    });
  });

  group('looksLikeCertificateMismatch', () {
    test('matches common certificate/handshake/TLS substrings', () {
      expect(looksLikeCertificateMismatch(Exception('HandshakeException: x')),
          isTrue);
      expect(
          looksLikeCertificateMismatch(
              Exception('CERTIFICATE_VERIFY_FAILED')),
          isTrue);
      expect(looksLikeCertificateMismatch(Exception('tls error')), isTrue);
    });

    test('false for an unrelated error', () {
      expect(looksLikeCertificateMismatch(Exception('connection refused')),
          isFalse);
    });
  });
}
