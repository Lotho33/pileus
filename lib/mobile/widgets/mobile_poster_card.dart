import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_sizing.dart';
import '../../shared/sdui/sport_theme.dart'
    show isLiveNow, liveStartAt, liveWhenShort;
import '../../shared/widgets/open_catalog_item.dart';
import '../../shared/widgets/language_badge.dart';
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.posterUrl.isNotEmpty
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
                                _Fallback(live: isLive),
                          )
                        : _Fallback(live: isLive),
                    if (isLive && isLiveNow(item.extra))
                      const Positioned(top: 6, left: 6, child: _LivePill())
                    else if (isLive && liveStartAt(item.extra) != null)
                      Positioned(
                          top: 6,
                          left: 6,
                          child: _StartPill(
                              label: liveWhenShort(liveStartAt(item.extra)!))),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: LanguageBadgePill(
                          lang: item.extra['lang'] ?? '',
                          subs: item.extra['subs'] ?? ''),
                    ),
                  ],
                ),
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

// No picture: an icon, not the title — the title is already right below.
class _Fallback extends StatelessWidget {
  final bool live;
  const _Fallback({required this.live});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface2,
      child: Center(
        child: Icon(
          live ? Icons.live_tv_rounded : Icons.movie_outlined,
          size: 36,
          color: AppTheme.textLow,
        ),
      ),
    );
  }
}

// Not on air yet: when it starts ("Oggi 20:45"), like the TV live card.
class _StartPill extends StatelessWidget {
  final String label;
  const _StartPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}

// Same cue as the TV live card.
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B3B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('• LIVE',
          style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }
}
