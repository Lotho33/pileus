// Part of card_carousel_block_view.dart — split out for readability (plan
// 2e). The library file holds the shared imports, the baseline ratio consts
// and the public API (CardCarouselInteraction, CarouselLoadMore,
// CardCarouselBlockView); private identifiers are shared across all parts.
part of '../card_carousel_block_view.dart';

// ── live row — fixed-slot carousel (3 visible), translate-scroll like above

class _LiveRowView extends StatefulWidget {
  final CardCarouselBlock block;
  final CardCarouselInteraction interaction;
  final int? visibleCardsOverride;
  final double? availableWidthOverride;
  final double? hPadOverride;

  const _LiveRowView({
    required this.block,
    required this.interaction,
    this.visibleCardsOverride,
    this.availableWidthOverride,
    this.hPadOverride,
  });

  @override
  State<_LiveRowView> createState() => _LiveRowViewState();
}

class _LiveRowViewState extends State<_LiveRowView> {
  int _focusedIndex = 0;
  // Lazy — see _FixedCarouselViewState._fns for why. Live rows poll on a
  // short TTL, so the old "dispose all, recreate all" on every size change
  // meant regenerating every node on every poll tick, not just an edit.
  final Map<int, FocusNode> _fns = {};
  FocusNode _fnAt(int i) => _fns.putIfAbsent(i, () => FocusNode());

  // Precomputed dimensions — updated only when screen size changes.
  double _hPad = 0, _cardGap = 0, _cardW = 0, _cardH = 0, _scaleOvf = 0;

  @override
  void initState() {
    super.initState();
    // No addListener needed: _LiveCardView.onFocused fires for every focus
    // gain, including programmatic restores after popup close.
    // Same split as _FixedCarouselViewState.initState() — see its comment.
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

  @override
  void didUpdateWidget(_LiveRowView old) {
    super.didUpdateWidget(old);
    // Live catalogs poll with a short TTL, so the item list can genuinely
    // change size under an already-mounted row — keep _fns in sync or stale
    // nodes leave cards that render but can't be focused/navigated. Nodes
    // for indices still valid are kept as-is, not recreated.
    if (old.block.items.length != widget.block.items.length) {
      final prevFocused = _focusedIndex;
      // Only restore focus if this row already had it — a background poll
      // must never steal focus from wherever the user actually is.
      final hadFocus = anyHasFocus(_fns.values);
      final newLen = widget.block.items.length;
      _fns.removeWhere((i, n) {
        if (i >= newLen) {
          n.dispose();
          return true;
        }
        return false;
      });
      if (newLen > 0) {
        final target = prevFocused.clamp(0, newLen - 1);
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
          ? _kVisibleLiveCardsFeatured
          : _kVisibleLiveCards);

  // See _FixedCarouselViewState._computeDims — recomputed every build, not
  // cached via didChangeDependencies, for the same reason.
  void _computeDims() {
    final screenW =
        widget.availableWidthOverride ?? MediaQuery.sizeOf(context).width;
    var hPad = widget.hPadOverride ?? AppScale.catalogHPadRatio(screenW);
    _cardGap = screenW * _rLiveGap;
    final avail = screenW - hPad * 2;
    // _visibleCards full cards + _kPeekFraction of one more (see its doc
    // comment) so the trailing off-window card shows a sliver instead of
    // landing exactly on the clip edge.
    //
    // Floor only — this had no clamp at all before, so on a narrow window
    // the card (and so the fixed-fontSize title positioned inside it, see
    // _LiveCardView) could shrink well below what the title needs to fit.
    _cardW =
        ((avail - _cardGap * _visibleCards) / (_visibleCards + _kPeekFraction))
            .clamp(120.0, double.infinity);
    // The floor above can force _visibleCards cards + gaps to need more
    // width than `avail` allows, since hPad/cardGap were never revisited
    // once the floor took over sizing — the last card then got pushed past
    // this row's own clip bound instead of the layout shrinking to fit.
    // Reclaim the difference from hPad first (pure padding, safe to give
    // up) before ever letting a card clip.
    final neededWidth =
        _cardW * (_visibleCards + _kPeekFraction) + _cardGap * _visibleCards;
    final overflow = neededWidth - avail;
    if (overflow > 0) {
      hPad = (hPad - overflow / 2).clamp(0.0, hPad);
    }
    _hPad = hPad;
    _cardH = _cardW * 9 / 16; // 16:9
    _scaleOvf = _cardH * 0.08;
  }

  @override
  void dispose() {
    for (final n in _fns.values) {
      n.dispose();
    }
    super.dispose();
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
    if (i < widget.block.items.length - 1) {
      _fnAt(i + 1).requestFocus();
    } else {
      widget.interaction.onNavigateRightAtEnd?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    _computeDims();
    final items = widget.block.items;
    final scrollIdx =
        _focusedIndex.clamp(0, (items.length - _visibleCards).clamp(0, 9999));
    final translateX = scrollIdx * (_cardW + _cardGap);

    const kBuf = 3;
    final winStart = (scrollIdx - kBuf).clamp(0, items.length);
    final winEnd = (scrollIdx + _visibleCards + kBuf).clamp(0, items.length);
    final winOffX = winStart * (_cardW + _cardGap);

    final row = Padding(
      padding: EdgeInsets.only(left: _hPad + winOffX),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = winStart; i < winEnd; i++) ...[
            if (i > winStart) SizedBox(width: _cardGap),
            RepaintBoundary(
              key: ValueKey('${widget.block.pluginId}_live_$i'),
              child: _LiveCardView(
                focusNode: _fnAt(i),
                title: items[i].title,
                posterUrl: items[i].imageUrl,
                width: _cardW,
                height: _cardH,
                isActuallyLive: items[i].isLive,
                sportCat: items[i].sportCat,
                onTap: () => widget.interaction.onItemTap?.call(items[i].id),
                onFocused: () {
                  setState(() => _focusedIndex = i);
                  widget.interaction.onItemFocused?.call(items[i].id);
                },
                onLeft: () => _navigateLeft(i),
                onLeftRepeat: () => _navigateLeftRepeat(i),
                onRight: () => _navigateRight(i),
                onUp: widget.interaction.onNavigateUp,
                onDown: widget.interaction.onNavigateDown,
                onHoldChanged: widget.interaction.onNavigateHoldChanged,
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
              duration: const Duration(milliseconds: 220),
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
