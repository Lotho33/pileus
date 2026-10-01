/// Plain data holder for one cached-catalog/layout row — replaces the old
/// Isar `@collection` class. Each row is stored under its own
/// SharedPreferences key, `'layoutcache:$screenEndpoint'` (see
/// MediaRepository), which is what used to be Isar's unique index on
/// [screenEndpoint] — the prefix lets MediaRepository enumerate all cache
/// rows via SharedPreferences.getKeys() the same way Isar's
/// `screenEndpointStartsWith` did.
class LayoutCache {
  LayoutCache();

  String screenEndpoint = '';
  String jsonLayoutStructure = '';
  int cachedAtTimestamp = 0;

  factory LayoutCache.fromJson(Map<String, dynamic> json) => LayoutCache()
    ..screenEndpoint = json['screenEndpoint'] as String? ?? ''
    ..jsonLayoutStructure = json['jsonLayoutStructure'] as String? ?? ''
    ..cachedAtTimestamp = json['cachedAtTimestamp'] as int? ?? 0;

  Map<String, dynamic> toJson() => {
        'screenEndpoint': screenEndpoint,
        'jsonLayoutStructure': jsonLayoutStructure,
        'cachedAtTimestamp': cachedAtTimestamp,
      };
}
