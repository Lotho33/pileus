import 'dart:async';

import '../../core/grpc/clients/media_client.dart'
    show SeasonInfo, StreamSource;
import '../media/data/media_repository.dart';
import 'episode_prefetch.dart';
import 'source_preference.dart';

/// "Same source, same language" across a binge and across a Continue
/// Watching resume — shared by every player screen.
///
/// On the plugins Pileus talks to, a *source* (a GetStreams entry) is what
/// carries the language: an episode typically exposes "ITA" and "SUB ITA" as
/// two sources with distinct stream ids (the id itself has the language/
/// variant baked in). So:
///
///  - Continue Watching must store the *stream id* that was playing, not the
///    bare episode id: resolving a bare episode id gives the plugin's default
///    source, i.e. a resume could silently switch language. See
///    [PlaybackReady.streamId].
///  - The next episode must be resolved with the same source *label* as the
///    one playing. A Continue Watching launch carries only the stream id, not
///    its label — [inferSourceLabel] recovers it.

const _kLookupTimeout = Duration(seconds: 10);

/// Picks the source whose label matches [label] (case-insensitive), else the
/// first one. Null only when [sources] is empty.
///
/// The label-continuity step: what an episode switch or a next-episode
/// prefetch uses to stay on the language being watched. A fresh Play goes
/// through choosePlaySource (source_preference.dart), which adds the
/// profile's language preference on top of this.
StreamSource? pickSourceByLabel(List<StreamSource> sources, String label) {
  if (sources.isEmpty) return null;
  if (label.isNotEmpty) {
    final l = label.toLowerCase();
    for (final s in sources) {
      if (s.label.toLowerCase() == l) return s;
    }
  }
  return sources.first;
}

/// The stream id a Play of [mediaId] would send to ResolveStream when the
/// user doesn't choose a source by hand — GetStreams (cached by the
/// repository, so the details screen's own call is reused) then
/// choosePlaySource, the same rule every Play entry point uses: the stream
/// warmer must prepare byte-for-byte the stream id the Play then asks for
/// (the server coalesces on it, plugins cache per language). Null when
/// there's no source. Throws what GetStreams throws.
Future<String?> playStreamIdFor(
  MediaRepository repo, {
  required String pluginId,
  required String mediaId,
  String preferredLabel = '',
  String seriesId = '',
}) async {
  final res = await repo.getStreams(pluginId, mediaId);
  final id = choosePlaySource(res.sources,
          explicitLabel: preferredLabel, pluginId: pluginId, seriesId: seriesId)
      ?.id;
  return (id == null || id.isEmpty) ? null : id;
}

/// The stream id a details page's main Play button resolves when there's
/// nothing to resume — mirrors its "play from the start" path on mobile and
/// desktop: a series plays the first episode of the first season that has
/// any (the season list cached by the repository, as the page loaded it),
/// a movie plays the title itself; either way through [playStreamIdFor].
/// Null when that can't be known yet (no seasons loaded, empty season).
Future<String?> defaultPlayStreamId(
  MediaRepository repo, {
  required String pluginId,
  required String itemId,
  required bool isSeries,
  List<SeasonInfo> seasons = const [],
}) async {
  if (!isSeries) {
    return playStreamIdFor(repo, pluginId: pluginId, mediaId: itemId);
  }
  if (seasons.isEmpty) return null;
  final season = seasons.firstWhere((s) => s.episodeCount > 0,
      orElse: () => seasons.first);
  final b = await repo.browse(pluginId, season.directoryId, '', cache: true);
  if (b.episodes.isEmpty) return null;
  return playStreamIdFor(repo,
      pluginId: pluginId, mediaId: b.episodes.first.id, seriesId: itemId);
}

/// Label of the source [streamId] belongs to, looked up among [episodeId]'s
/// own sources. Null when it can't be determined (lookup failed, or
/// [streamId] isn't one of them — e.g. an older Continue Watching row that
/// stored the bare episode id). Best-effort, never throws.
Future<String?> inferSourceLabel(
  MediaRepository repo, {
  required String pluginId,
  required String episodeId,
  required String streamId,
}) async {
  if (episodeId.isEmpty || streamId.isEmpty || episodeId == streamId) {
    return null;
  }
  try {
    final res =
        await repo.getStreams(pluginId, episodeId).timeout(_kLookupTimeout);
    for (final s in res.sources) {
      if (s.id == streamId && s.label.isNotEmpty) return s.label;
    }
  } catch (_) {}
  return null;
}

/// The id a Continue Watching "roll-forward" row for [nextEpisodeId] should
/// carry: the stream id of its [sourceLabel] source, so resuming it later
/// keeps the language of the episode being finished now. Uses [prefetched]
/// when it already resolved that episode (it runs at 80%, before the 90%
/// roll-forward), otherwise one GetStreams. Falls back to the bare
/// [nextEpisodeId] — the previous behaviour — if neither works out.
Future<String> streamIdForNextEpisode(
  MediaRepository repo, {
  required String pluginId,
  required String nextEpisodeId,
  required String sourceLabel,
  PrefetchedEpisode? prefetched,
}) async {
  if (prefetched != null &&
      prefetched.mediaId == nextEpisodeId &&
      prefetched.streamId.isNotEmpty) {
    return prefetched.streamId;
  }
  try {
    final res =
        await repo.getStreams(pluginId, nextEpisodeId).timeout(_kLookupTimeout);
    final match = pickSourceByLabel(res.sources, sourceLabel);
    if (match != null && match.id.isNotEmpty) return match.id;
  } catch (_) {}
  return nextEpisodeId;
}
