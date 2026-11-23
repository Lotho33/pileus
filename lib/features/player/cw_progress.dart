import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' show ProgressResponse;
import '../media/data/media_repository.dart';
import 'cw_advance.dart';
import 'episode_poster.dart';
import 'episode_prefetch.dart' show PrefetchedEpisode;
import 'player_tuning.dart';
import 'source_continuity.dart';

/// What Continue Watching should store for the title playing right now.
///
/// Every player builds one from its own live state on demand (TV and web
/// change episode/season mid-session, mobile and desktop read it from
/// PlaybackArgs) — so [ContinueWatchingTracker] never caches stale metadata
/// across an episode switch.
class CwSnapshot {
  const CwSnapshot({
    required this.pluginId,
    required this.cwId,
    required this.parentId,
    this.title = '',
    this.showTitle = '',
    this.poster = '',
    this.rating = 0,
    this.genres = const [],
    this.plot = '',
    this.year = 0,
    this.episodeList = const [],
    this.episodeIndex = -1,
    this.episodeTitles = const [],
    this.episodeThumbs = const [],
    this.seasonNumbers = const [],
    this.episodeNumbers = const [],
    this.knownSeasonIds = const [],
    this.sourceLabel = '',
    this.seriesPoster = '',
    this.seriesCoverUrl = '',
    this.fallbackPoster = '',
  });

  final String pluginId;

  /// The row's playable id: the stream id once known (see
  /// source_continuity.dart), the bare media id otherwise.
  final String cwId;

  /// The series' own stable id (never a season-folder id) — mycelium's
  /// per-series cleanup in UpsertProgress is keyed on it. Empty for a movie.
  final String parentId;

  /// Card main line: the episode (or movie) title; [showTitle] when empty.
  final String title;
  final String showTitle;

  /// This item's own cover (already resolved — see episode_poster.dart).
  final String poster;
  final double rating;
  final List<String> genres;

  /// Always the series' own synopsis, never an episode's.
  final String plot;
  final int year;

  /// The season being played, in order, and where the current item sits in
  /// it (-1 when there is no list: a movie, a download).
  final List<String> episodeList;
  final int episodeIndex;
  final List<String> episodeTitles;
  final List<String> episodeThumbs;
  final List<int> seasonNumbers;
  final List<int> episodeNumbers;

  /// Season directory ids the player knows (cw_advance.dart fallback).
  final List<String> knownSeasonIds;

  /// The source playing now — the next episode resumes on the same one.
  final String sourceLabel;
  final String seriesPoster;
  final String seriesCoverUrl;

  /// The entry point's own cover, last resort for the next episode's.
  final String fallbackPoster;

  int get seasonNumber => numberForEpisode(seasonNumbers, episodeIndex);
  int get episodeNumber => numberForEpisode(episodeNumbers, episodeIndex);

  bool get hasSameSeasonNext =>
      episodeIndex >= 0 && episodeIndex + 1 < episodeList.length;

  String get cardTitle => title.isNotEmpty ? title : showTitle;
}

/// Continue Watching bookkeeping shared by the four players: the "opened"
/// write, the periodic/final saves, and the end-of-title handling (roll the
/// row forward to the next episode, on to the next season, or drop it).
///
/// Engine-agnostic on purpose: callers pass positions/durations in, so the
/// web player (an HTMLVideoElement) uses it exactly like the three
/// PlayerEngine ones.
///
/// Live streams never write anything — see PlaybackProgress's class doc
/// ("Why every screen's 15s heartbeat still skips live streams").
class ContinueWatchingTracker {
  ContinueWatchingTracker({
    required this.snapshot,
    required this.isLive,
    this.onPlaybackElsewhere,
    this.onWrite,
    MediaRepository? repo,
  }) : _repo = repo;

  /// The current title's metadata, read at each write.
  CwSnapshot Function() snapshot;

  final bool isLive;

  /// Fired at most once (until [rearmElsewhere]) when an UpdateProgress
  /// reveals another device now holds the profile's playback lease.
  final void Function(String playingOn)? onPlaybackElsewhere;

  /// Runs right before each [markStarted]/[save] write (e.g. keeping the
  /// per-content "Formato" memory in step with the ids being stored).
  final void Function()? onWrite;

  final MediaRepository? _repo;
  MediaRepository get _r => _repo ?? getIt<MediaRepository>();

  bool _cleared = false;
  bool _elsewhereReported = false;

  /// The row was already closed for this item (finished, or rolled
  /// forward): later saves must not silently recreate it.
  bool get cleared => _cleared;

  /// A new item (episode switch) or a retry of the same one: saves may
  /// write the row again.
  void resetCleared() => _cleared = false;

  /// This device can legitimately lose the lease again (after "Riprendi
  /// qui", or on a fresh item).
  void rearmElsewhere() => _elsewhereReported = false;

  void resetForRetry() {
    resetCleared();
    rearmElsewhere();
  }

  /// Writes the row the moment the stream opens. [position] is the resume
  /// target (the engine still reads ~0 at this point — reporting that would
  /// zero the row if the user backs out before the first heartbeat).
  Future<void> markStarted({
    required Duration position,
    Duration duration = Duration.zero,
  }) async {
    if (_cleared || isLive) return;
    await _write(position, duration);
  }

  /// Periodic/final save at the real playback position; a no-op at 0.
  Future<void> save({
    required Duration position,
    Duration duration = Duration.zero,
  }) async {
    if (_cleared || isLive) return;
    if (position.inSeconds <= 0) return;
    await _write(position, duration);
  }

  Future<void> _write(Duration position, Duration duration) async {
    onWrite?.call();
    final s = snapshot();
    final resp = await _r.updateProgress(
      pluginId: s.pluginId,
      mediaId: s.cwId,
      parentId: s.parentId,
      position: position,
      totalDuration: duration,
      title: s.cardTitle,
      showTitle: s.showTitle,
      poster: s.poster,
      rating: s.rating,
      genres: s.genres,
      plot: s.plot,
      year: s.year,
      seasonNumber: s.seasonNumber,
      episodeNumber: s.episodeNumber,
    );
    _checkElsewhere(resp);
  }

  void _checkElsewhere(ProgressResponse? resp) {
    if (_elsewhereReported || resp == null || !resp.playbackElsewhere) return;
    _elsewhereReported = true;
    onPlaybackElsewhere?.call(bareDeviceLabel(resp.playingOn));
  }

  /// End-of-title handling, run on every position tick:
  ///  - an episode ~90% in with a next one in the same season rolls the row
  ///    forward to it — stored under the next episode's *stream id* for the
  ///    source playing now ([prefetched] when it already covers it; see
  ///    source_continuity.dart), 31 s in with no duration (an empty bar,
  ///    resuming past the recap);
  ///  - the last episode of a season (or a download with no list) ~95% in
  ///    moves it to the next season's first episode, or drops it when the
  ///    series is over (cw_advance.dart);
  ///  - a movie ~95% in is dropped so it doesn't linger at ~100%.
  ///
  /// Returns the pending roll-forward write (for tests); fire-and-forget
  /// for the players.
  Future<void>? maybeClear({
    required Duration position,
    required Duration duration,
    PrefetchedEpisode? prefetched,
  }) {
    if (_cleared || isLive) return null;
    if (duration.inSeconds <= 0) return null;
    final frac = position.inSeconds / duration.inSeconds;
    final s = snapshot();
    final repo = _r;
    if (s.hasSameSeasonNext && frac >= kCwRollForwardThreshold) {
      _cleared = true;
      return _rollForward(repo, s, prefetched);
    } else if (!s.hasSameSeasonNext && frac >= kCwDropThreshold) {
      _cleared = true;
      if (isEpisodeOfSeries(s.parentId, s.cwId)) {
        return advanceContinueWatching(
          repo,
          CwAdvanceRequest(
            pluginId: s.pluginId,
            seriesId: s.parentId,
            currentCwId: s.cwId,
            currentTitle: s.title,
            seasonNumber: s.seasonNumber,
            episodeNumber: s.episodeNumber,
            knownSeasonIds: s.knownSeasonIds,
            sourceLabel: s.sourceLabel,
            showTitle: s.showTitle,
            seriesPoster: s.seriesPoster,
            seriesCoverUrl: s.seriesCoverUrl,
            fallbackPoster: s.fallbackPoster,
            rating: s.rating,
            genres: s.genres,
            plot: s.plot,
            year: s.year,
          ),
        );
      }
      return repo
          .deleteProgress(providerID: s.pluginId, playableID: s.cwId)
          .then((_) {});
    }
    return null;
  }

  // Everything is captured in [s] up front: the lookup is async and the
  // screen may have moved on to the next episode by the time it lands.
  Future<void> _rollForward(
    MediaRepository repo,
    CwSnapshot s,
    PrefetchedEpisode? prefetched,
  ) async {
    final next = s.episodeIndex + 1;
    final nextId = s.episodeList[next];
    final nextTitle =
        next < s.episodeTitles.length ? s.episodeTitles[next] : '';
    try {
      final nextStreamId = await streamIdForNextEpisode(
        repo,
        pluginId: s.pluginId,
        nextEpisodeId: nextId,
        sourceLabel: s.sourceLabel,
        prefetched: prefetched,
      );
      await repo.updateProgress(
        pluginId: s.pluginId,
        mediaId: nextStreamId,
        parentId: s.parentId,
        position: const Duration(seconds: 31),
        title: nextTitle.isNotEmpty ? nextTitle : s.showTitle,
        showTitle: s.showTitle,
        // The *next* episode's own thumbnail, not the current one's.
        poster: posterForEpisode(
          episodeThumbs: s.episodeThumbs,
          index: next,
          seriesCoverUrl: s.seriesCoverUrl,
          seriesPoster: s.seriesPoster,
          fallback: s.fallbackPoster,
        ),
        rating: s.rating,
        genres: s.genres,
        plot: s.plot,
        year: s.year,
        seasonNumber: numberForEpisode(s.seasonNumbers, next),
        episodeNumber: numberForEpisode(s.episodeNumbers, next),
      );
    } catch (_) {}
    await repo.deleteProgress(providerID: s.pluginId, playableID: s.cwId);
  }
}

/// The other device's name without the «» some servers already put around
/// it: the players quote it themselves ("spostata su «TV salotto»"), and
/// the two together read ««TV salotto»».
String bareDeviceLabel(String label) {
  var s = label.trim();
  while (s.length >= 2 &&
      ((s.startsWith('«') && s.endsWith('»')) ||
          (s.startsWith('"') && s.endsWith('"')))) {
    s = s.substring(1, s.length - 1).trim();
  }
  return s;
}
