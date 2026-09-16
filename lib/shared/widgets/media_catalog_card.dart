import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_scale.dart';
import '../../core/utils/image_sizing.dart';
import 'tv_focusable.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

const _kFocusColor = Color(0xFF7C6AF7);

class MediaCatalogCard extends StatelessWidget {
  final String title;
  final String posterUrl;
  final double? rating;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool wide; // 16:9 (live/landscape) vs 2:3 (poster) aspect
  final bool isFirst; // true → handles ← by calling onNavigateLeft
  final double width; // actual on-screen size, computed by the caller from
  final double
      height; // the real grid/screen constraints — never hardcoded here.
  final VoidCallback? onFocused; // fired when this card gains focus
  final VoidCallback? onNavigateLeft; // fired when isFirst && ← pressed
  final VoidCallback? onNavigateUp; // fired when ↑ pressed (first section only)
  final VoidCallback?
      onNavigateDown; // fired when ↓ pressed (first section only)

  const MediaCatalogCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.onTap,
    required this.width,
    required this.height,
    this.focusNode,
    this.rating,
    this.autofocus = false,
    this.wide = false,
    this.isFirst = false,
    this.onFocused,
    this.onNavigateLeft,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  void _onFocusChange(BuildContext context, bool v) {
    if (v) {
      onFocused?.call();
      // Scroll to visible only for non-first cards; first card is always visible.
      // Use a short delay so the ListView has time to lay out after focus.
      if (!isFirst) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (v) => _onFocusChange(context, v),
      onActivate: onTap,
      // First card: ← goes to nav
      onLeft: isFirst ? onNavigateLeft : null,
      onUp: onNavigateUp,
      onDown: onNavigateDown,
      // Scale the whole column (poster + title) on focus: scaling only the
      // poster made it grow over the title sitting right below it.
      builder: (context, focused) => AnimatedScale(
        scale: focused ? 1.08 : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppScale.focusDuration,
              curve: AppScale.focusCurve,
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: focused ? _kFocusColor : Colors.transparent,
                  width: 3,
                ),
                // Focus cue is the border + AnimatedScale above; no blurred
                // glow (shader-compile hitch on weak GPUs). See
                // AppScale.focusGlow.
                boxShadow: const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            // Web-only, no-op on every other platform — see image_sizing.dart's
                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                            // CachedNetworkImage call site in the app sets this.
                            imageRenderMethodForWeb:
                                ImageRenderMethodForWeb.HttpGet,
                            imageUrl: posterSrc(
                                posterUrl, cacheWidthFor(context, width)),
                            fit: BoxFit.cover,
                            memCacheWidth: cacheWidthFor(context, width),
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (_, __) =>
                                const ColoredBox(color: Color(0xFF1A1A2A)),
                            errorWidget: (_, __, ___) =>
                                _Placeholder(title: title),
                          )
                        : _Placeholder(title: title),
                    if (!wide)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 80,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xCC000000)],
                            ),
                          ),
                        ),
                      ),
                    if (rating != null && rating! > 0)
                      Positioned(
                        right: AppScale.space(context, 6),
                        bottom: AppScale.space(context, 6),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: AppScale.space(context, 6),
                              vertical: AppScale.space(context, 3)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  size: AppScale.space(context, 12),
                                  color: const Color(0xFFFFD700)),
                              SizedBox(width: AppScale.space(context, 3)),
                              Text(
                                rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppScale.caption(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!wide) ...[
              SizedBox(height: AppScale.space(context, 8)),
              SizedBox(
                width: width,
                child: Text(
                  title,
                  style: TextStyle(
                    color: focused ? Colors.white : Colors.white70,
                    fontSize: AppScale.caption(context),
                    fontWeight: focused ? FontWeight.w600 : FontWeight.w400,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2A),
      alignment: Alignment.center,
      padding: EdgeInsets.all(AppScale.space(context, 8)),
      child: Text(
        title,
        style: TextStyle(
            color: Colors.white54, fontSize: AppScale.caption(context)),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
