import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_sizing.dart';
import '../../shared/widgets/open_catalog_item.dart';
import '../mobile_item_sheet.dart';
import '../mobile_live_sheet.dart';
import 'press_scale.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Touch equivalent of the TV [MediaCatalogCard]: tap to open, no focus
/// treatment. `landscape` picks a 16:9 still (live / landscape catalogs)
/// over the default 2:3 poster.
class MobilePosterCard extends StatelessWidget {
  final String pluginId;
  final CatalogItem item;
  final bool landscape;
  final double width;

  const MobilePosterCard({
    super.key,
    required this.pluginId,
    required this.item,
    required this.width,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = landscape ? 16 / 9 : 2 / 3;
    final imgW = cacheWidthFor(context, width);
    final isLive = item.mediaType == 'live';
    return SizedBox(
      width: width,
      child: PressScale(
        onTap: () => isLive
            ? showLiveSheet(context, pluginId, item)
            : openCatalogItem(context, pluginId, item),
        onLongPress: () => isLive
            ? showLiveSheet(context, pluginId, item)
            : showItemSheet(context, pluginId, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: ratio,
                child: item.posterUrl.isNotEmpty
                    ? CachedNetworkImage(
                        // Web-only, no-op on every other platform — see image_sizing.dart's
                        // "ImageRenderMethodForWeb.HttpGet" section for why every
                        // CachedNetworkImage call site in the app sets this.
                        imageRenderMethodForWeb:
                            ImageRenderMethodForWeb.HttpGet,
                        imageUrl: posterSrc(item.posterUrl, imgW),
                        memCacheWidth: imgW,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 180),
                        placeholder: (_, __) =>
                            const ColoredBox(color: AppTheme.surface2),
                        errorWidget: (_, __, ___) =>
                            _Fallback(title: item.title),
                      )
                    : _Fallback(title: item.title),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMid,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String title;
  const _Fallback({required this.title});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface2,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            maxLines: 3,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textLow, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
