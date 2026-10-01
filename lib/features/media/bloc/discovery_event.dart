import 'package:equatable/equatable.dart';

abstract class DiscoveryEvent extends Equatable {
  const DiscoveryEvent();
  @override
  List<Object?> get props => [];
}

class LoadCatalogEvent extends DiscoveryEvent {
  final String pluginId;
  final String catalogId;
  final int page;
  final int cacheTtlSeconds;
  final bool forceRefresh;
  const LoadCatalogEvent({
    required this.pluginId,
    required this.catalogId,
    this.page = 1,
    this.cacheTtlSeconds = 0,
    this.forceRefresh = false,
  });
  @override
  List<Object?> get props =>
      [pluginId, catalogId, page, cacheTtlSeconds, forceRefresh];
}

class SearchRequestEvent extends DiscoveryEvent {
  final String pluginId;
  final String query;
  final Map<String, String> filters;
  const SearchRequestEvent({
    required this.pluginId,
    required this.query,
    this.filters = const {},
  });
  @override
  List<Object?> get props => [pluginId, query, filters];
}

class LoadMoreSearchEvent extends DiscoveryEvent {
  const LoadMoreSearchEvent();
}

// Resets back to DiscoveryInitial — used when quick search is dismissed so
// reopening it starts from a clean slate instead of showing the previous
// query's now-stale results.
class ClearSearchEvent extends DiscoveryEvent {
  const ClearSearchEvent();
}

class LoadBrowseEvent extends DiscoveryEvent {
  final String pluginId;
  final String parentId;
  final int page;
  const LoadBrowseEvent(
      {required this.pluginId, required this.parentId, this.page = 1});
  @override
  List<Object?> get props => [pluginId, parentId, page];
}

class LoadMoreCatalogEvent extends DiscoveryEvent {
  final String pluginId;
  final String catalogId;
  const LoadMoreCatalogEvent({required this.pluginId, required this.catalogId});
  @override
  List<Object?> get props => [pluginId, catalogId];
}
