/// Session cache for the player's prev/next episode list, keyed
/// `"<pluginId> <parentId>"`. Building one list can take several sequential
/// `browse()` calls (walking season directories), and the answer is stable
/// for the session — so playing the next episode of the same series, or
/// re-opening it, reuses this instead of re-walking.
///
/// It is **session-scoped, not app-lifetime**: the lists belong to one
/// server's catalog. [clearPlaybackEpisodeCache] is called from
/// `rebuildGrpcClients` on a server switch so a "Cambia server" doesn't leave
/// the next player showing the previous server's episode ids.
final Map<String, List<({String id, String title})>> playbackEpisodeCache = {};

void clearPlaybackEpisodeCache() => playbackEpisodeCache.clear();
