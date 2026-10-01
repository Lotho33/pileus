import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/grpc/clients/media_client.dart';
import '../../../../core/perf_profile.dart';
import '../../../../core/utils/image_sizing.dart';
import '../../../../shared/sdui/sport_theme.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

// ── hero background — full-bleed fanart with crossfade ───────────────────────
// Image fills the screen; a bottom gradient fades it seamlessly into the dark
// carousel area without any visible seam. Extracted from home_screen.dart —
// self-contained (own state, no callbacks back into the parent screen), one
// of the first pieces split out per the design audit's file-size
// recommendation (§08).

class HomeHeroBackground extends StatefulWidget {
  final CatalogItem? item;
  final String sportCat;
  // When true, never derive the hero from item.extra/posterUrl — always the
  // neutral/anonymous fallback (flat dark, or the sport gradient when
  // sportCat is set) that already renders whenever no image is available.
  // Driven by CatalogDef.disableHeroBackground — see home_screen.dart's
  // _heroBackgroundDisabled.
  final bool forceAnonymous;
  // Confined mode ("performance" hero layout): the image lives in a small
  // box top-right instead of full-bleed, so it drops the internal
  // bottom-fade-to-black gradient (that's only there to blend a full-screen
  // image into the carousel area below it).
  final bool confined;
  const HomeHeroBackground({
    super.key,
    required this.item,
    this.sportCat = '',
    this.forceAnonymous = false,
    this.confined = false,
  });

  @override
  State<HomeHeroBackground> createState() => _HomeHeroBackgroundState();
}

class _HomeHeroBackgroundState extends State<HomeHeroBackground> {
  String _urlA = '';
  String _urlB = '';
  bool _showA = true;

  String _urlFor(CatalogItem? it) {
    if (widget.forceAnonymous) return '';
    if (it == null) return '';
    final fanart = it.extra['fanart_url'] ?? '';
    if (fanart.isNotEmpty) return fanart;
    // Catalog-level static background provided by the plugin (any catalog type)
    final catalogBg = it.extra['catalog_bg_url'] ?? '';
    if (catalogBg.isNotEmpty) return catalogBg;
    // For live/sport items skip posterUrl (usually low-quality team logos); let
    // the sport gradient show instead.
    if ((it.extra['sport_cat'] ?? '').isNotEmpty) return '';
    return it.posterUrl;
  }

  @override
  void initState() {
    super.initState();
    _urlA = _urlFor(widget.item);
  }

  @override
  void didUpdateWidget(HomeHeroBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newUrl = _urlFor(widget.item);
    final curUrl = _showA ? _urlA : _urlB;
    if (newUrl == curUrl) return;
    setState(() {
      if (_showA) {
        _urlB = newUrl;
        _showA = false;
      } else {
        _urlA = newUrl;
        _showA = true;
      }
    });
  }

  Widget _layer(String url) {
    // In confined mode the image box is ~half the screen wide — decode/request
    // it at that size, not full-screen.
    final int srcW = widget.confined
        ? cacheWidthFor(context, MediaQuery.sizeOf(context).width * 0.55)
        : backdropCacheWidth(context);
    // If a real image URL is available (fanart, catalog_bg_url, or posterUrl for
    // non-live content), show it — even for sport items with catalog_bg_url set.
    if (url.isNotEmpty) {
      return Stack(fit: StackFit.expand, children: [
        // Sport gradient as base under the image (tints dark areas with sport color)
        if (widget.sportCat.isNotEmpty)
          _SportGradientBg(sportCat: widget.sportCat)
        else
          const ColoredBox(color: Color(0xFF0A0A0F)),
        Positioned.fill(
          child: CachedNetworkImage(
            // Web-only, no-op on every other platform — see image_sizing.dart's
            // "ImageRenderMethodForWeb.HttpGet" section for why every
            // CachedNetworkImage call site in the app sets this.
            imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
            imageUrl: backdropSrc(url, srcW, proxy: true),
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.25),
            memCacheWidth: srcW,
            fadeInDuration: const Duration(milliseconds: 200),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        // Full-bleed only: the long fade blends a full-screen image into the
        // dark carousel area below it. The confined box has clean clipped
        // (rounded) edges and doesn't need it.
        if (!widget.confined)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.40, 1.0],
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
            ),
          ),
      ]);
    }
    // No image: use sport gradient for live/sport content, else flat dark.
    // In confined mode there's no full-screen area to fill — render nothing
    // so the empty box doesn't show as a dark rectangle beside the metadata.
    if (widget.sportCat.isNotEmpty) {
      return _SportGradientBg(sportCat: widget.sportCat);
    }
    return widget.confined
        ? const SizedBox.shrink()
        : const ColoredBox(color: Color(0xFF0A0A0F));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Each layer in its own RepaintBoundary: during the crossfade the
        // compositor reuses the cached raster of the settled layer instead
        // of re-decoding/re-scaling both full-screen images every frame — a
        // real cost on a low-power GPU.
        RepaintBoundary(child: _layer(_urlA)),
        RepaintBoundary(
          child: AnimatedOpacity(
            opacity: _showA ? 0.0 : 1.0,
            // This crossfade runs on *every* D-pad move through a carousel
            // (each focus change picks a new hero image), so it's kept
            // short — two full-screen layers blending for 400ms per
            // navigation step was continuous GPU fill during a scroll.
            // Instant under "hardware modesto".
            duration:
                lowPowerUi ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _layer(_urlB),
          ),
        ),
      ],
    );
  }
}

class _SportGradientBg extends StatelessWidget {
  final String sportCat;
  const _SportGradientBg({required this.sportCat});

  @override
  Widget build(BuildContext context) {
    final accent = sportAccentColor(sportCat);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF08090F)),
        // Primary radial glow — top-right quadrant
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.55, -0.65),
                radius: 1.1,
                colors: [
                  accent.withValues(alpha: 0.40),
                  accent.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // Secondary glow for depth — center-right
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.20, -0.25),
                radius: 0.65,
                colors: [
                  accent.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
        // Bottom fade to black for carousel legibility
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.35, 1.0],
                colors: [Colors.transparent, Colors.black],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
