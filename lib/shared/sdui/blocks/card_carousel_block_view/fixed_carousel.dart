// Part of card_carousel_block_view.dart — split out for readability (plan
// 2e). The library file holds the shared imports, the baseline ratio consts
// and the public API (CardCarouselInteraction, CarouselLoadMore,
// CardCarouselBlockView); private identifiers are shared across all parts.
part of '../card_carousel_block_view.dart';

// ── poster carousel — exactly _kVisibleCards slots, translate-scroll ───────
//
// Layout: LayoutBuilder gives availableWidth.
//   cardW = (avail - hPad*2 - cardGap*(_kVisibleCards-1)) / _kVisibleCards
//   cardH = cardW / (2/3)  [poster aspect]
// All _kVisibleCards cards are always laid out in a Row; scrolling is done by
// translating the Row left by (_focusedIndex - visible offset) * (cardW+spacing).
// No ListView → no clipping, no scroll controller, perfect geometry at all times.

class _FixedCarouselView extends StatefulWidget {
  final CardCarouselBlock block;
  final CardCarouselInteraction interaction;
  final int? visibleCardsOverride;
  final double? availableWidthOverride;
  final double? hPadOverride;
  final CarouselLoadMore? loadMore;

  const _FixedCarouselView({
    required this.block,
    required this.interaction,
    this.visibleCardsOverride,
    this.availableWidthOverride,
    this.hPadOverride,
    this.loadMore,
  });

  @override
  State<_FixedCarouselView> createState() => _FixedCarouselViewState();
}

class _FixedCarouselViewState extends State<_FixedCarouselView> {
  int _focusedIndex = 0;
  // Lazy, not List.generate(items.length) — items.length can be in the
  // hundreds (a full catalog row or search result set) while only ~13 cards
  // (visible + a small buffer) are ever actually rendered at once (see the
  // windowed build() below). Eagerly allocating one FocusNode per item, and
  // fully disposing+recreating all of them on every page-append, was pure
  // waste on the app's hottest widget (backs every home carousel and every
  // search result row).
  final Map<int, FocusNode> _fns = {};
  FocusNode _fnAt(int i) => _fns.putIfAbsent(i, () => FocusNode());

  double _cardW = 0;
  double _cardH = 0;
  double _cardGap = 0;
  double _hPad = 0;
  double _scaleOvf = 0;

  @override
  void initState() {
    super.initState();
    // No addListener needed: Focus.onFocusChange in _PosterCardView already
    // calls onFocused for every focus change, including programmatic.
    //
    // Two distinct behaviors, deliberately not tied together: capturing the
    // first card's FocusNode (so a caller like search_screen.dart can move
    // focus there later, on an explicit down-arrow from the search bar)
    // always happens — it's cheap and harmless. Actually STEALING focus on
    // mount only happens when isFirstSection is true (home screen's single
    // active row). Search always passes isFirstSection: false for exactly
    // this reason: reloading results must never yank focus off the search
    // bar the user is still typing in.
    if (widget.block.items.isNotEmpty) {
      widget.interaction.onFirstCardFocus?.call(_fnAt(0));
      widget.interaction.onLastCardFocus
          ?.call(_fnAt(widget.block.items.length - 1));
    }
    if (widget.block.isFirstSection && widget.block.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fnAt(0).requestFocus();
      });
    }
  }

  // Real item slots + the trailing load-more card, if any.
  int get _slotCount =>
      widget.block.items.length + (widget.loadMore != null ? 1 : 0);

  @override
  void didUpdateWidget(_FixedCarouselView old) {
    super.didUpdateWidget(old);
    // The item list can change size after the carousel is already built (e.g.
    // a background catalog refresh, or search results replaced after a new
    // query). Nodes for indices that no longer exist must go; nodes for
    // indices still valid are kept as-is (no need to touch or recreate them —
    // that's the whole point of keying by index instead of a positional List).
    if (old.block.items.length != widget.block.items.length) {
      final prevFocused = _focusedIndex;
      // Only restore focus into the carousel if it already had focus
      // somewhere inside it — otherwise this steals focus from wherever
      // the user actually is (e.g. still typing in search_screen.dart's
      // search bar while a new, differently-sized result set replaces the
      // old one).
      final hadFocus = anyHasFocus(_fns.values);
      // Was focus on the trailing load-more card (its node lives at the old
      // items.length index) when the list grew? Then this was a load-more
      // append — keep focus on that same slot, which now holds the first
      // freshly-loaded item, so the user just scrolls right into the new
      // batch instead of being yanked back to the start of the row.
      final wasOnTrailing = old.loadMore != null &&
          widget.block.items.length > old.block.items.length &&
          (_fns[old.block.items.length]?.hasFocus ?? false);
      final newLen = widget.block.items.length;
      final keepUpTo = _slotCount; // valid indices are 0 .. keepUpTo-1
      _fns.removeWhere((i, n) {
        if (i >= keepUpTo) {
          n.dispose();
          return true;
        }
        return false;
      });
      if (newLen > 0) {
        final target = wasOnTrailing
            ? old.block.items.length.clamp(0, newLen - 1)
            : prevFocused.clamp(0, newLen - 1);
        _focusedIndex = target;
        if (hadFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fnAt(target).requestFocus();
          });
        }
        widget.interaction.onLastCardFocus?.call(_fnAt(newLen - 1));
      } else {
        _focusedIndex = 0;
      }
    }
  }

  int get _visibleCards =>
      widget.visibleCardsOverride ??
      (widget.block.featured && kFeaturedCarouselResizeEnabled
          ? _kVisibleCardsFeatured
          : _kVisibleCards);

  // Recomputed every build (cheap arithmetic, no side effects) rather than
  // cached via didChangeDependencies — a host that hands in
  // availableWidthOverride (e.g. the home screen's quick-search panel,
  // whose width comes from its own LayoutBuilder) can rebuild this widget
  // with a different width without MediaQuery itself ever changing, which
  // didChangeDependencies would miss entirely. That used to freeze card
  // size at whatever the container's width happened to be on first mount
  // (sometimes a mid-animation transient), visibly out of sync with the
  // container's true size from then on.
  void _computeDims() {
    final screenW =
        widget.availableWidthOverride ?? MediaQuery.sizeOf(context).width;
    var hPad = widget.hPadOverride ?? AppScale.catalogHPadRatio(screenW);
    _cardGap = AppScale.catalogGapRatio(screenW);
    final avail = screenW - hPad * 2;
    // _visibleCards full cards + _kPeekFraction of one more, so the
    // trailing off-window card shows a sliver instead of landing exactly
    // on the clip edge (see _kPeekFraction's doc comment).
    //
    // Floor only, same reasoning as _LiveRowViewState._computeDims: on a
    // narrow window the badges/focus border/title text inside a poster
    // card need a minimum width to render sanely — without it cardW (and
    // the cardH derived from it) can shrink toward zero or go negative.
    _cardW =
        ((avail - _cardGap * _visibleCards) / (_visibleCards + _kPeekFraction))
            .clamp(90.0, double.infinity);
    // See _LiveRowViewState._computeDims — the floor above can need more
    // total width than `avail` allows; reclaim the difference from hPad
    // (safe to shrink) instead of letting the last card clip past this
    // row's own bound.
    final neededWidth =
        _cardW * (_visibleCards + _kPeekFraction) + _cardGap * _visibleCards;
    final overflow = neededWidth - avail;
    if (overflow > 0) {
      hPad = (hPad - overflow / 2).clamp(0.0, hPad);
    }
    _hPad = hPad;
    _cardH = _cardW * 3 / 2;
    _scaleOvf = _cardH * 0.10;
  }

  @override
  void dispose() {
    for (final n in _fns.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _onCardFocused(int i) {
    setState(() => _focusedIndex = i);
    if (i < widget.block.items.length) {
      widget.interaction.onItemFocused?.call(widget.block.items[i].id);
    }
  }

  // From a fresh Left press: step to the previous card, or open the side nav
  // if already on the first one. The card only routes a *fresh* press here
  // (repeats go to _navigateLeftRepeat), so no timer / heuristic is needed.
  void _navigateLeft(int i) {
    if (i > 0) {
      _fnAt(i - 1).requestFocus();
    } else {
      widget.interaction.onOpenNav?.call();
    }
  }

  // From a held Left (repeat): step to the previous card and stop dead at
  // the first one — a hold never opens the side nav.
  void _navigateLeftRepeat(int i) {
    if (i > 0) _fnAt(i - 1).requestFocus();
  }

  void _navigateRight(int i) {
    if (i < _slotCount - 1) {
      _fnAt(i + 1).requestFocus();
    } else {
      widget.interaction.onNavigateRightAtEnd?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    _computeDims();
    final items = widget.block.items;
    final slots = _slotCount;
    final scrollIdx =
        _focusedIndex.clamp(0, (slots - _visibleCards).clamp(0, 9999));
    final translateX = scrollIdx * (_cardW + _cardGap);

    // Windowed rendering: build only visible cards + a small buffer on each side.
    // Single-step navigation always targets an index inside this window, so no
    // frame-delay workaround is needed.
    const kBuf = 3;
    final winStart = (scrollIdx - kBuf).clamp(0, slots);
    final winEnd = (scrollIdx + _visibleCards + kBuf).clamp(0, slots);
    final winOffX = winStart * (_cardW + _cardGap);

    final row = Padding(
      padding: EdgeInsets.only(left: _hPad + winOffX),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = winStart; i < winEnd; i++) ...[
            if (i > winStart) SizedBox(width: _cardGap),
            if (i < items.length)
              RepaintBoundary(
                key: ValueKey('${widget.block.pluginId}_${items[i].id}_$i'),
                child: _PosterCardView(
                  focusNode: _fnAt(i),
                  item: items[i],
                  width: _cardW,
                  height: _cardH,
                  onTap: () => widget.interaction.onItemTap?.call(items[i].id),
                  onLongPress: () =>
                      widget.interaction.onItemLongPress?.call(items[i].id),
                  onFocused: () => _onCardFocused(i),
                  onLeft: () => _navigateLeft(i),
                  onLeftRepeat: () => _navigateLeftRepeat(i),
                  onRight: () => _navigateRight(i),
                  onUp: widget.interaction.onNavigateUp,
                  onDown: widget.interaction.onNavigateDown,
                  onHoldChanged: widget.interaction.onNavigateHoldChanged,
                  onEsc: widget.interaction.onEsc ?? widget.interaction.onBack,
                ),
              )
            else
              RepaintBoundary(
                key: ValueKey('${widget.block.pluginId}_loadmore'),
                child: _LoadMoreCardView(
                  focusNode: _fnAt(i),
                  width: _cardW,
                  height: _cardH,
                  isLoading: widget.loadMore!.isLoading,
                  onActivate: widget.loadMore!.onActivate,
                  onFocused: () => _onCardFocused(i),
                  onLeft: () => _navigateLeft(i),
                  onRight: () => _navigateRight(i),
                  onUp: widget.interaction.onNavigateUp,
                  onDown: widget.interaction.onNavigateDown,
                  onEsc: widget.interaction.onEsc ?? widget.interaction.onBack,
                ),
              ),
          ],
        ],
      ),
    );

    return SizedBox(
      height: _cardH + _scaleOvf * 2,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: _scaleOvf),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: translateX),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (_, tx, __) => Transform.translate(
                offset: Offset(-tx, 0),
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
