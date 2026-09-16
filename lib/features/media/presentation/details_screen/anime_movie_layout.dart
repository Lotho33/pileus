// Part of details_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the layout-ratio comment, the
// DetailsScreen / _DetailsView / _DetailsContent entry chain and the shared
// logo helpers (logoUrlOnly / logoDark / logoRenderSize); private
// identifiers are shared across all parts.
part of '../details_screen.dart';

// ── Anime movie layout ────────────────────────────────────────────────────────

class _AnimeMovieLayout extends StatelessWidget {
  final String pluginId;
  final CatalogItem item;
  final SeriesDetails? series;
  final MovieDetails? movie;
  const _AnimeMovieLayout({
    required this.pluginId,
    required this.item,
    required this.series,
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    final sd = series;
    final md = movie;
    final fanartUrl = (sd?.fanartUrl.isNotEmpty == true)
        ? sd!.fanartUrl
        : (md?.fanartUrl.isNotEmpty == true)
            ? md!.fanartUrl
            : (item.extra['fanart_url'] ?? '');
    final plot = sd?.plot ?? md?.plot ?? '';
    final genres = sd?.genres ?? md?.genres ?? <String>[];
    final bgUrl = fanartUrl.isNotEmpty ? fanartUrl : item.posterUrl;

    final hasRelated = (item.extra['related'] ?? '').isNotEmpty ||
        (item.extra['similar'] ?? '').isNotEmpty;

    return Stack(
      children: [
        if (bgUrl.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              // Web-only, no-op on every other platform — see image_sizing.dart's
              // "ImageRenderMethodForWeb.HttpGet" section for why every
              // CachedNetworkImage call site in the app sets this.
              imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
              imageUrl: backdropSrc(bgUrl, backdropCacheWidth(context)),
              fit: BoxFit.cover,
              memCacheWidth: backdropCacheWidth(context),
              fadeInDuration: const Duration(milliseconds: 300),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x59000000), Color(0xD1000000), Colors.black],
                stops: [0.0, 0.40, 0.80],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.50],
                colors: [Color(0xBF000000), Colors.transparent],
              ),
            ),
          ),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DetailsBackButton(onTap: () => context.pop()),
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, bc) {
                final w = bc.maxWidth;
                final h = bc.maxHeight;
                final hPad = AppScale.catalogHPadRatio(w);
                final posterWBase = w * detailsPosterWRatio;
                final gap = w * detailsGapRatio;
                // See the analogous _MovieLayout definition above for why this
                // is anchored to 1080p (s==1.15 there) instead of 540p, why
                // it's bumped further with no related/similar footer, and why
                // the floor is 0.55 and s is divided by the ambient textScaler
                // (infoColumn overflow on small-canvas Android TV / on the
                // desktop 1.35× textScaler).
                final s = AppScale.contentScale(context, hasFooter: hasRelated);

                final footerH =
                    hasRelated ? (h * 0.40).clamp(0.0, h * 0.5) : 0.0;
                final mainH = h - footerH;
                final cardH = hasRelated
                    ? (footerH -
                            MediaQuery.sizeOf(context).height *
                                (132.0 / 1080.0))
                        .clamp(151.0, 383.0)
                    : 0.0;
                // See the analogous _MovieLayout poster growth above.
                final posterW = hasRelated
                    ? posterWBase
                    : (mainH / 1.5).clamp(posterWBase, posterWBase * 1.3);

                // See the analogous _MovieLayout definitions above — same
                // plain Column + Flexible(loose) plot, no ConstrainedBox or
                // SingleChildScrollView (this Expanded already gets a tight
                // height from the stretched Row it sits in).
                final infoColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 38 * s,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 10 * s),
                    AnimeMetaRow(item: item, series: series),
                    if (genres.isNotEmpty) ...[
                      SizedBox(height: 10 * s),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: genres
                            .take(4)
                            .map((g) => Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10 * s, vertical: 4 * s),
                                  decoration: BoxDecoration(
                                    color: AppTheme.textHigh
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(g,
                                      style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 15 * s)),
                                ))
                            .toList(),
                      ),
                    ],
                    if (item.rating > 0) ...[
                      SizedBox(height: 8 * s),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16 * s, color: const Color(0xFFFFD700)),
                          SizedBox(width: 4 * s),
                          Text(item.rating.toStringAsFixed(1),
                              style: TextStyle(
                                  color: AppTheme.textMid, fontSize: 16 * s)),
                          if (item.year > 0) ...[
                            SizedBox(width: 14 * s),
                            Text('${item.year}',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 16 * s)),
                          ],
                        ],
                      ),
                    ] else if (item.year > 0) ...[
                      SizedBox(height: 8 * s),
                      Text('${item.year}',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16 * s)),
                    ],
                    SizedBox(height: 16 * s),
                    _WatchButton(
                      pluginId: pluginId,
                      mediaId: item.id,
                      posterUrl: item.posterUrl,
                      fanartUrl: item.extra['fanart_url'] ?? '',
                      itemTitle: item.title,
                      plot: plot,
                      genres: genres,
                      rating: item.rating,
                      year: item.year,
                    ),
                    if (plot.isNotEmpty) ...[
                      SizedBox(height: 12 * s),
                      Flexible(
                        fit: FlexFit.loose,
                        child: FocusableScrollTarget(
                          maxHeightOverride: double.infinity,
                          child: Text(
                            plot,
                            style: TextStyle(
                              color: const Color(0xA0FFFFFF),
                              fontSize: 16 * s,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Main: poster + info ────────────────────────────────
                    SizedBox(
                      height: mainH,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            hPad, h * detailsVPadRatio, hPad, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: posterW,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: item.posterUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            // Web-only, no-op on every other platform — see image_sizing.dart's
                                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                                            // CachedNetworkImage call site in the app sets this.
                                            imageRenderMethodForWeb:
                                                ImageRenderMethodForWeb.HttpGet,
                                            imageUrl: posterSrc(
                                                item.posterUrl,
                                                cacheWidthFor(
                                                    context, posterW)),
                                            fit: BoxFit.cover,
                                            memCacheWidth:
                                                cacheWidthFor(context, posterW),
                                            fadeInDuration: const Duration(
                                                milliseconds: 200),
                                            placeholder: (_, __) =>
                                                const PosterSkeleton(),
                                            errorWidget: (_, __, ___) =>
                                                PlaceholderPoster(
                                                    title: item.title),
                                          )
                                        : PlaceholderPoster(title: item.title),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(child: infoColumn),
                          ],
                        ),
                      ),
                    ),

                    // ── Footer: Correlati / Simili (full width) ───────────
                    if (hasRelated)
                      SizedBox(
                        height: footerH,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
                          child: SeriesRelatedCarouselFooter(
                            pluginId: pluginId,
                            item: item,
                            cardHeight: cardH,
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}
