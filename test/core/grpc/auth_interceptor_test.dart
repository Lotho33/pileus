import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';

void main() {
  group('AuthInterceptor — profile PIN session token', () {
    test('no token set: metadata never carries x-profile-session', () {
      final i = AuthInterceptor();
      i.setCredentials('jwt', 'profile-a');
      expect(i.debugMetadataForTests.containsKey('x-profile-session'), isFalse);
    });

    test('token set for the current profile: header carries it verbatim', () {
      final i = AuthInterceptor();
      i.setCredentials('jwt', 'profile-a');
      i.setProfileSessionToken('tok-123');
      expect(i.debugMetadataForTests['x-profile-session'], 'tok-123');
      // The other auth headers are still there alongside it.
      expect(i.debugMetadataForTests['authorization'], 'Bearer jwt');
      expect(i.debugMetadataForTests['x-profile-id'], 'profile-a');
    });

    test('switching to a different profile clears the token', () {
      final i = AuthInterceptor();
      i.setCredentials('jwt', 'profile-a');
      i.setProfileSessionToken('tok-123');
      i.setCredentials('jwt', 'profile-b');
      expect(i.debugMetadataForTests.containsKey('x-profile-session'), isFalse);
      expect(i.debugMetadataForTests['x-profile-id'], 'profile-b');
    });

    test(
        're-setting credentials for the SAME profile does NOT clear the '
        'token — this is what lets a PIN dialog call setCredentials before '
        'setProfileSessionToken without a caller\'s later (now redundant) '
        'setCredentials call for the same profile wiping it out again', () {
      final i = AuthInterceptor();
      i.setCredentials('jwt', 'profile-a');
      i.setProfileSessionToken('tok-123');
      i.setCredentials('jwt', 'profile-a'); // idempotent re-set
      expect(i.debugMetadataForTests['x-profile-session'], 'tok-123');
    });

    test('an empty profileId (the "keep current" convention) never clears '
        'the token', () {
      final i = AuthInterceptor();
      i.setCredentials('jwt', 'profile-a');
      i.setProfileSessionToken('tok-123');
      i.setCredentials('jwt', ''); // e.g. getStoredSession()'s pre-login call
      expect(i.debugMetadataForTests['x-profile-session'], 'tok-123');
      expect(i.profileId, 'profile-a'); // unchanged
    });

    test('clearProfileSessionToken() drops it without touching credentials',
        () {
      final i = AuthInterceptor();
      i.setCredentials('jwt', 'profile-a');
      i.setProfileSessionToken('tok-123');
      i.clearProfileSessionToken();
      expect(i.debugMetadataForTests.containsKey('x-profile-session'), isFalse);
      expect(i.profileId, 'profile-a');
      expect(i.jwt, 'jwt');
    });

    test('clear() (logout) drops the token along with everything else', () {
      final i = AuthInterceptor();
      i.setCredentials('jwt', 'profile-a');
      i.setProfileSessionToken('tok-123');
      i.clear();
      expect(i.debugMetadataForTests.containsKey('x-profile-session'), isFalse);
      expect(i.hasCredentials, isFalse);
    });

    test(
        'a fresh instance never inherits another instance\'s token — the '
        'token is a plain in-memory field with no backing store a new '
        'instance (a cold app restart, or a page reload on web) could read '
        'it back from', () {
      final a = AuthInterceptor();
      a.setCredentials('jwt', 'profile-a');
      a.setProfileSessionToken('tok-123');

      final b = AuthInterceptor();
      b.setCredentials('jwt', 'profile-a');
      expect(b.debugMetadataForTests.containsKey('x-profile-session'), isFalse);
    });

    test('setProfileSessionToken("") is treated as "no token"', () {
      final i = AuthInterceptor();
      i.setCredentials('jwt', 'profile-a');
      i.setProfileSessionToken('tok-123');
      i.setProfileSessionToken('');
      expect(i.debugMetadataForTests.containsKey('x-profile-session'), isFalse);
    });

    test('no session header at all before any jwt is set (pre-login calls)',
        () {
      final i = AuthInterceptor();
      i.setProfileSessionToken('tok-123'); // shouldn't normally happen, but
      // guards against ever sending x-profile-session on an unauthenticated
      // channel.
      expect(i.debugMetadataForTests.containsKey('x-profile-session'), isFalse);
    });
  });
}
