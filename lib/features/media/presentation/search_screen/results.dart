// Part of search_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the ratio/threshold constants and
// the public SearchScreen entry point; private identifiers are shared across
// all parts.
part of '../search_screen.dart';


// ── Search carousel — fixed-slot horizontal carousel (6 cards) ────────────────
// Wraps the shared CardCarouselBlockView (SDUI module). Load-more is an
// explicit D-pad-reachable arrow past the last card (see _LoadMoreArrow),
// not an automatic trigger from scrolling/focusing near the end — the
// latter fired invisibly, with no way to tell whether more content was
// actually being fetched.

class _SearchCarousel extends StatefulWidget {
  final String pluginId;
  final List<CatalogItem> items;
  final bool hasMore;
  final bool isLoadingMore;
  final double screenH;
  final void Function(FocusNode) onFirstCardFocus;
  final VoidCallback onNavigateUp;

  const _SearchCarousel({
    required this.pluginId,
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.screenH,
    required this.onFirstCardFocus,
    required this.onNavigateUp,
  });

  @override
  State<_SearchCarousel> createState() => _SearchCarouselState();
}

class _SearchCarouselState extends State<_SearchCarousel> {
  CatalogItem? _focusedItem;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) _focusedItem = widget.items.first;
  }

  @override
  void didUpdateWidget(_SearchCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset the info panel's focused item when the result set genuinely
    // changes. Load-more append (same first id, more items) and focus
    // handling on it now live entirely inside CardCarouselBlockView's
    // trailing load-more card.
    if (widget.items.isEmpty ||
        oldWidget.items.isEmpty ||
        widget.items.first.id != oldWidget.items.first.id) {
      _focusedItem = widget.items.isNotEmpty ? widget.items.first : null;
    }
  }

  CatalogItem? _findItem(String id) {
    for (final it in widget.items) {
      if (it.id == id) return it;
    }
    return null;
  }

  void _onItemFocused(CatalogItem item) {
    if (_focusedItem?.id != item.id) setState(() => _focusedItem = item);
  }

  void _loadMore() {
    if (widget.isLoadingMore || !widget.hasMore) return;
    context.read<DiscoveryBloc>().add(const LoadMoreSearchEvent());
  }

  @override
  Widget build(BuildContext context) {
    final block = CardCarouselBlock(
      sectionId: 'search_${widget.pluginId}',
      pluginId: widget.pluginId,
      variant: SduiCardVariant.poster,
      items:
          widget.items.map(sduiCardItemFromCatalogItem).toList(growable: false),
      // false: the search bar owns focus by default (see _SearchViewState),
      // reaching results is an explicit down-arrow, not an automatic steal
      // whenever a (re)search loads.
      isFirstSection: false,
    );
    // SingleChildScrollView as a safety net, not the primary fix — the
    // scale capping in _SearchItemInfo (width vs height, whichever is more
    // constraining) is what should normally keep this within the Expanded
    // budget above. This just means an extreme aspect ratio degrades to a
    // (rare, D-pad-inert since navigation here is horizontal) vertical
    // scroll instead of a hard RenderFlex overflow, same safety-net pattern
    // already used for _EpisodePopup/_RelatedDetailsPopup in
    // details_screen.dart.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CardCarouselBlockView(
            key: ValueKey('search_${widget.pluginId}'),
            block: block,
            visibleCardsOverride: 7,
            // Load-more is a real trailing card in the row now — it scrolls
            // and focuses like any other, and on append the carousel snaps
            // focus back to the first card (see CarouselLoadMore).
            loadMore: widget.hasMore
                ? CarouselLoadMore(
                    isLoading: widget.isLoadingMore,
                    onActivate: _loadMore,
                  )
                : null,
            interaction: CardCarouselInteraction(
              onItemFocused: (id) {
                final item = _findItem(id);
                if (item != null) _onItemFocused(item);
              },
              onItemTap: (id) {
                final item = _findItem(id);
                if (item != null) {
                  openCatalogItem(context, widget.pluginId, item);
                }
              },
              onFirstCardFocus: widget.onFirstCardFocus,
              onNavigateUp: widget.onNavigateUp,
            ),
          ),
          if (_focusedItem != null)
            _SearchItemInfo(item: _focusedItem!, screenH: widget.screenH),
        ],
      ),
    );
  }
}

// ── Info panel shown below carousel for the focused item ─────────────────────

class _SearchItemInfo extends StatelessWidget {
  final CatalogItem item;
  final double screenH;
  const _SearchItemInfo({required this.item, required this.screenH});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, bc) {
      final w = bc.maxWidth;
      final hPad = w * _rSrHPad;
      // Scale fonts with screen width (1920 baseline) — more stable than
      // height for a horizontal carousel — but also cap against the actual
      // available height (screenH, 1080 baseline): this panel sits in a
      // fixed-height Expanded below the toolbar with no separate height
      // reservation, so on a window that's wide relative to how tall it is
      // (plausible on desktop, impossible on a real 16:9 TV) a pure
      // width-based scale could make the title/plot block taller than the
      // budget actually available, overflowing it.
      final widthScale = w / 1920;
      final heightScale = screenH / 1080;
      final scale = widthScale < heightScale ? widthScale : heightScale;
      final titleFs = 34.0 * scale;
      final metaFs = 20.0 * scale;
      final genreFs = 17.0 * scale;
      final plotFs = 17.0 * scale;

      final plot = item.extra['plot'] ?? '';
      final genres = (item.extra['genres'] ?? '')
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .take(4)
          .toList();
      final typeLabel = _typeLabel(item.mediaType);

      return Padding(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad * 2, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title ───────────────────────────────────────────────────────
            // maxLines: 1, not 2 — this Column (mainAxisSize.min) sits inside
            // a fixed-height Expanded below the toolbar; a title that wraps
            // to a second line makes the column taller than that budget and
            // the overflow clips the plot text at the bottom. A single fixed
            // line keeps this zone's height deterministic regardless of
            // title length (same reasoning as the fixed-height metadata
            // zones in home_screen.dart).
            Text(
              item.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFs,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10 * scale),

            // ── Meta row: type · year · rating ────────────────────────────
            Row(
              children: [
                if (typeLabel.isNotEmpty) ...[
                  _InfoChip(text: typeLabel, fontSize: metaFs),
                ],
                if (item.year > 0) ...[
                  _InfoDot(fontSize: metaFs),
                  _InfoChip(text: '${item.year}', fontSize: metaFs),
                ],
                if (item.rating > 0) ...[
                  _InfoDot(fontSize: metaFs),
                  _InfoChip(
                    text: item.rating.toStringAsFixed(1),
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFFD700),
                    fontSize: metaFs,
                  ),
                ],
              ],
            ),

            // ── Genres ───────────────────────────────────────────────────
            if (genres.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: genres
                    .map((g) => Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: genreFs * 0.7,
                              vertical: genreFs * 0.25),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Text(g,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: genreFs)),
                        ))
                    .toList(),
              ),
            ],

            // ── Plot ───────────────────────────────────────────────────────
            // Fixed-height zone sized for exactly 4 lines, text anchored
            // top-left inside it — a plot shorter than 4 lines must render
            // flush at the top, not wherever a content-hugging Text would
            // otherwise size itself, so switching between items with
            // different plot lengths doesn't visibly reshuffle the layout
            // (same pattern as the hero plot zone in home_screen.dart).
            if (plot.isNotEmpty) ...[
              SizedBox(height: 10 * scale),
              SizedBox(
                height: plotFs * 1.5 * 4,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    plot,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: plotFs,
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'movie':
        return 'Film';
      case 'series':
        return 'Serie';
      case 'episode':
        return 'Episodio';
      case 'live':
        return 'Live';
      case 'music':
        return 'Musica';
      case 'podcast':
        return 'Podcast';
      default:
        return '';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? iconColor;
  final double fontSize;
  const _InfoChip(
      {required this.text, this.icon, this.iconColor, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: fontSize * 1.1, color: iconColor ?? Colors.white54),
        SizedBox(width: fontSize * 0.25),
      ],
      Text(text,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55), fontSize: fontSize)),
    ]);
  }
}

class _InfoDot extends StatelessWidget {
  final double fontSize;
  const _InfoDot({this.fontSize = 12});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.4),
        child: Text('·',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: fontSize)),
      );
}
