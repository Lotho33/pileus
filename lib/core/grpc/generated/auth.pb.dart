// This is a generated file - do not edit.
//
// Generated from auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class AuthorizeDeviceRequest extends $pb.GeneratedMessage {
  factory AuthorizeDeviceRequest({
    $core.String? deviceId,
    $core.String? pinHash,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (pinHash != null) result.pinHash = pinHash;
    return result;
  }

  AuthorizeDeviceRequest._();

  factory AuthorizeDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AuthorizeDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuthorizeDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'pinHash')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthorizeDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthorizeDeviceRequest copyWith(
          void Function(AuthorizeDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as AuthorizeDeviceRequest))
          as AuthorizeDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AuthorizeDeviceRequest create() => AuthorizeDeviceRequest._();
  @$core.override
  AuthorizeDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AuthorizeDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuthorizeDeviceRequest>(create);
  static AuthorizeDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pinHash => $_getSZ(1);
  @$pb.TagNumber(2)
  set pinHash($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPinHash() => $_has(1);
  @$pb.TagNumber(2)
  void clearPinHash() => $_clearField(2);
}

class AuthorizeDeviceResponse extends $pb.GeneratedMessage {
  factory AuthorizeDeviceResponse({
    $core.String? deviceJwt,
    $fixnum.Int64? expiresAt,
  }) {
    final result = create();
    if (deviceJwt != null) result.deviceJwt = deviceJwt;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  AuthorizeDeviceResponse._();

  factory AuthorizeDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AuthorizeDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuthorizeDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceJwt')
    ..aInt64(2, _omitFieldNames ? '' : 'expiresAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthorizeDeviceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthorizeDeviceResponse copyWith(
          void Function(AuthorizeDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as AuthorizeDeviceResponse))
          as AuthorizeDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AuthorizeDeviceResponse create() => AuthorizeDeviceResponse._();
  @$core.override
  AuthorizeDeviceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AuthorizeDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuthorizeDeviceResponse>(create);
  static AuthorizeDeviceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceJwt => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceJwt($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceJwt() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceJwt() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiresAt => $_getI64(1);
  @$pb.TagNumber(2)
  set expiresAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiresAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresAt() => $_clearField(2);
}

class CreateProfileRequest extends $pb.GeneratedMessage {
  factory CreateProfileRequest({
    $core.String? name,
    $core.String? avatarUrl,
    $core.String? preferencesJson,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (preferencesJson != null) result.preferencesJson = preferencesJson;
    return result;
  }

  CreateProfileRequest._();

  factory CreateProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(5, _omitFieldNames ? '' : 'preferencesJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateProfileRequest copyWith(void Function(CreateProfileRequest) updates) =>
      super.copyWith((message) => updates(message as CreateProfileRequest))
          as CreateProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateProfileRequest create() => CreateProfileRequest._();
  @$core.override
  CreateProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateProfileRequest>(create);
  static CreateProfileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get avatarUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set avatarUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAvatarUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearAvatarUrl() => $_clearField(2);

  /// Opaque JSON blob of person-scoped client preferences (subtitle
  /// appearance). Optional; server stores "{}" when empty.
  @$pb.TagNumber(5)
  $core.String get preferencesJson => $_getSZ(2);
  @$pb.TagNumber(5)
  set preferencesJson($core.String value) => $_setString(2, value);
  @$pb.TagNumber(5)
  $core.bool hasPreferencesJson() => $_has(2);
  @$pb.TagNumber(5)
  void clearPreferencesJson() => $_clearField(5);
}

class ProfileResponse extends $pb.GeneratedMessage {
  factory ProfileResponse({
    $core.String? profileId,
    $core.String? name,
    $core.String? avatarUrl,
    $core.String? preferencesJson,
    $core.bool? pinProtected,
    $core.bool? unlocked,
    $core.bool? deviceTrusted,
  }) {
    final result = create();
    if (profileId != null) result.profileId = profileId;
    if (name != null) result.name = name;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (preferencesJson != null) result.preferencesJson = preferencesJson;
    if (pinProtected != null) result.pinProtected = pinProtected;
    if (unlocked != null) result.unlocked = unlocked;
    if (deviceTrusted != null) result.deviceTrusted = deviceTrusted;
    return result;
  }

  ProfileResponse._();

  factory ProfileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProfileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProfileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'profileId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(6, _omitFieldNames ? '' : 'preferencesJson')
    ..aOB(7, _omitFieldNames ? '' : 'pinProtected')
    ..aOB(8, _omitFieldNames ? '' : 'unlocked')
    ..aOB(9, _omitFieldNames ? '' : 'deviceTrusted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileResponse copyWith(void Function(ProfileResponse) updates) =>
      super.copyWith((message) => updates(message as ProfileResponse))
          as ProfileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileResponse create() => ProfileResponse._();
  @$core.override
  ProfileResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProfileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProfileResponse>(create);
  static ProfileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get profileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set profileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProfileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get avatarUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set avatarUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAvatarUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatarUrl() => $_clearField(3);

  /// Opaque JSON blob of person-scoped client preferences. The client owns
  /// the schema; the server only stores and echoes it. Profiles are
  /// server-wide, so this follows the person across every paired device.
  @$pb.TagNumber(6)
  $core.String get preferencesJson => $_getSZ(3);
  @$pb.TagNumber(6)
  set preferencesJson($core.String value) => $_setString(3, value);
  @$pb.TagNumber(6)
  $core.bool hasPreferencesJson() => $_has(3);
  @$pb.TagNumber(6)
  void clearPreferencesJson() => $_clearField(6);

  /// Profile access PIN (a new feature: NOT the removed parental PIN, whose
  /// field 5 stays reserved). The three flags below are computed for the
  /// calling device, so the client knows whether to ask for the PIN.
  @$pb.TagNumber(7)
  $core.bool get pinProtected => $_getBF(4);
  @$pb.TagNumber(7)
  set pinProtected($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(7)
  $core.bool hasPinProtected() => $_has(4);
  @$pb.TagNumber(7)
  void clearPinProtected() => $_clearField(7);

  /// The caller may use this profile right now: no PIN, device trusted, or a
  /// valid session token for it sent as "x-profile-session".
  @$pb.TagNumber(8)
  $core.bool get unlocked => $_getBF(5);
  @$pb.TagNumber(8)
  set unlocked($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(8)
  $core.bool hasUnlocked() => $_has(5);
  @$pb.TagNumber(8)
  void clearUnlocked() => $_clearField(8);

  /// The calling device holds persistent trust for this profile (PIN entered
  /// with remember_device) — lets the client offer "forget this device".
  @$pb.TagNumber(9)
  $core.bool get deviceTrusted => $_getBF(6);
  @$pb.TagNumber(9)
  set deviceTrusted($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(9)
  $core.bool hasDeviceTrusted() => $_has(6);
  @$pb.TagNumber(9)
  void clearDeviceTrusted() => $_clearField(9);
}

class ListProfilesRequest extends $pb.GeneratedMessage {
  factory ListProfilesRequest() => create();

  ListProfilesRequest._();

  factory ListProfilesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListProfilesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListProfilesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProfilesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProfilesRequest copyWith(void Function(ListProfilesRequest) updates) =>
      super.copyWith((message) => updates(message as ListProfilesRequest))
          as ListProfilesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListProfilesRequest create() => ListProfilesRequest._();
  @$core.override
  ListProfilesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListProfilesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListProfilesRequest>(create);
  static ListProfilesRequest? _defaultInstance;
}

class ListProfilesResponse extends $pb.GeneratedMessage {
  factory ListProfilesResponse({
    $core.Iterable<ProfileResponse>? profiles,
  }) {
    final result = create();
    if (profiles != null) result.profiles.addAll(profiles);
    return result;
  }

  ListProfilesResponse._();

  factory ListProfilesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListProfilesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListProfilesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<ProfileResponse>(1, _omitFieldNames ? '' : 'profiles',
        subBuilder: ProfileResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProfilesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProfilesResponse copyWith(void Function(ListProfilesResponse) updates) =>
      super.copyWith((message) => updates(message as ListProfilesResponse))
          as ListProfilesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListProfilesResponse create() => ListProfilesResponse._();
  @$core.override
  ListProfilesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListProfilesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListProfilesResponse>(create);
  static ListProfilesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ProfileResponse> get profiles => $_getList(0);
}

class DeleteProfileRequest extends $pb.GeneratedMessage {
  factory DeleteProfileRequest({
    $core.String? profileId,
  }) {
    final result = create();
    if (profileId != null) result.profileId = profileId;
    return result;
  }

  DeleteProfileRequest._();

  factory DeleteProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'profileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProfileRequest copyWith(void Function(DeleteProfileRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteProfileRequest))
          as DeleteProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteProfileRequest create() => DeleteProfileRequest._();
  @$core.override
  DeleteProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProfileRequest>(create);
  static DeleteProfileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get profileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set profileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProfileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileId() => $_clearField(1);
}

class DeleteProfileResponse extends $pb.GeneratedMessage {
  factory DeleteProfileResponse({
    $core.bool? ok,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  DeleteProfileResponse._();

  factory DeleteProfileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteProfileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProfileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProfileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProfileResponse copyWith(
          void Function(DeleteProfileResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteProfileResponse))
          as DeleteProfileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteProfileResponse create() => DeleteProfileResponse._();
  @$core.override
  DeleteProfileResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteProfileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProfileResponse>(create);
  static DeleteProfileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

class UpdateProfileRequest extends $pb.GeneratedMessage {
  factory UpdateProfileRequest({
    $core.String? profileId,
    $core.String? name,
    $core.String? avatarUrl,
  }) {
    final result = create();
    if (profileId != null) result.profileId = profileId;
    if (name != null) result.name = name;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    return result;
  }

  UpdateProfileRequest._();

  factory UpdateProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'profileId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'avatarUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProfileRequest copyWith(void Function(UpdateProfileRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateProfileRequest))
          as UpdateProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateProfileRequest create() => UpdateProfileRequest._();
  @$core.override
  UpdateProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateProfileRequest>(create);
  static UpdateProfileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get profileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set profileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProfileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get avatarUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set avatarUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAvatarUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatarUrl() => $_clearField(3);
}

/// SetProfilePreferences replaces only the preferences blob — a separate call
/// so the client doesn't have to round-trip name/avatar just to save a
/// subtitle setting. preferences_json is stored verbatim ("{}" to clear).
class SetProfilePreferencesRequest extends $pb.GeneratedMessage {
  factory SetProfilePreferencesRequest({
    $core.String? profileId,
    $core.String? preferencesJson,
  }) {
    final result = create();
    if (profileId != null) result.profileId = profileId;
    if (preferencesJson != null) result.preferencesJson = preferencesJson;
    return result;
  }

  SetProfilePreferencesRequest._();

  factory SetProfilePreferencesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetProfilePreferencesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetProfilePreferencesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'profileId')
    ..aOS(2, _omitFieldNames ? '' : 'preferencesJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetProfilePreferencesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetProfilePreferencesRequest copyWith(
          void Function(SetProfilePreferencesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SetProfilePreferencesRequest))
          as SetProfilePreferencesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetProfilePreferencesRequest create() =>
      SetProfilePreferencesRequest._();
  @$core.override
  SetProfilePreferencesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetProfilePreferencesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetProfilePreferencesRequest>(create);
  static SetProfilePreferencesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get profileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set profileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProfileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get preferencesJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set preferencesJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPreferencesJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearPreferencesJson() => $_clearField(2);
}

class RefreshTokenRequest extends $pb.GeneratedMessage {
  factory RefreshTokenRequest() => create();

  RefreshTokenRequest._();

  factory RefreshTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefreshTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshTokenRequest copyWith(void Function(RefreshTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RefreshTokenRequest))
          as RefreshTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefreshTokenRequest create() => RefreshTokenRequest._();
  @$core.override
  RefreshTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RefreshTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshTokenRequest>(create);
  static RefreshTokenRequest? _defaultInstance;
}

class DeviceInfo extends $pb.GeneratedMessage {
  factory DeviceInfo({
    $core.String? deviceId,
    $core.String? label,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? lastSeenAt,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (label != null) result.label = label;
    if (createdAt != null) result.createdAt = createdAt;
    if (lastSeenAt != null) result.lastSeenAt = lastSeenAt;
    return result;
  }

  DeviceInfo._();

  factory DeviceInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aInt64(3, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(4, _omitFieldNames ? '' : 'lastSeenAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceInfo copyWith(void Function(DeviceInfo) updates) =>
      super.copyWith((message) => updates(message as DeviceInfo)) as DeviceInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceInfo create() => DeviceInfo._();
  @$core.override
  DeviceInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceInfo>(create);
  static DeviceInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get createdAt => $_getI64(2);
  @$pb.TagNumber(3)
  set createdAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get lastSeenAt => $_getI64(3);
  @$pb.TagNumber(4)
  set lastSeenAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastSeenAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastSeenAt() => $_clearField(4);
}

class ListDevicesRequest extends $pb.GeneratedMessage {
  factory ListDevicesRequest() => create();

  ListDevicesRequest._();

  factory ListDevicesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListDevicesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDevicesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDevicesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDevicesRequest copyWith(void Function(ListDevicesRequest) updates) =>
      super.copyWith((message) => updates(message as ListDevicesRequest))
          as ListDevicesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDevicesRequest create() => ListDevicesRequest._();
  @$core.override
  ListDevicesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListDevicesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDevicesRequest>(create);
  static ListDevicesRequest? _defaultInstance;
}

class ListDevicesResponse extends $pb.GeneratedMessage {
  factory ListDevicesResponse({
    $core.Iterable<DeviceInfo>? devices,
  }) {
    final result = create();
    if (devices != null) result.devices.addAll(devices);
    return result;
  }

  ListDevicesResponse._();

  factory ListDevicesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListDevicesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDevicesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<DeviceInfo>(1, _omitFieldNames ? '' : 'devices',
        subBuilder: DeviceInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDevicesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDevicesResponse copyWith(void Function(ListDevicesResponse) updates) =>
      super.copyWith((message) => updates(message as ListDevicesResponse))
          as ListDevicesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDevicesResponse create() => ListDevicesResponse._();
  @$core.override
  ListDevicesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListDevicesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDevicesResponse>(create);
  static ListDevicesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DeviceInfo> get devices => $_getList(0);
}

class RenameDeviceRequest extends $pb.GeneratedMessage {
  factory RenameDeviceRequest({
    $core.String? deviceId,
    $core.String? label,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (label != null) result.label = label;
    return result;
  }

  RenameDeviceRequest._();

  factory RenameDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RenameDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameDeviceRequest copyWith(void Function(RenameDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RenameDeviceRequest))
          as RenameDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenameDeviceRequest create() => RenameDeviceRequest._();
  @$core.override
  RenameDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RenameDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameDeviceRequest>(create);
  static RenameDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);
}

class RenameDeviceResponse extends $pb.GeneratedMessage {
  factory RenameDeviceResponse({
    $core.bool? ok,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  RenameDeviceResponse._();

  factory RenameDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RenameDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameDeviceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameDeviceResponse copyWith(void Function(RenameDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as RenameDeviceResponse))
          as RenameDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenameDeviceResponse create() => RenameDeviceResponse._();
  @$core.override
  RenameDeviceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RenameDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameDeviceResponse>(create);
  static RenameDeviceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

class UnpairSelfRequest extends $pb.GeneratedMessage {
  factory UnpairSelfRequest() => create();

  UnpairSelfRequest._();

  factory UnpairSelfRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnpairSelfRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnpairSelfRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnpairSelfRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnpairSelfRequest copyWith(void Function(UnpairSelfRequest) updates) =>
      super.copyWith((message) => updates(message as UnpairSelfRequest))
          as UnpairSelfRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnpairSelfRequest create() => UnpairSelfRequest._();
  @$core.override
  UnpairSelfRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnpairSelfRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnpairSelfRequest>(create);
  static UnpairSelfRequest? _defaultInstance;
}

class UnpairSelfResponse extends $pb.GeneratedMessage {
  factory UnpairSelfResponse({
    $core.bool? ok,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  UnpairSelfResponse._();

  factory UnpairSelfResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnpairSelfResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnpairSelfResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnpairSelfResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnpairSelfResponse copyWith(void Function(UnpairSelfResponse) updates) =>
      super.copyWith((message) => updates(message as UnpairSelfResponse))
          as UnpairSelfResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnpairSelfResponse create() => UnpairSelfResponse._();
  @$core.override
  UnpairSelfResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnpairSelfResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnpairSelfResponse>(create);
  static UnpairSelfResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

class UnlockProfileRequest extends $pb.GeneratedMessage {
  factory UnlockProfileRequest({
    $core.String? profileId,
    $core.String? pin,
    $core.bool? rememberDevice,
  }) {
    final result = create();
    if (profileId != null) result.profileId = profileId;
    if (pin != null) result.pin = pin;
    if (rememberDevice != null) result.rememberDevice = rememberDevice;
    return result;
  }

  UnlockProfileRequest._();

  factory UnlockProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnlockProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnlockProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'profileId')
    ..aOS(2, _omitFieldNames ? '' : 'pin')
    ..aOB(3, _omitFieldNames ? '' : 'rememberDevice')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlockProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlockProfileRequest copyWith(void Function(UnlockProfileRequest) updates) =>
      super.copyWith((message) => updates(message as UnlockProfileRequest))
          as UnlockProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnlockProfileRequest create() => UnlockProfileRequest._();
  @$core.override
  UnlockProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnlockProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnlockProfileRequest>(create);
  static UnlockProfileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get profileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set profileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProfileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pin => $_getSZ(1);
  @$pb.TagNumber(2)
  set pin($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPin() => $_has(1);
  @$pb.TagNumber(2)
  void clearPin() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get rememberDevice => $_getBF(2);
  @$pb.TagNumber(3)
  set rememberDevice($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRememberDevice() => $_has(2);
  @$pb.TagNumber(3)
  void clearRememberDevice() => $_clearField(3);
}

class UnlockProfileResponse extends $pb.GeneratedMessage {
  factory UnlockProfileResponse({
    $core.bool? ok,
    $core.String? sessionToken,
    $fixnum.Int64? sessionExpiresAt,
    $core.bool? deviceTrusted,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (sessionExpiresAt != null) result.sessionExpiresAt = sessionExpiresAt;
    if (deviceTrusted != null) result.deviceTrusted = deviceTrusted;
    return result;
  }

  UnlockProfileResponse._();

  factory UnlockProfileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnlockProfileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnlockProfileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..aOS(2, _omitFieldNames ? '' : 'sessionToken')
    ..aInt64(3, _omitFieldNames ? '' : 'sessionExpiresAt')
    ..aOB(4, _omitFieldNames ? '' : 'deviceTrusted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlockProfileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlockProfileResponse copyWith(
          void Function(UnlockProfileResponse) updates) =>
      super.copyWith((message) => updates(message as UnlockProfileResponse))
          as UnlockProfileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnlockProfileResponse create() => UnlockProfileResponse._();
  @$core.override
  UnlockProfileResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnlockProfileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnlockProfileResponse>(create);
  static UnlockProfileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);

  /// Set only for a one-off session (remember_device=false on a protected
  /// profile). Send it as "x-profile-session" with every call for this profile.
  @$pb.TagNumber(2)
  $core.String get sessionToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sessionExpiresAt => $_getI64(2);
  @$pb.TagNumber(3)
  set sessionExpiresAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionExpiresAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionExpiresAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get deviceTrusted => $_getBF(3);
  @$pb.TagNumber(4)
  set deviceTrusted($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeviceTrusted() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceTrusted() => $_clearField(4);
}

class LockProfileRequest extends $pb.GeneratedMessage {
  factory LockProfileRequest({
    $core.String? profileId,
    $core.bool? forgetDevice,
  }) {
    final result = create();
    if (profileId != null) result.profileId = profileId;
    if (forgetDevice != null) result.forgetDevice = forgetDevice;
    return result;
  }

  LockProfileRequest._();

  factory LockProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LockProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LockProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'profileId')
    ..aOB(2, _omitFieldNames ? '' : 'forgetDevice')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LockProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LockProfileRequest copyWith(void Function(LockProfileRequest) updates) =>
      super.copyWith((message) => updates(message as LockProfileRequest))
          as LockProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LockProfileRequest create() => LockProfileRequest._();
  @$core.override
  LockProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LockProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LockProfileRequest>(create);
  static LockProfileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get profileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set profileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProfileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get forgetDevice => $_getBF(1);
  @$pb.TagNumber(2)
  set forgetDevice($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasForgetDevice() => $_has(1);
  @$pb.TagNumber(2)
  void clearForgetDevice() => $_clearField(2);
}

class LockProfileResponse extends $pb.GeneratedMessage {
  factory LockProfileResponse({
    $core.bool? ok,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  LockProfileResponse._();

  factory LockProfileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LockProfileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LockProfileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LockProfileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LockProfileResponse copyWith(void Function(LockProfileResponse) updates) =>
      super.copyWith((message) => updates(message as LockProfileResponse))
          as LockProfileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LockProfileResponse create() => LockProfileResponse._();
  @$core.override
  LockProfileResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LockProfileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LockProfileResponse>(create);
  static LockProfileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

class SetProfilePinRequest extends $pb.GeneratedMessage {
  factory SetProfilePinRequest({
    $core.String? profileId,
    $core.String? currentPin,
    $core.String? newPin,
  }) {
    final result = create();
    if (profileId != null) result.profileId = profileId;
    if (currentPin != null) result.currentPin = currentPin;
    if (newPin != null) result.newPin = newPin;
    return result;
  }

  SetProfilePinRequest._();

  factory SetProfilePinRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetProfilePinRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetProfilePinRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'profileId')
    ..aOS(2, _omitFieldNames ? '' : 'currentPin')
    ..aOS(3, _omitFieldNames ? '' : 'newPin')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetProfilePinRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetProfilePinRequest copyWith(void Function(SetProfilePinRequest) updates) =>
      super.copyWith((message) => updates(message as SetProfilePinRequest))
          as SetProfilePinRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetProfilePinRequest create() => SetProfilePinRequest._();
  @$core.override
  SetProfilePinRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetProfilePinRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetProfilePinRequest>(create);
  static SetProfilePinRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get profileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set profileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProfileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get currentPin => $_getSZ(1);
  @$pb.TagNumber(2)
  set currentPin($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCurrentPin() => $_has(1);
  @$pb.TagNumber(2)
  void clearCurrentPin() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get newPin => $_getSZ(2);
  @$pb.TagNumber(3)
  set newPin($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewPin() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewPin() => $_clearField(3);
}

class SetProfilePinResponse extends $pb.GeneratedMessage {
  factory SetProfilePinResponse({
    $core.bool? ok,
    $core.bool? pinProtected,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    if (pinProtected != null) result.pinProtected = pinProtected;
    return result;
  }

  SetProfilePinResponse._();

  factory SetProfilePinResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetProfilePinResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetProfilePinResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..aOB(2, _omitFieldNames ? '' : 'pinProtected')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetProfilePinResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetProfilePinResponse copyWith(
          void Function(SetProfilePinResponse) updates) =>
      super.copyWith((message) => updates(message as SetProfilePinResponse))
          as SetProfilePinResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetProfilePinResponse create() => SetProfilePinResponse._();
  @$core.override
  SetProfilePinResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetProfilePinResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetProfilePinResponse>(create);
  static SetProfilePinResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get pinProtected => $_getBF(1);
  @$pb.TagNumber(2)
  set pinProtected($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPinProtected() => $_has(1);
  @$pb.TagNumber(2)
  void clearPinProtected() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
