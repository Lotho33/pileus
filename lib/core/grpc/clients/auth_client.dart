import 'package:grpc/service_api.dart';

import '../auth_interceptor.dart';
import '../generated/auth.pbgrpc.dart';

export '../generated/auth.pbgrpc.dart'
    show
        AuthorizeDeviceRequest,
        AuthorizeDeviceResponse,
        RefreshTokenRequest,
        CreateProfileRequest,
        ProfileResponse,
        ListProfilesRequest,
        ListProfilesResponse,
        DeleteProfileRequest,
        DeleteProfileResponse,
        UpdateProfileRequest,
        SetProfilePreferencesRequest,
        UnpairSelfRequest,
        UnpairSelfResponse,
        UnlockProfileRequest,
        UnlockProfileResponse,
        LockProfileRequest,
        LockProfileResponse,
        SetProfilePinRequest,
        SetProfilePinResponse;

// Same rationale and value as MediaGrpcClient's (see media_client.dart):
// without a per-RPC deadline, a hung call here left the calling
// bloc/cubit's *Loading state spinning forever — the channel's idleTimeout
// only bounds a connection with no traffic, not an RPC that's alive but
// never answers. Pairing/profile management (this client) had no bound at
// all until this audit pass.
const _defaultRpcTimeout = Duration(seconds: 20);

class AuthGrpcClient {
  late final AuthServiceClient _stub;

  AuthGrpcClient(ClientChannel channel, AuthInterceptor interceptor) {
    _stub = AuthServiceClient(channel, interceptors: [interceptor]);
  }

  Future<AuthorizeDeviceResponse> authorizeDevice(
          AuthorizeDeviceRequest request) =>
      _stub.authorizeDevice(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  /// Renews the device JWT (same device_id, new expiry) before the 30-day
  /// expiry forces the device back through pairing — see
  /// AuthRepository.refreshToken's doc for why this matters.
  Future<AuthorizeDeviceResponse> refreshToken() =>
      _stub.refreshToken(RefreshTokenRequest(),
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<ProfileResponse> createProfile(CreateProfileRequest request) =>
      _stub.createProfile(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<ListProfilesResponse> listProfiles() =>
      _stub.listProfiles(ListProfilesRequest(),
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<DeleteProfileResponse> deleteProfile(DeleteProfileRequest request) =>
      _stub.deleteProfile(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<ProfileResponse> updateProfile(UpdateProfileRequest request) =>
      _stub.updateProfile(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  /// Replaces only the profile's opaque `preferences_json` blob (subtitle
  /// appearance today) — separate from updateProfile so a settings change
  /// doesn't round-trip name/avatar.
  Future<ProfileResponse> setProfilePreferences(
          String profileId, String preferencesJson) =>
      _stub.setProfilePreferences(
          SetProfilePreferencesRequest(
              profileId: profileId, preferencesJson: preferencesJson),
          options: CallOptions(timeout: _defaultRpcTimeout));

  /// Deregisters this device from mycelium (its own device_id, derived
  /// server-side from the JWT — never able to unpair another device). Used
  /// by "Cambia server" so a device doesn't linger in the dashboard's device
  /// list forever after the person has moved to a different server.
  Future<UnpairSelfResponse> unpairSelf() =>
      _stub.unpairSelf(UnpairSelfRequest(),
          options: CallOptions(timeout: _defaultRpcTimeout));

  /// Unlocks a PIN-protected profile for this device — `rememberDevice: true`
  /// trusts the device persistently (no PIN needed again until revoked);
  /// `false` returns a `sessionToken` instead, which the caller must hand to
  /// AuthInterceptor.setProfileSessionToken (in-memory only, see its doc) so
  /// every subsequent call for this profile carries it as
  /// "x-profile-session". A wrong PIN or a rate-limit lockout come back as a
  /// GrpcError (PERMISSION_DENIED / RESOURCE_EXHAUSTED) with a message
  /// already written for the user — the PIN dialog shows it directly.
  Future<UnlockProfileResponse> unlockProfile(UnlockProfileRequest request) =>
      _stub.unlockProfile(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  /// Ends this device's session(s) on a profile — call on "exit profile" /
  /// logout / switch profile. `forgetDevice: true` also drops this device's
  /// persistent trust (the profile settings screen's "Dimentica questo
  /// dispositivo"). Best-effort at every call site: never allowed to block
  /// leaving the profile.
  Future<LockProfileResponse> lockProfile(LockProfileRequest request) =>
      _stub.lockProfile(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  /// Sets, changes (current_pin required if one is already set) or removes
  /// (new_pin empty) a profile's PIN. Revokes every device's trust and
  /// session for the profile — including this device's — so the profile
  /// settings screen should immediately offer to unlock again afterward.
  Future<SetProfilePinResponse> setProfilePin(SetProfilePinRequest request) =>
      _stub.setProfilePin(request,
          options: CallOptions(timeout: _defaultRpcTimeout));
}
