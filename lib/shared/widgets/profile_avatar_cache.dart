import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for the profile pictures imported from mycelium's dashboard —
/// kept apart from the posters' one, where hundreds of images a session
/// would evict them. A handful of tiny files (256 px JPEG), so a long life:
/// the profile screen is the first thing shown, and shows them even when
/// the server is slow or unreachable.
final BaseCacheManager profileAvatarCache = CacheManager(Config(
  'pileusProfileAvatars',
  stalePeriod: const Duration(days: 365),
  maxNrOfCacheObjects: 32,
));

/// Cache key of an avatar URL. mycelium makes the URL absolute with the
/// address each client reached it on, so the same picture has a different
/// URL on LAN and VPN: the key keeps only its path and `?v=`, which changes
/// with every new picture.
String profileAvatarCacheKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.path.contains('/profile-avatar/')) return url;
  return 'avatar:${uri.path}?${uri.query}';
}
