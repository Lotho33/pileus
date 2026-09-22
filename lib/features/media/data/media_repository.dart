import 'dart:convert';

import 'package:fixnum/fixnum.dart' show Int64;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/models/layout_cache.dart';
import '../../../core/di/injection.dart' show getIt;
import '../../../core/grpc/auth_interceptor.dart';
import '../../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../../core/grpc/grpc_errors.dart';
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

  static const int _cacheTtlSeconds = 86400; // 24h default for static catalogs
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

  /// true when [e] is a dead session and [onSessionExpired] has been fired.
  bool _handledSessionExpiry(Object e) {
    if (isUnauthenticated(e)) {
      onSessionExpired?.call();
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
  Future<({CatalogResponse catalog, bool fromCache})> getCatalog(
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

      if (cached != null && (nowSec - cached.cachedAtTimestamp) < ttl) {
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
            return (catalog: parsed, fromCache: true);
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
    return (catalog: response, fromCache: false);
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
    return _filtersInFlight[pluginId] ??= _client
        .getSearchFilters(SearchFiltersRequest(pluginId: pluginId))
        .then((resp) {
      if (resp.filters.isNotEmpty) {
        _filtersCache[pluginId] = (resp, DateTime.now());
      }
      return resp;
    }).whenComplete(() => _filtersInFlight.remove(pluginId));
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
  // recreated (their own AutomaticKeepAliveClientMixin fix, 2026-09-14,
  // only covers the scroll-out-of-view case — switching plugin remounts
  // them from scratch regardless, same widget subtree, new key, and
  // reported still refetching every single time, 2026-09-16), and
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
    // — a live Android TV trace (2026-09-22) showed the underlying RPC
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

  Future<BrowseResponse> browse(
          String pluginId, String parentId, String childId) =>
      _client.browse(BrowseRequest(
          pluginId: pluginId, parentId: parentId, childId: childId));

  Future<StreamsResponse> getStreams(String pluginId, String mediaId) =>
      _client.getStreams(StreamsRequest(pluginId: pluginId, mediaId: mediaId));

  Stream<ResolveStreamEvent> resolveStream(String pluginId, String streamId) =>
      _client.resolveStream(
          ResolveRequest(pluginId: pluginId, streamId: streamId));

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

  Future<PluginListResponse> _fetchPluginList() =>
      _listPluginsInFlight ??= _client
          .listPlugins()
          .whenComplete(() => _listPluginsInFlight = null);

  Future<List<PluginInfo>> _orderedPlugins() async {
    final resp = await _fetchPluginList();
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
    _lastOrdered = sorted;
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

  Future<List<String>> loadPluginOrder() async {
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

  // ── per-plugin home customisation (visibility + catalog order/hiding) ──
  // Same per-profile keying + bare-key fallback as _pluginOrderKey above.
  static const String _pluginPrefsKeyPrefix = '__plugin_prefs__';

  String get _pluginPrefsKey {
    final pid = _interceptor.profileId;
    return (pid == null || pid.isEmpty)
        ? _pluginPrefsKeyPrefix
        : '$_pluginPrefsKeyPrefix:$pid';
  }

  Future<PluginPrefs> loadPluginPrefs() async {
    final entry =
        _readEntry(_pluginPrefsKey) ?? _readEntry(_pluginPrefsKeyPrefix);
    if (entry == null || entry.jsonLayoutStructure.isEmpty) {
      return const PluginPrefs();
    }
    return PluginPrefs.decode(entry.jsonLayoutStructure);
  }

  Future<void> savePluginPrefs(PluginPrefs prefs) async {
    final entry = LayoutCache()
      ..screenEndpoint = _pluginPrefsKey
      ..jsonLayoutStructure = prefs.encode()
      ..cachedAtTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _writeEntry(entry);
  }

  Future<void> savePluginOrder(List<String> pluginIds) async {
    final entry = LayoutCache()
      ..screenEndpoint = _pluginOrderKey
      ..jsonLayoutStructure = jsonEncode(pluginIds)
      ..cachedAtTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _writeEntry(entry);
  }

  /// Saves playback position + metadata (title, poster, rating, genres,
  /// plot, year) via gRPC, in one call — used both for the periodic
  /// heartbeat and for pause/dispose. Empty-string/zero fields merge
  /// server-side (UpsertProgress keeps the previously stored value instead
  /// of blanking it), so a position-only heartbeat doesn't need to resend
  /// metadata every tick.
  Future<void> updateProgress({
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
  }) async {
    try {
      await _client.updateProgress(ProgressRequest(
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
      ));
    } catch (e) {
      if (_handledSessionExpiry(e)) return;
      if (kDebugMode) debugPrint('[MediaRepo] updateProgress error: $e');
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
      return true;
    } catch (e) {
      if (_handledSessionExpiry(e)) return false;
      if (kDebugMode) debugPrint('[MediaRepo] deleteProgress error: $e');
      return false;
    }
  }

  /// Fetches items the user has not yet finished watching, most recent first.
  Future<List<ContinueWatchingItem>> getContinueWatching(
      {int limit = 20}) async {
    try {
      final resp = await _client
          .getContinueWatching(ContinueWatchingRequest(limit: limit));
      return resp.items
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
              ))
          .toList();
    } catch (e) {
      if (_handledSessionExpiry(e)) return [];
      if (kDebugMode) debugPrint('[MediaRepo] getContinueWatching error: $e');
      return [];
    }
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
