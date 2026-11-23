import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'default_avatars.dart';
import 'profile_avatar_cache.dart';

/// A profile's avatar as the settings screens show it: a built-in one
/// (avatar://N), the picture imported from mycelium's dashboard, or the
/// initial when there is none (or the picture fails). Square: the caller
/// clips it to its own shape.
class ProfileAvatar extends StatelessWidget {
  final String url;
  final String name;
  final double size;
  const ProfileAvatar(
      {super.key, required this.url, required this.name, required this.size});

  Widget _initial() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withValues(alpha: 0.8),
              AppTheme.primary.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Center(
          child: Text(
            name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
            style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.41,
                fontWeight: FontWeight.w700),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (isDefaultAvatarUrl(url)) {
      child = DefaultAvatarView(index: defaultAvatarIndex(url), size: size);
    } else if (url.isEmpty) {
      child = _initial();
    } else {
      child = CachedNetworkImage(
        // Web-only, no-op on every other platform — see image_sizing.dart's
        // "ImageRenderMethodForWeb.HttpGet" section for why every
        // CachedNetworkImage call site in the app sets this.
        imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
        imageUrl: url,
        cacheManager: profileAvatarCache,
        cacheKey: profileAvatarCacheKey(url),
        memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(64, 512),
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => const ColoredBox(color: AppTheme.surface2),
        errorWidget: (_, __, ___) => _initial(),
      );
    }
    return SizedBox(width: size, height: size, child: child);
  }
}
