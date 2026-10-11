import 'dart:async';

import '../../core/grpc/clients/media_client.dart' show StreamSource;
import '../media/data/media_repository.dart';
import 'episode_prefetch.dart';

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
/// first one. Null only when [sources] is empty. Same rule the PlaybackBloc
/// and every episode-switch path already use.
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
    final res = await repo
        .getStreams(pluginId, nextEpisodeId)
        .timeout(_kLookupTimeout);
    final match = pickSourceByLabel(res.sources, sourceLabel);
    if (match != null && match.id.isNotEmpty) return match.id;
  } catch (_) {}
  return nextEpisodeId;
}
