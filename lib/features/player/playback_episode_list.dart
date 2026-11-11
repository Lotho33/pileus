import '../../core/grpc/clients/media_client.dart' show BrowseResponse;
import '../media/data/media_repository.dart';
import 'playback_episode_cache.dart';

/// One episode as every player keeps it (the shape of [playbackEpisodeCache]).
typedef PlaybackEpisode = ({
  String id,
  String title,
  String thumb,
  int episodeNumber,
  int seasonNumber
});

/// A browse answer's playable episodes. Episodes-first, items-as-fallback —
/// see episode_nav.dart's loadSeasonEpisodes for why `episodes` wins.
List<PlaybackEpisode> episodesOf(BrowseResponse res) => res.episodes.isNotEmpty
    ? [
        for (final e in res.episodes)
          (
            id: e.id,
            title: e.title,
            thumb: e.thumbnailUrl,
            episodeNumber: e.episodeNumber,
            seasonNumber: e.seasonNumber,
          )
      ]
    : [
        for (final i in res.items)
          if (!i.isDir)
            (
              id: i.id,
              title: i.title,
              thumb: i.posterUrl,
              episodeNumber: i.episodeNumber,
              seasonNumber: i.seasonNumber,
            )
      ];

/// Normalized title used to find the playing episode in a list.
String episodeMatchKey(String? title) => (title ?? '').trim().toLowerCase();

/// Rebuilds the episode list around what's playing when the launch didn't
/// carry one — a Continue Watching tap only knows the episode and its
/// parent. Was copied identically in the TV and mobile players (and missing
/// on desktop/web, where a resume therefore had no prev/next/auto-advance).
///
/// [target] is [episodeMatchKey] of the playing title. A parent that is a
/// list of season directories is walked until one holds [target], capped at
/// 8 sequential browses (a deep series would otherwise stall right after
/// playback starts; prev/next is a convenience). [cancelled] is checked
/// between browses — the screen may be gone. Null when nothing usable (< 2
/// episodes) was found. Results are kept in [playbackEpisodeCache].
Future<List<PlaybackEpisode>?> resolvePlaybackEpisodes(
  MediaRepository repo, {
  required String pluginId,
  required String parentId,
  required String target,
  bool Function()? cancelled,
}) async {
  final cacheKey = '$pluginId $parentId';
  final cached = playbackEpisodeCache[cacheKey];
  if (cached != null && cached.length >= 2) return cached;

  final res = await repo.browse(pluginId, parentId, '');
  if (cancelled?.call() ?? false) return null;
  var eps = episodesOf(res);
  if (eps.length < 2) {
    for (final s in res.items.where((i) => i.isDir).take(8)) {
      if (cancelled?.call() ?? false) return null;
      final se = episodesOf(await repo.browse(pluginId, s.id, ''));
      if (se.length > 1 &&
          (target.isEmpty ||
              se.any((e) => episodeMatchKey(e.title) == target))) {
        eps = se;
        break;
      }
    }
  }
  if (eps.length < 2) return null;
  playbackEpisodeCache[cacheKey] = eps;
  return eps;
}

/// Index of the playing episode in [eps], or -1. [currentId] may be a
/// resolved stream id rather than the bare episode id, hence the title and
/// then the loose-containment fallbacks — the latter only for ids long
/// enough to be a real token (a bare "1" is a substring of almost every
/// stream URL: the unguarded check matched episode 1 for nearly every
/// Continue Watching tap).
int matchPlaybackEpisode(List<PlaybackEpisode> eps,
    {required String currentId, required String target}) {
  var idx = eps.indexWhere((e) => e.id == currentId);
  if (idx < 0 && target.isNotEmpty) {
    idx = eps.indexWhere((e) => episodeMatchKey(e.title) == target);
  }
  if (idx < 0) {
    idx = eps.indexWhere((e) => e.id.length >= 8 && currentId.contains(e.id));
  }
  return idx;
}
