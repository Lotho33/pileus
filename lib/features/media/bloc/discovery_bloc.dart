import 'package:collection/collection.dart' show ListEquality;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/clients/media_client.dart' show CatalogItem;
import '../../../core/grpc/grpc_errors.dart';
import '../data/media_repository.dart';
import 'discovery_event.dart';
import 'discovery_state.dart';

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final MediaRepository _repo;
  final void Function()? onSessionExpired;
  final void Function()? onProfileLocked;

  // search_screen.dart debounces per keystroke, but doesn't cancel an
  // in-flight search when a newer one is dispatched — plugin backends
  // answer with variable latency, so an older, slower query's
  // response can land after a newer, faster one's and silently overwrite
  // it (the UI ends up showing results for a query that's no longer in the
  // search box, with no error). This generation counter lets _onSearch drop
  // any response that's no longer the most recently dispatched one.
  int _searchGeneration = 0;

  // Same guardrail as _searchGeneration above, for catalog loads instead of
  // search — no dispatch site sends a second LoadCatalogEvent/
  // LoadMoreCatalogEvent to the same bloc today (2026-09 audit), so this
  // is defensive/for-symmetry rather than fixing a reproducible bug: a
  // future retry/refresh action that redispatches onto an existing bloc
  // would otherwise be exposed to the exact same out-of-order response bug
  // _onSearch already guards against.
  int _catalogGeneration = 0;

  DiscoveryBloc(this._repo, {this.onSessionExpired, this.onProfileLocked})
      : super(const DiscoveryInitial()) {
    on<LoadCatalogEvent>(_onLoadCatalog);
    on<LoadMoreCatalogEvent>(_onLoadMore);
    on<RefreshCatalogEvent>(_onRefreshCatalog);
    on<SearchRequestEvent>(_onSearch);
    on<LoadMoreSearchEvent>(_onLoadMoreSearch);
    on<LoadBrowseEvent>(_onLoadBrowse);
    on<ClearSearchEvent>(_onClearSearch);
  }

  void _onClearSearch(ClearSearchEvent event, Emitter<DiscoveryState> emit) {
    // Invalidates any search/load-more still in flight — otherwise a slow
    // response for the just-cleared query can land after this and silently
    // repopulate the (now supposed to be empty) search state.
    _searchGeneration++;
    emit(const DiscoveryInitial());
  }

  Future<void> _onLoadCatalog(
      LoadCatalogEvent event, Emitter<DiscoveryState> emit) async {
    final myGeneration = ++_catalogGeneration;
    emit(const DiscoveryLoading());
    try {
      final result = await _repo.getCatalog(
        event.pluginId,
        event.catalogId,
        page: event.page,
        ttlSeconds: event.cacheTtlSeconds,
        forceRefresh: event.forceRefresh,
      );
      if (myGeneration != _catalogGeneration) return;
      // Diagnostic only — the poster URL in particular has no business in a
      // release logcat. kDebugMode is a const bool so this tree-shakes out.
      if (kDebugMode) {
        final items = result.catalog.items;
        debugPrint(items.isEmpty
            ? '[catalog] ${event.catalogId} items=0'
            : '[catalog] ${event.catalogId} items=${items.length} '
                'first="${items.first.title}" fromCache=${result.fromCache} '
                'poster="${items.first.posterUrl}"');
      }
      emit(DiscoveryLoaded(
        result.catalog.items,
        hasMore: result.catalog.hasMore,
        fromCache: result.fromCache,
        pluginId: event.pluginId,
        catalogId: event.catalogId,
        currentPage: event.page,
      ));
      if (result.stale) {
        await _revalidate(event, myGeneration, result.catalog.items, emit);
      }
    } catch (e) {
      if (myGeneration != _catalogGeneration) return;
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      if (isProfileLocked(e)) {
        onProfileLocked?.call();
        return;
      }
      emit(DiscoveryError(e.toString()));
    }
  }

  // The row is on screen from a cache past its TTL (stale-while-revalidate,
  // see MediaRepository.getCatalog): fetch the live one and swap it in only
  // if it differs — an identical answer must not rebuild a carousel the
  // user may already be moving through — and only if nothing happened to
  // the row meanwhile (a newer load, a "load more" in flight or done).
  // A failure keeps the cached row: that's the point of having it.
  Future<void> _revalidate(LoadCatalogEvent event, int generation,
      List<CatalogItem> shown, Emitter<DiscoveryState> emit,
      {bool liveState = false}) async {
    try {
      final fresh = await _repo.getCatalog(
        event.pluginId,
        event.catalogId,
        page: event.page,
        ttlSeconds: event.cacheTtlSeconds,
        forceRefresh: true,
      );
      if (generation != _catalogGeneration) return;
      final current = state;
      if (current is! DiscoveryLoaded ||
          current.isLoadingMore ||
          current.currentPage != event.page) {
        return;
      }
      // Compared on what the row shows: items read back from the disk
      // cache carry only a subset of the wire fields, so a plain equality
      // would see every refresh as a change.
      List<String> shape(List<CatalogItem> items) => [
            for (final i in items)
              '${i.id}|${i.title}|${i.posterUrl}|${i.logoUrl}'
                  '${liveState ? '|${i.extra['is_live']}|${i.extra['plot']}' : ''}'
          ];
      if (const ListEquality<String>()
          .equals(shape(fresh.catalog.items), shape(shown))) {
        return;
      }
      emit(current.copyWith(
        items: fresh.catalog.items,
        hasMore: fresh.catalog.hasMore,
        fromCache: false,
      ));
    } catch (e) {
      if (isUnauthenticated(e)) onSessionExpired?.call();
      if (isProfileLocked(e)) onProfileLocked?.call();
    }
  }

  Future<void> _onRefreshCatalog(
      RefreshCatalogEvent event, Emitter<DiscoveryState> emit) async {
    final current = state;
    if (current is! DiscoveryLoaded || current.currentPage != 1) return;
    await _revalidate(
      LoadCatalogEvent(
        pluginId: event.pluginId,
        catalogId: event.catalogId,
        cacheTtlSeconds: event.cacheTtlSeconds,
      ),
      _catalogGeneration,
      current.items,
      emit,
      // A live event going on air changes only this flag.
      liveState: true,
    );
  }

  Future<void> _onLoadMore(
      LoadMoreCatalogEvent event, Emitter<DiscoveryState> emit) async {
    final myGeneration = _catalogGeneration;
    final current = state;
    if (current is! DiscoveryLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    try {
      var result = await _repo.getCatalog(
        event.pluginId,
        event.catalogId,
        page: current.currentPage + 1,
      );
      // A stale next page would not line up with a first page that was
      // just revalidated — try the live one, fall back to the stale one.
      if (result.stale) {
        try {
          result = await _repo.getCatalog(
            event.pluginId,
            event.catalogId,
            page: current.currentPage + 1,
            forceRefresh: true,
          );
        } catch (_) {}
      }
      if (myGeneration != _catalogGeneration) return;
      emit(current.copyWith(
        items: [...current.items, ...result.catalog.items],
        hasMore: result.catalog.hasMore,
        currentPage: current.currentPage + 1,
        isLoadingMore: false,
      ));
    } catch (e) {
      if (myGeneration != _catalogGeneration) return;
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      if (isProfileLocked(e)) {
        onProfileLocked?.call();
        return;
      }
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSearch(
      SearchRequestEvent event, Emitter<DiscoveryState> emit) async {
    final myGeneration = ++_searchGeneration;
    emit(const DiscoveryLoading());
    try {
      final response = await _repo.search(
        event.pluginId,
        event.query,
        page: 1,
        filters: event.filters,
      );
      // A newer search was dispatched while this one was in flight — its
      // result (or loading state) has already superseded this one, so
      // applying this stale response now would overwrite it out of order.
      if (myGeneration != _searchGeneration) return;
      emit(DiscoveryLoaded(
        response.items,
        pluginId: event.pluginId,
        hasMore: response.hasMore,
        searchQuery: event.query,
        searchPage: 1,
        activeFilters: event.filters,
      ));
    } catch (e) {
      if (myGeneration != _searchGeneration) return;
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      if (isProfileLocked(e)) {
        onProfileLocked?.call();
        return;
      }
      emit(DiscoveryError(e.toString()));
    }
  }

  Future<void> _onLoadMoreSearch(
      LoadMoreSearchEvent event, Emitter<DiscoveryState> emit) async {
    // Same guardrail as _onSearch: captured before the await, checked after
    // it, so a load-more that's still in flight when a newer search (or a
    // clear) supersedes it can't overwrite that newer state with a stale
    // response operating on the `current` snapshot taken here.
    final myGeneration = _searchGeneration;
    final current = state;
    if (current is! DiscoveryLoaded ||
        (current.searchQuery.isEmpty && current.activeFilters.isEmpty) ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    try {
      final nextPage = current.searchPage + 1;
      final response = await _repo.search(
        current.pluginId,
        current.searchQuery,
        page: nextPage,
        filters: current.activeFilters,
      );
      if (myGeneration != _searchGeneration) return;
      final existingIds = {for (final i in current.items) i.id};
      final newItems =
          response.items.where((i) => !existingIds.contains(i.id)).toList();
      emit(current.copyWith(
        items: [...current.items, ...newItems],
        hasMore: response.hasMore,
        searchPage: nextPage,
        isLoadingMore: false,
      ));
    } catch (e) {
      if (myGeneration != _searchGeneration) return;
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      if (isProfileLocked(e)) {
        onProfileLocked?.call();
        return;
      }
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onLoadBrowse(
      LoadBrowseEvent event, Emitter<DiscoveryState> emit) async {
    // For-symmetry generation guard, same reasoning as _onLoadCatalog: no
    // caller dispatches a second overlapping LoadBrowseEvent on this bloc
    // today, but if one ever does (retry/refresh on a folder view), this
    // stops the two responses from interleaving instead of reintroducing the
    // same class of bug that guard was added for.
    final myGeneration = ++_catalogGeneration;
    emit(const DiscoveryLoading());
    try {
      final response = await _repo.browse(event.pluginId, event.parentId, '');
      if (myGeneration != _catalogGeneration) return;
      emit(DiscoveryLoaded(response.items, hasMore: response.hasMore));
    } catch (e) {
      if (myGeneration != _catalogGeneration) return;
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      if (isProfileLocked(e)) {
        onProfileLocked?.call();
        return;
      }
      emit(DiscoveryError(e.toString()));
    }
  }
}
