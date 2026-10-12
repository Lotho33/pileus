import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' show DownloadInfo;
import '../media/data/continue_watching_item.dart';
import '../media/data/media_repository.dart';

/// Router `extra` for playing a completed download — the same map from the
/// TV downloads screen and the phone/desktop downloads page.
///
/// A download's progress is tracked under the original plugin/media ids
/// (see PlaybackArgs.directUrl's own doc) exactly like a regular stream, so
/// replaying one resumes from Continue Watching — same lookup and "real
/// progress" guard as _WatchButton._checkResume
/// (details_screen/watch_button.dart): a CW row parked at ~31s just to clear
/// mycelium's progress_time>=30 filter isn't a genuine resume point.
///
/// `directUrlContainer` tells the player the file is progressive (MKV…)
/// instead of letting it guess from the URL.
Future<Map<String, dynamic>> downloadPlaybackExtra(DownloadInfo info) async {
  ContinueWatchingItem? resume;
  try {
    final items = await getIt<MediaRepository>()
        .getContinueWatching(pluginId: info.pluginId);
    resume = items
        .where((i) => i.parentID.isEmpty && i.playableID == info.mediaId)
        .firstOrNull;
    if (resume != null && resume.totalTime <= 0 && resume.progressTime <= 35) {
      resume = null;
    }
  } catch (_) {
    // best-effort — falls back to starting from 0.
  }
  return <String, dynamic>{
    'directUrl': info.fileUrl,
    'directUrlContainer': info.container,
    'title': info.title,
    'showTitle': info.seriesTitle,
    'poster': info.poster,
    'parentId': info.parentId,
    if (resume != null) 'seekTo': resume.progressTime.toInt(),
  };
}
