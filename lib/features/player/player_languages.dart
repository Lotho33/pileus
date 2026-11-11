import '../../core/di/injection.dart' show getIt;
import '../../core/grpc/clients/media_client.dart' show StreamSource;
import '../media/data/media_repository.dart';

/// The language versions (sources) of what's playing, for the player's
/// "Lingua" menu. Once per title: loading is a no-op until the media
/// changes. Was the same few lines in all four player screens.
class PlayerLanguages {
  List<StreamSource> sources = const [];
  String? loadedFor;

  /// True when the sources were (re)loaded — the screen may need a rebuild.
  /// A failure leaves the menu as it was and is retried on the next call.
  Future<bool> load(String pluginId, String mediaId) async {
    if (loadedFor == mediaId) return false;
    try {
      final r = await getIt<MediaRepository>().getStreams(pluginId, mediaId);
      sources = r.sources;
      loadedFor = mediaId;
      return true;
    } catch (_) {
      return false;
    }
  }
}
