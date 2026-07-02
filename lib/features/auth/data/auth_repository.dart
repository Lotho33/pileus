import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/models/device_session.dart';
import '../../../core/db/models/local_profile.dart';
import '../../../core/di/injection.dart' show getIt;
import '../../../core/grpc/auth_interceptor.dart';
import '../../../core/grpc/clients/auth_client.dart';
import '../../settings/data/settings_repository.dart';

/// `ClientChannel` connects lazily — the HTTP/2 handshake only starts on
/// the *first* RPC. Whichever of authorizeDevice / syncProfiles happens to
/// run first each app launch races that handshake
/// (mDNS resolve included) and can fail with UNAVAILABLE even though the
/// server is fine — a manual retry a moment later always works because the
/// channel is warm by then. One quick, silent retry covers exactly that
/// without masking a real outage (which just fails again immediately).
Future<T> _withColdStartRetry<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on GrpcError catch (e) {
    if (e.code != StatusCode.unavailable) rethrow;
    await Future.delayed(const Duration(milliseconds: 400));
    return call();
  }
}

class AuthRepository {
  final SharedPreferences _prefs;
  final AuthGrpcClient _client;
  final AuthInterceptor _interceptor;

  AuthRepository(this._prefs, this._client, this._interceptor);

  static const String _profilesKey = 'local_profiles';

  Future<List<LocalProfile>> _readProfiles() async {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LocalProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeProfiles(List<LocalProfile> profiles) => _prefs.setString(
        _profilesKey,
        jsonEncode(profiles.map((p) => p.toJson()).toList()),
      );

  Future<DeviceSession?> getStoredSession() async {
    final session = DeviceSession.readFrom(_prefs);
    if (session != null &&
        session.isAuthorized &&
        session.deviceJwt.length > 20) {
      _interceptor.setCredentials(session.deviceJwt, '');
    }
    return session;
  }

  Future<DeviceSession> authorizeDevice(String pin) async {
    final deviceId = const Uuid().v4();

    // Deliberately a raw string — despite the proto field's name. The
    // mycelium server checks it against a short-lived pairing code the user
    // generates from the admin dashboard; the wire shape is unchanged, so
    // this field just carries whatever the pairing screen collected
    // verbatim. Do not "fix" this by hashing client-side — that would send a
    // hash where the server expects the raw value and break device pairing.
    final response = await _withColdStartRetry(() => _client.authorizeDevice(
          AuthorizeDeviceRequest(deviceId: deviceId, pinHash: pin),
        ));

    // Reuse existing row (preserves grpcHost/tlsFingerprint) or create new.
    final existing = DeviceSession.readFrom(_prefs);
    final session = existing ?? DeviceSession();
    session
      ..deviceId = deviceId
      ..deviceJwt = response.deviceJwt
      ..expiresAtTimestamp = response.expiresAt.toInt()
      ..isAuthorized = true;

    await DeviceSession.writeTo(_prefs, session);
    _interceptor.setCredentials(session.deviceJwt, '');
    return session;
  }

  /// Clears only the auth fields (deviceId/JWT/authorized flag/last active
  /// profile), preserving grpcHost/vpnHost/tlsFingerprint — a session
  /// expiring mid-use (SessionExpiredEvent) is not a "forget this server"
  /// event. Wiping the whole row here used to force a full re-discovery on
  /// next launch and drop the pinned TLS fingerprint, silently downgrading
  /// the gRPC channel to plaintext (see DeviceSession.tlsFingerprint's doc).
  Future<void> logout() async {
    final session = DeviceSession.readFrom(_prefs);
    if (session == null) return;
    session
      ..deviceId = ''
      ..deviceJwt = ''
      ..expiresAtTimestamp = 0
      ..isAuthorized = false
      ..lastActiveProfileId = null;
    await DeviceSession.writeTo(_prefs, session);
  }

  /// Full wipe of the cached device/session row and local profile list —
  /// used by "Cambia server" in settings. Unlike [logout] (which keeps
  /// grpcHost/tlsFingerprint so a mid-session expiry doesn't force a
  /// re-scan), changing server means the host, its pinned TLS fingerprint,
  /// the device pairing and every profile that belonged to the old server
  /// are all about to be replaced — none of it should carry over.
  Future<void> forgetServer() async {
    await DeviceSession.clear(_prefs);
    await _writeProfiles(const []);
    _interceptor.clear();
  }

  Future<List<LocalProfile>> getLocalProfiles() => _readProfiles();

  /// Persists which profile should be auto-selected on the next cold start
  /// (see AuthBloc._onAppStarted) — set on every successful profile pick and
  /// on first-ever profile creation, never cleared except by logout.
  Future<void> setLastActiveProfile(String profileId) async {
    final session = DeviceSession.readFrom(_prefs) ?? DeviceSession();
    session.lastActiveProfileId = profileId;
    await DeviceSession.writeTo(_prefs, session);
  }

  /// Un-sets the remembered default — the next cold start falls back to the
  /// profile picker instead of auto-selecting.
  Future<void> clearLastActiveProfile() async {
    final session = DeviceSession.readFrom(_prefs);
    if (session == null) return;
    session.lastActiveProfileId = null;
    await DeviceSession.writeTo(_prefs, session);
  }

  /// Fetches profiles from the server and overwrites the local cache.
  ///
  /// Deliberately lets a network failure propagate instead of swallowing it
  /// into a silent fallback to the local cache: both call sites
  /// (AuthBloc._onAuthenticateDevice right after first pairing, and
  /// _onCreateProfile right after creating one) already wrap this in a
  /// try/catch that surfaces AuthError — with the fallback, a transient
  /// failure at exactly those moments (no local cache yet, or a
  /// just-created profile not reflected) showed "0 profiles" / the profile
  /// list unchanged with no indication anything went wrong, instead of a
  /// visible error the user could retry from.
  Future<List<LocalProfile>> syncProfilesFromServer() async {
    final resp = await _withColdStartRetry(() => _client.listProfiles());
    final locals = resp.profiles
        .map(
          (p) => LocalProfile()
            ..profileId = p.profileId
            ..profileName = p.name
            ..avatarUrl = p.avatarUrl
            ..isChildProfile = p.isChild,
        )
        .toList();
    await _writeProfiles(locals);
    // Profiles are server-wide and carry a `preferences_json` blob (subtitle
    // appearance) that must follow the person across devices — hand each
    // one to SettingsRepository so the active profile's values are ready
    // before Preferenze / the player reads them. getIt lookup (not a ctor
    // dep) so a rebuildGrpcClients doesn't leave a stale reference.
    final settings = getIt<SettingsRepository>();
    for (final p in resp.profiles) {
      await settings.cacheProfilePrefsBlob(p.profileId, p.preferencesJson);
    }
    return locals;
  }

  /// Pushes a profile's opaque preferences blob to the server. Called
  /// (debounced) by SettingsRepository when a person-scoped setting changes.
  Future<void> setProfilePreferences(String profileId, String json) =>
      _client.setProfilePreferences(profileId, json);

  Future<ProfileResponse> createProfile({
    required String name,
    required String avatarUrl,
  }) async {
    final response = await _withColdStartRetry(() => _client.createProfile(
          CreateProfileRequest(
            name: name,
            avatarUrl: avatarUrl,
            isChild: false,
          ),
        ));

    final local = LocalProfile()
      ..profileId = response.profileId
      ..profileName = response.name
      ..avatarUrl = response.avatarUrl
      ..isChildProfile = response.isChild;

    final profiles = await _readProfiles();
    profiles.add(local);
    await _writeProfiles(profiles);
    return response;
  }

  Future<LocalProfile?> _findLocal(String profileId) async {
    final profiles = await _readProfiles();
    return profiles.firstWhereOrNull((p) => p.profileId == profileId);
  }

  /// Low-level UpdateProfile call — patches name/avatar/isChild locally from
  /// the server's response.
  ///
  /// Sentinel semantics come from the server handler (mycelium-core
  /// internal/pileus/auth_handler.go UpdateProfile): empty name/avatarUrl
  /// means "keep current". isChild has NO "keep" fallback — every caller
  /// below must pass the real current value.
  Future<ProfileResponse> updateProfile({
    required String profileId,
    String name = '',
    String avatarUrl = '',
    required bool isChild,
  }) async {
    final response = await _client.updateProfile(UpdateProfileRequest(
      profileId: profileId,
      name: name,
      avatarUrl: avatarUrl,
      isChild: isChild,
    ));
    final profiles = await _readProfiles();
    final idx = profiles.indexWhere((p) => p.profileId == profileId);
    final local = idx >= 0 ? profiles[idx] : LocalProfile();
    local
      ..profileId = response.profileId
      ..profileName = response.name
      ..avatarUrl = response.avatarUrl
      ..isChildProfile = response.isChild;
    if (idx >= 0) {
      profiles[idx] = local;
    } else {
      profiles.add(local);
    }
    await _writeProfiles(profiles);
    return response;
  }

  Future<ProfileResponse> renameProfile(
      String profileId, String newName) async {
    final current = await _findLocal(profileId);
    return updateProfile(
      profileId: profileId,
      name: newName,
      isChild: current?.isChildProfile ?? false,
    );
  }

  Future<ProfileResponse> updateAvatarUrl(
      String profileId, String newUrl) async {
    final current = await _findLocal(profileId);
    return updateProfile(
      profileId: profileId,
      avatarUrl: newUrl,
      isChild: current?.isChildProfile ?? false,
    );
  }

  Future<void> deleteProfileRemote(String profileId) async {
    await _client.deleteProfile(DeleteProfileRequest(profileId: profileId));
    final profiles = await _readProfiles();
    profiles.removeWhere((p) => p.profileId == profileId);
    await _writeProfiles(profiles);
    // If the deleted profile was the remembered default, drop it — otherwise
    // the next cold start tries to auto-select a profile that no longer
    // exists (it falls back to the picker, but only after a needless beat).
    final session = DeviceSession.readFrom(_prefs);
    if (session != null && session.lastActiveProfileId == profileId) {
      session.lastActiveProfileId = null;
      await DeviceSession.writeTo(_prefs, session);
    }
  }

  /// Saves the gRPC host + TLS fingerprint learned during server discovery,
  /// preserving any existing session row (deviceId/JWT/auth state) instead
  /// of overwriting it — mirrors the previous Isar find-or-create pattern
  /// used by ServerDiscoveryScreen._saveHost.
  Future<void> saveHostInfo(String host, String? tlsFingerprint) async {
    final session = DeviceSession.readFrom(_prefs) ?? DeviceSession();
    session
      ..grpcHost = host
      ..tlsFingerprint = tlsFingerprint;
    await DeviceSession.writeTo(_prefs, session);
  }
}
