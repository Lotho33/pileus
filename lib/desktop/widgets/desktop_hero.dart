import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_sizing.dart';
import '../../features/media/data/media_repository.dart';
import '../../features/player/episode_poster.dart';
import '../../features/player/resolve_and_play.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/open_catalog_item.dart';
import 'desktop_dialogs.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Large-screen hero: the first item of the active plugin's first non-live
/// catalog, shown as a wide backdrop with a left-aligned logo / metadata and
/// Play + Info actions. Static (no cycling) — same choice as the mobile hero.
class DesktopHero extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  final double height;
  final Breakpoint bp;

  const DesktopHero({
    super.key,
    required this.pluginId,
    required this.item,
    required this.height,
    required this.bp,
  });

  @override
  State<DesktopHero> createState() => _DesktopHeroState();
}

// AutomaticKeepAliveClientMixin: the outer page (desktop_home_screen.dart)
// is a plain ListView, whose default ~250px cacheExtent is nowhere near
// this widget's own height (440-760px) — scroll down even a few carousel
// rows and the hero goes far enough outside that window that Flutter fully
// deactivates its Element, not just keeps it offscreen. Scrolling back then
// rebuilds it from scratch: a fresh initState()/_enrich() (an unexpected
// extra GetDetails call — reported 2026-09-14, that's what surfaced this)
// and a brand new CachedNetworkImage decode for the backdrop/logo racing
// against whatever GPU resource the just-torn-down instance was still
// holding — the far more likely trigger for the CanvasKit
// "texImage2D: no image" black-poster bug than the raster-cache theory
// originally chased for it. Opting into keep-alive here holds this one
// (single, not-per-item) widget's Element alive across any scroll distance,
// the same way the rest of the page's carousels are already fine with their
// own — much cheaper — dispose/recreate cycle.
class _DesktopHeroState extends State<DesktopHero>
    with AutomaticKeepAliveClientMixin {
  final _repo = getIt<MediaRepository>();
  List<String> _genres = const [];
  String _logoUrl = '';
  String _backdrop = '';
  String _plot = '';
  bool _enriched = false;
  int _enrichSeq = 0; // guards against a stale getDetails writing back

  @override
  void initState() {
    super.initState();
    _reset();
    _enrich();
  }

  @override
  void didUpdateWidget(DesktopHero old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id) {
      _reset();
      _enrich();
    }
  }

  void _reset() {
    _genres = const [];
    _plot = '';
    _enriched = false;
    _logoUrl = widget.item.logoUrl;
    final ex = widget.item.extra;
    _backdrop = (ex['fanart_url']?.isNotEmpty ?? false)
        ? ex['fanart_url']!
        : (ex['catalog_bg_url']?.isNotEmpty ?? false)
            ? ex['catalog_bg_url']!
            : widget.item.bannerUrl;
  }

  Future<void> _enrich() async {
    final seq = ++_enrichSeq;
    try {
      final d = await _repo.getDetails(widget.pluginId, widget.item.id);
      if (!mounted || seq != _enrichSeq) return;
      List<String> genres = const [];
      String logo = _logoUrl;
      String fanart = '';
      String plot = '';
      if (d.hasSeries()) {
        genres = d.series.genres;
        if (logo.isEmpty) logo = d.series.logoUrl;
        fanart = d.series.fanartUrl;
        plot = d.series.plot;
      } else if (d.hasMovie()) {
        genres = d.movie.genres;
        if (logo.isEmpty) logo = d.movie.logoUrl;
        fanart = d.movie.fanartUrl;
        plot = d.movie.plot;
      }
      setState(() {
        _genres = genres;
        _logoUrl = logo;
        _plot = plot;
        _enriched = true;
        if (_backdrop.isEmpty && fanart.isNotEmpty) _backdrop = fanart;
      });
    } catch (_) {
      if (mounted && seq == _enrichSeq) setState(() => _enriched = true);
    }
  }

  void _info() => openCatalogItem(context, widget.pluginId, widget.item);

  void _play() {
    final mt = widget.item.mediaType;
    if (mt == 'movie' || mt == 'episode') {
      resolveAndPlay(
        context,
        widget.pluginId,
        widget.item.id,
        extra: {
          'title': widget.item.title,
          // For a movie, the CW poster must be the horizontal
          // extra['cover_url'] when the plugin has one, never the plain
          // backdrop/vertical poster (_backdrop, already resolved
          // synchronously in _reset(), stands in for "fanart" here — see
          // posterForMovie()). An episode keeps its own thumbnail as-is,
          // same as every other launch site.
          'poster': mt == 'movie'
              ? posterForMovie(
                  coverUrl: widget.item.extra['cover_url'] ?? '',
                  fanartUrl: _backdrop,
                  posterUrl: widget.item.posterUrl,
                )
              : widget.item.posterUrl,
          'mediaType': mt,
        },
        sourcePicker: showDesktopSourcePicker,
      );
    } else {
      _info();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin contract
    final it = widget.item;
    final imgW = backdropCacheWidth(context);
    final big = widget.bp.atLeastLarge;
    // Same left inset as the catalog rows below (bp.gutter) so the hero copy
    // and the carousels share one left edge.
    final pad = widget.bp.gutter;
    final maxW = big ? 760.0 : 620.0;
    final logoH = big ? 168.0 : 132.0;
    final logoW = big ? 560.0 : 460.0;
    final meta = <String>[
      if (it.rating > 0) '★ ${it.rating.toStringAsFixed(1)}',
      if (it.year > 0) '${it.year}',
      ..._genres.take(3),
    ].join('   ·   ');

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_backdrop.isNotEmpty)
            CachedNetworkImage(
              // Web-only, no-op on every other platform — see image_sizing.dart's
              // "ImageRenderMethodForWeb.HttpGet" section for why every
              // CachedNetworkImage call site in the app sets this.
              imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
              imageUrl: backdropSrc(_backdrop, imgW),
              memCacheWidth: imgW,
              fit: BoxFit.cover,
              alignment: const Alignment(0.2, -0.2),
              placeholder: (_, __) => const ColoredBox(color: AppTheme.surface),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: AppTheme.surface),
            )
          else
            const ColoredBox(color: AppTheme.surface),
          // Left + bottom scrim so the copy sits on solid ground and the art
          // melts into the page below.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.55, 1.0],
                colors: [
                  Color(0xF20D0D1A),
                  Color(0x660D0D1A),
                  Color(0x000D0D1A),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0.0, 0.45],
                colors: [AppTheme.bg, Colors.transparent],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, big ? 56 : 44),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_logoUrl.isNotEmpty && !_logoUrl.endsWith('.svg'))
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: logoH, maxWidth: logoW),
                        child: CachedNetworkImage(
                          // Web-only, no-op on every other platform — see image_sizing.dart's
                          // "ImageRenderMethodForWeb.HttpGet" section for why every
                          // CachedNetworkImage call site in the app sets this.
                          imageRenderMethodForWeb:
                              ImageRenderMethodForWeb.HttpGet,
                          imageUrl: _logoUrl,
                          memCacheWidth: cacheWidthFor(context, logoW),
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          errorWidget: (_, __, ___) => _TitleText(it.title,
                              size: widget.bp.heroTitleSize),
                        ),
                      )
                    else if (_enriched)
                      _TitleText(it.title, size: widget.bp.heroTitleSize),
                    if (meta.isNotEmpty) ...[
                      SizedBox(height: big ? 18 : 14),
                      Text(
                        meta,
                        style: TextStyle(
                          color: AppTheme.textMid,
                          fontSize: big ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_plot.isNotEmpty) ...[
                      SizedBox(height: big ? 14 : 12),
                      Text(
                        _plot,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textMid,
                          fontSize: big ? 15 : 13.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                    SizedBox(height: big ? 28 : 22),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _play,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Riproduci'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.textHigh,
                            foregroundColor: AppTheme.bg,
                            padding: EdgeInsets.symmetric(
                                horizontal: big ? 32 : 26,
                                vertical: big ? 20 : 16),
                            textStyle: TextStyle(
                                fontSize: big ? 16 : 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _info,
                          icon: const Icon(Icons.info_outline_rounded),
                          label: const Text('Altre info'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textHigh,
                            side: const BorderSide(color: Colors.white24),
                            padding: EdgeInsets.symmetric(
                                horizontal: big ? 28 : 22,
                                vertical: big ? 20 : 16),
                            textStyle: TextStyle(
                                fontSize: big ? 16 : 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  final String title;
  final double size;
  const _TitleText(this.title, {this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppTheme.textHigh,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
    );
  }
}
