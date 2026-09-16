import 'package:grpc/service_api.dart';

import '../auth_interceptor.dart';
import '../generated/auth.pbgrpc.dart';

export '../generated/auth.pbgrpc.dart'
    show
        AuthorizeDeviceRequest,
        AuthorizeDeviceResponse,
        CreateProfileRequest,
        ProfileResponse,
        ListProfilesRequest,
        ListProfilesResponse,
        DeleteProfileRequest,
        DeleteProfileResponse,
        UpdateProfileRequest,
        SetProfilePreferencesRequest;

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
}
