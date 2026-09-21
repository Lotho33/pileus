import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:grpc/service_api.dart';

import '../auth_interceptor.dart';
import '../request_gate.dart';
import '../generated/media.pbgrpc.dart';

export '../generated/media.pbgrpc.dart'
    show
        CatalogItem,
        EpisodeInfo,
        CatalogRequest,
        CatalogResponse,
        SearchRequest,
        SearchResponse,
        SearchFilter,
        FilterOption,
        SearchFiltersRequest,
        SearchFiltersResponse,
        DetailsRequest,
        DetailsResponse,
        MovieDetails,
        SeriesDetails,
        EpisodeDetails,
        LiveDetails,
        VideoDetails,
        MusicDetails,
        PodcastDetails,
        SeasonInfo,
        BrowseRequest,
        BrowseResponse,
        StreamSource,
        StreamsRequest,
        StreamsResponse,
        ResolveRequest,
        ResolveResponse,
        ResolveProgress,
        ResolveStreamEvent,
        ProgressRequest,
        ProgressResponse,
        DeleteProgressRequest,
        DeleteProgressResponse,
        ContinueWatchingItem,
        ContinueWatchingRequest,
        ContinueWatchingResponse,
        PluginListRequest,
        PluginListResponse,
        PluginInfo,
        CatalogDef,
        PluginSettingField,
        GetPluginSettingsRequest,
        GetPluginSettingsResponse,
        SavePluginSettingRequest,
        SavePluginSettingResponse,
        TriggerRefreshRequest,
        TriggerRefreshResponse;

// Default per-RPC deadline. Without this, a slow or unresponsive plugin
// backend left the calling BLoC's *Loading state
// spinning forever — the channel's idleTimeout only bounds a connection with
// no traffic at all, not an RPC that's alive but never gets an application
// response. Previously only resolveStream was bounded, via a Future.timeout
// at the call site in playback_bloc.dart (kept as-is: it wraps a streaming
// call with its own longer-lived semantics, not a fire-and-forget unary
// call like the ones below).
const _defaultRpcTimeout = Duration(seconds: 20);

// Web only — see RequestGate. Null elsewhere: native gRPC is one multiplexed
// HTTP/2 connection with no per-origin connection cap to protect.
final RequestGate? _contentGate = kIsWeb ? RequestGate(3) : null;

Future<T> _gated<T>(String pluginId, Future<T> Function() call) =>
    _contentGate == null ? call() : _contentGate!.run(call, group: pluginId);

class MediaGrpcClient {
  late final MediaPipelineClient _mediaStub;
  late final PluginServiceClient _pluginStub;

  MediaGrpcClient(ClientChannel channel, AuthInterceptor interceptor) {
    _mediaStub = MediaPipelineClient(channel, interceptors: [interceptor]);
    _pluginStub = PluginServiceClient(channel, interceptors: [interceptor]);
  }

  Future<CatalogResponse> getCatalog(CatalogRequest request) => _gated(
      request.pluginId,
      () => _mediaStub.getCatalog(request,
          options: CallOptions(timeout: _defaultRpcTimeout)));

  Future<SearchFiltersResponse> getSearchFilters(
          SearchFiltersRequest request) =>
      _gated(
          request.pluginId,
          () => _mediaStub.getSearchFilters(request,
              options: CallOptions(timeout: _defaultRpcTimeout)));

  Future<SearchResponse> search(SearchRequest request) => _gated(
      request.pluginId,
      () => _mediaStub.search(request,
          options: CallOptions(timeout: _defaultRpcTimeout)));

  Future<DetailsResponse> getDetails(DetailsRequest request) => _gated(
      request.pluginId,
      () => _mediaStub.getDetails(request,
          options: CallOptions(timeout: _defaultRpcTimeout)));

  Future<BrowseResponse> browse(BrowseRequest request) => _gated(
      request.pluginId,
      () => _mediaStub.browse(request,
          options: CallOptions(timeout: _defaultRpcTimeout)));

  Future<StreamsResponse> getStreams(StreamsRequest request) => _mediaStub
      .getStreams(request, options: CallOptions(timeout: _defaultRpcTimeout));

  Stream<ResolveStreamEvent> resolveStream(ResolveRequest request) =>
      _mediaStub.resolveStream(request);

  Future<ProgressResponse> updateProgress(ProgressRequest request) =>
      _mediaStub.updateProgress(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<DeleteProgressResponse> deleteProgress(
          DeleteProgressRequest request) =>
      _mediaStub.deleteProgress(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<ContinueWatchingResponse> getContinueWatching(
          ContinueWatchingRequest request) =>
      _mediaStub.getContinueWatching(request,
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<PluginListResponse> listPlugins() =>
      _mediaStub.listPlugins(PluginListRequest(),
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<GetPluginSettingsResponse> getPluginSettings(
          String pluginId, String profileId) =>
      _pluginStub.getPluginSettings(
          GetPluginSettingsRequest(pluginId: pluginId, profileId: profileId),
          options: CallOptions(timeout: _defaultRpcTimeout));

  Future<SavePluginSettingResponse> savePluginSetting(
          String pluginId, String profileId, String key, String value) =>
      _pluginStub.savePluginSetting(
          SavePluginSettingRequest(
              pluginId: pluginId, profileId: profileId, key: key, value: value),
          options: CallOptions(timeout: _defaultRpcTimeout));

  // Manually kicks off a plugin's live_refresh-marked task(s) (e.g. sport's
  // "Live Ora") instead of waiting for its cron schedule. Non-blocking on
  // the core side — see TriggerRefreshResponse.message for why it did or
  // didn't start (e.g. a task already in flight).
  Future<TriggerRefreshResponse> triggerRefresh(String pluginId) =>
      _pluginStub.triggerRefresh(TriggerRefreshRequest(pluginId: pluginId),
          options: CallOptions(timeout: _defaultRpcTimeout));
}
