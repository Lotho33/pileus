import '../../core/grpc/clients/media_client.dart' show DetailsResponse;
import '../media/data/media_repository.dart';
import 'player_tuning.dart';

/// A fully resolved next episode, warmed in the background — see
/// [EpisodePrefetcher]. Everything a caller needs to either open it directly
/// (bypassing PlaybackBloc, no spinner) or carry its fresher metadata
/// forward into the currently-tracked episode info once it becomes current.
class PrefetchedEpisode {
  final String mediaId;
  final String resolvedUrl;
  final Map<String, String> httpHeaders;
  final String sourceLabel;
  final String? title;
  final double? rating;
  final int? durationSeconds;
  final int? year;
  final String? skipTimesJson;

  const PrefetchedEpisode({
    required this.mediaId,
    required this.resolvedUrl,
    required this.httpHeaders,
    required this.sourceLabel,
    this.title,
    this.rating,
    this.durationSeconds,
    this.year,
    this.skipTimesJson,
  });
}

/// Best-effort: resolves the next episode's stream (+ its own fresh
/// rating/duration/year/skip markers) ahead of time, once the current one
/// is mostly watched, so switching episodes opens the cached URL directly
/// instead of cold-resolving (getStreams + resolveStream, which on a slow
/// plugin is several seconds spent staring at a spinner right when the
/// episode you were watching just ended).
///
/// Backend-agnostic — this only ever talks to [MediaRepository], never a
/// player engine/video element, so all four platform screens can share one
/// implementation instead of each keeping a hand-copied algorithm (and,
/// before this was extracted, one algorithm subtly missing the rating/
/// duration/year fields the others carried — see desktop_playback_screen.
/// dart's history for the continue-watching staleness bug that caused).
///
/// Any failure here is silent — the actual switch just falls back to a cold
/// resolve, exactly as if prefetch had never started.
class EpisodePrefetcher {
  final MediaRepository repo;
  final String pluginId;

  EpisodePrefetcher({required this.repo, required this.pluginId});

  bool _busy = false;
  // Guards against a stale in-flight prefetch (its getStreams/resolveStream/
  // getDetails chain can take up to ~50s combined) overwriting a fresher
  // one, or landing after [clear] already dropped it (e.g. the user hit
  // "previous" instead of letting the prefetched "next" land).
  int _generation = 0;
  PrefetchedEpisode? _cached;

  bool get isBusy => _busy;
  PrefetchedEpisode? get cached => _cached;

  /// Call on every position tick while a (non-live) episode is playing.
  /// Starts the background prefetch once [position]/[duration] crosses
  /// [kPrefetchThreshold], unless one is already running or already cached
  /// for [nextEpisodeId]. No-ops below [kMinDurationForEndOfEpisodeLogicSec]
  /// — too short for prefetch to be worth the extra plugin calls.
  void maybeStart({
    required Duration position,
    required Duration duration,
    required String? nextEpisodeId,
    required String currentSourceLabel,
    String? nextEpisodeFallbackTitle,
  }) {
    if (_busy || nextEpisodeId == null) return;
    if (_cached?.mediaId == nextEpisodeId) return;
    if (duration.inSeconds <= kMinDurationForEndOfEpisodeLogicSec) return;
    if (position.inSeconds / duration.inSeconds < kPrefetchThreshold) return;
    _start(nextEpisodeId, nextEpisodeFallbackTitle, currentSourceLabel);
  }

  Future<void> _start(
    String nextId,
    String? fallbackTitle,
    String currentSourceLabel,
  ) async {
    final generation = ++_generation;
    _busy = true;
    try {
      final streamsRes = await repo
          .getStreams(pluginId, nextId)
          .timeout(kPrefetchGetStreamsTimeout);
      if (generation != _generation) return;
      final sources = streamsRes.sources;
      final match = (currentSourceLabel.isEmpty
              ? null
              : sources
                  .where((s) =>
                      s.label.toLowerCase() == currentSourceLabel.toLowerCase())
                  .firstOrNull) ??
          (sources.isNotEmpty ? sources.first : null);
      if (match == null) return;

      String? resolvedUrl;
      Map<String, String> httpHeaders = const {};
      String? skipTimesJson;
      await for (final ev in repo
          .resolveStream(pluginId, match.id)
          .timeout(kPrefetchResolveTimeout)) {
        if (ev.hasResult()) {
          resolvedUrl = ev.result.resolvedUrl;
          httpHeaders = ev.result.httpHeaders;
          skipTimesJson = ev.result.extra['skip_times'];
          break;
        }
      }
      if (generation != _generation ||
          resolvedUrl == null ||
          resolvedUrl.isEmpty) {
        return;
      }

      DetailsResponse? details;
      try {
        details = await repo
            .getDetails(pluginId, nextId)
            .timeout(kPrefetchGetDetailsTimeout);
      } catch (_) {
        // metadata is a bonus — a resolved stream with no fresh
        // rating/duration/year is still a win over cold-resolving later.
        // Already catches a timeout too, not just a thrown error.
      }
      if (generation != _generation) return;

      final ep =
          (details != null && details.hasEpisode()) ? details.episode : null;
      _cached = PrefetchedEpisode(
        mediaId: nextId,
        resolvedUrl: resolvedUrl,
        httpHeaders: httpHeaders,
        sourceLabel: match.label,
        title: (details != null && details.item.title.isNotEmpty)
            ? details.item.title
            : fallbackTitle,
        rating: (ep != null && ep.vote > 0) ? ep.vote : null,
        durationSeconds: (ep != null && ep.duration > 0) ? ep.duration * 60 : null,
        year: (details != null && details.item.year > 0) ? details.item.year : null,
        skipTimesJson: skipTimesJson,
      );
    } catch (_) {
      // ignore — falls back to a cold resolve when actually switching
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  /// Invalidates any prefetch in flight or already cached — call whenever
  /// the episode actually being switched to isn't [cached] (so its result,
  /// once it lands, doesn't get treated as still current), and once
  /// [cached] has actually been consumed by opening it.
  void clear() {
    _generation++;
    _busy = false;
    _cached = null;
  }
}
