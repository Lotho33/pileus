import 'package:equatable/equatable.dart';

import '../../../core/grpc/clients/media_client.dart';

abstract class DiscoveryState extends Equatable {
  const DiscoveryState();
  @override
  List<Object?> get props => [];
}

class DiscoveryInitial extends DiscoveryState {
  const DiscoveryInitial();
}

class DiscoveryLoading extends DiscoveryState {
  const DiscoveryLoading();
}

class DiscoveryLoaded extends DiscoveryState {
  final List<CatalogItem> items;
  final bool hasMore;
  final bool fromCache;
  final bool isLoadingMore;
  final String pluginId;
  final String catalogId;
  final int currentPage;
  final String searchQuery;
  final int searchPage;
  final Map<String, String> activeFilters;

  const DiscoveryLoaded(
    this.items, {
    this.hasMore = false,
    this.fromCache = false,
    this.isLoadingMore = false,
    this.pluginId = '',
    this.catalogId = '',
    this.currentPage = 1,
    this.searchQuery = '',
    this.searchPage = 1,
    this.activeFilters = const {},
  });

  DiscoveryLoaded copyWith({
    List<CatalogItem>? items,
    bool? hasMore,
    bool? fromCache,
    bool? isLoadingMore,
    String? pluginId,
    String? catalogId,
    int? currentPage,
    String? searchQuery,
    int? searchPage,
    Map<String, String>? activeFilters,
  }) {
    return DiscoveryLoaded(
      items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      fromCache: fromCache ?? this.fromCache,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pluginId: pluginId ?? this.pluginId,
      catalogId: catalogId ?? this.catalogId,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      searchPage: searchPage ?? this.searchPage,
      activeFilters: activeFilters ?? this.activeFilters,
    );
  }

  @override
  List<Object?> get props => [
        items, hasMore, fromCache, isLoadingMore,
        pluginId, catalogId, currentPage,
        searchQuery, searchPage, activeFilters,
      ];
}

class DiscoveryError extends DiscoveryState {
  final String errorCode;
  const DiscoveryError(this.errorCode);
  @override
  List<Object?> get props => [errorCode];
}
