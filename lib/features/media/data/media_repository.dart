import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:fixnum/fixnum.dart' show Int64;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/models/layout_cache.dart';
import '../../../core/di/injection.dart' show getIt;
import '../../../core/grpc/auth_interceptor.dart';
import '../../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../../core/grpc/grpc_errors.dart';
import '../../../core/utils/perf_log.dart';
import '../../auth/data/auth_repository.dart';
import '../../player/content_view_mode.dart';
import '../../settings/data/settings_repository.dart';
import 'continue_watching_item.dart';
import 'plugin_prefs.dart';

class MediaRepository {
  final SharedPreferences _prefs;
  final AuthInterceptor _interceptor;

  // Resolved per call, never cached. `rebuildGrpcClients()` re-registers
  // MediaGrpcClient when the server host changes; a reference captured in
  // the constructor would keep every bloc that holds this repo (PluginBloc,
  // ContinueWatchingBloc — long-lived lazy singletons) talking to the dead
  // HTTP/2 channel after a re-discovery.
  MediaGrpcClient get _client => getIt<MediaGrpcClient>();

  // Plugin order/visibility (loadPluginOrder/savePluginOrder/loadPluginPrefs/
  // savePluginPrefs below) delegate here — same getIt-per-call idiom as
  // _client above, so this stays consistent even though SettingsRepository
  // itself isn't rebuilt by rebuildGrpcClients.
  SettingsRepository get _settings => getIt<SettingsRepository>();

  static const int _cacheTtlSeconds = 86400; // 24h default for static catalogs
  // Past its TTL a cached catalog is still shown at once — and refreshed in
  // the background (see getCatalog's `stale`) — up to this age. Older than
  // that it's too far from the real thing to show even for a moment.
  static const int _staleMaxSeconds = 7 * 86400;
  // Sentinel: cacheTtlSeconds = -1 means "bypass cache entirely" (live/dynamic).
  static const int _noCache = -1;
  // Bump this when the cache schema or field names change to force a full wipe.
  static const int _cacheVersion = 13;
  static const String _cacheVersionKey = '__cache_version__';

  // Every LayoutCache row lives under 'layoutcache:$screenEndpoint' — this
  // prefix is what used to be Isar's dedicated collection namespace, keeping
  // these rows distinguishable from device_session/local_profiles/settings
  // keys that share the same SharedPreferences instance (a wipe here must
  // never touch those).
  static const String _keyPrefix = 'layoutcache:';

  MediaRepository(this._prefs, this._interceptor);

  /// Fired when a gRPC call here comes back `unauthenticated` — the in-memory
  /// JWT is dead (no refresh flow exists), so the whole session is over.
  /// Wired in `configureDependencies` / `rebuildGrpcClients` to dispatch
  /// `SessionExpiredEvent` on `AuthBloc`, same as every media bloc does. The
  /// progress/continue-watching calls below are invoked straight off
  /// `getIt<MediaRepository>()` by the four playback screens, bypassing any
  /// bloc, so without this a mid-playback expiry is swallowed: playback keeps
  /// going, progress silently stops persisting, and the user is never routed
  /// back to the auth flow.
  void Function()? onSessionExpired;

  /// Fired when a gRPC call here comes back isProfileLocked (see
  /// grpc_errors.dart) — the active profile's PIN lease/trust stopped
  /// covering this device mid-session. Same wiring/reasoning as
  /// [onSessionExpired], distinct callback because the two must never be
  /// confused (this one doesn't touch device pairing at all).
  void Function()? onProfileLocked;

  /// true when [e] is a dead session and [onSessionExpired] has been fired.
  bool _handledSessionExpiry(Object e) {
    if (isUnauthenticated(e)) {
      onSessionExpired?.call();
      return true;
    }
    return false;
  }

  /// true when [e] is a profile PIN lockout and [onProfileLocked] has been
  /// fired. Checked alongside [_handledSessionExpiry] at every call site
  /// that already checks it — the two error classes are mutually exclusive
  /// gRPC codes, so callers can check both unconditionally.
  bool _handledProfileLock(Object e) {
    if (isProfileLocked(e)) {
      onProfileLocked?.call();
      return true;
    }
    return false;
  }

  String _keyFor(String screenEndpoint) => '$_keyPrefix$screenEndpoint';

  LayoutCache? _readEntry(String screenEndpoint) {
    final raw = _prefs.getString(_keyFor(screenEndpoint));
    if (raw == null) return null;
    try {
      return LayoutCache.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeEntry(LayoutCache entry) => _prefs.setString(
        _keyFor(entry.screenEndpoint),
        jsonEncode(entry.toJson()),
      );

  Future<void> init() async {
    final versionEntry = _readEntry(_cacheVersionKey);
    final storedVersion = int.tryParse(
          versionEntry?.jsonLayoutStructure ?? '0',
        ) ??
        0;
    if (storedVersion < _cacheVersion) {
      // Preserve user preferences stored alongside catalog caches — every
      // profile's plugin-order entry, not just the active one (each is a
      // separate row keyed '$_pluginOrderKeyPrefix:$profileId').
      final savedOrders = _savedPluginOrders();
      await _wipeAllLayoutCacheKeys();
      final newVersion = LayoutCache()
        ..screenEndpoint = _cacheVersionKey
        ..jsonLayoutStructure = '$_cacheVersion'
        ..cachedAtTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _writeEntry(newVersion);
      for (final order in savedOrders) {
        await _writeEntry(order);
      }
    }
  }

  /// User-triggered "Svuota cache" (Settings) — wipes every cached catalog
  /// response so stale/since-changed server-side catalog content stops
  /// being served from a still-live TTL window. Preserves every profile's
  /// plugin-order preference and re-seeds the version marker the same way
  /// init()'s version-bump wipe does, so this doesn't get redundantly
  /// re-wiped again on next launch.
  Future<void> clearCatalogCache() async {
    final savedOrders = _savedPluginOrders();
    await _wipeAllLayoutCacheKeys();
    final versionEntry = LayoutCache()
      ..screenEndpoint = _cacheVersionKey
      ..jsonLayoutStructure = '$_cacheVersion'
      ..cachedAtTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _writeEntry(versionEntry);
    for (final order in savedOrders) {
      await _writeEntry(order);
    }
  }

  /// User-preference rows that must survive a catalog-cache wipe — every
  /// profile's plugin-order row (`__plugin_order__[:profileId]`) and its
  /// home-customisation row (`__plugin_prefs__[:profileId]`). These live in
  /// the same 'layoutcache:' keyspace as cached catalog responses but are
  /// not cache — losing them would silently reset the user's layout.
  List<LayoutCache> _savedPluginOrders() {
    final orders = <LayoutCache>[];
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      final screenEndpoint = key.substring(_keyPrefix.length);
      if (!screenEndpoint.startsWith(_pluginOrderKeyPrefix) &&
          !screenEndpoint.startsWith(_pluginPrefsKeyPrefix)) {
        continue;
      }
      final entry = _readEntry(screenEndpoint);
      if (entry != null) orders.add(entry);
    }
    return orders;
  }

  /// Removes every 'layoutcache:*' key — this is the "clear" — without
  /// touching device_session/local_profiles/settings keys living in the
  /// same SharedPreferences instance.
  Future<void> _wipeAllLayoutCacheKeys() async {
    final keys =
        _prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  // Cache-first: fresh cache → skip gRPC.
  //
  // ttlSeconds:
  //   0        → use global default (86400 s / 24 h). Used when the plugin
  //              manifest does not set cache_ttl_seconds.
  //   > 0      → use this value (e.g. 120 s for live sport catalogs).
  //   _noCache → bypass cache entirely; always fetch fresh and do NOT persist.
  //
  // forceRefresh: skip TTL check and always fetch from network (still persists).
  //
  // Stale-while-revalidate: a cached response past its TTL (but younger
  // than _staleMaxSeconds) is returned at once with `stale: true` instead of
  // blocking on the network — the caller shows it and then asks again with
  // forceRefresh (DiscoveryBloc does). The home paints from disk even when
  // the server is slow or unreachable.
  Future<({CatalogResponse catalog, bool fromCache, bool stale})> getCatalog(
    String pluginId,
    String catalogId, {
    int page = 1,
    int ttlSeconds = 0,
    bool forceRefresh = false,
  }) async {
    final endpoint = '$pluginId/$catalogId/$page';
    final skipCache = ttlSeconds == _noCache;

    if (!skipCache && !forceRefresh) {
      final ttl = ttlSeconds > 0 ? ttlSeconds : _cacheTtlSeconds;
      final cached = _readEntry(endpoint);

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final age = cached == null ? 0 : nowSec - cached.cachedAtTimestamp;
      if (cached != null && age < _staleMaxSeconds) {
        final parsed = _parseCachedCatalog(cached.jsonLayoutStructure);
        // Only use cache if it has items with valid poster URLs.
        if (parsed.items.isNotEmpty &&
            parsed.items.first.posterUrl.isNotEmpty) {
          // Invalidate if none of the media cards have a logo — cached before
          // prefetch completed.
          final mediaCards = parsed.items
              .where((i) => i.mediaType == 'series' || i.mediaType == 'movie')
              .toList();
          final hasAnyLogo = mediaCards.any((i) => i.logoUrl.isNotEmpty);
          if (mediaCards.isEmpty || hasAnyLogo) {
            return (catalog: parsed, fromCache: true, stale: age >= ttl);
          }
        }
      }
    }

    final response = await _client.getCatalog(
      CatalogRequest(pluginId: pluginId, catalogId: catalogId, page: page),
    );

    // Don't persist live/no-cache catalogs — their data is always stale
    // by the time it would be read back.
    if (!skipCache) await _updateCache(endpoint, response);
    return (catalog: response, fromCache: false, stale: false);
  }

  // Filters are static per plugin (the plugins themselves cache them for
  // 24h), yet the search screen asked for them at boot and again on every
  // plugin switch — three identical GetSearchFilters in one web page load,
  // each holding a browser connection and a plugin Lua state. One shared
  // in-flight call, and a short session cache. Empty answers are never
  // cached: the server returns an empty list (not an error) for a plugin
  // that isn't ready yet, and that must not stick.
  static const _filtersCacheTtl = Duration(minutes: 10);
  final Map<String, (SearchFiltersResponse, DateTime)> _filtersCache = {};
  final Map<String, Future<SearchFiltersResponse>> _filtersInFlight = {};

  Future<SearchFiltersResponse> getSearchFilters(String pluginId) {
    final cached = _filtersCache[pluginId];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _filtersCacheTtl) {
      return Future.value(cached.$1);
    }
    return _filtersInFlight[pluginId] ??= _fetchAndCacheFilters(pluginId);
  }

  // Not a `.then().whenComplete(() => _filtersInFlight.remove(id))` chain:
  // `remove` returns the removed value — that very chain's future — and
  // whenComplete waits on a Future its callback returns, so the future
  // waited on itself and never completed. Every first open of a plugin's
  // search sat on the Filtri spinner (retryNow joined the stuck call); only
  // a later screen, served from _filtersCache, saw the filters.
  Future<SearchFiltersResponse> _fetchAndCacheFilters(String pluginId) async {
    try {
      final resp = await _client
          .getSearchFilters(SearchFiltersRequest(pluginId: pluginId));
      if (resp.filters.isNotEmpty) {
        _filtersCache[pluginId] = (resp, DateTime.now());
      }
      return resp;
    } finally {
      _filtersInFlight.remove(pluginId);
    }
  }

  Future<SearchResponse> search(
    String pluginId,
    String query, {
    int page = 1,
    Map<String, String> filters = const {},
  }) =>
      _client.search(SearchRequest(
        pluginId: pluginId,
        query: query,
        page: page,
        filters: filters.entries,
      ));

  // In-memory only (session lifetime, never persisted) — unlike the
  // SharedPreferences-backed catalog cache above, this one exists purely to
  // survive a widget being torn down and rebuilt with the exact same
  // pluginId/mediaId a moment later, which getDetails callers hit a lot:
  // DesktopHero/MobileHero call it from initState() every time they're
  // recreated (their own AutomaticKeepAliveClientMixin fix,
  // only covers the scroll-out-of-view case — switching plugin remounts
  // them from scratch regardless, same widget subtree, new key, and
  // reported still refetching every single time), and
  // _resolveSeriesMetaIfMissing in the player screen backfills from a
  // cold resume. A short TTL, not "forever": unlike the poster/logo/plot
  // fields those callers actually read (which don't change mid-session), a
  // stale cache could otherwise paper over a real "genuinely still doesn't
  // exist" 404 for 24h if this reused the catalog cache's TTL.
  static const _detailsCacheTtl = Duration(minutes: 5);
  final Map<String, (DetailsResponse, DateTime)> _detailsCache = {};
  final Map<String, Future<DetailsResponse>> _detailsInFlight = {};

  // [urgent]: a screen the user just opened (DetailsBloc). It must not join
  // an in-flight call started by a background hero — that one may still be
  // parked in the web RequestGate queue — so it fires its own, skipping the
  // queue, and refreshes the cache for everyone else.
  Future<DetailsResponse> getDetails(String pluginId, String mediaId,
      {bool urgent = false}) async {
    final key = '$pluginId|$mediaId';
    final cached = _detailsCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _detailsCacheTtl) {
      return cached.$1;
    }
    if (urgent) {
      final resp = await _client.getDetails(
          DetailsRequest(pluginId: pluginId, mediaId: mediaId),
          urgent: true);
      _detailsCache[key] = (resp, DateTime.now());
      return resp;
    }
    // Two heroes built in the same frame used to fire the same call twice.
    //
    // Plain async/await + try/finally, not a `.then().whenComplete()` chain
    // — a live Android TV trace showed the underlying RPC
    // itself answer in 47ms (media_client.dart's own timing) while a
    // listener attached just outside this method (episode_popup.dart) never
    // saw it complete for 15-30+ seconds, though the value DID land in
    // _detailsCache in that window (confirmed by a retry moments later
    // hitting the cache with no fresh RPC) — i.e. the combinator chain
    // itself ran, just far later than any sane network latency explains,
    // specifically on that hardware. getStreams, which has no such
    // wrapping (a bare pass-through to _client.getStreams), never showed
    // the same stall in the same traces. Root cause not confirmed from
    // here, but the correlation is exact and repeated — this removes the
    // extra Future-combinator layer for every non-urgent caller (heroes
    // included, not just the popup that surfaced it) instead of only
    // working around it at one call site.
    final inFlight = _detailsInFlight[key];
    if (inFlight != null) return inFlight;
    final future = _fetchAndCacheDetails(pluginId, mediaId, key);
    _detailsInFlight[key] = future;
    return future;
  }

  Future<DetailsResponse> _fetchAndCacheDetails(
      String pluginId, String mediaId, String key) async {
    try {
      final resp = await _client
          .getDetails(DetailsRequest(pluginId: pluginId, mediaId: mediaId));
      _detailsCache[key] = (resp, DateTime.now());
      return resp;
    } finally {
      _detailsInFlight.remove(key);
    }
  }

  // Opt-in short cache + single flight ([cache]), like getStreams below: a
  // series' details screen loads a season, and its Play button (and the
  // stream warmer working out that button's episode) asks for the very same
  // one. Opt-in because other directories are live (a sports plugin's
  // events) and must stay fresh.
  static const _browseCacheTtl = Duration(minutes: 3);
  final Map<String, (BrowseResponse, DateTime)> _browseCache = {};
  final Map<String, Future<BrowseResponse>> _browseInFlight = {};

  Future<BrowseResponse> browse(
      String pluginId, String parentId, String childId,
      {bool cache = false}) async {
    if (!cache) {
      return _client.browse(BrowseRequest(
          pluginId: pluginId, parentId: parentId, childId: childId));
    }
    _checkSessionClient();
    final key = '${_interceptor.profileId ?? ''}|$pluginId|$parentId|$childId';
    final cached = _browseCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _browseCacheTtl) {
      return cached.$1;
    }
    final inFlight = _browseInFlight[key];
    if (inFlight != null) return inFlight;
    final future = _fetchAndCacheBrowse(pluginId, parentId, childId, key);
    _browseInFlight[key] = future;
    return future;
  }

  Future<BrowseResponse> _fetchAndCacheBrowse(
      String pluginId, String parentId, String childId, String key) async {
    try {
      final resp = await _client.browse(BrowseRequest(
          pluginId: pluginId, parentId: parentId, childId: childId));
      if (resp.items.isNotEmpty || resp.episodes.isNotEmpty) {
        _browseCache[key] = (resp, DateTime.now());
      }
      return resp;
    } finally {
      _browseInFlight.remove(key);
    }
  }

  // Short session cache + single flight, like getDetails. The sources of a
  // title are asked for by its details screen, then again by the Play (the
  // bloc), the episode popup, the resume lookup and the stream warmer — one
  // call now serves them all. Keyed by profile too: a plugin may order the
  // sources by the profile's last language (the last one used first), and
  // that order decides which source a Play picks. Only successes are kept.
  static const _streamsCacheTtl = Duration(minutes: 3);
  final Map<String, (StreamsResponse, DateTime)> _streamsCache = {};
  final Map<String, Future<StreamsResponse>> _streamsInFlight = {};
  // The client the session caches/flags below belong to: a server switch
  // (rebuildGrpcClients) registers a new one, and nothing learned from the
  // old server may leak onto the new one.
  MediaGrpcClient? _sessionClient;

  void _checkSessionClient() {
    final c = _client;
    if (identical(c, _sessionClient)) return;
    _sessionClient = c;
    _streamsCache.clear();
    _browseCache.clear();
    _warmUnsupported = false;
    _warmDisabledPlugins.clear();
  }

  Future<StreamsResponse> getStreams(String pluginId, String mediaId) async {
    _checkSessionClient();
    final key = '${_interceptor.profileId ?? ''}|$pluginId|$mediaId';
    final cached = _streamsCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _streamsCacheTtl) {
      return cached.$1;
    }
    final inFlight = _streamsInFlight[key];
    if (inFlight != null) return inFlight;
    final future = _fetchAndCacheStreams(pluginId, mediaId, key);
    _streamsInFlight[key] = future;
    return future;
  }

  // Plain async/await + try/finally — see _fetchAndCacheDetails.
  Future<StreamsResponse> _fetchAndCacheStreams(
      String pluginId, String mediaId, String key) async {
    try {
      final resp = await _client.getStreams(
          StreamsRequest(pluginId: pluginId, mediaId: mediaId));
      // An empty list can be a plugin that isn't ready yet — never let it
      // stick (same rule as the search filters).
      if (resp.sources.isNotEmpty) _streamsCache[key] = (resp, DateTime.now());
      return resp;
    } finally {
      _streamsInFlight.remove(key);
    }
  }

  // WarmStream state for this session: a server without the RPC
  // (UNIMPLEMENTED) and the plugins it said it won't warm
  // (skipped/disabled) aren't asked again until the server changes.
  bool _warmUnsupported = false;
  final Set<String> _warmDisabledPlugins = {};

  /// False once the server said it won't warm [pluginId] (or can't warm at
  /// all) — lets the caller skip working out a stream id for nothing.
  bool canWarm(String pluginId) {
    _checkSessionClient();
    return !_warmUnsupported && !_warmDisabledPlugins.contains(pluginId);
  }

  /// Asks the server to prepare [streamId] ahead of Play (WarmStream, see
  /// proto/media.proto). Fire-and-forget, never awaited and never retried:
  /// `started`/`joined`/`skipped` all need nothing more from us. [streamId]
  /// must be exactly the one the Play will send to ResolveStream — see
  /// pickSourceByLabel.
  void warmStream(String pluginId, String streamId) {
    if (pluginId.isEmpty || streamId.isEmpty || !canWarm(pluginId)) return;
    unawaited(_client
        .warmStream(WarmStreamRequest(pluginId: pluginId, streamId: streamId))
        .then((r) {
      perf('warm $pluginId $streamId → ${r.outcome}'
          '${r.reason.isEmpty ? '' : ' (${r.reason})'}');
      if (r.outcome == 'skipped' && r.reason == 'disabled') {
        _warmDisabledPlugins.add(pluginId);
      }
    }).catchError((Object e) {
      if (e is GrpcError && e.code == StatusCode.unimplemented) {
        _warmUnsupported = true;
      }
      perf('warm $pluginId $streamId failed: $e');
    }));
  }

  /// [startPositionSec]: the Continue Watching resume point, when applicable
  /// (see resume_seek.dart's resolveStartPositionSec) — lets the server warm
  /// the segments around that point instead of the first ones. 0 (the
  /// default) is the proto field's own "not applicable" value.
  ///
  /// [takeOver]: contract "One device playing per profile" — true only for
  /// the explicit "Guarda qui"/"Riprendi qui" retry after an ABORTED/
  /// playback_elsewhere signal (see grpc_errors.dart's isPlayingElsewhere).
  Stream<ResolveStreamEvent> resolveStream(String pluginId, String streamId,
          {double startPositionSec = 0, bool takeOver = false}) =>
      _client.resolveStream(ResolveRequest(
          pluginId: pluginId,
          streamId: streamId,
          startPositionSec: startPositionSec,
          takeOver: takeOver));

  /// Best-effort, never blocks the caller — see ReleasePlaybackRequest's own
  /// doc and MediaGrpcClient.releasePlayback. Call whenever the player
  /// closes on a device that was actually holding the lease (exiting the
  /// screen, end of content with no next episode, TV backgrounded a while,
  /// logout, profile switch) — never on an episode switch, which keeps
  /// playing on this same device.
  void releasePlayback() {
    unawaited(_client.releasePlayback().catchError((e) {
      if (kDebugMode) debugPrint('[MediaRepo] releasePlayback error: $e');
      return ReleasePlaybackResponse();
    }));
  }

  static const String _pluginOrderKeyPrefix = '__plugin_order__';

  // Per profile — the same device may have a kid's profile and an adult's
  // sharing the plugin list but wanting a different browsing order. Falls
  // back to the pre-per-profile key (a bare '__plugin_order__' row, with no
  // ':$profileId' suffix) so an order set before this became per-profile
  // isn't silently lost — it's just the shared starting point until a
  // profile reorders it, same fallback pattern as SettingsRepository.
  String get _pluginOrderKey {
    final pid = _interceptor.profileId;
    return (pid == null || pid.isEmpty)
        ? _pluginOrderKeyPrefix
        : '$_pluginOrderKeyPrefix:$pid';
  }

  Future<List<PluginInfo>> listPlugins() async =>
      _applyPluginPrefs(await _orderedPlugins(), await loadPluginPrefs());

  // Last good _orderedPlugins() result — HomeScreen refreshes it every ~30s,
  // so it's normally warm. listAllPlugins() falls back to it when a call
  // fails, so the per-plugin settings screen isn't left blank on a transient
  // gRPC error (e.g. right after another screen's request timed out).
  List<PluginInfo>? _lastOrdered;

  /// Every installed plugin in the profile's chosen order, with full catalog
  /// lists and WITHOUT the hide filter — for the settings screens, which have
  /// to keep a hidden plugin reachable so it can be re-enabled.
  Future<List<PluginInfo>> listAllPlugins() async {
    try {
      return await _orderedPlugins();
    } catch (_) {
      final cached = _lastOrdered;
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  // LoadPluginsEvent is dispatched by auth, home, search and the shell at
  // about the same moment (4 ListPlugins in one web page load). They all want
  // the same wire response — profile prefs/order are applied per caller below,
  // so sharing the network call is safe across a profile switch.
  Future<PluginListResponse>? _listPluginsInFlight;

  Future<PluginListResponse> _fetchPluginList() => _listPluginsInFlight ??=
      _client.listPlugins().whenComplete(() => _listPluginsInFlight = null);

  // Last ListPlugins answer per profile, on disk (a layoutcache row, so
  // "Svuota cache" and a cache-version bump drop it too): what the home is
  // drawn from at the next cold start before the server has answered —
  // see cachedPlugins / PluginBloc._onLoad. Written only when it changed:
  // the 30 s poll would otherwise rewrite the same bytes forever.
  static const String _pluginsSnapshotPrefix = '__plugins_snapshot__:';
  String? _lastPluginsSnapshot;

  void _savePluginsSnapshot(PluginListResponse resp) {
    final pid = _interceptor.profileId;
    if (pid == null || pid.isEmpty) return;
    final encoded = base64Encode(resp.writeToBuffer());
    if ('$pid|$encoded' == _lastPluginsSnapshot) return;
    _lastPluginsSnapshot = '$pid|$encoded';
    unawaited(_writeEntry(LayoutCache()
      ..screenEndpoint = '$_pluginsSnapshotPrefix$pid'
      ..jsonLayoutStructure = encoded
      ..cachedAtTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000));
  }

  PluginListResponse? _readPluginsSnapshot(String profileId) {
    final entry = _readEntry('$_pluginsSnapshotPrefix$profileId');
    if (entry == null || entry.jsonLayoutStructure.isEmpty) return null;
    try {
      return PluginListResponse.fromBuffer(
          base64Decode(entry.jsonLayoutStructure));
    } catch (_) {
      return null;
    }
  }

  /// Synchronous — the splash asks it before AuthBloc has done anything:
  /// can the home be drawn from disk for [profileId] right away?
  bool hasStartupSnapshot(String profileId) =>
      profileId.isNotEmpty && _readPluginsSnapshot(profileId) != null;

  /// The plugin list as of the last successful ListPlugins for the active
  /// profile — same order and home customisation as [listPlugins], no
  /// network. Null when there's none. Plugin statuses in it are as old as
  /// the snapshot; the caller replaces them with the live answer.
  Future<List<PluginInfo>?> cachedPlugins() async {
    final pid = _interceptor.profileId;
    if (pid == null || pid.isEmpty) return null;
    final resp = _readPluginsSnapshot(pid);
    if (resp == null || resp.plugins.isEmpty) return null;
    return _applyPluginPrefs(await _orderPlugins(resp), await loadPluginPrefs());
  }

  Future<List<PluginInfo>> _orderedPlugins() async {
    final resp = await _fetchPluginList();
    _savePluginsSnapshot(resp);
    final sorted = await _orderPlugins(resp);
    _lastOrdered = sorted;
    return sorted;
  }

  Future<List<PluginInfo>> _orderPlugins(PluginListResponse resp) async {
    // mycelium-core's ListPlugins ranges over a Go map internally, so the
    // wire order is randomized on every single call — never rely on it.
    // Sorting here gives a stable fallback (both for a profile that never
    // set a custom order, and for the "newly added plugin" tail below)
    // instead of the nav silently reshuffling itself every ~30s.
    //
    // Sorted by pluginId, not by name: `name` is plugin-reported metadata
    // that can still be empty/generic on the very first call right after
    // launch, while a plugin's own backend process is still finishing
    // startup — sorting by it then meant the very first render used
    // whatever incomplete names had arrived so far, and the nav visibly
    // reordered itself a few seconds later once every plugin had reported
    // its real name. pluginId is known and stable from the moment a plugin
    // is registered, so sorting by it gives the same order on every call,
    // including the first.
    final byName = List<PluginInfo>.from(resp.plugins)
      ..sort((a, b) => a.pluginId.compareTo(b.pluginId));
    final order = await loadPluginOrder();
    List<PluginInfo> sorted;
    if (order.isEmpty) {
      sorted = byName;
    } else {
      final byId = {for (final p in byName) p.pluginId: p};
      sorted = <PluginInfo>[];
      for (final id in order) {
        if (byId.containsKey(id)) sorted.add(byId.remove(id)!);
      }
      sorted.addAll(byId.values); // newly added plugins go to the end, by name
    }
    return sorted;
  }

  /// Applies the active profile's home-customisation: drops hidden plugins
  /// entirely, and for the rest reorders + filters each plugin's catalog
  /// (carousel) list. Returns fresh PluginInfo clones where catalogs were
  /// touched so the cached wire objects aren't mutated.
  List<PluginInfo> _applyPluginPrefs(
      List<PluginInfo> plugins, PluginPrefs prefs) {
    if (prefs.isEmpty) return plugins;
    final out = <PluginInfo>[];
    for (final p in plugins) {
      if (prefs.isPluginHidden(p.pluginId)) continue;
      final cp = prefs.catalogPrefs(p.pluginId);
      if (cp.isEmpty) {
        out.add(p);
        continue;
      }
      final srcById = {for (final c in p.catalogs) c.id: c};
      final seen = <String>{};
      final ordered = <CatalogDef>[];
      for (final id in cp.order) {
        final c = srcById[id];
        if (c != null && !cp.isHidden(id) && seen.add(id)) ordered.add(c);
      }
      // Catalogs not covered by the saved order (e.g. added server-side
      // after the user last customised) keep their original relative order
      // and stay visible unless explicitly hidden.
      for (final c in p.catalogs) {
        if (!seen.contains(c.id) && !cp.isHidden(c.id)) {
          ordered.add(c);
          seen.add(c.id);
        }
      }
      // Fresh PluginInfo + fresh CatalogDefs so nothing in the cached wire
      // object graph is mutated or re-parented.
      final clone = PluginInfo()..mergeFromMessage(p);
      clone.catalogs
        ..clear()
        ..addAll(ordered.map((c) => CatalogDef()..mergeFromMessage(c)));
      out.add(clone);
    }
    return out;
  }

  // Returns (ok, message) rather than throwing on ok=false — a task already
  // running is an expected, common outcome (see TriggerRefreshResponse's
  // doc), not an error the caller should treat like a failed request.
  Future<TriggerRefreshResponse> triggerRefresh(String pluginId) =>
      _client.triggerRefresh(pluginId);

  // A device that's been paired for a while never re-pulls ProfilePrefs
  // (subtitles + plugin order/visibility) from the server on its own:
  // AuthBloc._onAppStarted's "remembered profile" cold-start path — the
  // common case, every launch after the first — reads straight from the
  // local profile cache and never calls syncProfilesFromServer(); that only
  // happens at a fresh pairing or when the profile picker is shown. So a
  // reorder made on another device would otherwise never arrive here until
  // something else forced a full re-sync. loadPluginOrder/loadPluginPrefs
  // below are the one shared read path every platform's UI already goes
  // through (see plugin_bloc.dart/mobile_plugins_screen.dart/
  // desktop_settings_pane.dart/plugin_settings_screen.dart), so refreshing
  // here — instead of teaching each of those call sites separately —
  // covers all of them at once.
  //
  // Fire-and-forget on purpose, not awaited before returning below: this
  // must never add a network round-trip to the latency of showing the home
  // screen's plugin row. It corrects SettingsRepository's cache in the
  // background; the fix becomes visible on the *next* call (PluginBloc's
  // own ~30s poll already re-runs loadPluginOrder/loadPluginPrefs, so a
  // stale order self-heals within about one poll cycle, not instantly but
  // without ever blocking).
  //
  // Debounced because listPlugins() calls both loadPluginOrder() and
  // loadPluginPrefs() back-to-back on every poll: without this they'd fire
  // two syncProfilesFromServer() calls each time for no benefit.
  DateTime? _lastPrefsSync;
  static const _prefsSyncMinInterval = Duration(seconds: 10);

  void _refreshProfilePrefsIfStale() {
    final now = DateTime.now();
    if (_lastPrefsSync != null &&
        now.difference(_lastPrefsSync!) < _prefsSyncMinInterval) {
      return;
    }
    _lastPrefsSync = now;
    unawaited(_syncProfilePrefsBestEffort());
  }

  Future<void> _syncProfilePrefsBestEffort() async {
    try {
      await getIt<AuthRepository>().syncProfilesFromServer();
    } catch (_) {
      // Best-effort — whatever's already cached in SettingsRepository just
      // stays as-is, same as before this existed.
    }
  }

  /// Server-synced (SettingsRepository, part of the profile's ProfilePrefs
  /// blob) — follows the profile to every paired device. Used to be
  /// local-only under [_pluginOrderKey] below, which meant pairing a new
  /// device lost any custom order; that key now only serves the one-time
  /// migration in [_legacyLoadPluginOrder].
  Future<List<String>> loadPluginOrder() async {
    _refreshProfilePrefsIfStale();
    final synced = _settings.getPluginOrder();
    if (synced.isNotEmpty) return synced;
    // Self-limiting: once seeded, getPluginOrder() stops being empty, so
    // this legacy read never fires again for this profile.
    final legacy = await _legacyLoadPluginOrder();
    if (legacy.isNotEmpty) {
      await _settings.setPluginOrder(legacy);
    }
    return legacy;
  }

  Future<List<String>> _legacyLoadPluginOrder() async {
    final entry =
        _readEntry(_pluginOrderKey) ?? _readEntry(_pluginOrderKeyPrefix);
    if (entry == null || entry.jsonLayoutStructure.isEmpty) return [];
    try {
      final list = jsonDecode(entry.jsonLayoutStructure) as List<dynamic>;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePluginOrder(List<String> pluginIds) =>
      _settings.setPluginOrder(pluginIds);

  // ── per-plugin home customisation (visibility + catalog order/hiding) ──
  // Same per-profile keying + bare-key fallback as _pluginOrderKey above —
  // kept only for the one-time legacy-migration read in
  // _legacyLoadPluginPrefs, same story as loadPluginOrder above.
  static const String _pluginPrefsKeyPrefix = '__plugin_prefs__';

  String get _pluginPrefsKey {
    final pid = _interceptor.profileId;
    return (pid == null || pid.isEmpty)
        ? _pluginPrefsKeyPrefix
        : '$_pluginPrefsKeyPrefix:$pid';
  }

  /// Server-synced, same story as [loadPluginOrder] above.
  Future<PluginPrefs> loadPluginPrefs() async {
    _refreshProfilePrefsIfStale();
    final synced = _settings.getPluginPrefs();
    if (!synced.isEmpty) return synced;
    final legacy = await _legacyLoadPluginPrefs();
    if (!legacy.isEmpty) {
      await _settings.setPluginPrefs(legacy);
    }
    return legacy;
  }

  Future<PluginPrefs> _legacyLoadPluginPrefs() async {
    final entry =
        _readEntry(_pluginPrefsKey) ?? _readEntry(_pluginPrefsKeyPrefix);
    if (entry == null || entry.jsonLayoutStructure.isEmpty) {
      return const PluginPrefs();
    }
    return PluginPrefs.decode(entry.jsonLayoutStructure);
  }

  Future<void> savePluginPrefs(PluginPrefs prefs) =>
      _settings.setPluginPrefs(prefs);

  /// Saves playback position + metadata (title, poster, rating, genres,
  /// plot, year) via gRPC, in one call — used both for the periodic
  /// heartbeat and for pause/dispose. Empty-string/zero fields merge
  /// server-side (UpsertProgress keeps the previously stored value instead
  /// of blanking it), so a position-only heartbeat doesn't need to resend
  /// metadata every tick.
  ///
  /// Returns the raw response (null on any error — logged, never thrown) so
  /// callers can check `playbackElsewhere`/`playingOn` (contract "One device
  /// playing per profile"): this device's next heartbeat/markStarted call
  /// after another device takes over the profile's playback lease is how it
  /// learns about it. Most callers don't care and just ignore the result,
  /// same as when this returned `void`.
  Future<ProgressResponse?> updateProgress({
    required String pluginId,
    required String mediaId,
    required Duration position,
    Duration totalDuration = Duration.zero,
    String parentId = '',
    String title = '',
    String showTitle = '',
    String poster = '',
    double rating = 0.0,
    List<String> genres = const [],
    String plot = '',
    int year = 0,
    // 0 = unknown/not-episodic (a movie) — same keep-if-empty merge as the
    // rest of this metadata server-side. See episode_poster.dart's
    // numberForEpisode() for how callers compute these.
    int seasonNumber = 0,
    int episodeNumber = 0,
  }) async {
    try {
      return await _client.updateProgress(ProgressRequest(
        pluginId: pluginId,
        mediaId: mediaId,
        parentId: parentId,
        currentPosition: Int64(position.inSeconds),
        totalDuration: Int64(totalDuration.inSeconds),
        title: title,
        // The series name for an episode — the card's overline. Empty for a
        // movie, which merges server-side (keeps any stored value).
        navigationContext: showTitle,
        poster: poster,
        rating: rating,
        genres: genres,
        plot: plot,
        year: year,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      ));
    } catch (e) {
      if (_handledSessionExpiry(e)) return null;
      if (_handledProfileLock(e)) return null;
      if (kDebugMode) debugPrint('[MediaRepo] updateProgress error: $e');
      return null;
    }
  }

  /// Returns whether the delete actually reached the server — callers doing
  /// an optimistic UI removal (ContinueWatchingBloc) need this to roll back
  /// when it didn't, instead of the item just vanishing from the list with
  /// no way to tell the delete silently failed server-side.
  Future<bool> deleteProgress({
    required String providerID,
    required String playableID,
  }) async {
    try {
      await _client.deleteProgress(DeleteProgressRequest(
        pluginId: providerID,
        mediaId: playableID,
      ));
      _dropFromCwSnapshot(providerID, playableID);
      return true;
    } catch (e) {
      if (_handledSessionExpiry(e)) return false;
      if (_handledProfileLock(e)) return false;
      if (kDebugMode) debugPrint('[MediaRepo] deleteProgress error: $e');
      return false;
    }
  }

  /// Fetches items the user has not yet finished watching, most recent first.
  /// [parentId]/[pluginId] are optional server-side filters — the proto and
  /// generated gRPC client already supported them
  /// (`ContinueWatchingRequest.parent_id`/`plugin_id`), this method just
  /// hadn't exposed them yet. Used by the details screens' watch buttons to
  /// ask "is there progress for this specific series/movie?" instead of
  /// fetching the whole list and filtering client-side.
  Future<List<ContinueWatchingItem>> getContinueWatching(
      {int limit = 20, String? parentId, String? pluginId}) async =>
      await fetchContinueWatching(
              limit: limit, parentId: parentId, pluginId: pluginId) ??
          const [];

  /// [getContinueWatching] that tells a failure (null) apart from an empty
  /// list — ContinueWatchingBloc must not replace the row it drew from disk
  /// with nothing just because the server didn't answer.
  Future<List<ContinueWatchingItem>?> fetchContinueWatching(
      {int limit = 20, String? parentId, String? pluginId}) async {
    try {
      final resp = await _client.getContinueWatching(ContinueWatchingRequest(
        limit: limit,
        parentId: parentId,
        pluginId: pluginId,
      ));
      // The home row (unfiltered) is kept on disk per profile — drawn at the
      // next cold start before the server answers (cachedContinueWatching).
      if (parentId == null && pluginId == null) _saveCwSnapshot(resp);
      final items = _cwItems(resp);
      // A format remembered for a content lasts as long as its Continue
      // Watching row — only a successful, unfiltered fetch can say which
      // rows are gone (never the [] an error returns below).
      if (parentId == null && pluginId == null) {
        contentViewModes.prune(items, complete: items.length < limit);
      }
      return items;
    } catch (e) {
      if (_handledSessionExpiry(e)) return null;
      if (_handledProfileLock(e)) return null;
      if (kDebugMode) debugPrint('[MediaRepo] getContinueWatching error: $e');
      return null;
    }
  }

  static const String _cwSnapshotPrefix = '__cw_snapshot__:';

  void _saveCwSnapshot(ContinueWatchingResponse resp) {
    final pid = _interceptor.profileId;
    if (pid == null || pid.isEmpty) return;
    unawaited(_writeEntry(LayoutCache()
      ..screenEndpoint = '$_cwSnapshotPrefix$pid'
      ..jsonLayoutStructure = base64Encode(resp.writeToBuffer())
      ..cachedAtTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000));
  }

  // A removed row must not come back from disk at the next cold start (for
  // the second or two before the live list replaces it).
  void _dropFromCwSnapshot(String pluginId, String mediaId) {
    final pid = _interceptor.profileId;
    if (pid == null || pid.isEmpty) return;
    final entry = _readEntry('$_cwSnapshotPrefix$pid');
    if (entry == null || entry.jsonLayoutStructure.isEmpty) return;
    try {
      final resp = ContinueWatchingResponse.fromBuffer(
          base64Decode(entry.jsonLayoutStructure));
      resp.items.removeWhere(
          (i) => i.pluginId == pluginId && i.mediaId == mediaId);
      _saveCwSnapshot(resp);
    } catch (_) {}
  }

  /// The home's Continue Watching row as of the last successful fetch for
  /// the active profile, no network. Null when there's none.
  List<ContinueWatchingItem>? cachedContinueWatching() {
    final pid = _interceptor.profileId;
    if (pid == null || pid.isEmpty) return null;
    final entry = _readEntry('$_cwSnapshotPrefix$pid');
    if (entry == null || entry.jsonLayoutStructure.isEmpty) return null;
    try {
      return _cwItems(ContinueWatchingResponse.fromBuffer(
          base64Decode(entry.jsonLayoutStructure)));
    } catch (_) {
      return null;
    }
  }

  List<ContinueWatchingItem> _cwItems(ContinueWatchingResponse resp) =>
      resp.items
          .map((i) => ContinueWatchingItem(
                providerID: i.pluginId,
                playableID: i.mediaId,
                parentID: i.parentId,
                title: i.title,
                showTitle: i.navigationContext,
                poster: i.poster,
                progressTime: i.progressTime,
                totalTime: i.totalTime,
                rating: i.rating,
                genres: i.genres,
                plot: i.plot,
                year: i.year,
                seasonNumber: i.seasonNumber,
                episodeNumber: i.episodeNumber,
              ))
          .toList();

  // ── Offline downloads ────────────────────────────────────────────────────
  // Thin pass-throughs, deliberately NOT swallowing errors here (unlike
  // getContinueWatching/deleteProgress above) — the caller (DownloadOptionsCubit/
  // DownloadsBloc) needs the real exception to tell FAILED_PRECONDITION (a
  // ready-to-show message, never retried — see grpc_errors.dart's own doc)
  // apart from UNAVAILABLE ("downloads not active on this server", per the
  // contract) apart from a genuine transient failure. `available: false` +
  // `unavailable_reason` on a normal DownloadOptionsResponse is not an error
  // at all — that's just a field on a successful response.
  Future<DownloadOptionsResponse> getDownloadOptions(
          String pluginId, String streamId) =>
      _client.getDownloadOptions(
          DownloadOptionsRequest(pluginId: pluginId, streamId: streamId));

  Future<DownloadInfo> createDownload(CreateDownloadRequest request) =>
      _client.createDownload(request);

  /// A whole season/next-N batch — a single RPC, the server keys the chosen
  /// variant/audio/subtitle ids (criteria, not fixed values) against each
  /// item's own resolve. See CreateDownloadsResponse.estimatedTotalBytes for
  /// the server's own total once this returns (the sheet shows a client-side
  /// estimate — first item's weight × N — before confirming, since that
  /// number doesn't exist until this call actually runs).
  Future<CreateDownloadsResponse> createDownloads(
          CreateDownloadsRequest request) =>
      _client.createDownloads(request);

  Future<ListDownloadsResponse> listDownloads() => _client.listDownloads();

  Future<bool> cancelDownload(String downloadId) async {
    try {
      final resp = await _client.cancelDownload(downloadId);
      return resp.ok;
    } catch (e) {
      if (_handledSessionExpiry(e)) return false;
      if (_handledProfileLock(e)) return false;
      if (kDebugMode) debugPrint('[MediaRepo] cancelDownload error: $e');
      return false;
    }
  }

  Future<bool> deleteDownload(String downloadId) async {
    try {
      final resp = await _client.deleteDownload(downloadId);
      return resp.ok;
    } catch (e) {
      if (_handledSessionExpiry(e)) return false;
      if (_handledProfileLock(e)) return false;
      if (kDebugMode) debugPrint('[MediaRepo] deleteDownload error: $e');
      return false;
    }
  }

  /// Deliberately NOT swallowing errors (unlike cancel/deleteDownload above)
  /// — the caller (the local-index ack queue) needs to tell "genuinely
  /// failed, don't mark it acked" apart from "ok, or the download/server
  /// already forgot about it entirely" itself. See AckDownloadFetched's own
  /// doc: a server-side "delete after fetched" config can make the download
  /// disappear from ListDownloads on its own right after this succeeds —
  /// that's expected, not a failure.
  Future<bool> ackDownloadFetched(String downloadId) async {
    final resp = await _client.ackDownloadFetched(downloadId);
    return resp.ok;
  }

  Future<List<PluginSettingField>> getPluginSettings(
      String pluginId, String profileId) async {
    final resp = await _client.getPluginSettings(pluginId, profileId);
    return resp.fields;
  }

  Future<bool> savePluginSetting(
      String pluginId, String profileId, String key, String value) async {
    final resp =
        await _client.savePluginSetting(pluginId, profileId, key, value);
    return resp.ok;
  }

  // ── cache helpers ──────────────────────────────────────────────────────────

  Future<void> _updateCache(String endpoint, CatalogResponse response) async {
    final items = response.items
        .map((i) => {
              'id': i.id,
              'title': i.title,
              'poster_url': i.posterUrl,
              'fanart_url': i.extra['fanart_url'] ?? '',
              'media_type': i.mediaType,
              'is_dir': i.isDir,
              'year': i.year,
              'rating': i.rating,
              'genres': i.extra['genres'] ?? '',
              'plot': i.extra['plot'] ?? '',
              'image_hint': i.extra['image_hint'] ?? '',
              'anilist_id': i.extra['anilist_id'] ?? '',
              'mal_id': i.extra['mal_id'] ?? '',
              'lang': i.extra['lang'] ?? '',
              'subtype': i.extra['subtype'] ?? '',
              'logo_url': i.logoUrl,
            })
        .toList();
    final jsonStr = jsonEncode({'items': items, 'has_more': response.hasMore});

    final entry = LayoutCache()
      ..screenEndpoint = endpoint
      ..jsonLayoutStructure = jsonStr
      ..cachedAtTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _writeEntry(entry);
  }

  CatalogResponse _parseCachedCatalog(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final rawItems = map['items'] as List<dynamic>? ?? [];
      final items = rawItems.map((e) {
        final m = e as Map<String, dynamic>;
        final fanartUrl = m['fanart_url'] as String? ?? '';
        final genres = m['genres'] as String? ?? '';
        final plot = m['plot'] as String? ?? '';
        final imageHint = m['image_hint'] as String? ?? '';
        final anilistId = m['anilist_id'] as String? ?? '';
        final malId = m['mal_id'] as String? ?? '';
        final lang = m['lang'] as String? ?? '';
        final subtype = m['subtype'] as String? ?? '';
        final logoUrl = m['logo_url'] as String? ?? '';
        return CatalogItem(
          id: m['id'] as String? ?? '',
          title: m['title'] as String? ?? '',
          posterUrl: m['poster_url'] as String? ?? '',
          logoUrl: logoUrl,
          mediaType: m['media_type'] as String? ?? '',
          isDir: m['is_dir'] as bool? ?? false,
          year: m['year'] as int? ?? 0,
          rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
          extra: {
            'fanart_url': fanartUrl,
            'genres': genres,
            'plot': plot,
            'image_hint': imageHint,
            'anilist_id': anilistId,
            'mal_id': malId,
            'lang': lang,
            'subtype': subtype,
          }.entries,
        );
      }).toList();
      return CatalogResponse(
          items: items, hasMore: map['has_more'] as bool? ?? false);
    } catch (_) {
      return CatalogResponse();
    }
  }
}
