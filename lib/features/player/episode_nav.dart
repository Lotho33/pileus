import '../media/data/media_repository.dart';
import 'models/playback_args.dart';

/// Episodes-first, items-as-fallback: a season-directory browse returns real
/// episode data (title, thumbnail, …) in `episodes` — mycelium only routes
/// media tagged as an episode there (see mycelium-core's
/// lua_pipeline.go:Browse), `items` holds everything else. Reading `items`
/// directly for an episode listing (a pre-existing bug found and fixed
/// elsewhere — TV's playback_screen/view.dart and
/// mobile_playback_screen.dart's own season-crossing code) got an empty-or-
/// wrong list for a properly-tagged season, silently failing or producing a
/// Continue Watching entry with a generic title and no poster.
Future<
    List<
        ({
          String id,
          String title,
          String thumb,
          int episodeNumber,
          int seasonNumber
        })>> _browseEpisodes(
    MediaRepository repo, String pluginId, String parentId) async {
  final res = await repo.browse(pluginId, parentId, '');
  return res.episodes.isNotEmpty
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
}

/// Resolves the next/previous episode across season boundaries — same
/// strategy as the TV player's `_resolveEpisodeAt`
/// (`presentation/playback_screen/view.dart`), rewritten standalone so
/// desktop/web can gain episode navigation without touching that screen's
/// mature, battle-tested state machine (or mobile's own separate copy,
/// which also has prefetch layered on top).
///
/// Deliberately dumb about how the resolved episode's stream actually gets
/// opened: the caller dispatches the same `PlaybackBloc` events
/// (`InitializeVideoEvent`/`SelectStreamEvent`) its own "cold" initial load
/// already uses — this class only figures out *which* episode is next/
/// previous and keeps the season-crossing bookkeeping (`allSeasonIds`/
/// `allSeasonLabels`/`episodeList`) in sync as it resolves across seasons.
class EpisodeNavState {
  final String pluginId;
  int episodeIndex;
  int seasonIndex;
  List<String> episodeList;
  List<String> episodeTitles;
  // Parallel to episodeList/episodeTitles — see PlaybackArgs.episodeThumbs
  // and episode_poster.dart's posterForEpisode() for why this exists (the
  // Continue Watching cover must track the *current* episode, not whichever
  // one the session launched with).
  List<String> episodeThumbs;
  // Parallel to episodeList — the real "S{x} · E{y}" numbers (not the list
  // *index*, which is just position and can differ from the plugin's own
  // numbering, e.g. specials). 0 means "unknown". See
  // PlaybackArgs.episodeNumbers/seasonNumbers.
  List<int> episodeNumbers;
  List<int> seasonNumbers;
  final List<String> allSeasonIds;
  final List<String> allSeasonLabels;
  String parentId;
  final String seriesPoster;
  // Series' own horizontal extra['cover_url'] — see PlaybackArgs.seriesCoverUrl
  // and episode_poster.dart's posterForEpisode() (tried before seriesPoster).
  final String seriesCoverUrl;

  EpisodeNavState({
    required this.pluginId,
    required this.episodeIndex,
    required this.seasonIndex,
    required this.episodeList,
    required this.episodeTitles,
    required this.episodeThumbs,
    required this.allSeasonIds,
    required this.allSeasonLabels,
    required this.parentId,
    required this.seriesPoster,
    this.seriesCoverUrl = '',
    this.episodeNumbers = const [],
    this.seasonNumbers = const [],
  });

  factory EpisodeNavState.fromArgs(PlaybackArgs args) => EpisodeNavState(
        pluginId: args.epPluginId,
        episodeIndex: args.episodeIndex,
        seasonIndex: args.seasonIndex,
        episodeList: List<String>.of(args.episodeList),
        episodeTitles: List<String>.of(args.episodeTitles),
        episodeThumbs: List<String>.of(args.episodeThumbs),
        episodeNumbers: List<int>.of(args.episodeNumbers),
        seasonNumbers: List<int>.of(args.seasonNumbers),
        allSeasonIds: List<String>.of(args.allSeasonIds),
        allSeasonLabels: List<String>.of(args.allSeasonLabels),
        parentId: args.parentId,
        seriesPoster:
            args.seriesPoster.isNotEmpty ? args.seriesPoster : args.poster,
        seriesCoverUrl: args.seriesCoverUrl,
      );

  /// This episode's real number, or 0 if unknown/out of range — never the
  /// list *index* (see the field doc comment).
  int get currentEpisodeNumber =>
      episodeIndex >= 0 && episodeIndex < episodeNumbers.length
          ? episodeNumbers[episodeIndex]
          : 0;
  int get currentSeasonNumber =>
      episodeIndex >= 0 && episodeIndex < seasonNumbers.length
          ? seasonNumbers[episodeIndex]
          : 0;

  /// Whether there's any episode list to navigate at all — false for a
  /// movie/single item (`episodeIndex == -1`, the `PlaybackArgs` default).
  bool get isEpisodic => episodeIndex >= 0 && episodeList.isNotEmpty;

  bool get hasNext =>
      isEpisodic &&
      (episodeIndex + 1 < episodeList.length ||
          seasonIndex + 1 < allSeasonIds.length);

  bool get hasPrevious => isEpisodic && (episodeIndex > 0 || seasonIndex > 0);

  Future<EpisodeNavTarget?> resolveNext(MediaRepository repo) =>
      _resolveAt(repo, episodeIndex + 1);

  Future<EpisodeNavTarget?> resolvePrevious(MediaRepository repo) =>
      _resolveAt(repo, episodeIndex - 1);

  Future<EpisodeNavTarget?> _resolveAt(
      MediaRepository repo, int wantedIndex) async {
    if (!isEpisodic) return null;
    var list = episodeList;
    var titles = episodeTitles;
    var thumbs = episodeThumbs;
    var epNums = episodeNumbers;
    var seasonNums = seasonNumbers;
    var newSeasonIndex = seasonIndex;
    var newParentId = parentId;
    var newIndex = wantedIndex;

    if (newIndex < 0) {
      if (allSeasonIds.isEmpty || seasonIndex <= 0) return null;
      newSeasonIndex = seasonIndex - 1;
      newParentId = allSeasonIds[newSeasonIndex];
      final eps = await _browseEpisodes(repo, pluginId, newParentId);
      if (eps.isEmpty) return null;
      list = [for (final e in eps) e.id];
      titles = [for (final e in eps) e.title];
      thumbs = [for (final e in eps) e.thumb];
      epNums = [for (final e in eps) e.episodeNumber];
      seasonNums = [for (final e in eps) e.seasonNumber];
      newIndex = list.length - 1;
    } else if (newIndex >= list.length) {
      if (allSeasonIds.isEmpty || seasonIndex + 1 >= allSeasonIds.length) {
        return null;
      }
      newSeasonIndex = seasonIndex + 1;
      newParentId = allSeasonIds[newSeasonIndex];
      final eps = await _browseEpisodes(repo, pluginId, newParentId);
      if (eps.isEmpty) return null;
      list = [for (final e in eps) e.id];
      titles = [for (final e in eps) e.title];
      thumbs = [for (final e in eps) e.thumb];
      epNums = [for (final e in eps) e.episodeNumber];
      seasonNums = [for (final e in eps) e.seasonNumber];
      newIndex = 0;
    }
    if (newIndex < 0 || newIndex >= list.length) return null;

    // Commit so a subsequent resolveNext/resolvePrevious continues from here.
    episodeIndex = newIndex;
    seasonIndex = newSeasonIndex;
    episodeList = list;
    episodeTitles = titles;
    episodeThumbs = thumbs;
    episodeNumbers = epNums;
    seasonNumbers = seasonNums;
    parentId = newParentId;

    return EpisodeNavTarget(
      mediaId: list[newIndex],
      title: newIndex < titles.length ? titles[newIndex] : '',
      episodeIndex: newIndex,
      seasonIndex: newSeasonIndex,
      episodeList: list,
      episodeTitles: titles,
      episodeThumbs: thumbs,
      episodeNumbers: epNums,
      seasonNumbers: seasonNums,
      seriesPoster: seriesPoster,
      allSeasonIds: allSeasonIds,
      allSeasonLabels: allSeasonLabels,
      parentId: newParentId,
    );
  }
}

/// A resolved navigation target — enough to both dispatch a stream request
/// (`mediaId`) and update the caller's own copy of the episode/season
/// bookkeeping for next time.
class EpisodeNavTarget {
  final String mediaId;
  final String title;
  final int episodeIndex;
  final int seasonIndex;
  final List<String> episodeList;
  final List<String> episodeTitles;
  final List<String> episodeThumbs;
  final List<int> episodeNumbers;
  final List<int> seasonNumbers;
  final String seriesPoster;
  final List<String> allSeasonIds;
  final List<String> allSeasonLabels;
  final String parentId;

  const EpisodeNavTarget({
    required this.mediaId,
    required this.title,
    required this.episodeIndex,
    required this.seasonIndex,
    required this.episodeList,
    required this.episodeTitles,
    required this.episodeThumbs,
    required this.seriesPoster,
    required this.allSeasonIds,
    required this.allSeasonLabels,
    required this.parentId,
    this.episodeNumbers = const [],
    this.seasonNumbers = const [],
  });
}
