import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;
import 'package:grpc/service_api.dart';

import '../../utils/perf_log.dart';
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

// The reads a user is waiting on (open a title, its episodes and languages,
// search). mycelium caps those at 45s (readEntrypointTimeout) and, since a
// plugin call can't be cancelled, keeps running it after the client hangs up:
// giving up at 20s only left an orphan call holding one of the plugin's two
// Lua states while the retap queued a duplicate. Waiting just past the
// server's own limit gets the real answer — or its clear "plugin busy"/
// timeout error — instead. Catalogs (the home) keep the short timeout: many
// of them are in flight at once and each carousel fails on its own.
const _readRpcTimeout = Duration(seconds: 50);

// Web only — see RequestGate. Null elsewhere: native gRPC is one multiplexed
// HTTP/2 connection with no per-origin connection cap to protect.
final RequestGate? _contentGate = kIsWeb ? RequestGate(3) : null;

// [urgent] = the user just asked for this (search, opening a title): it skips
// the queue. Behind the gate it would wait for every background catalog/hero
// call still queued — none of which can be cancelled — and the screen would
// sit on its spinner until the burst drained.
//
// Every content read is timed (`pileus/perf` in logcat, only with the
// diagnostics toggle on): "rpc <name> <plugin> ok|FAIL <ms>", where the ms
// include time spent waiting in the web gate. Reads are idempotent, so a
// call that dies with UNAVAILABLE — a connection that went stale while the
// app sat idle (phone asleep, Wi-Fi roam) and only got noticed when the
// request was written to it — is retried once on the fresh connection
// instead of leaving the screen for the user to tap again. A timeout is
// NOT retried: that one is a slow server/upstream, and a second identical
// request would just pile a second plugin call on top of the first.
Future<T> _gated<T>(String name, String pluginId, Future<T> Function() call,
    {bool urgent = false}) {
  Future<T> timed() async {
    final sw = Stopwatch()..start();
    for (var attempt = 1;; attempt++) {
      try {
        final r = await call();
        perf('rpc $name $pluginId ok ${sw.elapsedMilliseconds}ms'
            '${attempt > 1 ? ' (retry)' : ''}');
        return r;
      } catch (e) {
        final retry =
            attempt == 1 && e is GrpcError && e.code == StatusCode.unavailable;
        perf('rpc $name $pluginId FAIL ${sw.elapsedMilliseconds}ms '
            '${e is GrpcError ? '${e.codeName} ${e.message}' : e}'
            '${retry ? ' -> retrying' : ''}');
        if (!retry) rethrow;
      }
    }
  }

  return _contentGate == null || urgent
      ? timed()
      : _contentGate!.run(timed, group: pluginId);
}

class MediaGrpcClient {
  late final MediaPipelineClient _mediaStub;
  late final PluginServiceClient _pluginStub;

  MediaGrpcClient(ClientChannel channel, AuthInterceptor interceptor) {
    _mediaStub = MediaPipelineClient(channel, interceptors: [interceptor]);
    _pluginStub = PluginServiceClient(channel, interceptors: [interceptor]);
  }

  Future<CatalogResponse> getCatalog(CatalogRequest request) => _gated(
      'getCatalog',
      request.pluginId,
      () => _mediaStub.getCatalog(request,
          options: CallOptions(timeout: _defaultRpcTimeout)));

  Future<SearchFiltersResponse> getSearchFilters(
          SearchFiltersRequest request) =>
      _gated(
          'getSearchFilters',
          request.pluginId,
          urgent: true,
          () => _mediaStub.getSearchFilters(request,
              options: CallOptions(timeout: _readRpcTimeout)));

  Future<SearchResponse> search(SearchRequest request) => _gated(
      'search',
      request.pluginId,
      urgent: true,
      () => _mediaStub.search(request,
          options: CallOptions(timeout: _readRpcTimeout)));

  Future<DetailsResponse> getDetails(DetailsRequest request,
          {bool urgent = false}) =>
      _gated(
          'getDetails',
          request.pluginId,
          urgent: urgent,
          () => _mediaStub.getDetails(request,
              options: CallOptions(timeout: _readRpcTimeout)));

  Future<BrowseResponse> browse(BrowseRequest request) => _gated(
      'browse',
      request.pluginId,
      urgent: true,
      () => _mediaStub.browse(request,
          options: CallOptions(timeout: _readRpcTimeout)));

  // Timed like the reads above (it's a read too, and the slowest one: the
  // plugin resolves the episode's sources — the language list — against its
  // upstream site on a cold call).
  Future<StreamsResponse> getStreams(StreamsRequest request) => _gated(
      'getStreams',
      request.pluginId,
      urgent: true,
      () => _mediaStub.getStreams(request,
          options: CallOptions(timeout: _readRpcTimeout)));

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
