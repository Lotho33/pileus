import 'dart:async';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' show DownloadInfo;
import '../media/data/continue_watching_item.dart';
import '../media/data/media_repository.dart';

// Offline (a train) the lookup can hang on a dead network for a long time
// before failing: past this, the copy on disk answers instead.
const _resumeLookupTimeout = Duration(seconds: 3);

/// Router `extra` for playing a completed download — the same map from the
/// TV downloads screen and the phone/desktop downloads page.
///
/// [localPath]: this device's own copy (DeviceDownloads), played instead of
/// the server's file_url — works with no server at all.
///
/// A download's progress is tracked under the original plugin/media ids
/// (see PlaybackArgs.directUrl's own doc) exactly like a regular stream, so
/// replaying one resumes from Continue Watching — same lookup and "real
/// progress" guard as _WatchButton._checkResume
/// (details_screen/watch_button.dart): a CW row parked at ~31s just to clear
/// mycelium's progress_time>=30 filter isn't a genuine resume point. With
/// the server unreachable the resume point comes from the copy of Continue
/// Watching on disk, with what was watched offline since laid over it.
///
/// `directUrlContainer` tells the player the file is progressive (MKV…)
/// instead of letting it guess from the URL.
Future<Map<String, dynamic>> downloadPlaybackExtra(DownloadInfo info,
    {String? localPath}) async {
  final repo = getIt<MediaRepository>();
  ContinueWatchingItem? resume;
  try {
    List<ContinueWatchingItem>? items;
    try {
      items = await repo
          .fetchContinueWatching(pluginId: info.pluginId)
          .timeout(_resumeLookupTimeout);
    } on TimeoutException {
      items = null;
    }
    items ??= repo.cachedContinueWatching() ?? const [];
    resume = items
        .where((i) => i.providerID == info.pluginId)
        .where((i) => i.playableID == info.mediaId)
        .firstOrNull;
    if (resume != null && resume.totalTime <= 0 && resume.progressTime <= 35) {
      resume = null;
    }
  } catch (_) {
    // best-effort — falls back to starting from 0.
  }
  final local = localPath != null && localPath.isNotEmpty;
  return <String, dynamic>{
    'directUrl': local ? localPath : info.fileUrl,
    'directUrlContainer': info.container.isNotEmpty ? info.container : 'mkv',
    'title': info.title,
    'showTitle': info.seriesTitle,
    'poster': info.poster,
    'parentId': info.parentId,
    if (resume != null) 'seekTo': resume.progressTime.toInt(),
  };
}
