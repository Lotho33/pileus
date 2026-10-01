import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show ClientChannel;
import 'package:pileus/core/db/models/device_session.dart';
import 'package:pileus/core/db/models/local_profile.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/auth_client.dart';
import 'package:pileus/features/auth/data/auth_repository.dart';
import 'package:pileus/features/settings/bloc/profile_management_cubit.dart';
import 'package:pileus/features/settings/bloc/profile_management_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Real AuthRepository (not scripted) — every method setDefault touches
// (getStoredSession/getLocalProfiles/setLastActiveProfile/
// clearLastActiveProfile) is a plain SharedPreferences read/write with no
// gRPC involved, so seeding prefs directly and using the real repo gives
// correct read-after-write behaviour for free — a scripted repo returning a
// fixed session wouldn't reflect what setLastActiveProfile just wrote,
// which is exactly the thing under test here.
AuthRepository _buildRepo(SharedPreferences prefs) => AuthRepository(
      prefs,
      AuthGrpcClient(ClientChannel('localhost', port: 0), AuthInterceptor()),
      AuthInterceptor(),
    );

Future<void> _seedProfiles(SharedPreferences prefs, List<String> ids) async {
  final list = ids
      .map((id) => (LocalProfile()
            ..profileId = id
            ..profileName = 'Profile $id')
          .toJson())
      .toList();
  await prefs.setString('local_profiles', jsonEncode(list));
}

Future<void> _seedSession(SharedPreferences prefs, {String? lastActiveProfileId}) {
  final session = DeviceSession()
    ..deviceId = 'd1'
    ..deviceJwt = 'jwt'
    ..isAuthorized = true
    ..lastActiveProfileId = lastActiveProfileId;
  return DeviceSession.writeTo(prefs, session);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('ProfileManagementCubit.setDefault', () {
    test('no default set yet → turning it on succeeds', () async {
      await _seedProfiles(prefs, ['p1', 'p2']);
      await _seedSession(prefs, lastActiveProfileId: null);
      final cubit = ProfileManagementCubit(_buildRepo(prefs));
      addTearDown(cubit.close);
      await cubit.load('p1');

      await cubit.setDefault(true);

      final s = cubit.state as ProfileMgmtLoaded;
      expect(s.isDefault, isTrue);
      final session = DeviceSession.readFrom(prefs);
      expect(session?.lastActiveProfileId, 'p1');
    });

    test('another EXISTING profile already holds it → refused, no-op',
        () async {
      await _seedProfiles(prefs, ['p1', 'p2']);
      await _seedSession(prefs, lastActiveProfileId: 'p2');
      final cubit = ProfileManagementCubit(_buildRepo(prefs));
      addTearDown(cubit.close);
      await cubit.load('p1');
      expect((cubit.state as ProfileMgmtLoaded).otherDefaultName,
          'Profile p2');

      await cubit.setDefault(true);

      final s = cubit.state as ProfileMgmtLoaded;
      expect(s.isDefault, isFalse);
      final session = DeviceSession.readFrom(prefs);
      expect(session?.lastActiveProfileId, 'p2'); // unchanged
    });

    // lastActiveProfileId pointing at a profile that no longer exists
    // (deleted, or left over from an earlier pairing) made otherDefaultName
    // read null (nothing to warn about — the UI shows the normal confirm
    // dialog) while setDefault's own occupied-check still saw a non-null,
    // mismatched id and silently refused anyway. The toggle looked like it
    // did nothing: no error, no state change, switch stayed off.
    test('an ORPHANED lastActiveProfileId (no matching profile left) does '
        'NOT block setting a new default', () async {
      await _seedProfiles(prefs, ['p1', 'p2']); // 'ghost' is NOT in this list
      await _seedSession(prefs, lastActiveProfileId: 'ghost');
      final cubit = ProfileManagementCubit(_buildRepo(prefs));
      addTearDown(cubit.close);
      await cubit.load('p1');
      // The UI's own gate already reads this as "free to set" — setDefault
      // must agree, not silently disagree with what the dialog it's guarded
      // behind already promised.
      expect((cubit.state as ProfileMgmtLoaded).otherDefaultName, isNull);

      await cubit.setDefault(true);

      final s = cubit.state as ProfileMgmtLoaded;
      expect(s.isDefault, isTrue);
      final session = DeviceSession.readFrom(prefs);
      expect(session?.lastActiveProfileId, 'p1');
    });

    test('turning it off clears lastActiveProfileId', () async {
      await _seedProfiles(prefs, ['p1']);
      await _seedSession(prefs, lastActiveProfileId: 'p1');
      final cubit = ProfileManagementCubit(_buildRepo(prefs));
      addTearDown(cubit.close);
      await cubit.load('p1');
      expect((cubit.state as ProfileMgmtLoaded).isDefault, isTrue);

      await cubit.setDefault(false);

      final s = cubit.state as ProfileMgmtLoaded;
      expect(s.isDefault, isFalse);
      final session = DeviceSession.readFrom(prefs);
      expect(session?.lastActiveProfileId, isNull);
    });
  });
}
