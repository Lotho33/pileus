import '../../core/grpc/generated/media.pb.dart'
    show CatalogDef, CatalogItem, NewEpisode, PluginInfo;

/// The home's "Nuovi episodi" row: the series this profile follows with an
/// episode out since it last watched them (mycelium's GetNewEpisodes, one
/// answer for every plugin, most recent first).
///
/// It rides as a catalog of its own: [withNewEpisodesRow] slips this def
/// into each plugin's list as its second row, and MediaRepository.getCatalog
/// answers it from GetNewEpisodes (that plugin's entries) instead of asking
/// the plugin. So every home — TV, mobile, desktop — pages, focuses, shows
/// the hero and hides it when empty exactly like any other row, with no
/// special case in the D-pad navigation.
const kNewEpisodesCatalogId = '_pileus_new_episodes';

bool isNewEpisodesCatalog(String catalogId) =>
    catalogId == kNewEpisodesCatalogId;

CatalogDef newEpisodesCatalogDef() => CatalogDef(
      id: kNewEpisodesCatalogId,
      // Not just "Nuovi episodi": a plugin may have its own row by that name
      // (everything just out on the site), this one is the profile's series.
      name: 'Nuovi episodi delle tue serie',
      type: 'series',
    );

/// [plugins] with the row added to each one that has on-demand catalogs
/// (not a live-only plugin), after its first row. Fresh clones: the cached
/// wire objects are never touched.
List<PluginInfo> withNewEpisodesRow(List<PluginInfo> plugins) => [
      for (final p in plugins)
        if (p.catalogs.isEmpty ||
            p.catalogs.every((c) => c.type == 'live') ||
            p.catalogs.any((c) => isNewEpisodesCatalog(c.id)))
          p
        else
          PluginInfo()
            ..mergeFromMessage(p)
            ..catalogs.insert(1, newEpisodesCatalogDef()),
    ];

/// The card for a series with a new episode: opens its details page. The
/// server sends the series' full card (backdrop, plot, genres, logo) once it
/// has checked it with details; until then title and poster are all there is.
CatalogItem newEpisodeCard(NewEpisode e) {
  if (e.hasItem() && e.item.id.isNotEmpty) {
    return (CatalogItem()..mergeFromMessage(e.item))
      ..id = e.seriesId
      ..mediaType = 'series'
      ..badge = 'new_episode';
  }
  return CatalogItem(
    id: e.seriesId,
    title: e.title,
    posterUrl: e.posterUrl,
    mediaType: 'series',
    badge: 'new_episode',
  );
}
