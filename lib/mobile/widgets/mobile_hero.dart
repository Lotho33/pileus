import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_sizing.dart';
import '../../features/media/data/media_repository.dart';
import '../../shared/widgets/open_catalog_item.dart';

/// Home hero — the first item of the first (non-live) carousel, shown big
/// with logo / rating / genre and Play + Info actions. Replaces the TV
/// app's constantly-cycling hero background: on mobile it's one fixed
/// feature card for the session's first row.
class MobileHero extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;

  const MobileHero({super.key, required this.pluginId, required this.item});

  @override
  State<MobileHero> createState() => _MobileHeroState();
}

// AutomaticKeepAliveClientMixin — same fix and same reason as
// DesktopHero/_DesktopHeroState (2026-09-14): mobile_home_screen.dart's
// outer ListView has Flutter's default ~250px cacheExtent, far short of
// this widget's own height — scroll down a few rows and it's fully
// deactivated, not just offscreen. Scrolling back rebuilds it from scratch:
// an unexpected extra GetDetails (initState → _enrich() again) and a fresh
// CachedNetworkImage decode for the backdrop/logo/portrait racing the torn-
// down instance's own GPU resource — the likely trigger for the web build's
// CanvasKit "texImage2D: no image" black-poster bug, reproduced through this
// same widget when web runs the mobile shell at a phone-width viewport.
class _MobileHeroState extends State<MobileHero>
    with AutomaticKeepAliveClientMixin {
  final _repo = getIt<MediaRepository>();

  List<String> _genres = const [];
  String _logoUrl = '';
  String _backdrop = '';
  String _portrait = '';
  // False until getDetails returns. While false and there's no logo yet the
  // slot stays blank — so a title never flashes in and then gets replaced
  // by the logo a moment later.
  bool _enriched = false;
  int _enrichSeq = 0; // guards against a stale getDetails writing back

  @override
  void initState() {
    super.initState();
    _reset();
    _enrich();
  }

  @override
  void didUpdateWidget(MobileHero old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id) {
      _reset();
      _enrich();
    }
  }

  void _reset() {
    _genres = const [];
    _logoUrl = widget.item.logoUrl;
    // Backdrop only — never the portrait poster. Prefer a portrait key-art
    // if the server ever provides one (`extra['portrait_backdrop_url']` /
    // `extra['keyart_url']` — not populated today; when it is, the taller
    // hero below fills without cropping). Otherwise the landscape wide art,
    // same lookup order as the TV hero (home_hero_background.dart): it lives
    // in the catalog item's `extra` map, not the usually-empty banner_url.
    final ex = widget.item.extra;
    _portrait = (ex['portrait_backdrop_url']?.isNotEmpty ?? false)
        ? ex['portrait_backdrop_url']!
        : (ex['keyart_url']?.isNotEmpty ?? false)
            ? ex['keyart_url']!
            : '';
    _backdrop = _portrait.isNotEmpty
        ? _portrait
        : (ex['fanart_url']?.isNotEmpty ?? false)
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
      if (d.hasSeries()) {
        genres = d.series.genres;
        if (logo.isEmpty) logo = d.series.logoUrl;
        fanart = d.series.fanartUrl;
      } else if (d.hasMovie()) {
        genres = d.movie.genres;
        if (logo.isEmpty) logo = d.movie.logoUrl;
        fanart = d.movie.fanartUrl;
      }
      setState(() {
        _genres = genres;
        _logoUrl = logo;
        _enriched = true;
        if (_backdrop.isEmpty && fanart.isNotEmpty) _backdrop = fanart;
      });
    } catch (_) {
      if (mounted && seq == _enrichSeq) setState(() => _enriched = true);
    }
  }

  void _info() => openCatalogItem(context, widget.pluginId, widget.item);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin contract
    final it = widget.item;
    final size = MediaQuery.sizeOf(context);
    // Portrait key-art (rare) can fill a tall hero; landscape wide art gets
    // a more modest height so it isn't cropped to a thin band.
    final heroH = _portrait.isNotEmpty
        ? (size.height * 0.72).clamp(480.0, 760.0)
        : (size.height * 0.56).clamp(420.0, 560.0);
    final imgW = _portrait.isNotEmpty
        ? cacheWidthFor(context, size.width)
        : backdropCacheWidth(context);

    // Non-breaking spaces inside each token ( ) so a wrap can only
    // happen at the " · " separators — a multi-word genre ("Science
    // Fiction") moves to the next line whole instead of splitting.
    String nb(String s) => s.replaceAll(' ', ' ');
    final meta = <String>[
      if (it.rating > 0) '★ ${it.rating.toStringAsFixed(1)}',
      if (it.year > 0) '${it.year}',
      ..._genres.take(3).map(nb),
    ].join(' · ');

    return SizedBox(
      height: heroH,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_backdrop.isNotEmpty)
            CachedNetworkImage(
              imageUrl: backdropSrc(_backdrop, imgW, proxy: true),
              memCacheWidth: imgW,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.25),
              placeholder: (_, __) => const ColoredBox(color: AppTheme.surface),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: AppTheme.surface),
            )
          else
            const ColoredBox(color: AppTheme.surface),
          // Bottom scrim: text/logo sits on solid ground and the image
          // melts into the page background below.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.45, 1.0],
                colors: [
                  Color(0x11000000),
                  Color(0x66000000),
                  AppTheme.bg,
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed-height slot: the logo image and the fallback title
                // occupy the same 92px box, so the block doesn't shift when
                // the logo finishes loading. Blank until we know whether a
                // logo exists — no title flash before the logo appears.
                SizedBox(
                  height: 92,
                  width: size.width * 0.8,
                  child: (_logoUrl.isNotEmpty && !_logoUrl.endsWith('.svg'))
                      ? CachedNetworkImage(
                          imageUrl: _logoUrl,
                          memCacheWidth:
                              cacheWidthFor(context, size.width * 0.8),
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          fadeInDuration: const Duration(milliseconds: 150),
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) =>
                              Center(child: _TitleText(it.title)),
                        )
                      : _enriched
                          ? Center(child: _TitleText(it.title))
                          : const SizedBox.shrink(),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    meta,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _info,
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Dettagli'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.textHigh,
                    foregroundColor: AppTheme.bg,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  final String title;
  const _TitleText(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppTheme.textHigh,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
    );
  }
}
