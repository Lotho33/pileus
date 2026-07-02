// Part of details_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the layout-ratio comment, the
// DetailsScreen / _DetailsView / _DetailsContent entry chain and the shared
// logo helpers (logoUrlOnly / logoDark / logoRenderSize); private
// identifiers are shared across all parts.
part of '../details_screen.dart';

// ── Movie layout ──────────────────────────────────────────────────────────────

class _MovieLayout extends StatelessWidget {
  final String pluginId;
  final CatalogItem item;
  final MovieDetails? movie;
  const _MovieLayout(
      {required this.pluginId, required this.item, required this.movie});

  @override
  Widget build(BuildContext context) {
    final d = movie;
    final fanartUrl = (d?.fanartUrl.isNotEmpty == true)
        ? d!.fanartUrl
        : (item.extra['fanart_url'] ?? '');
    final bgUrl = fanartUrl.isNotEmpty ? fanartUrl : item.posterUrl;
    final plot = d?.plot ?? '';
    final genres = d?.genres ?? <String>[];
    final cast = d?.cast ?? <String>[];
    final directors = d?.directors ?? <String>[];
    final runtime = d?.runtime ?? '';
    final tagline = d?.tagline ?? '';
    final cr = d?.contentRating ?? '';

    final hasRelated = (item.extra['related'] ?? '').isNotEmpty ||
        (item.extra['similar'] ?? '').isNotEmpty;

    return Stack(
      children: [
        if (bgUrl.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
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
                // s scales every *s font size below with screen height, anchored
                // so s==1.15 at 1080p (today's tuned/tested look, unchanged). The
                // previous (sh/540.0).clamp(0.9, 1.15) was pinned at its own
                // ceiling for any sh above ~621 — i.e. every real 1080p+ panel —
                // so this text never actually resized in practice. Safe against
                // the "runaway" the old comment worried about: main.dart's global
                // text scaler trim saturates at sh==1080 too, so above that only
                // this single multiplier keeps growing, not two compounding ones.
                // See AppScale.contentScale for the shared bump/textScaler
                // logic (2026-09: consolidated here from 3 near-identical
                // copies in this file, episode_detail_screen.dart and
                // series_page_layout.dart). The 0.55 floor is specific to
                // this screen: infoColumn below is a plain Column given a
                // tight height (mainH, from this LayoutBuilder's real
                // constraints); its non-plot children are sized off s, and
                // when s was pinned above what mainH could hold — an Android
                // TV reporting a half-size logical canvas (sh ≈ 540) hit
                // exactly this — the Flexible plot collapsed to 0 and the
                // column overflowed ("BOTTOM OVERFLOWED"). 0.55 lets s track
                // mainH down instead of staying pinned.
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
                // Same idea for the poster: fixed 2:3 aspect off posterWBase left
                // dead space below it once mainH grew past the footer-present
                // case. Let it grow toward mainH's height, capped at +30% so it
                // doesn't crowd the Expanded info column next to it — no other
                // rebalancing needed, Expanded just absorbs whatever's left.
                final posterW = hasRelated
                    ? posterWBase
                    : (mainH / 1.5).clamp(posterWBase, posterWBase * 1.3);

                // Plain Column (no SingleChildScrollView/ConstrainedBox) —
                // Expanded(child: infoColumn) below sits in a Row with
                // crossAxisAlignment.stretch inside a SizedBox(height: mainH),
                // so it already receives a tight height equal to the column's
                // real vertical budget. The plot at the bottom is
                // Flexible(loose) so it takes however much of that height is
                // left over after everything above it, instead of a
                // fixed/guessed cap — grows on its own when there's little
                // other metadata (or no related/similar footer widens mainH),
                // shrinks when there's a lot, and can never force this column
                // to overflow since Flexible never exceeds what's left. A Flex
                // child needs a bounded-height ancestor, which is exactly why
                // this can no longer be a SingleChildScrollView (unbounded
                // height) — everything above the plot already has its own
                // bounds (maxLines/.take(n)) so it isn't expected to need one.
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
                    if (tagline.isNotEmpty) ...[
                      SizedBox(height: 6 * s),
                      Text(
                        tagline,
                        style: TextStyle(
                          color: AppTheme.textHigh.withValues(alpha: 0.50),
                          fontSize: 16 * s,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 8 * s),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.rating > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 16 * s, color: const Color(0xFFFFD700)),
                              SizedBox(width: 4 * s),
                              Text(item.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                      color: AppTheme.textMid,
                                      fontSize: 16 * s)),
                            ],
                          ),
                        if (item.year > 0)
                          Text('${item.year}',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 16 * s)),
                        if (runtime.isNotEmpty)
                          Text(runtime,
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 16 * s)),
                        if (cr.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 7 * s, vertical: 2 * s),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.textLow),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(cr,
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13 * s)),
                          ),
                      ],
                    ),
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
                    if (directors.isNotEmpty) ...[
                      SizedBox(height: 16 * s),
                      Text('Regia: ${directors.join(', ')}',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 15 * s)),
                    ],
                    if (cast.isNotEmpty) ...[
                      SizedBox(height: 6 * s),
                      Text(cast.take(5).join('  ·  '),
                          style: TextStyle(
                              color: AppTheme.textLow,
                              fontSize: 14 * s,
                              height: 1.4)),
                    ],
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
                            // ── POSTER ──────────────────────────────────────
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

                            // ── INFO + WATCH BUTTON + PLOT ─────────────────
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
