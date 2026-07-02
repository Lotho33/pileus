// This is a generated file - do not edit.
//
// Generated from media.proto.

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

import 'media.pb.dart' as $0;

export 'media.pb.dart';

@$pb.GrpcServiceName('mycelium.PluginService')
class PluginServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PluginServiceClient(super.channel, {super.options, super.interceptors});

  /// Returns user-scoped setting definitions + current values for a plugin.
  $grpc.ResponseFuture<$0.GetPluginSettingsResponse> getPluginSettings(
    $0.GetPluginSettingsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPluginSettings, request, options: options);
  }

  /// Saves or clears a single user-scoped setting.
  $grpc.ResponseFuture<$0.SavePluginSettingResponse> savePluginSetting(
    $0.SavePluginSettingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$savePluginSetting, request, options: options);
  }

  /// Manually triggers a plugin's live_refresh task(s) on demand.
  $grpc.ResponseFuture<$0.TriggerRefreshResponse> triggerRefresh(
    $0.TriggerRefreshRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$triggerRefresh, request, options: options);
  }

  // method descriptors

  static final _$getPluginSettings = $grpc.ClientMethod<
          $0.GetPluginSettingsRequest, $0.GetPluginSettingsResponse>(
      '/mycelium.PluginService/GetPluginSettings',
      ($0.GetPluginSettingsRequest value) => value.writeToBuffer(),
      $0.GetPluginSettingsResponse.fromBuffer);
  static final _$savePluginSetting = $grpc.ClientMethod<
          $0.SavePluginSettingRequest, $0.SavePluginSettingResponse>(
      '/mycelium.PluginService/SavePluginSetting',
      ($0.SavePluginSettingRequest value) => value.writeToBuffer(),
      $0.SavePluginSettingResponse.fromBuffer);
  static final _$triggerRefresh =
      $grpc.ClientMethod<$0.TriggerRefreshRequest, $0.TriggerRefreshResponse>(
          '/mycelium.PluginService/TriggerRefresh',
          ($0.TriggerRefreshRequest value) => value.writeToBuffer(),
          $0.TriggerRefreshResponse.fromBuffer);
}

@$pb.GrpcServiceName('mycelium.PluginService')
abstract class PluginServiceBase extends $grpc.Service {
  $core.String get $name => 'mycelium.PluginService';

  PluginServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetPluginSettingsRequest,
            $0.GetPluginSettingsResponse>(
        'GetPluginSettings',
        getPluginSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPluginSettingsRequest.fromBuffer(value),
        ($0.GetPluginSettingsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SavePluginSettingRequest,
            $0.SavePluginSettingResponse>(
        'SavePluginSetting',
        savePluginSetting_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SavePluginSettingRequest.fromBuffer(value),
        ($0.SavePluginSettingResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TriggerRefreshRequest,
            $0.TriggerRefreshResponse>(
        'TriggerRefresh',
        triggerRefresh_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.TriggerRefreshRequest.fromBuffer(value),
        ($0.TriggerRefreshResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetPluginSettingsResponse> getPluginSettings_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetPluginSettingsRequest> $request) async {
    return getPluginSettings($call, await $request);
  }

  $async.Future<$0.GetPluginSettingsResponse> getPluginSettings(
      $grpc.ServiceCall call, $0.GetPluginSettingsRequest request);

  $async.Future<$0.SavePluginSettingResponse> savePluginSetting_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SavePluginSettingRequest> $request) async {
    return savePluginSetting($call, await $request);
  }

  $async.Future<$0.SavePluginSettingResponse> savePluginSetting(
      $grpc.ServiceCall call, $0.SavePluginSettingRequest request);

  $async.Future<$0.TriggerRefreshResponse> triggerRefresh_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.TriggerRefreshRequest> $request) async {
    return triggerRefresh($call, await $request);
  }

  $async.Future<$0.TriggerRefreshResponse> triggerRefresh(
      $grpc.ServiceCall call, $0.TriggerRefreshRequest request);
}

@$pb.GrpcServiceName('mycelium.MediaPipeline')
class MediaPipelineClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  MediaPipelineClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CatalogResponse> getCatalog(
    $0.CatalogRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCatalog, request, options: options);
  }

  $grpc.ResponseFuture<$0.SearchFiltersResponse> getSearchFilters(
    $0.SearchFiltersRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSearchFilters, request, options: options);
  }

  $grpc.ResponseFuture<$0.SearchResponse> search(
    $0.SearchRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$search, request, options: options);
  }

  $grpc.ResponseFuture<$0.DetailsResponse> getDetails(
    $0.DetailsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getDetails, request, options: options);
  }

  $grpc.ResponseFuture<$0.BrowseResponse> browse(
    $0.BrowseRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$browse, request, options: options);
  }

  $grpc.ResponseFuture<$0.StreamsResponse> getStreams(
    $0.StreamsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStreams, request, options: options);
  }

  $grpc.ResponseStream<$0.ResolveStreamEvent> resolveStream(
    $0.ResolveRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$resolveStream, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.ProgressResponse> updateProgress(
    $0.ProgressRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateProgress, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteProgressResponse> deleteProgress(
    $0.DeleteProgressRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteProgress, request, options: options);
  }

  $grpc.ResponseFuture<$0.ContinueWatchingResponse> getContinueWatching(
    $0.ContinueWatchingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getContinueWatching, request, options: options);
  }

  $grpc.ResponseFuture<$0.PluginListResponse> listPlugins(
    $0.PluginListRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPlugins, request, options: options);
  }

  // method descriptors

  static final _$getCatalog =
      $grpc.ClientMethod<$0.CatalogRequest, $0.CatalogResponse>(
          '/mycelium.MediaPipeline/GetCatalog',
          ($0.CatalogRequest value) => value.writeToBuffer(),
          $0.CatalogResponse.fromBuffer);
  static final _$getSearchFilters =
      $grpc.ClientMethod<$0.SearchFiltersRequest, $0.SearchFiltersResponse>(
          '/mycelium.MediaPipeline/GetSearchFilters',
          ($0.SearchFiltersRequest value) => value.writeToBuffer(),
          $0.SearchFiltersResponse.fromBuffer);
  static final _$search =
      $grpc.ClientMethod<$0.SearchRequest, $0.SearchResponse>(
          '/mycelium.MediaPipeline/Search',
          ($0.SearchRequest value) => value.writeToBuffer(),
          $0.SearchResponse.fromBuffer);
  static final _$getDetails =
      $grpc.ClientMethod<$0.DetailsRequest, $0.DetailsResponse>(
          '/mycelium.MediaPipeline/GetDetails',
          ($0.DetailsRequest value) => value.writeToBuffer(),
          $0.DetailsResponse.fromBuffer);
  static final _$browse =
      $grpc.ClientMethod<$0.BrowseRequest, $0.BrowseResponse>(
          '/mycelium.MediaPipeline/Browse',
          ($0.BrowseRequest value) => value.writeToBuffer(),
          $0.BrowseResponse.fromBuffer);
  static final _$getStreams =
      $grpc.ClientMethod<$0.StreamsRequest, $0.StreamsResponse>(
          '/mycelium.MediaPipeline/GetStreams',
          ($0.StreamsRequest value) => value.writeToBuffer(),
          $0.StreamsResponse.fromBuffer);
  static final _$resolveStream =
      $grpc.ClientMethod<$0.ResolveRequest, $0.ResolveStreamEvent>(
          '/mycelium.MediaPipeline/ResolveStream',
          ($0.ResolveRequest value) => value.writeToBuffer(),
          $0.ResolveStreamEvent.fromBuffer);
  static final _$updateProgress =
      $grpc.ClientMethod<$0.ProgressRequest, $0.ProgressResponse>(
          '/mycelium.MediaPipeline/UpdateProgress',
          ($0.ProgressRequest value) => value.writeToBuffer(),
          $0.ProgressResponse.fromBuffer);
  static final _$deleteProgress =
      $grpc.ClientMethod<$0.DeleteProgressRequest, $0.DeleteProgressResponse>(
          '/mycelium.MediaPipeline/DeleteProgress',
          ($0.DeleteProgressRequest value) => value.writeToBuffer(),
          $0.DeleteProgressResponse.fromBuffer);
  static final _$getContinueWatching = $grpc.ClientMethod<
          $0.ContinueWatchingRequest, $0.ContinueWatchingResponse>(
      '/mycelium.MediaPipeline/GetContinueWatching',
      ($0.ContinueWatchingRequest value) => value.writeToBuffer(),
      $0.ContinueWatchingResponse.fromBuffer);
  static final _$listPlugins =
      $grpc.ClientMethod<$0.PluginListRequest, $0.PluginListResponse>(
          '/mycelium.MediaPipeline/ListPlugins',
          ($0.PluginListRequest value) => value.writeToBuffer(),
          $0.PluginListResponse.fromBuffer);
}

@$pb.GrpcServiceName('mycelium.MediaPipeline')
abstract class MediaPipelineServiceBase extends $grpc.Service {
  $core.String get $name => 'mycelium.MediaPipeline';

  MediaPipelineServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CatalogRequest, $0.CatalogResponse>(
        'GetCatalog',
        getCatalog_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CatalogRequest.fromBuffer(value),
        ($0.CatalogResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SearchFiltersRequest, $0.SearchFiltersResponse>(
            'GetSearchFilters',
            getSearchFilters_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SearchFiltersRequest.fromBuffer(value),
            ($0.SearchFiltersResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SearchRequest, $0.SearchResponse>(
        'Search',
        search_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SearchRequest.fromBuffer(value),
        ($0.SearchResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DetailsRequest, $0.DetailsResponse>(
        'GetDetails',
        getDetails_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DetailsRequest.fromBuffer(value),
        ($0.DetailsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BrowseRequest, $0.BrowseResponse>(
        'Browse',
        browse_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BrowseRequest.fromBuffer(value),
        ($0.BrowseResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.StreamsRequest, $0.StreamsResponse>(
        'GetStreams',
        getStreams_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.StreamsRequest.fromBuffer(value),
        ($0.StreamsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ResolveRequest, $0.ResolveStreamEvent>(
        'ResolveStream',
        resolveStream_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.ResolveRequest.fromBuffer(value),
        ($0.ResolveStreamEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ProgressRequest, $0.ProgressResponse>(
        'UpdateProgress',
        updateProgress_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ProgressRequest.fromBuffer(value),
        ($0.ProgressResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteProgressRequest,
            $0.DeleteProgressResponse>(
        'DeleteProgress',
        deleteProgress_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteProgressRequest.fromBuffer(value),
        ($0.DeleteProgressResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ContinueWatchingRequest,
            $0.ContinueWatchingResponse>(
        'GetContinueWatching',
        getContinueWatching_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ContinueWatchingRequest.fromBuffer(value),
        ($0.ContinueWatchingResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PluginListRequest, $0.PluginListResponse>(
        'ListPlugins',
        listPlugins_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PluginListRequest.fromBuffer(value),
        ($0.PluginListResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CatalogResponse> getCatalog_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CatalogRequest> $request) async {
    return getCatalog($call, await $request);
  }

  $async.Future<$0.CatalogResponse> getCatalog(
      $grpc.ServiceCall call, $0.CatalogRequest request);

  $async.Future<$0.SearchFiltersResponse> getSearchFilters_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SearchFiltersRequest> $request) async {
    return getSearchFilters($call, await $request);
  }

  $async.Future<$0.SearchFiltersResponse> getSearchFilters(
      $grpc.ServiceCall call, $0.SearchFiltersRequest request);

  $async.Future<$0.SearchResponse> search_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.SearchRequest> $request) async {
    return search($call, await $request);
  }

  $async.Future<$0.SearchResponse> search(
      $grpc.ServiceCall call, $0.SearchRequest request);

  $async.Future<$0.DetailsResponse> getDetails_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DetailsRequest> $request) async {
    return getDetails($call, await $request);
  }

  $async.Future<$0.DetailsResponse> getDetails(
      $grpc.ServiceCall call, $0.DetailsRequest request);

  $async.Future<$0.BrowseResponse> browse_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.BrowseRequest> $request) async {
    return browse($call, await $request);
  }

  $async.Future<$0.BrowseResponse> browse(
      $grpc.ServiceCall call, $0.BrowseRequest request);

  $async.Future<$0.StreamsResponse> getStreams_Pre($grpc.ServiceCall $call,
      $async.Future<$0.StreamsRequest> $request) async {
    return getStreams($call, await $request);
  }

  $async.Future<$0.StreamsResponse> getStreams(
      $grpc.ServiceCall call, $0.StreamsRequest request);

  $async.Stream<$0.ResolveStreamEvent> resolveStream_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ResolveRequest> $request) async* {
    yield* resolveStream($call, await $request);
  }

  $async.Stream<$0.ResolveStreamEvent> resolveStream(
      $grpc.ServiceCall call, $0.ResolveRequest request);

  $async.Future<$0.ProgressResponse> updateProgress_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ProgressRequest> $request) async {
    return updateProgress($call, await $request);
  }

  $async.Future<$0.ProgressResponse> updateProgress(
      $grpc.ServiceCall call, $0.ProgressRequest request);

  $async.Future<$0.DeleteProgressResponse> deleteProgress_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteProgressRequest> $request) async {
    return deleteProgress($call, await $request);
  }

  $async.Future<$0.DeleteProgressResponse> deleteProgress(
      $grpc.ServiceCall call, $0.DeleteProgressRequest request);

  $async.Future<$0.ContinueWatchingResponse> getContinueWatching_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ContinueWatchingRequest> $request) async {
    return getContinueWatching($call, await $request);
  }

  $async.Future<$0.ContinueWatchingResponse> getContinueWatching(
      $grpc.ServiceCall call, $0.ContinueWatchingRequest request);

  $async.Future<$0.PluginListResponse> listPlugins_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PluginListRequest> $request) async {
    return listPlugins($call, await $request);
  }

  $async.Future<$0.PluginListResponse> listPlugins(
      $grpc.ServiceCall call, $0.PluginListRequest request);
}
