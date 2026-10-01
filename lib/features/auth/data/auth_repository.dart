import 'dart:convert';

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

  /// Renews the device JWT in place — same device_id, new deviceJwt +
  /// expiresAtTimestamp — before the 30-day expiry lapses. mycelium-core
  /// started wiping every PIN trust/session this device held
  /// the moment its device_id re-pairs (a rotating code is meant for a device
  /// re-authorizing, not for a renewal); Pileus never called this RPC before,
  /// so every device silently hit that wall once a month and every protected
  /// profile asked for its PIN again on the family TV. AuthBloc is the only
  /// caller (see its "Device JWT refresh" section) — decides whether an
  /// UNAUTHENTICATED here (device revoked/deleted) should bounce to pairing;
  /// this method just does the RPC and persists the result, same shape as
  /// [authorizeDevice].
  Future<void> refreshToken() async {
    final response = await _client.refreshToken();
    final session = DeviceSession.readFrom(_prefs);
    if (session == null) return;
    session
      ..deviceJwt = response.deviceJwt
      ..expiresAtTimestamp = response.expiresAt.toInt();
    await DeviceSession.writeTo(_prefs, session);
    _interceptor.setCredentials(session.deviceJwt, '');
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

  /// Best-effort: asks the server to forget this device right away
  /// (mycelium.UnpairSelf) before [forgetServer] wipes the host/JWT/TLS
  /// fingerprint this call needs to reach it — call this first. Never
  /// throws and never allowed to block/prevent changing server: an
  /// unreachable server, an already-expired JWT, or — on the certMismatch
  /// recovery path — a TLS fingerprint that no longer matches (the device is
  /// leaving *because* the server's identity changed) must all just be
  /// swallowed silently, same as a device that was already removed from the
  /// server's list would be.
  Future<void> unpairSelf() async {
    try {
      await _client.unpairSelf();
    } catch (_) {
      // Ignored on purpose — see above.
    }
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
            ..pinProtected = p.pinProtected
            ..unlocked = p.unlocked
            ..deviceTrusted = p.deviceTrusted,
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
          ),
        ));

    final local = LocalProfile()
      ..profileId = response.profileId
      ..profileName = response.name
      ..avatarUrl = response.avatarUrl
      ..pinProtected = response.pinProtected
      ..unlocked = response.unlocked
      ..deviceTrusted = response.deviceTrusted;

    final profiles = await _readProfiles();
    profiles.add(local);
    await _writeProfiles(profiles);
    return response;
  }

  /// Low-level UpdateProfile call — patches name/avatar locally from the
  /// server's response.
  ///
  /// Sentinel semantics come from the server handler (mycelium-core
  /// internal/pileus/auth_handler.go UpdateProfile): empty name/avatarUrl
  /// means "keep current".
  Future<ProfileResponse> updateProfile({
    required String profileId,
    String name = '',
    String avatarUrl = '',
  }) async {
    final response = await _client.updateProfile(UpdateProfileRequest(
      profileId: profileId,
      name: name,
      avatarUrl: avatarUrl,
    ));
    final profiles = await _readProfiles();
    final idx = profiles.indexWhere((p) => p.profileId == profileId);
    final local = idx >= 0 ? profiles[idx] : LocalProfile();
    local
      ..profileId = response.profileId
      ..profileName = response.name
      ..avatarUrl = response.avatarUrl
      ..pinProtected = response.pinProtected
      ..unlocked = response.unlocked
      ..deviceTrusted = response.deviceTrusted;
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
    return updateProfile(profileId: profileId, name: newName);
  }

  Future<ProfileResponse> updateAvatarUrl(
      String profileId, String newUrl) async {
    return updateProfile(profileId: profileId, avatarUrl: newUrl);
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

  // ─── Profile PIN ───────────────────────────────────────────
  // See proto/auth.proto's "Profile PIN" section for the server-side rules
  // this wraps.

  /// Unlocks [profileId] with [pin] for this device. `rememberDevice: true`
  /// trusts the device persistently; `false` gets a one-off session token
  /// back in the response instead — the caller (the PIN dialog) is
  /// responsible for handing that to
  /// `AuthInterceptor.setProfileSessionToken`, this method only makes the
  /// RPC and updates the local cache. Throws (a [GrpcError]) on a wrong PIN
  /// or a rate-limit lockout — both come with a message written for the
  /// user, shown directly by the caller.
  Future<UnlockProfileResponse> unlockProfile(
    String profileId,
    String pin, {
    required bool rememberDevice,
  }) async {
    final response = await _client.unlockProfile(UnlockProfileRequest(
      profileId: profileId,
      pin: pin,
      rememberDevice: rememberDevice,
    ));
    if (response.ok) {
      final profiles = await _readProfiles();
      final idx = profiles.indexWhere((p) => p.profileId == profileId);
      if (idx >= 0) {
        profiles[idx]
          ..unlocked = true
          ..deviceTrusted = response.deviceTrusted;
        await _writeProfiles(profiles);
      }
    }
    return response;
  }

  /// Ends this device's session(s) on [profileId] — call on exit
  /// profile/switch profile/logout. Best-effort and never throws, same
  /// reasoning as [unpairSelf]: an unreachable server or an already-expired
  /// JWT must not block leaving the profile. [forgetDevice] also drops this
  /// device's persistent trust (profile settings' "Dimentica questo
  /// dispositivo"). Updates the local cache regardless of whether the RPC
  /// actually reached the server, so this device's own picker doesn't show
  /// itself as still unlocked a moment after deliberately locking it.
  Future<void> lockProfile(String profileId, {bool forgetDevice = false}) async {
    try {
      await _client.lockProfile(LockProfileRequest(
        profileId: profileId,
        forgetDevice: forgetDevice,
      ));
    } catch (_) {
      // Ignored on purpose — see above.
    }
    final profiles = await _readProfiles();
    final idx = profiles.indexWhere((p) => p.profileId == profileId);
    if (idx >= 0 && profiles[idx].pinProtected) {
      profiles[idx].unlocked = false;
      if (forgetDevice) profiles[idx].deviceTrusted = false;
      await _writeProfiles(profiles);
    }
  }

  /// Sets ([newPin] non-empty on a profile with none yet), changes
  /// ([currentPin] + [newPin] both non-empty) or removes ([newPin] empty)
  /// a profile's PIN. [currentPin] is required by the server whenever the
  /// profile already has one — a wrong one throws (message shown directly).
  /// A change or removal revokes every device's trust/session for the
  /// profile, including this one, so the cache reflects that immediately:
  /// the caller should offer to unlock again right after.
  Future<SetProfilePinResponse> setProfilePin(
    String profileId, {
    String currentPin = '',
    String newPin = '',
  }) async {
    final response = await _client.setProfilePin(SetProfilePinRequest(
      profileId: profileId,
      currentPin: currentPin,
      newPin: newPin,
    ));
    final profiles = await _readProfiles();
    final idx = profiles.indexWhere((p) => p.profileId == profileId);
    if (idx >= 0) {
      profiles[idx]
        ..pinProtected = response.pinProtected
        ..unlocked = !response.pinProtected
        ..deviceTrusted = false;
      await _writeProfiles(profiles);
    }
    return response;
  }

  /// Saves the gRPC host + TLS fingerprint + gRPC port learned during server
  /// discovery, preserving any existing session row (deviceId/JWT/auth
  /// state) instead of overwriting it — mirrors the previous Isar
  /// find-or-create pattern used by ServerDiscoveryScreen._saveHost.
  ///
  /// [grpcPort] is whatever the caller parsed out of /pileus/info's
  /// `grpc_port` field (it used to always be 50051 regardless
  /// of what the server actually listened on); null (missing field, older
  /// server) is saved as-is so a stale port from a *previous* discovery
  /// never lingers — [DeviceSession.grpcPort]'s doc covers the ServerPorts.
  /// grpc fallback this leaves callers to apply.
  ///
  /// [remote]/[remotePort] (see server_address.dart): a
  /// mycelium published on the public internet rather than found on the
  /// LAN — always passed explicitly (never defaulted from the existing
  /// row) so switching from one mode to the other on the same device
  /// can't leave a stale flag behind.
  Future<void> saveHostInfo(
    String host,
    String? tlsFingerprint, {
    int? grpcPort,
    bool remote = false,
    int? remotePort,
  }) async {
    final session = DeviceSession.readFrom(_prefs) ?? DeviceSession();
    session
      ..grpcHost = host
      ..tlsFingerprint = tlsFingerprint
      ..grpcPort = grpcPort
      ..remote = remote
      ..remotePort = remotePort;
    await DeviceSession.writeTo(_prefs, session);
  }
}
