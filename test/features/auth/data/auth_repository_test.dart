import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show ClientChannel;
import 'package:pileus/core/db/models/device_session.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/auth_client.dart';
import 'package:pileus/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scripted [AuthGrpcClient] — overrides only authorizeDevice, same
/// "subclass, don't mock" approach as the rest of the test suite (no
/// mocking package in this project's dev_dependencies). Records the
/// device_id each call actually sent, which is exactly what these tests
/// care about — never hits a real channel.
class _ScriptedAuthGrpcClient extends AuthGrpcClient {
  _ScriptedAuthGrpcClient(super.channel, super.interceptor);

  final List<String> deviceIdsSent = [];

  @override
  Future<AuthorizeDeviceResponse> authorizeDevice(
      AuthorizeDeviceRequest request) async {
    deviceIdsSent.add(request.deviceId);
    return AuthorizeDeviceResponse(
      deviceJwt: 'jwt-for-${request.deviceId}',
      expiresAt: Int64(9999999999),
    );
  }
}

void main() {
  late SharedPreferences prefs;
  late _ScriptedAuthGrpcClient client;
  late AuthRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    client = _ScriptedAuthGrpcClient(
        ClientChannel('localhost', port: 0), AuthInterceptor());
    repo = AuthRepository(prefs, client, AuthInterceptor());
  });

  group('AuthRepository.authorizeDevice — device_id stability', () {
    test('first-ever pairing mints a device_id and persists it', () async {
      final session = await repo.authorizeDevice('ABC123');

      expect(session.deviceId, isNotEmpty);
      expect(client.deviceIdsSent, [session.deviceId]);
      final stored = DeviceSession.readFrom(prefs);
      expect(stored?.deviceId, session.deviceId);
    });

    test(
        're-pairing (lost session, retried PIN, crash-then-restart) reuses '
        'the SAME device_id — never mints a new one while any is already '
        'on disk', () async {
      final seeded = DeviceSession()..deviceId = 'already-known-device';
      await DeviceSession.writeTo(prefs, seeded);

      final session = await repo.authorizeDevice('ABC123');

      expect(session.deviceId, 'already-known-device');
      expect(client.deviceIdsSent, ['already-known-device']);
    });

    test(
        'two consecutive authorizeDevice calls (e.g. a wrong-code retry) '
        'send the identical device_id both times', () async {
      await repo.authorizeDevice('WRONG1');
      await repo.authorizeDevice('RIGHT2');

      expect(client.deviceIdsSent, hasLength(2));
      expect(client.deviceIdsSent[0], client.deviceIdsSent[1]);
    });
  });

  group('AuthRepository.logout', () {
    test('clears the session but leaves device_id untouched — the next '
        'authorizeDevice() must still see it and reuse it, not mint a '
        'fresh one', () async {
      final authorized = DeviceSession()
        ..deviceId = 'stable-device-id'
        ..deviceJwt = 'some-jwt'
        ..expiresAtTimestamp = 1234567890
        ..isAuthorized = true
        ..lastActiveProfileId = 'p1';
      await DeviceSession.writeTo(prefs, authorized);

      await repo.logout();

      final after = DeviceSession.readFrom(prefs);
      expect(after?.deviceId, 'stable-device-id');
      expect(after?.deviceJwt, isEmpty);
      expect(after?.isAuthorized, isFalse);
      expect(after?.expiresAtTimestamp, 0);
      expect(after?.lastActiveProfileId, isNull);

      await repo.authorizeDevice('NEWCODE');
      expect(client.deviceIdsSent, ['stable-device-id']);
    });
  });
}
