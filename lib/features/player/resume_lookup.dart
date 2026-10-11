import '../media/data/continue_watching_item.dart';
import '../media/data/media_repository.dart';

/// The Continue Watching entry to resume for a catalog item, or null — one
/// lookup for every "Riproduci/Riprendi" entry point (details pages on TV and
/// mobile, the mobile long-press sheet), so they can't disagree.
///
/// - Series: the row whose parent is this series (mycelium keeps one per
///   series). A "roll-forward" row — the next episode, parked at ~31 s when
///   the previous one was finished — counts too: resuming it is exactly
///   "continue with the next episode" (continueWatchingPlayerExtra starts it
///   from the top).
/// - Movie: a parentless row whose playable id is the movie id *or the id of
///   one of its sources*. Continue Watching stores the stream id of the
///   source that was playing (it carries the language, see
///   source_continuity.dart), so matching on the movie id alone misses it.
///   [knownSourceIds] skips the extra GetStreams when the caller already has
///   them. A row with no real progress (opened, closed at 0) is ignored.
///
/// Best-effort: any failure yields null ("play from the start").
Future<ContinueWatchingItem?> findResumeEntry(
  MediaRepository repo, {
  required String pluginId,
  required String itemId,
  required bool isSeries,
  List<String>? knownSourceIds,
}) async {
  try {
    if (isSeries) {
      final items = await repo.getContinueWatching(
          pluginId: pluginId, parentId: itemId);
      return items.firstOrNull;
    }
    final itemsFuture =
        repo.getContinueWatching(pluginId: pluginId, limit: 100);
    var sourceIds = knownSourceIds;
    if (sourceIds == null) {
      try {
        final res = await repo.getStreams(pluginId, itemId);
        sourceIds = [for (final s in res.sources) s.id];
      } catch (_) {
        sourceIds = const [];
      }
    }
    final ids = {itemId, ...sourceIds};
    final items = await itemsFuture;
    final match = items
        .where((i) => i.parentID.isEmpty && ids.contains(i.playableID))
        .firstOrNull;
    if (match == null) return null;
    final isRealProgress = !(match.totalTime <= 0 && match.progressTime <= 35);
    return isRealProgress ? match : null;
  } catch (_) {
    return null;
  }
}
