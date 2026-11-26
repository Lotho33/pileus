import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/host_resolver_io.dart';

void main() {
  test('only the paired server counts, whatever the fingerprint format', () {
    const pinned = 'AB:CD:EF:01';
    expect(sameFingerprint(pinned, {'grpc_tls_fingerprint': 'abcdef01'}),
        isTrue);
    expect(sameFingerprint(pinned, {'grpc_tls_fingerprint': '910c8911'}),
        isFalse);
  });

  test('a server without TLS (no fingerprint) cannot be told apart', () {
    expect(sameFingerprint('abcdef01', {'name': 'Mycelium'}), isTrue);
    expect(sameFingerprint('', {'grpc_tls_fingerprint': 'abcdef01'}), isTrue);
  });
}
