// This is a generated file - do not edit.
//
// Generated from auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'auth.pb.dart' as $0;

export 'auth.pb.dart';

@$pb.GrpcServiceName('mycelium.AuthService')
class AuthServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AuthServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.AuthorizeDeviceResponse> authorizeDevice(
    $0.AuthorizeDeviceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$authorizeDevice, request, options: options);
  }

  $grpc.ResponseFuture<$0.ProfileResponse> createProfile(
    $0.CreateProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createProfile, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListProfilesResponse> listProfiles(
    $0.ListProfilesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listProfiles, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteProfileResponse> deleteProfile(
    $0.DeleteProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteProfile, request, options: options);
  }

  $grpc.ResponseFuture<$0.ProfileResponse> updateProfile(
    $0.UpdateProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateProfile, request, options: options);
  }

  $grpc.ResponseFuture<$0.ProfileResponse> setProfilePreferences(
    $0.SetProfilePreferencesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setProfilePreferences, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthorizeDeviceResponse> refreshToken(
    $0.RefreshTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$refreshToken, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListDevicesResponse> listDevices(
    $0.ListDevicesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listDevices, request, options: options);
  }

  $grpc.ResponseFuture<$0.RenameDeviceResponse> renameDevice(
    $0.RenameDeviceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$renameDevice, request, options: options);
  }

  // method descriptors

  static final _$authorizeDevice =
      $grpc.ClientMethod<$0.AuthorizeDeviceRequest, $0.AuthorizeDeviceResponse>(
          '/mycelium.AuthService/AuthorizeDevice',
          ($0.AuthorizeDeviceRequest value) => value.writeToBuffer(),
          $0.AuthorizeDeviceResponse.fromBuffer);
  static final _$createProfile =
      $grpc.ClientMethod<$0.CreateProfileRequest, $0.ProfileResponse>(
          '/mycelium.AuthService/CreateProfile',
          ($0.CreateProfileRequest value) => value.writeToBuffer(),
          $0.ProfileResponse.fromBuffer);
  static final _$listProfiles =
      $grpc.ClientMethod<$0.ListProfilesRequest, $0.ListProfilesResponse>(
          '/mycelium.AuthService/ListProfiles',
          ($0.ListProfilesRequest value) => value.writeToBuffer(),
          $0.ListProfilesResponse.fromBuffer);
  static final _$deleteProfile =
      $grpc.ClientMethod<$0.DeleteProfileRequest, $0.DeleteProfileResponse>(
          '/mycelium.AuthService/DeleteProfile',
          ($0.DeleteProfileRequest value) => value.writeToBuffer(),
          $0.DeleteProfileResponse.fromBuffer);
  static final _$updateProfile =
      $grpc.ClientMethod<$0.UpdateProfileRequest, $0.ProfileResponse>(
          '/mycelium.AuthService/UpdateProfile',
          ($0.UpdateProfileRequest value) => value.writeToBuffer(),
          $0.ProfileResponse.fromBuffer);
  static final _$setProfilePreferences =
      $grpc.ClientMethod<$0.SetProfilePreferencesRequest, $0.ProfileResponse>(
          '/mycelium.AuthService/SetProfilePreferences',
          ($0.SetProfilePreferencesRequest value) => value.writeToBuffer(),
          $0.ProfileResponse.fromBuffer);
  static final _$refreshToken =
      $grpc.ClientMethod<$0.RefreshTokenRequest, $0.AuthorizeDeviceResponse>(
          '/mycelium.AuthService/RefreshToken',
          ($0.RefreshTokenRequest value) => value.writeToBuffer(),
          $0.AuthorizeDeviceResponse.fromBuffer);
  static final _$listDevices =
      $grpc.ClientMethod<$0.ListDevicesRequest, $0.ListDevicesResponse>(
          '/mycelium.AuthService/ListDevices',
          ($0.ListDevicesRequest value) => value.writeToBuffer(),
          $0.ListDevicesResponse.fromBuffer);
  static final _$renameDevice =
      $grpc.ClientMethod<$0.RenameDeviceRequest, $0.RenameDeviceResponse>(
          '/mycelium.AuthService/RenameDevice',
          ($0.RenameDeviceRequest value) => value.writeToBuffer(),
          $0.RenameDeviceResponse.fromBuffer);
}

@$pb.GrpcServiceName('mycelium.AuthService')
abstract class AuthServiceBase extends $grpc.Service {
  $core.String get $name => 'mycelium.AuthService';

  AuthServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.AuthorizeDeviceRequest,
            $0.AuthorizeDeviceResponse>(
        'AuthorizeDevice',
        authorizeDevice_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AuthorizeDeviceRequest.fromBuffer(value),
        ($0.AuthorizeDeviceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateProfileRequest, $0.ProfileResponse>(
        'CreateProfile',
        createProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateProfileRequest.fromBuffer(value),
        ($0.ProfileResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListProfilesRequest, $0.ListProfilesResponse>(
            'ListProfiles',
            listProfiles_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListProfilesRequest.fromBuffer(value),
            ($0.ListProfilesResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeleteProfileRequest, $0.DeleteProfileResponse>(
            'DeleteProfile',
            deleteProfile_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeleteProfileRequest.fromBuffer(value),
            ($0.DeleteProfileResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateProfileRequest, $0.ProfileResponse>(
        'UpdateProfile',
        updateProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateProfileRequest.fromBuffer(value),
        ($0.ProfileResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetProfilePreferencesRequest,
            $0.ProfileResponse>(
        'SetProfilePreferences',
        setProfilePreferences_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SetProfilePreferencesRequest.fromBuffer(value),
        ($0.ProfileResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RefreshTokenRequest, $0.AuthorizeDeviceResponse>(
            'RefreshToken',
            refreshToken_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RefreshTokenRequest.fromBuffer(value),
            ($0.AuthorizeDeviceResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListDevicesRequest, $0.ListDevicesResponse>(
            'ListDevices',
            listDevices_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListDevicesRequest.fromBuffer(value),
            ($0.ListDevicesResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RenameDeviceRequest, $0.RenameDeviceResponse>(
            'RenameDevice',
            renameDevice_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RenameDeviceRequest.fromBuffer(value),
            ($0.RenameDeviceResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.AuthorizeDeviceResponse> authorizeDevice_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AuthorizeDeviceRequest> $request) async {
    return authorizeDevice($call, await $request);
  }

  $async.Future<$0.AuthorizeDeviceResponse> authorizeDevice(
      $grpc.ServiceCall call, $0.AuthorizeDeviceRequest request);

  $async.Future<$0.ProfileResponse> createProfile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateProfileRequest> $request) async {
    return createProfile($call, await $request);
  }

  $async.Future<$0.ProfileResponse> createProfile(
      $grpc.ServiceCall call, $0.CreateProfileRequest request);

  $async.Future<$0.ListProfilesResponse> listProfiles_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListProfilesRequest> $request) async {
    return listProfiles($call, await $request);
  }

  $async.Future<$0.ListProfilesResponse> listProfiles(
      $grpc.ServiceCall call, $0.ListProfilesRequest request);

  $async.Future<$0.DeleteProfileResponse> deleteProfile_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteProfileRequest> $request) async {
    return deleteProfile($call, await $request);
  }

  $async.Future<$0.DeleteProfileResponse> deleteProfile(
      $grpc.ServiceCall call, $0.DeleteProfileRequest request);

  $async.Future<$0.ProfileResponse> updateProfile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateProfileRequest> $request) async {
    return updateProfile($call, await $request);
  }

  $async.Future<$0.ProfileResponse> updateProfile(
      $grpc.ServiceCall call, $0.UpdateProfileRequest request);

  $async.Future<$0.ProfileResponse> setProfilePreferences_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SetProfilePreferencesRequest> $request) async {
    return setProfilePreferences($call, await $request);
  }

  $async.Future<$0.ProfileResponse> setProfilePreferences(
      $grpc.ServiceCall call, $0.SetProfilePreferencesRequest request);

  $async.Future<$0.AuthorizeDeviceResponse> refreshToken_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RefreshTokenRequest> $request) async {
    return refreshToken($call, await $request);
  }

  $async.Future<$0.AuthorizeDeviceResponse> refreshToken(
      $grpc.ServiceCall call, $0.RefreshTokenRequest request);

  $async.Future<$0.ListDevicesResponse> listDevices_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListDevicesRequest> $request) async {
    return listDevices($call, await $request);
  }

  $async.Future<$0.ListDevicesResponse> listDevices(
      $grpc.ServiceCall call, $0.ListDevicesRequest request);

  $async.Future<$0.RenameDeviceResponse> renameDevice_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RenameDeviceRequest> $request) async {
    return renameDevice($call, await $request);
  }

  $async.Future<$0.RenameDeviceResponse> renameDevice(
      $grpc.ServiceCall call, $0.RenameDeviceRequest request);
}
