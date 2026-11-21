import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;

import '../media/data/media_repository.dart';
import 'episode_nav.dart' show loadSeasonEpisodes;
import 'episode_poster.dart';
import 'playback_episode_list.dart';
import 'source_continuity.dart';

/// End of an episode with no next one in the list the player holds (last
/// episode of a season, or a download played with no list at all): what
/// Continue Watching should do with the row.
///
/// The same-season case stays where it was (each player rolls the row
/// forward at kCwRollForwardThreshold from its own list). This covers the
/// rest at kCwDropThreshold: the first episode of the next season becomes
/// the row (31 s in, like the same-season roll), the row goes when the
/// series really is over, and a movie never comes here (callers check
/// [isEpisodeOfSeries] first).
///
/// Serializable: a row finished offline (a download watched on a train) is
/// queued as-is in the Continue Watching offline queue and replayed once the
/// server answers again — finding the next episode needs it.
class CwAdvanceRequest {
  final String pluginId;
  // The series id Continue Watching groups the row under (never a season
  // folder id).
  final String seriesId;
  // The row to replace (a stream id or a bare episode id).
  final String currentCwId;
  final String currentTitle;
  final int seasonNumber;
  final int episodeNumber;
  // Season directory ids the player knew, in order — used only when the
  // series' own details don't list them.
  final List<String> knownSeasonIds;
  final String sourceLabel;
  final String showTitle;
  final String seriesPoster;
  final String seriesCoverUrl;
  final String fallbackPoster;
  final double rating;
  final List<String> genres;
  final String plot;
  final int year;

  const CwAdvanceRequest({
    required this.pluginId,
    required this.seriesId,
    required this.currentCwId,
    this.currentTitle = '',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.knownSeasonIds = const [],
    this.sourceLabel = '',
    this.showTitle = '',
    this.seriesPoster = '',
    this.seriesCoverUrl = '',
    this.fallbackPoster = '',
    this.rating = 0,
    this.genres = const [],
    this.plot = '',
    this.year = 0,
  });

  Map<String, dynamic> toJson() => {
        'pluginId': pluginId,
        'seriesId': seriesId,
        'currentCwId': currentCwId,
        'currentTitle': currentTitle,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'knownSeasonIds': knownSeasonIds,
        'sourceLabel': sourceLabel,
        'showTitle': showTitle,
        'seriesPoster': seriesPoster,
        'seriesCoverUrl': seriesCoverUrl,
        'fallbackPoster': fallbackPoster,
        'rating': rating,
        'genres': genres,
        'plot': plot,
        'year': year,
      };

  factory CwAdvanceRequest.fromJson(Map<String, dynamic> j) => CwAdvanceRequest(
        pluginId: j['pluginId'] as String? ?? '',
        seriesId: j['seriesId'] as String? ?? '',
        currentCwId: j['currentCwId'] as String? ?? '',
        currentTitle: j['currentTitle'] as String? ?? '',
        seasonNumber: (j['seasonNumber'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episodeNumber'] as num?)?.toInt() ?? 0,
        knownSeasonIds:
            (j['knownSeasonIds'] as List?)?.cast<String>() ?? const [],
        sourceLabel: j['sourceLabel'] as String? ?? '',
        showTitle: j['showTitle'] as String? ?? '',
        seriesPoster: j['seriesPoster'] as String? ?? '',
        seriesCoverUrl: j['seriesCoverUrl'] as String? ?? '',
        fallbackPoster: j['fallbackPoster'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        plot: j['plot'] as String? ?? '',
        year: (j['year'] as num?)?.toInt() ?? 0,
      );
}

/// True when [mediaId] is an episode of the series [parentId] — the only
/// case where moving on to "the next one" makes sense (never for a movie,
/// whose launch carries no parent, or the parent's own id).
bool isEpisodeOfSeries(String parentId, String mediaId) =>
    parentId.isNotEmpty && parentId != mediaId;

/// Moves the row on (see [CwAdvanceRequest]); queues it for later when the
/// server can't be reached. Fire-and-forget from the players.
Future<void> advanceContinueWatching(
    MediaRepository repo, CwAdvanceRequest r) async {
  final done = await tryAdvanceContinueWatching(repo, r);
  if (done == null) await repo.queueCwAdvance(r);
}

/// [advanceContinueWatching] without the queueing: true when handled (moved
/// to the next episode, removed because the series is over, or left alone
/// because the plugin couldn't say), null when the server didn't answer.
///
/// [replay]: run from the offline queue — the write must not claim the
/// profile's playback lease (see MediaGrpcClient.updateProgress).
Future<bool?> tryAdvanceContinueWatching(
    MediaRepository repo, CwAdvanceRequest r,
    {bool replay = false}) async {
  _Next? next;
  try {
    next = await _findNext(repo, r);
  } catch (e) {
    if (_offline(e)) return null;
    if (kDebugMode) debugPrint('[cw_advance] lookup failed: $e');
    return true; // the plugin can't tell: the row stays as it is
  }
  if (next == null) return true;
  if (next.isEnd) {
    final ok = await repo.deleteProgress(
        providerID: r.pluginId, playableID: r.currentCwId, queueOffline: false);
    return ok ? true : null;
  }
  final ep = next.episode!;
  final streamId = await streamIdForNextEpisode(
    repo,
    pluginId: r.pluginId,
    nextEpisodeId: ep.id,
    sourceLabel: r.sourceLabel,
  );
  final resp = await repo.updateProgress(
    pluginId: r.pluginId,
    mediaId: streamId,
    parentId: r.seriesId,
    // Same as the same-season roll forward: an empty bar, resuming past
    // the recap.
    position: const Duration(seconds: 31),
    title: ep.title.isNotEmpty ? ep.title : r.showTitle,
    showTitle: r.showTitle,
    poster: posterForEpisode(
      episodeThumbs: [ep.thumb],
      index: 0,
      seriesCoverUrl: r.seriesCoverUrl,
      seriesPoster: r.seriesPoster,
      fallback: r.fallbackPoster,
    ),
    rating: r.rating,
    genres: r.genres,
    plot: r.plot,
    year: r.year,
    seasonNumber: ep.seasonNumber,
    episodeNumber: ep.episodeNumber,
    queueOffline: false,
    replay: replay,
  );
  if (resp == null) return null;
  // The server already drops the series' other rows on that upsert; this
  // covers a row stored under another parent id.
  if (streamId != r.currentCwId) {
    await repo.deleteProgress(
        providerID: r.pluginId, playableID: r.currentCwId, queueOffline: false);
  }
  return true;
}

class _Next {
  final PlaybackEpisode? episode;
  const _Next.episode(PlaybackEpisode this.episode);
  const _Next.end() : episode = null;
  bool get isEnd => episode == null;
}

// How many season folders to browse looking for the current episode when
// its season number is unknown (a download, an old row).
const _maxSeasonWalk = 40;

/// The episode after the current one across seasons, [_Next.end] when the
/// series is over, null when the current episode can't be found.
Future<_Next?> _findNext(MediaRepository repo, CwAdvanceRequest r) async {
  final details = await repo.getDetails(r.pluginId, r.seriesId);
  if (!details.hasSeries()) {
    // Not a series after all (a movie launched with a parent id): finished.
    return details.hasMovie() ? const _Next.end() : null;
  }
  var seasonIds = [
    for (final s in details.series.seasons)
      if (s.directoryId.isNotEmpty) s.directoryId
  ];
  final seasonNums = [
    for (final s in details.series.seasons)
      if (s.directoryId.isNotEmpty) s.number
  ];
  final target = episodeMatchKey(r.currentTitle);

  if (seasonIds.isEmpty && r.knownSeasonIds.isNotEmpty) {
    seasonIds = r.knownSeasonIds;
  }
  if (seasonIds.isEmpty) {
    // Single-level series: the episodes sit right under it.
    final eps = episodesOf(await repo.browse(r.pluginId, r.seriesId, ''));
    final idx = _match(eps, r, target);
    if (idx < 0) return null;
    return idx + 1 < eps.length
        ? _Next.episode(eps[idx + 1])
        : const _Next.end();
  }

  // The current season first when its number is known, then the others.
  final order = List<int>.generate(seasonIds.length, (i) => i);
  if (r.seasonNumber > 0) {
    final si = seasonNums.indexOf(r.seasonNumber);
    if (si >= 0) {
      order
        ..remove(si)
        ..insert(0, si);
    }
  }
  for (final si in order.take(_maxSeasonWalk)) {
    final eps = await loadSeasonEpisodes(repo, r.pluginId, seasonIds[si]);
    if (eps == null) continue;
    final list = [
      for (var i = 0; i < eps.ids.length; i++)
        (
          id: eps.ids[i],
          title: i < eps.titles.length ? eps.titles[i] : '',
          thumb: i < eps.thumbs.length ? eps.thumbs[i] : '',
          episodeNumber:
              i < eps.episodeNumbers.length ? eps.episodeNumbers[i] : 0,
          seasonNumber: i < eps.seasonNumbers.length ? eps.seasonNumbers[i] : 0,
        )
    ];
    final idx = _match(list, r, target);
    if (idx < 0) continue;
    if (idx + 1 < list.length) return _Next.episode(list[idx + 1]);
    // Last of its season: the first episode of the next season with any.
    for (var n = si + 1; n < seasonIds.length; n++) {
      final next = await loadSeasonEpisodes(repo, r.pluginId, seasonIds[n]);
      if (next == null || next.ids.isEmpty) continue;
      return _Next.episode((
        id: next.ids.first,
        title: next.titles.isNotEmpty ? next.titles.first : '',
        thumb: next.thumbs.isNotEmpty ? next.thumbs.first : '',
        episodeNumber:
            next.episodeNumbers.isNotEmpty ? next.episodeNumbers.first : 0,
        seasonNumber: next.seasonNumbers.isNotEmpty
            ? next.seasonNumbers.first
            : (n < seasonNums.length ? seasonNums[n] : 0),
      ));
    }
    return const _Next.end();
  }
  return null;
}

/// The playing episode's index: by id/title (see matchPlaybackEpisode),
/// then by its season/episode numbers.
int _match(List<PlaybackEpisode> eps, CwAdvanceRequest r, String target) {
  final idx =
      matchPlaybackEpisode(eps, currentId: r.currentCwId, target: target);
  if (idx >= 0 || r.episodeNumber <= 0) return idx;
  return eps.indexWhere((e) =>
      e.episodeNumber == r.episodeNumber &&
      (r.seasonNumber <= 0 ||
          e.seasonNumber <= 0 ||
          e.seasonNumber == r.seasonNumber));
}

/// The server didn't answer (vs a plugin error): worth retrying later.
bool _offline(Object e) {
  // No dart:io here (the web player uses this too): the gRPC client
  // reports a dropped connection as UNAVAILABLE anyway.
  if (e is TimeoutException) return true;
  if (e is GrpcError) {
    return e.code == StatusCode.unavailable ||
        e.code == StatusCode.deadlineExceeded;
  }
  return false;
}
