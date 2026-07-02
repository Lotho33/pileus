// Part of quick_search_area.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the two consts and the
// QuickSearchArea widget; private identifiers are shared across all parts.
part of '../quick_search_area.dart';

class _QuickSearchAreaState extends State<QuickSearchArea> {
  late final DiscoveryBloc _bloc = getIt<DiscoveryBloc>();
  final _controller = TextEditingController();
  final _keyboardKey = GlobalKey<OnScreenKeyboardState>();
  final _barKey = GlobalKey<_QuickSearchBarState>();
  // Ancestor-only node (canRequestFocus: false, see build()) — FocusNode.hasFocus
  // is true for every ancestor along the primary-focus path, not just the
  // exact leaf, so this doubles as "is focus anywhere inside this subtree"
  // without a separate FocusScope.
  final _scopeFocusNode = FocusNode();
  // SafeFocusRef (see lib/shared/utils/safe_focus.dart): this exact field
  // was the dangling-FocusNode bug this session found and fixed by hand —
  // migrated onto the shared utility so the same defense doesn't need
  // re-deriving here by hand a second time.
  final _firstResultFocus = SafeFocusRef();
  final _seeAllFn = FocusNode();
  // The visible TextField's own focus node — deliberately never reachable
  // by D-pad (canRequestFocus: false). It used to be widget.barFocusNode
  // itself, which meant landing real focus on a readOnly text field with
  // nowhere further to go (no onUp/onLeft) other than Escape/Back — closing
  // search via the X could leave focus stranded right back on this same
  // field if the restore-focus race documented in _dismiss() below lost,
  // reading as "stuck in the textbox". Kept only for cursor rendering
  // (showCursor below) — never a real focus target.
  final _textFieldFocusNode = FocusNode(canRequestFocus: false);
  Timer? _debounce;
  String _lastQuery = '';
  bool _expanded = false;
  // True from the moment a keystroke changes the query until the debounced
  // _search actually dispatches — without it, the *previous* query's result
  // carousel just sat there unchanged (a valid-looking DiscoveryLoaded, not
  // DiscoveryLoading) for the whole debounce + network round trip, looking
  // like the new keystrokes hadn't done anything yet.
  bool _pendingSearch = false;
  // Title of whichever result card currently has focus, shown centered
  // above the preview carousel — the compact quick-search card style has
  // no room for a title bar on the card itself, unlike the full
  // SearchScreen/browse grid. Reset on every new query so the previous
  // query's title doesn't linger over a freshly loaded, unrelated result set.
  String? _focusedResultTitle;

  // Set true whenever primary focus is observed anywhere inside this
  // subtree. Lets _onGlobalFocusChange tell a genuine "focus has left the
  // panel" from the brief not-yet-focused window right after opening (where
  // _scopeFocusNode.hasFocus can read false for a beat).
  bool _sawFocusInside = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    // widget.barFocusNode is home_screen.dart's external trigger — it calls
    // .requestFocus() on it to "open" search, but it's attached to an
    // invisible proxy below (never the TextField, see _textFieldFocusNode),
    // so redirect any real focus it receives straight to the keyboard's
    // first key instead.
    widget.barFocusNode.addListener(_onBarFocusRequested);
    FocusManager.instance.addListener(_onGlobalFocusChange);
  }

  void _onBarFocusRequested() {
    if (!widget.barFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardKey.currentState?.firstFocusNode.requestFocus();
    });
  }

  // Self-heal for a stuck-open panel the _scopeFocusNode.onFocusChange latch
  // (see build()) can't catch by itself: tap a quick-search result and it
  // pushes a details/player route (or "Vedi tutti" pushes SearchScreen);
  // when the user backs all the way out to home, Flutter's focus restore on
  // the pop can momentarily land back on a quick-search descendant —
  // flipping _expanded true again via onFocusChange — then settle on a home
  // card with no matching onFocusChange(false). The panel is then visibly
  // expanded (bar + keyboard + stale results) but holds no focus, so no key
  // event ever reaches the scope Focus's Escape/Back dismiss handler: it
  // can't be closed. Every primary-focus change runs through here — if the
  // panel is expanded while focus sits entirely outside it, dismiss it.
  void _onGlobalFocusChange() {
    if (!mounted) return;
    if (_scopeFocusNode.hasFocus) {
      _sawFocusInside = true;
      return;
    }
    if (_expanded && _sawFocusInside) {
      _sawFocusInside = false;
      _dismiss();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onGlobalFocusChange);
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    widget.barFocusNode.removeListener(_onBarFocusRequested);
    _textFieldFocusNode.dispose();
    _scopeFocusNode.dispose();
    _seeAllFn.dispose();
    _bloc.close();
    super.dispose();
  }

  // Fires for every controller mutation, hardware typing or the on-screen
  // keyboard alike — same debounce idiom as search_screen.dart's live search.
  void _onQueryChanged() {
    _debounce?.cancel();
    final text = _controller.text;
    // Below _kMinSearchLength, _search() below is just going to clear
    // everything — showing a loading spinner for a search that's never
    // actually going to fire is misleading, not helpful.
    final willSearch = text.trim().length >= _kMinSearchLength;
    if (willSearch && !_pendingSearch) {
      setState(() => _pendingSearch = true);
    } else if (!willSearch && _pendingSearch) {
      setState(() => _pendingSearch = false);
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  void _search(String query) {
    _debounce?.cancel();
    if (_pendingSearch) setState(() => _pendingSearch = false);
    final q = query.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    _focusedResultTitle = null;
    if (q.length < _kMinSearchLength) {
      // Below the minimum length to actually search — a single-letter
      // query fires a broad, mostly-noise search and empties out almost
      // immediately as the user keeps typing. Also covers backspacing the
      // query down to nothing, which previously left stale results from a
      // longer prior query visible under the (now short/empty) search box.
      _bloc.add(const ClearSearchEvent());
      return;
    }
    _bloc.add(SearchRequestEvent(
      pluginId: widget.pluginId,
      query: q,
      filters: const {},
    ));
  }

  // Closing search (Escape/Back or the close button, both funnel into
  // _QuickSearchBar's onDismiss) used to leave the query and its results
  // sitting in the controller/bloc — reopening quick search later showed
  // the previous search instead of a clean slate.
  // Debounces _dismiss() itself: the Android box this was tested on
  // occasionally delivers two Back/Esc KeyDownEvents for a single physical
  // press. The first call here closes search and starts the async focus
  // restore in home_screen.dart's onDismiss below; the second arrives before
  // that restore has landed (still inside this widget's Escape handling),
  // so it re-entered _dismiss() a second time mid-teardown and could race
  // the restore into leaving focus back inside this subtree — which then
  // read as "search reopens right after closing it". Anything within this
  // window is treated as the platform's duplicate, not a second real press.
  DateTime? _lastDismissAt;
  static const _dismissDebounce = Duration(milliseconds: 400);

  void _dismiss() {
    final now = DateTime.now();
    final last = _lastDismissAt;
    if (last != null && now.difference(last) < _dismissDebounce) return;
    _lastDismissAt = now;
    _controller.clear(); // fires _onQueryChanged, scheduling a debounce below
    _debounce?.cancel();
    _lastQuery = '';
    // _expanded normally only flips back to false as a side effect of
    // widget.onDismiss() (below) successfully moving focus outside this
    // subtree's _scopeFocusNode, via that node's own onFocusChange. Under
    // rapid input (fast repeated Up/Esc right as search is opening) that
    // restore can race — the target it captured hasn't settled, or focus
    // ends up back here before onFocusChange fires — leaving _expanded
    // stuck true with no further Escape press able to reach this state at
    // all once that happens (nothing outside the subtree has focus to
    // route the key to). Collapsing here directly, instead of only ever
    // relying on that side effect, means every _dismiss() call actually
    // closes the panel regardless of how the focus handoff below goes.
    if (_expanded || _pendingSearch) {
      setState(() {
        _expanded = false;
        _pendingSearch = false;
      });
    }
    _bloc.add(const ClearSearchEvent());
    widget.onDismiss();
    // Last-resort: if onDismiss's focus restore didn't move focus out of
    // this subtree (its target was stale — e.g. search was entered by a
    // stray focus drift rather than the deliberate trigger, so
    // _preSearchFocus never got captured), boot focus to the enclosing
    // scope so _scopeFocusNode.onFocusChange fires and the panel can't get
    // stuck open with no key able to reach _dismiss again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scopeFocusNode.hasFocus) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _openFullSearch() {
    // Captured before _dismiss() clears the controller. Same reasoning as
    // onItemTap below: without collapsing quick search first, it stays
    // mounted and expanded underneath SearchScreen — popping back with
    // Escape/Back later then lands on a home screen that still has it open,
    // not the clean home the user actually expects to return to.
    final query = _controller.text;
    _dismiss();
    context.push('/search/${widget.pluginId}', extra: {
      'pluginName': widget.pluginName,
      'initialQuery': query,
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    final collapsedW = (sw * 0.30).clamp(320.0, 620.0);
    final expandedW = (sw * 0.60)
        .clamp(700.0, 1200.0)
        .clamp(0.0, sw - AppScale.screenHPad(context) * 2);

    // AnimatedSize+AnimatedSwitcher below let the extra content grow and
    // fade in together with the container's own width/blur tween instead
    // of popping in the instant _expanded flips — that mismatch (smooth
    // container, instant content) is what read as "mechanical" before.
    // Built once here and reused by both branches of the BackdropFilter
    // toggle further down, so that split doesn't duplicate this subtree.
    final searchContent = AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      // The results carousel already reserves its own focus-scale overflow
      // allowance internally (ClipRect+OverflowBox sized for
      // AppScale.focusScaleCard, see card_carousel_block_view.dart) —
      // AnimatedSize's default hard clip would cut that back off at its
      // own (independently-computed) box edge.
      clipBehavior: Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Invisible: the real landing spot for widget.barFocusNode
          // (home_screen.dart's "open search" trigger) — see
          // _onBarFocusRequested, which bounces any focus landing here
          // straight to the keyboard's first key. Still a real descendant
          // of _scopeFocusNode's subtree, so "focus entered search" (→
          // _expanded) keeps working exactly as before.
          Focus(
            focusNode: widget.barFocusNode,
            skipTraversal: true,
            child: const SizedBox.shrink(),
          ),
          _QuickSearchBar(
            key: _barKey,
            focusNode: _textFieldFocusNode,
            controller: _controller,
            pluginName: widget.pluginName,
            expanded: _expanded,
            onSubmitted: () => _search(_controller.text),
            onNavigateDown: () =>
                _keyboardKey.currentState?.firstFocusNode.requestFocus(),
            onDismiss: _dismiss,
            onOpenFilters: _openFullSearch,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: AppScale.fadeCurve,
            switchOutCurve: AppScale.fadeCurve,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: !_expanded
                ? const SizedBox.shrink(key: ValueKey('collapsed'))
                : Column(
                    key: const ValueKey('expanded'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: AppScale.space(context, 15)),
                      OnScreenKeyboard(
                        key: _keyboardKey,
                        controller: _controller,
                        // No Invio key — quick search already dispatches
                        // automatically past _kMinSearchLength.
                        showEnter: false,
                        // Was widget.barFocusNode.requestFocus() — that node
                        // is the invisible landing spot _onBarFocusRequested
                        // always bounces straight back to the keyboard's
                        // first key (see its own doc), so "Up" from the top
                        // of the keyboard looped back into the keyboard
                        // instead of ever reaching the filters/close (X)
                        // buttons — they were visually present but
                        // structurally unreachable by D-pad. Land on the
                        // close button directly instead; Left from there
                        // already reaches filters (see _QuickSearchBarState).
                        onNavigateUp: () =>
                            _barKey.currentState?._closeFn.requestFocus(),
                        onNavigateDown: () => _firstResultFocus.requestFocus(),
                      ),
                      SizedBox(height: AppScale.space(context, 19.4)),
                      BlocBuilder<DiscoveryBloc, DiscoveryState>(
                        builder: (context, state) {
                          if (_pendingSearch ||
                              state is! DiscoveryLoaded ||
                              state.items.isEmpty) {
                            // The carousel (and the FocusNode _firstResultFocus
                            // points at) isn't rendered in this state — without
                            // this, _firstResultFocus keeps pointing at whatever
                            // node the *previous* search's carousel disposed of
                            // (every search passes through DiscoveryLoading
                            // first, and an empty/no-match result is common
                            // while typing character-by-character), and
                            // requestFocus() on a disposed node is what left
                            // the D-pad stuck with no visible focus anywhere —
                            // including Escape/Back, since primary focus ends
                            // up detached from the ancestor Focus that catches
                            // it (see this widget's build() below).
                            _firstResultFocus.clear();
                            // Without a visible loading state, a search in
                            // flight and a genuine no-match result looked
                            // identical (both just empty space) — nothing
                            // told the user their keystrokes had actually
                            // triggered anything.
                            if (_pendingSearch || state is DiscoveryLoading) {
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: AppScale.space(context, 21.6)),
                                child: PileusSpinner(
                                  size: AppScale.spinnerS(context),
                                  color: AppTheme.primary,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }
                          // Preview caps at previewCount results, but
                          // shows _kQuickSearchVisibleCards fixed slots
                          // at a time (same fixed-slot pattern as the
                          // full SearchScreen's 6) so card size stays
                          // constant regardless of how many results
                          // came back — a 1-2 result search used to
                          // stretch each card to fill the whole row.
                          // Fixed slots also make the carousel's own
                          // windowing kick in once there are more items
                          // than fit at once, so several results are
                          // directly D-pad-navigable here — "Vedi
                          // tutti" is still one explicit step away for
                          // full pagination/filters.
                          const previewCount = 8;
                          final allItems = state.items.cast<CatalogItem>();
                          final items = allItems.take(previewCount).toList();
                          final remaining = allItems.length - items.length;
                          final block = CardCarouselBlock(
                            sectionId: 'quick_search_${widget.pluginId}',
                            pluginId: widget.pluginId,
                            variant: SduiCardVariant.poster,
                            items: items
                                .map(sduiCardItemFromCatalogItem)
                                .toList(growable: false),
                            isFirstSection: false,
                          );
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title of whichever card is focused, centered
                              // above the row — the compact quick-search card
                              // style has no title bar of its own (unlike
                              // browse_screen.dart's grid), so without this
                              // label there's no way to tell which result is
                              // which beyond the poster art. Defaults to the
                              // first item so it's never blank before the
                              // user has navigated focus down into the row.
                              Padding(
                                padding: EdgeInsets.only(
                                    bottom: AppScale.space(context, 13)),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  switchInCurve: AppScale.fadeCurve,
                                  switchOutCurve: AppScale.fadeCurve,
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                          opacity: anim, child: child),
                                  child: Text(
                                    _focusedResultTitle ?? items.first.title,
                                    key: ValueKey(_focusedResultTitle ??
                                        items.first.title),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: AppScale.caption(context),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              // The shared carousel sizes cards from
                              // MediaQuery's full screen width by
                              // default (correct for full-bleed rows
                              // like the home carousels and full
                              // SearchScreen) — this panel is
                              // deliberately narrower than the screen,
                              // so it must hand the carousel its own
                              // actual width or cards render sized for
                              // (and spill past) the full screen.
                              // visibleCardsOverride is always the
                              // fixed slot count (not clamped to
                              // items.length) so card size never
                              // changes with the result count — a 1-2
                              // result search just leaves empty slot
                              // space instead of stretching. hPad is
                              // kept (not 0) as horizontal breathing
                              // room for the edge cards' focus-scale
                              // growth (AppScale.focusScaleCard) —
                              // without it the first/last card's
                              // focused (scaled-up) edge gets clipped
                              // by this panel's own bounds.
                              LayoutBuilder(
                                  builder: (context, cc) =>
                                      CardCarouselBlockView(
                                        key: ValueKey(
                                            'quick_search_${widget.pluginId}_$_lastQuery'),
                                        block: block,
                                        visibleCardsOverride:
                                            _kQuickSearchVisibleCards,
                                        availableWidthOverride: cc.maxWidth,
                                        hPadOverride: AppScale.catalogHPadRatio(
                                            cc.maxWidth),
                                        interaction: CardCarouselInteraction(
                                          onItemTap: (id) {
                                            final item = items
                                                .where((i) => i.id == id)
                                                .firstOrNull;
                                            if (item != null) {
                                              // Collapse search *before* navigating —
                                              // otherwise this panel stays mounted
                                              // and _expanded underneath the pushed
                                              // details/player route, invisible
                                              // until the user backs all the way out
                                              // of it: at that point it can resurface
                                              // still expanded but with focus no
                                              // longer anchored inside its own
                                              // Escape-dismiss subtree (see the
                                              // safety-net Focus below), which reads
                                              // as Back doing nothing — stuck with
                                              // the search bar open.
                                              _dismiss();
                                              openCatalogItem(context,
                                                  widget.pluginId, item);
                                            }
                                          },
                                          onItemFocused: (id) {
                                            final item = items
                                                .where((i) => i.id == id)
                                                .firstOrNull;
                                            if (item != null &&
                                                item.title !=
                                                    _focusedResultTitle) {
                                              setState(() =>
                                                  _focusedResultTitle =
                                                      item.title);
                                            }
                                          },
                                          onFirstCardFocus: (fn) =>
                                              _firstResultFocus.set(fn),
                                          onNavigateUp: () => _keyboardKey
                                              .currentState?.firstFocusNode
                                              .requestFocus(),
                                          onNavigateDown: () =>
                                              _seeAllFn.requestFocus(),
                                          // Without this, Back on a focused result card
                                          // falls through to onOpenNav (unset here, no
                                          // side nav in this overlay) then onUp instead
                                          // — one Back press moved focus to the keyboard
                                          // rather than closing search, so a user
                                          // reasonably expecting Back to exit needed a
                                          // second press to actually leave.
                                          onEsc: _dismiss,
                                        ),
                                      )),
                              Padding(
                                padding: EdgeInsets.only(
                                    top: AppScale.space(context, 10.8)),
                                child: _SeeAllResultsButton(
                                  focusNode: _seeAllFn,
                                  label: remaining > 0
                                      ? 'Vedi tutti i risultati (+$remaining)'
                                      : 'Vedi tutti i risultati',
                                  fontSize: AppScale.space(context, 15),
                                  onActivate: _openFullSearch,
                                  onNavigateUp: () {
                                    if (!_firstResultFocus.requestFocus()) {
                                      _keyboardKey.currentState?.firstFocusNode
                                          .requestFocus();
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );

    return Focus(
      focusNode: _scopeFocusNode,
      canRequestFocus: false,
      onFocusChange: (v) {
        if (v != _expanded) setState(() => _expanded = v);
      },
      // Safety net: an arrow key that no descendant here has anywhere to
      // send it (e.g. right-arrow with no filters, or off some edge case
      // in the results carousel) would otherwise bubble past this whole
      // subtree unhandled — Flutter's own default directional-focus
      // traversal then picks it up and can jump focus to any other
      // focusable widget on screen by raw geometry, including an unrelated
      // catalog card far to the right, underneath this panel. Swallowing
      // every arrow key here while expanded keeps "leaving search" limited
      // to the explicit exits (Escape/Back, the close button) instead.
      //
      // Escape/Back is also caught here as a last-resort dismiss: the
      // search bar, filters button and close button all already handle it
      // directly, but the on-screen keyboard's own keys (letters,
      // backspace, space, enter) never did — pressing Escape while typing
      // silently did nothing instead of closing search. This is the one
      // place every focus path inside quick search passes through, so it
      // covers the keyboard (and anything else that doesn't handle Escape
      // more specifically) without having to thread a callback through
      // on_screen_keyboard.dart itself.
      onKeyEvent: (_, ev) {
        // _scopeFocusNode.hasFocus, not _expanded: _expanded only updates on
        // the next rebuild (it's set via this same node's onFocusChange,
        // which fires through a setState), while .hasFocus reflects the
        // real, current focus-manager state the instant requestFocus() is
        // called — no rebuild lag. On real Android TV hardware, a held
        // button delivers a fast cascade of genuine KeyDownEvents (not
        // KeyRepeatEvent), so a call arriving in that single-frame gap right
        // as focus first lands here used to read _expanded as still false
        // and fall through unhandled — right back out to whatever opened
        // search in the first place, reopening/closing it repeatedly for as
        // long as the button stayed held.
        if (!_scopeFocusNode.hasFocus) return KeyEventResult.ignored;
        final k = ev.logicalKey;
        final isArrow = k == LogicalKeyboardKey.arrowUp ||
            k == LogicalKeyboardKey.arrowDown ||
            k == LogicalKeyboardKey.arrowLeft ||
            k == LogicalKeyboardKey.arrowRight;
        // Swallow held-arrow *repeats* too, not just KeyDown: some TV
        // remotes emit real KeyRepeatEvents for a held D-pad. If one bubbled
        // up here unhandled it would reach Flutter's default directional
        // focus traversal and walk focus straight out of the open panel by
        // raw geometry — which read as quick search flickering shut (then
        // back open) while Up stayed held.
        if (ev is KeyRepeatEvent) {
          return isArrow ? KeyEventResult.handled : KeyEventResult.ignored;
        }
        if (ev is! KeyDownEvent) return KeyEventResult.ignored;
        if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
          // Funnel through the shared back gate, not just this widget's own
          // _dismiss() debounce: on an HDMI-CEC box the same Back press also
          // arrives on the platform channel (Activity.onBackPressed →
          // System.popRoute) and reaches the home root's PopScope. Without
          // claiming the window here, that echo was read as a fresh press
          // and popped the "premi due volte per uscire" hint. `consumeBackEvent`
          // false = same press on the other path → swallow. Still `handled`
          // either way so the key never bubbles.
          if (consumeBackEvent()) _dismiss();
          return KeyEventResult.handled;
        }
        return isArrow ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: BlocProvider.value(
        value: _bloc,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: _expanded ? expandedW : collapsedW,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          // Blurred backdrop + a genuinely translucent tint, replacing what
          // used to be a near-opaque (0xF0 ≈ 94%) solid panel — that fully
          // hid the catalog row behind it instead of reading as an overlay
          // on top of it. The blur is what keeps result text legible at a
          // low enough alpha to actually see through.
          //
          // BackdropFilter forces a framebuffer read-back + Gaussian pass
          // for as long as it's in the tree — even at sigma 0, Skia still
          // allocates the offscreen compositing layer, it just skips the
          // blur math. Since this bar is always mounted (collapsed or not)
          // on every home screen frame, keeping it in the tree unconditionally
          // was a *permanent* per-frame GPU cost paid whether or not anyone
          // ever opens search — exactly backwards for an app meant to run on
          // low-end Android TV boxes/sticks, not to chase a flagship-tier
          // frosted-glass look. So the filter is only mounted while actually
          // expanded; collapsed uses a plain translucent Container with zero
          // blur cost. searchContent (built once above) is shared unchanged
          // between both branches so this split doesn't duplicate that
          // subtree — its widgets do get rebuilt on each expand/collapse
          // (the ancestor type differs either way), but that's one discrete,
          // user-triggered transition, not a per-frame tax.
          child: _expanded
              ? (lowPowerUi
                  // "Hardware modesto": no framebuffer read-back + Gaussian
                  // pass. A near-opaque solid panel keeps result text
                  // legible without the blur shader.
                  ? Container(
                      padding: EdgeInsets.all(AppScale.space(context, 21.6)),
                      color: const Color(0xF2101018),
                      child: searchContent,
                    )
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.all(AppScale.space(context, 21.6)),
                        color: const Color(0xAD101018),
                        child: searchContent,
                      ),
                    ))
              : Container(
                  padding: EdgeInsets.zero,
                  color: Colors.transparent,
                  child: searchContent,
                ),
        ),
      ),
    );
  }
}

