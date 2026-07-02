// Part of home_screen.dart — split out for readability (plan 2e). The library
// file holds the shared imports plus the _HomeFsm enum and the HomeScreen
// entry point; private identifiers are shared across all parts.
part of '../home_screen.dart';

// ── standard home shell — fullscreen Stack: fanart + metadata + carousel overlay

class _StandardHomeShell extends StatefulWidget {
  final PluginInfo plugin;
  // Listenable, not a value: only the ValueListenableBuilder wrapping the
  // hero + metadata in build() reacts to it, so focusing a card doesn't
  // rebuild this whole shell (carousels included).
  final ValueListenable<CatalogItem?> displayItem;
  final List<DiscoveryBloc> sectionBlocs;
  final void Function(CatalogItem) onItemFocused;
  final void Function(FocusNode) onFirstCardFocus;
  final VoidCallback onOpenNav;
  final VoidCallback onNavigateUpFromCarousel;

  const _StandardHomeShell({
    super.key,
    required this.plugin,
    required this.displayItem,
    required this.sectionBlocs,
    required this.onItemFocused,
    required this.onFirstCardFocus,
    required this.onOpenNav,
    required this.onNavigateUpFromCarousel,
  });

  @override
  State<_StandardHomeShell> createState() => _StandardHomeShellState();
}

class _StandardHomeShellState extends State<_StandardHomeShell> {
  // _activeCatalog == -1 means the "continue watching" strip is active.
  int _activeCatalog = 0;
  // ContinueWatchingBloc loads asynchronously, so at initState() time we
  // don't yet know whether this plugin has any items — this flags the
  // first time its state resolves (empty or not) for this shell instance,
  // so build() below can jump straight to the CW strip on that one
  // resolution instead of starting on catalog 0 and never revisiting it.
  bool _initialCWCheckDone = false;
  // Indices of catalogs confirmed empty after load — skip when navigating
  final Set<int> _emptyCatalogs = {};

  // SafeFocusRef (see lib/shared/utils/safe_focus.dart) — same rationale
  // as _PluginPageBodyState._firstCardFocus above: a catalog/row switch
  // can dispose the previous carousel's FocusNodes before this is re-set.
  final _firstCard = SafeFocusRef();

  // A zero-size node focus is parked on during a row switch so it's never
  // null while the outgoing row's card gets disposed and the incoming one
  // isn't built yet — a null primary focus is what let an arrow key drift to
  // the quick-search bar. Its onKeyEvent (see build) eats arrow keys until
  // _consumePendingSwitchFocus hands focus to the real card.
  final FocusNode _switchParkFn = FocusNode(debugLabel: 'row-switch-park');

  // The continue-watching strip stays mounted across plugin re-visits, so
  // its own initState self-focus fires only once — reach it directly to
  // re-focus its first card whenever it becomes the shown row again.
  final GlobalKey<_ContinueWatchingStripState> _cwStripKey = GlobalKey();

  // Hold-to-repeat between carousel rows (Up/Down). The desktop/X11 dev
  // target doesn't reliably deliver a genuine stream of KeyDownEvents while
  // a key is held (see _onCarouselUp's own doc, and the same finding in
  // series_page_layout.dart's _onEpisodeHoldChanged / player_seek_bar.dart's
  // _holdTickInterval) — a real Android TV remote does, which is why
  // _onCarouselUp/_goNext were written to be safely callable repeatedly
  // (boundary-safe, cooldown-gated) without this timer. This synthesizes
  // that same repeated-call stream everywhere else, by having the row
  // widgets report raw KeyDown/KeyUp (via onNavigateHoldChanged, already
  // wired all the way down to CardCarouselBlockView's rows and
  // _ContinueWatchingStrip — only the top-level wiring was missing) instead
  // of relying on the platform to repeat the key itself.
  Timer? _carouselHoldTimer;
  LogicalKeyboardKey? _carouselHeldKey;
  static const _carouselHoldInitialDelay = Duration(milliseconds: 380);
  // Comfortably above _catalogSwitchGuard (260ms) so every tick actually
  // lands a switch instead of being silently eaten by that cooldown.
  static const _carouselHoldInterval = Duration(milliseconds: 300);

  void _onCarouselHoldChanged(LogicalKeyboardKey key, bool isDown) {
    if (key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown) {
      return;
    }
    if (isDown) {
      _carouselHeldKey = key;
      _carouselHoldTimer?.cancel();
      _carouselHoldTimer = Timer(_carouselHoldInitialDelay, _carouselHoldTick);
    } else if (key == _carouselHeldKey) {
      _carouselHoldTimer?.cancel();
      _carouselHoldTimer = null;
      _carouselHeldKey = null;
    }
  }

  void _carouselHoldTick() {
    final key = _carouselHeldKey;
    if (key == null || !mounted) return;
    if (key == LogicalKeyboardKey.arrowUp) {
      // A hold climbs the rows and stops at the top — it must never open
      // quick search (that's a deliberate-single-press action, see
      // _onCarouselUp). Once Up can't move further within the rows, the
      // hold's job is done: stop the timer instead of spinning or escaping.
      if (_upWouldEscapeToSearch()) {
        _carouselHoldTimer?.cancel();
        _carouselHoldTimer = null;
        _carouselHeldKey = null;
        return;
      }
      _onCarouselUp();
    } else {
      _goNext();
    }
    _carouselHoldTimer = Timer(_carouselHoldInterval, _carouselHoldTick);
  }

  @override
  void dispose() {
    _carouselHoldTimer?.cancel();
    _switchParkFn.dispose();
    super.dispose();
  }

  // Called (via GlobalKey, from _PluginPageBodyState) when the user
  // switches TO this plugin from the nav — this widget stays mounted the
  // whole time the app runs (see _HomeViewState.build()), so without this
  // _activeCatalog would silently resume wherever it was left on the
  // previous visit instead of showing the topmost row again.
  //
  // Topmost = the continue-watching strip when this plugin has any CW items,
  // otherwise catalog 0. If CW hasn't finished loading yet, land on catalog
  // 0 and let the _initialCWCheckDone path in build() jump up once it does.
  void resetToFirstCatalog() {
    final target = _hasCW ? -1 : 0;
    _initialCWCheckDone = false;
    if (_activeCatalog != target) {
      setState(() {
        _activeCatalog = target;
      });
    }
    // Always re-establish focus on the target row's first card, even when the
    // row was already active — re-picking the plugin from the nav (or coming
    // back to a plugin page that kept its state) can leave focus nowhere,
    // and the next arrow key then drifts to the quick-search bar.
    _focusFirstAfterSwitch();
  }

  // This widget stays mounted for the plugin's whole lifetime (see above),
  // but widget.plugin itself gets swapped for a fresher PluginInfo on every
  // PluginBloc refresh (e.g. the 30s background poll) — if that refresh
  // reports fewer catalogs than before, _activeCatalog can be left pointing
  // past the end of the new list, crashing the `catalogs[safeIdx]` lookup
  // in build(). Clamp it back in range whenever the catalog count shrinks.
  @override
  void didUpdateWidget(_StandardHomeShell old) {
    super.didUpdateWidget(old);
    final oldIds = old.plugin.catalogs.map((c) => c.id).toList();
    final newIds = widget.plugin.catalogs.map((c) => c.id).toList();
    var catalogsChanged = oldIds.length != newIds.length;
    if (!catalogsChanged) {
      for (var i = 0; i < oldIds.length; i++) {
        if (oldIds[i] != newIds[i]) {
          catalogsChanged = true;
          break;
        }
      }
    }
    if (catalogsChanged) {
      // _PluginPageBodyState has already rebuilt widget.sectionBlocs to
      // match the new catalog list by the time this runs (its
      // didUpdateWidget always runs before this child's), but _emptyCatalogs
      // is this widget's own state and would otherwise keep marking indices
      // "empty" against catalogs that just moved into those positions.
      _emptyCatalogs.clear();
      // The common case here isn't a real plugin switch — it's the "still
      // indexing" case (mostly sport: a live category appears/disappears
      // elsewhere in the list). Snapping back to row 0 on every such change
      // yanked the user off whatever they were actually looking at. Follow
      // the currently active catalog to its new position by id instead —
      // only fall back to row 0 if that catalog itself is the one that
      // disappeared (or the previous index was already out of range/CW).
      if (_activeCatalog >= 0 && _activeCatalog < oldIds.length) {
        final newIndex = newIds.indexOf(oldIds[_activeCatalog]);
        if (newIndex >= 0) {
          _activeCatalog = newIndex;
          return;
        }
      }
      _activeCatalog = 0;
      return;
    }
    final maxIdx = widget.plugin.catalogs.length - 1;
    if (_activeCatalog > maxIdx) {
      _activeCatalog = maxIdx;
    }
  }

  // CW hero — fetched from getDetails when a CW item is focused
  CatalogItem? _cwDisplayItem;
  final Map<String, CatalogItem> _cwHeroCache = {};
  // Key of the CW card that currently has focus. _fetchCwHero checks this
  // before applying its (async) result so a slow fetch for a card the user
  // has already moved off of doesn't overwrite the hero for the card they're
  // on now (e.g. focus Futurama, move to Simpsons before Futurama's details
  // land → hero must not snap back to Futurama).
  String? _cwFocusedKey;

  String _cwHeroKey(ContinueWatchingItem item) =>
      '${item.providerID}/${item.parentID.isNotEmpty ? item.parentID : item.playableID}';

  // A hero item built straight from the ContinueWatchingItem's own fields —
  // shown immediately on focus so the hero always matches the focused card,
  // then upgraded in place by _fetchCwHero with the logo / fanart / richer
  // plot. plot/rating/genres/year already come back from GetContinueWatching
  // (watch_history columns), so the hero is never metadata-less even if the
  // details lookup fails.
  CatalogItem _cwPlaceholderItem(ContinueWatchingItem item) {
    final displayTitle =
        item.showTitle.isNotEmpty ? item.showTitle : item.title;
    return CatalogItem(
      id: item.parentID.isNotEmpty ? item.parentID : item.playableID,
      title: displayTitle,
      posterUrl: item.poster,
      logoUrl: '',
      mediaType: '',
      isDir: false,
      year: item.year,
      rating: item.rating,
      extra: {
        'fanart_url': item.poster,
        'plot': item.plot,
        'genres': item.genres.join(', '),
      }.entries,
    );
  }

  // The hero item for the current context: the continue-watching hero while
  // that strip is active, otherwise whatever card is focused in a regular
  // row ([fromRow], the ValueListenableBuilder's current value).
  CatalogItem? _effectiveItem(CatalogItem? fromRow) =>
      (_activeCatalog == -1 && _cwDisplayItem != null)
          ? _cwDisplayItem
          : fromRow;

  void _onCwItemFocused(ContinueWatchingItem item) {
    final key = _cwHeroKey(item);
    _cwFocusedKey = key;
    // Always switch the hero to the focused card right now — cached rich
    // details if we have them, otherwise a placeholder built from the CW
    // item's own metadata. Never leave the hero showing the previously
    // focused card while a fetch is in flight.
    final next = _cwHeroCache[key] ?? _cwPlaceholderItem(item);
    if (!identical(_cwDisplayItem, next)) {
      setState(() => _cwDisplayItem = next);
    }
    if (!_cwHeroCache.containsKey(key)) _fetchCwHero(item, key);
  }

  // Per-card cooldown so a `_fetchCwHero` that keeps failing (no parentID,
  // getDetails errors, response is neither series nor movie) isn't re-run on
  // every single focus change. Without it, D-pad bouncing on a CW card — or
  // any rebuild that re-fires _onCwItemFocused — turns into a getDetails
  // storm, and each getDetails can be moderately expensive server-side.
  final Map<String, DateTime> _cwHeroFetchAt = {};

  Future<void> _fetchCwHero(ContinueWatchingItem item, String key) async {
    if (_cwHeroCache.containsKey(key)) return;
    final last = _cwHeroFetchAt[key];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _cwHeroFetchAt[key] = DateTime.now();
    try {
      // MediaRepository, not a captured MediaGrpcClient: the repo resolves
      // getIt<MediaGrpcClient>() fresh on every call, so it can't go stale
      // after rebuildGrpcClients() the way holding the client directly
      // could (see media_repository.dart's own `_client` getter).
      final repo = getIt<MediaRepository>();
      // An episode either carries a stored parentID, or we can still tell
      // it apart by its showTitle overline — older CW rows (and some launch
      // paths) never stored parent_id.
      final isEpisode = item.parentID.isNotEmpty ||
          (item.showTitle.isNotEmpty &&
              item.showTitle.toLowerCase() != item.title.toLowerCase());

      // Its own details always come first: for an episode they yield the
      // synopsis and, when parentID wasn't stored, the show_id to look the
      // series up with.
      DetailsResponse? episodeResp;
      var parentId = item.parentID;
      if (isEpisode) {
        // playableID is often the resolved stream-source id, not a real
        // mediaId — this getDetails can legitimately fail. Tolerate it: we
        // still have parentID (usually) and the CW item's own metadata.
        try {
          episodeResp = await repo.getDetails(item.providerID, item.playableID);
          if (!mounted) return;
          if (parentId.isEmpty) parentId = episodeResp.item.showId;
        } catch (e) {
          // Session expiry is real regardless of which of this function's
          // two getDetails calls surfaced it — rethrow so the outer catch
          // (which checks isUnauthenticated) sees it too, instead of it
          // being silently tolerated along with an actually-safe-to-ignore
          // "bad playableID" error.
          if (isUnauthenticated(e)) rethrow;
          episodeResp = null;
        }
      }

      if (parentId.isEmpty && isEpisode) {
        // No usable id to look the show up with — keep the placeholder
        // (already carries plot/rating/genres/year from the CW row).
        return;
      }
      final lookupId = parentId.isNotEmpty ? parentId : item.playableID;
      final resp = await repo.getDetails(item.providerID, lookupId);
      if (!mounted || _cwFocusedKey != key) return;
      final title = item.showTitle.isNotEmpty ? item.showTitle : item.title;
      CatalogItem? display;
      if (resp.hasSeries()) {
        final s = resp.series;
        final episode = (episodeResp != null && episodeResp.hasEpisode())
            ? episodeResp.episode
            : null;
        // The CW hero should read like the series' own details page — the
        // show synopsis first. Only when the series carries no plot at all
        // do we fall back to the episode synopsis, then the season overview.
        var plot = s.plot;
        if (plot.isEmpty) plot = episode?.plot ?? '';
        if (plot.isEmpty && episode != null) {
          final season = s.seasons
              .where((se) => se.number == episode.seasonNumber)
              .firstOrNull;
          plot = season?.overview ?? '';
        }
        display = CatalogItem(
          id: lookupId,
          title: title,
          posterUrl: s.posterUrl.isNotEmpty ? s.posterUrl : item.poster,
          logoUrl: s.logoUrl,
          mediaType: 'series',
          isDir: false,
          year: s.year,
          rating: resp.item.rating,
          extra: {
            'fanart_url': s.fanartUrl.isNotEmpty ? s.fanartUrl : item.poster,
            'plot': plot,
            'genres': s.genres.join(', '),
          }.entries,
        );
      } else if (resp.hasMovie()) {
        final m = resp.movie;
        display = CatalogItem(
          id: lookupId,
          title: title,
          posterUrl: m.posterUrl.isNotEmpty ? m.posterUrl : item.poster,
          logoUrl: m.logoUrl,
          mediaType: 'movie',
          isDir: false,
          year: m.year,
          rating: resp.item.rating,
          extra: {
            'fanart_url': m.fanartUrl.isNotEmpty ? m.fanartUrl : item.poster,
            'plot': m.plot,
            'genres': m.genres.join(', '),
          }.entries,
        );
      }
      if (display != null) {
        _cwHeroCache[key] = display;
        // Only paint it if the user is still on this card.
        if (mounted && _cwFocusedKey == key) {
          setState(() => _cwDisplayItem = display);
        }
      }
    } catch (e) {
      // Was swallowing this indiscriminately, unauthenticated included —
      // the user just saw an empty CW hero with no indication the session
      // had actually expired (2026-09 audit).
      if (isUnauthenticated(e)) {
        getIt<AuthBloc>().add(const SessionExpiredEvent());
        return;
      }
      if (kDebugMode) debugPrint('[CW Hero] fetch error key=$key: $e');
    }
  }

  bool get _isLivePlugin =>
      widget.plugin.catalogs.isNotEmpty &&
      widget.plugin.catalogs.every((c) => c.type == 'live');

  // Tied to whichever catalog is currently active (not plugin-wide like
  // _isLivePlugin) — a plugin can mix catalogs that want the dynamic hero
  // with ones that don't. -1 is the continue-watching pseudo-section, which
  // spans multiple plugins/catalogs and isn't covered by any single
  // CatalogDef, so it always keeps the default (dynamic) hero.
  bool get _heroBackgroundDisabled =>
      _activeCatalog >= 0 &&
      _activeCatalog < widget.plugin.catalogs.length &&
      widget.plugin.catalogs[_activeCatalog].disableHeroBackground;

  bool get _hasCW {
    if (_isLivePlugin) return false;
    final s = context.read<ContinueWatchingBloc>().state;
    return s is ContinueWatchingLoaded &&
        s.items.any((i) => i.providerID == widget.plugin.pluginId);
  }

  void onCatalogEmpty(int index) {
    if (_emptyCatalogs.contains(index)) return;
    setState(() => _emptyCatalogs.add(index));
    if (_activeCatalog != index) return;
    // Try forward, then backward, then escape upward if all catalogs are
    // empty — nextFocusableIndex (lib/shared/utils/safe_focus.dart) is the
    // same skip-forward/skip-backward idiom migrated into search_screen.dart's
    // filter panel and originally hand-rolled independently in both places.
    final length = widget.plugin.catalogs.length;
    final forward = nextFocusableIndex(
      from: _activeCatalog,
      direction: 1,
      length: length,
      isSkippable: (i) => _emptyCatalogs.contains(i),
    );
    if (forward != null) {
      setState(() {
        _activeCatalog = forward;
      });
      return;
    }
    final backward = nextFocusableIndex(
      from: _activeCatalog,
      direction: -1,
      length: length,
      isSkippable: (i) => _emptyCatalogs.contains(i),
    );
    if (backward != null) {
      setState(() {
        _activeCatalog = backward;
      });
      return;
    }
    // All catalogs empty — hand focus back up so the user isn't stranded.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onNavigateUpFromCarousel());
  }

  // Guards row-to-row switching against native key-repeat (~20-30
  // events/sec while a button is held, see TvFocusable's onKeyEvent doc):
  // without this, holding Up/Down would blow straight through several rows
  // in the time it takes the 260ms crossfade to play once. A fresh press
  // arriving after this window still switches immediately; only repeats
  // packed tighter than the guard get absorbed, so a held press advances
  // one row at a steady, watchable pace instead of stalling (the old bug)
  // or instantly skipping many rows (what a naive repeat-fire would do).
  DateTime? _lastCatalogSwitchAt;
  static const _catalogSwitchGuard = Duration(milliseconds: 260);

  bool _catalogSwitchOnCooldown() {
    final last = _lastCatalogSwitchAt;
    return last != null &&
        DateTime.now().difference(last) < _catalogSwitchGuard;
  }

  void _goNext() {
    if (_catalogSwitchOnCooldown()) return;
    _lastCatalogSwitchAt = DateTime.now();
    _slide(1);
  }

  void _goPrev() {
    if (_catalogSwitchOnCooldown()) return;
    _lastCatalogSwitchAt = DateTime.now();
    _slide(-1);
  }

  void _slide(int dir) {
    final max = widget.plugin.catalogs.length - 1;

    if (_activeCatalog == -1 && dir > 0) {
      // From continue watching → first real catalog
      setState(() {
        _activeCatalog = 0;
      });
      _focusFirstAfterSwitch();
      return;
    }

    var next = _activeCatalog + dir;
    if (next < 0) {
      // Going back past catalog 0 — show continue watching if available.
      if (_hasCW) {
        setState(() {
          _activeCatalog = -1;
        });
        _focusFirstAfterSwitch();
        context
            .read<ContinueWatchingBloc>()
            .add(const LoadContinueWatchingEvent());
      } else {
        _pendingSwitchFocus = false;
        widget.onNavigateUpFromCarousel();
      }
      return;
    }
    while (next >= 0 && next <= max && _emptyCatalogs.contains(next)) {
      next += dir;
    }
    if (next < 0 || next > max) return;
    setState(() {
      _activeCatalog = next;
    });
    _focusFirstAfterSwitch();
  }

  // True when the very next Up would leave this plugin's rows entirely
  // (mirrors _slide's own "next < 0 && !_hasCW → onNavigateUpFromCarousel"
  // fallback, and _ContinueWatchingStrip's onNavigateUp — always that same
  // escape once already on CW, nothing sits above it).
  bool _upWouldEscapeToSearch() {
    if (_activeCatalog == -1) return true;
    final hasPrev = List.generate(_activeCatalog, (i) => i)
        .any((i) => !_emptyCatalogs.contains(i));
    if (hasPrev) return false;
    return !_hasCW;
  }

  // Single entry point for Up from any focused card in this plugin's rows
  // (both the carousel and the CW strip wire straight to this — no more
  // ternary picking between _goPrev and widget.onNavigateUpFromCarousel at
  // the call site, this decides internally instead).
  //
  // Quick search opens ONLY on a deliberate, isolated Up press once already
  // on the topmost row — never on a key-repeat. A held Up (real Android
  // hardware sends a dense KeyDownEvent cascade, not KeyRepeatEvent) and a
  // fast burst of taps alike just climb the rows and then stop at the top;
  // the next Up that arrives after a real pause is the one that opens
  // search. Timestamping every Up handled here (climb step or top-row hit
  // alike) is what tells the two apart: anything within _freshPressGap of
  // the previous Up is a repeat.
  DateTime? _lastUpAt;
  // Must stay above the hardware remote's initial key-repeat delay
  // (~400-500ms on the boxes this was tested on) — otherwise the first
  // repeat after a held Up lands on the top row reads as a fresh press and
  // pops search open mid-hold, the exact bug being fixed here.
  static const _freshPressGap = Duration(milliseconds: 600);

  void _onCarouselUp() {
    final now = DateTime.now();
    final prevUpAt = _lastUpAt;
    _lastUpAt = now;

    if (!_upWouldEscapeToSearch()) {
      _goPrev();
      return;
    }

    // On the topmost row. Suppress anything that's part of a hold / rapid
    // repeat — it just parks focus here.
    final isKeyRepeat =
        prevUpAt != null && now.difference(prevUpAt) <= _freshPressGap;
    if (isKeyRepeat) return;

    // Leaving the rows for search — a still-pending switch-focus retry would
    // otherwise yank focus back onto a card the moment its carousel loads.
    _pendingSwitchFocus = false;
    widget.onNavigateUpFromCarousel();
    // The synthetic hold-repeat timer (see _onCarouselHoldChanged) stops
    // only on key-up, which once focus has moved to the search bar may never
    // arrive back here — cancel it proactively.
    _carouselHoldTimer?.cancel();
    _carouselHoldTimer = null;
    _carouselHeldKey = null;
  }

  // Metadata layers — top-down layout anchored from topBase.
  // Order: title → meta row → genres → plot (top to bottom).
  // Each zone has a fixed height derived from screenH — nothing shifts.
  List<Widget> _buildMetaLayers({
    required CatalogItem? item,
    required double left,
    required double metaW,
    required double screenW,
    required double topBase,
    required double screenH,
    required double carouselTop, // top edge of the carousel strip
    required double textScale, // MediaQuery.textScalerOf(context).scale(1.0)
    bool isLive = false,
  }) {
    // Live hero sits a touch lower — it reads as a featured event rather than
    // a header pinned to the very top. Non-live layouts are unchanged.
    final effTopBase = isLive ? topBase + screenH * 0.035 : topBase;
    // Long live titles used to run edge-to-edge before wrapping; a narrower
    // centred column makes them break onto a second line much sooner.
    final liveTitleW = screenW * 0.66;
    final titleFs = isLive ? screenH * 0.060 : screenH * 0.045;
    final metaChipFs =
        (screenH * 0.022).clamp(11.0, 48.0); // must match _MetaChip.build()
    final genreFs = screenH * 0.013;

    // Title zone is a fixed-height Positioned layer with a 2-line, ellipsised
    // title inside it. screenH*0.14 (0.18 live) covers 2 lines at textScale
    // 1.0 with margin, but the desktop/web build runs an ambient ~1.35×
    // textScaler (see main.dart) that the raw ratio doesn't know about — a
    // long 2-line title then painted past this zone and over the meta row
    // below it. Grow the reservation with textScale (no-op at 1.0, i.e. on a
    // plain Android TV); the plot below auto-fits into whatever's left.
    final zTitleH =
        (isLive ? screenH * 0.18 : screenH * 0.14) * textScale.clamp(1.0, 1.4);
    // Chip zones only need a light textScale allowance to contain their single
    // line — over-provisioning here steals vertical space from the plot below.
    // The live status line (IN DIRETTA pill + start time) needs a bit more.
    final zMetaH = metaChipFs * textScale * (isLive ? 1.9 : 1.35);
    final zGenreH = genreFs * textScale * 1.5 + screenH * (6.0 / 1080.0);
    final zGap1 = screenH * 0.012;
    final zGap2 = screenH * 0.009;
    final zGap3 = screenH * 0.009;
    // plot fills all space down to the carousel top edge (minus a small margin)
    final plotBottom = carouselTop - screenH * 0.004;
    final plotTop =
        effTopBase + zTitleH + zGap1 + zMetaH + zGap2 + zGenreH + zGap3;

    // Auto-fit the plot font to a TARGET line count so the number of visible
    // lines stays consistent across resolutions/aspect ratios (previously it
    // collapsed to 2 lines on QHD because the font grew with the screen). The
    // font is capped so it never balloons on QHD/4K and floored so it stays
    // readable; the line height then follows from the chosen font.
    final availPlotH = (plotBottom - plotTop).clamp(0.0, screenH * 0.42);
    final targetLines = isLive ? 3 : 4;
    // Must equal the plot Text's own TextStyle.height below (1.5) — this
    // factor is what sizes the reserved box (plotMaxLines * plotLineH), so
    // any mismatch between the two means the box is a few px shorter than
    // what plotMaxLines worth of *actual* rendered lines need, clipping the
    // bottom line's descenders on nearly every render rather than cleanly
    // ellipsizing at the line the box was sized for.
    final lineFactor = textScale * 1.5;
    final nominalFs = isLive
        ? (screenH * 0.030).clamp(16.0, 34.0)
        : (screenH * 0.020).clamp(12.0, 22.0);
    final minFs = isLive ? 14.0 : 11.0;
    final fitFs = availPlotH / (targetLines * lineFactor);
    final plotFs = fitFs.clamp(minFs, nominalFs).toDouble();
    final plotLineH = plotFs * lineFactor;
    final plotMaxLines =
        (availPlotH / plotLineH).floor().clamp(2, isLive ? 4 : 8);

    final tTitle = effTopBase;
    final tMeta = tTitle + zTitleH + zGap1;
    final tGenres = tMeta + zMetaH + zGap2;
    final tPlot = tGenres + zGenreH + zGap3;

    if (item == null) {
      if (isLive) {
        return [
          Positioned(
              left: 0,
              right: 0,
              top: tTitle,
              child: Center(
                  child: _ShimmerBox(width: metaW * 0.75, height: zTitleH))),
          Positioned(
              left: 0,
              right: 0,
              top: tMeta,
              child: Center(
                  child: _ShimmerBox(width: metaW * 0.35, height: zMetaH))),
        ];
      }
      return [
        Positioned(
            left: left,
            top: tTitle,
            child: _ShimmerBox(width: metaW * 0.75, height: zTitleH)),
        Positioned(
            left: left,
            top: tMeta,
            child: _ShimmerBox(width: metaW * 0.35, height: zMetaH)),
      ];
    }

    final hasMeta = item.year > 0 || item.rating > 0;
    final genreStr = item.extra['genres'] ?? '';
    // For a live event the plugin tends to stuff redundant tags into
    // `genres` — a literal "In diretta" (already the red pill) and the sport
    // name (now its own chip in _LiveStatusLine). Drop both so nothing is
    // shown twice.
    final sportCatLc = (item.extra['sport_cat'] ?? '')
        .toLowerCase()
        .replaceAll('-', ' ')
        .trim();
    final genres = genreStr.isNotEmpty
        ? genreStr
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .where((g) =>
                !isLive ||
                (!_redundantLiveGenres.contains(g.toLowerCase()) &&
                    g.toLowerCase().replaceAll('-', ' ') != sportCatLc))
            .take(4)
            .toList()
        : <String>[];
    final plot = item.extra['plot'] ?? '';

    final logoAlign = isLive ? Alignment.center : Alignment.centerLeft;
    final titleAlign = isLive ? Alignment.topCenter : Alignment.topLeft;
    final metaAlign = isLive ? Alignment.center : Alignment.centerLeft;
    final textCenter = isLive ? TextAlign.center : TextAlign.start;

    return [
      isLive
          ? Positioned(
              left: 0,
              right: 0,
              top: tTitle,
              child: _MetaZone(
                itemId: item.id,
                width: screenW,
                height: zTitleH,
                alignment: titleAlign,
                child: item.logoUrl.isNotEmpty
                    ? SizedBox(
                        width: screenW,
                        height: zTitleH,
                        child: Align(
                          alignment: logoAlign,
                          child: Builder(builder: (ctx) {
                            final maxH = zTitleH;
                            final maxW = metaW * 0.65;
                            final size = logoRenderSize(item.logoUrl,
                                targetW: maxW, maxH: maxH, maxW: maxW);
                            return _LogoWidget(
                              url: logoUrlOnly(item.logoUrl),
                              width: size.w,
                              height: size.h,
                              isDark: logoDark(item.logoUrl),
                              fallback: SizedBox(
                                width: liveTitleW,
                                child: Text(item.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppTheme.textHigh,
                                        fontSize: titleFs,
                                        fontWeight: FontWeight.w900,
                                        height: 1.12,
                                        letterSpacing: 0.5),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            );
                          }),
                        ),
                      )
                    : SizedBox(
                        width: liveTitleW,
                        height: zTitleH,
                        // Vertically centered in the title zone instead of
                        // sitting flush at its top — only the has-logo
                        // branch above already did this (via its own
                        // Align); the plain-text fallback used to be handed
                        // straight to _MetaZone's own top-anchored
                        // alignment instead.
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(item.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textHigh,
                                  fontSize: titleFs,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                  letterSpacing: 0.5),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
              ))
          : Positioned(
              left: left,
              top: tTitle,
              child: _MetaZone(
                itemId: item.id,
                width: metaW,
                height: zTitleH,
                alignment: Alignment.topLeft,
                child: item.logoUrl.isNotEmpty
                    ? SizedBox(
                        width: metaW,
                        height: zTitleH,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Builder(builder: (ctx) {
                            // Logo cappato a ~2 righe di titolo in altezza, 50% pannello in larghezza.
                            // Questo rende loghi di plugin diversi visivamente consistenti.
                            final maxH = zTitleH;
                            final maxW = metaW * 0.65;
                            final size = logoRenderSize(
                              item.logoUrl,
                              targetW: maxW,
                              maxH: maxH,
                              maxW: maxW,
                            );
                            return _LogoWidget(
                              url: logoUrlOnly(item.logoUrl),
                              width: size.w,
                              height: size.h,
                              isDark: logoDark(item.logoUrl),
                              fallback: SizedBox(
                                width: metaW,
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: AppTheme.textHigh,
                                    fontSize: titleFs,
                                    fontWeight: FontWeight.w900,
                                    height: 1.10,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }),
                        ),
                      )
                    : SizedBox(
                        width: metaW,
                        height: zTitleH,
                        // Same fix as the isLive branch above — center
                        // instead of top-anchoring the plain-text fallback.
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: titleFs,
                              fontWeight: FontWeight.w900,
                              height: 1.10,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
              )),

      Positioned(
        left: isLive ? 0 : left,
        right: isLive ? 0 : null,
        top: tMeta,
        child: _MetaZone(
          itemId: item.id,
          width: isLive ? screenW : metaW,
          height: zMetaH,
          alignment: metaAlign,
          child: isLive
              ? _LiveStatusLine(item: item)
              : (hasMeta
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (item.year > 0) _MetaChip(text: '${item.year}'),
                        if (item.rating > 0) ...[
                          if (item.year > 0) const _Dot(),
                          _MetaChip(
                            icon: Icons.star_rounded,
                            text: item.rating.toStringAsFixed(1),
                            iconColor: const Color(0xFFFFD700),
                          ),
                        ],
                      ],
                    )
                  : const SizedBox.shrink()),
        ),
      ),

      Positioned(
        left: isLive ? 0 : left,
        right: isLive ? 0 : null,
        top: tGenres,
        child: _MetaZone(
          itemId: item.id,
          width: isLive ? screenW : metaW,
          height: zGenreH,
          alignment: metaAlign,
          child: genres.isNotEmpty
              ? Wrap(
                  alignment:
                      isLive ? WrapAlignment.center : WrapAlignment.start,
                  spacing: screenH * (6.0 / 1080.0),
                  children: genres
                      .map((g) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenH * (9.0 / 1080.0),
                              vertical: screenH * (3.0 / 1080.0),
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.textHigh.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(g,
                                style: TextStyle(
                                  color: AppTheme.textMid,
                                  fontSize: genreFs,
                                  letterSpacing: 0.2,
                                )),
                          ))
                      .toList(),
                )
              : const SizedBox.shrink(),
        ),
      ),

      // Plot zone: fixed-height box reserved for `targetLines` lines so the
      // block never grows/shrinks when switching between items with shorter
      // plots (or no plot at all) — only its content crossfades.
      Positioned(
        left: isLive ? 0 : left,
        right: isLive ? 0 : null,
        top: tPlot,
        child: SizedBox(
          width: isLive ? screenW : metaW * 0.80,
          height: plotMaxLines * plotLineH,
          child: Align(
            alignment: isLive ? Alignment.topCenter : Alignment.topLeft,
            child: AnimatedSwitcher(
              duration: lowPowerUi
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              switchInCurve: AppScale.fadeCurve,
              switchOutCurve: AppScale.fadeCurve,
              // AnimatedSwitcher.defaultLayoutBuilder stacks old/new children
              // with Alignment.center — during the crossfade a shorter new
              // plot sits centered against the taller outgoing one, then
              // visibly snaps to the top once the old child is removed and
              // the Stack shrinks. The outer Align above doesn't reach
              // inside the switcher's own Stack, so it must be told the
              // same top alignment explicitly.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: isLive ? Alignment.topCenter : Alignment.topLeft,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: plot.isNotEmpty
                  ? Text(
                      plot,
                      key: ValueKey(item.id),
                      textAlign: textCenter,
                      style: TextStyle(
                        color: AppTheme.textHigh.withValues(alpha: 0.65),
                        fontSize: plotFs,
                        height: 1.5,
                      ),
                      maxLines: plotMaxLines,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const SizedBox.shrink(key: ValueKey('_no_plot')),
            ),
          ),
        ),
      ),
    ];
  }

  // Set while a row switch (CW ⇄ catalog, catalog ⇄ catalog) is waiting for
  // its target row's first card to exist. Without it, switching onto a row
  // whose carousel hasn't loaded yet leaves _firstCard pointing at the
  // outgoing row's node; that node is disposed when the crossfade ends and
  // focus drifts — Flutter's default directional traversal then jumps to the
  // topmost focusable, the quick-search bar (the same failure mode
  // documented on _PluginNotReadyPage's arrow handling). The onFirstCardFocus
  // closures below consume this the moment the new row reports its card.
  bool _pendingSwitchFocus = false;

  void _focusFirstAfterSwitch() {
    _pendingSwitchFocus = true;
    // Park focus somewhere that always exists so it's never null mid-switch.
    _switchParkFn.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pendingSwitchFocus) return;
        // CW strip owns its own nodes and stays mounted across re-visits —
        // ask it directly rather than trusting _firstCard, which may still
        // point at a catalog card the user navigated to before leaving.
        if (_activeCatalog == -1 &&
            (_cwStripKey.currentState?.focusFirstCard() ?? false)) {
          _pendingSwitchFocus = false;
          return;
        }
        // Catalog row already loaded → grab its first card. If not, the flag
        // stays set and _consumePendingSwitchFocus grabs it once the
        // carousel reports a card.
        if (_firstCard.requestFocus()) _pendingSwitchFocus = false;
      });
    });
  }

  // Called from the row's onFirstCardFocus once its carousel finally reports
  // a card: if a switch was still waiting for focus, grab it now (next frame,
  // so the node is mounted).
  void _consumePendingSwitchFocus() {
    if (!_pendingSwitchFocus) return;
    _pendingSwitchFocus = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstCard.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // A plugin reporting zero catalogs is not expected in practice, but a
    // background refresh (see didUpdateWidget above) could momentarily hand
    // one over — degrade to nothing rather than indexing into an empty list.
    if (widget.plugin.catalogs.isEmpty) return const SizedBox.shrink();

    final cwState = context.watch<ContinueWatchingBloc>().state;
    final cwItems = _isLivePlugin
        ? <ContinueWatchingItem>[]
        : cwState is ContinueWatchingLoaded
            ? cwState.items
                .where((i) => i.providerID == widget.plugin.pluginId)
                .toList()
            : <ContinueWatchingItem>[];
    final hasCW = cwItems.isNotEmpty;

    // The first time CW's load actually resolves for this plugin, jump
    // straight to it if it has items — otherwise the row opens on catalog
    // 0 and CW sits one Up-press away instead of being what's shown first.
    // Only fires once, and only if the user hasn't already navigated away
    // from the still-default catalog 0 in the meantime.
    if (!_initialCWCheckDone && cwState is ContinueWatchingLoaded) {
      _initialCWCheckDone = true;
      if (hasCW && _activeCatalog == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _activeCatalog == 0) {
            setState(() {
              _activeCatalog = -1;
            });
            _focusFirstAfterSwitch();
          }
        });
      }
    }

    final isShowingCW = _activeCatalog == -1;

    // When CW is active but all its items were removed, slide to first catalog.
    if (isShowingCW && !hasCW) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeCatalog == -1) {
          setState(() {
            _activeCatalog = 0;
          });
          _focusFirstAfterSwitch();
        }
      });
    }

    final safeIdx = (isShowingCW ? 0 : _activeCatalog)
        .clamp(0, widget.plugin.catalogs.length - 1)
        .toInt();
    final cat = widget.plugin.catalogs[safeIdx];
    final maxIdx = widget.plugin.catalogs.length - 1;
    final hasNext = isShowingCW
        ? true
        : List.generate(maxIdx - _activeCatalog, (i) => _activeCatalog + 1 + i)
            .any((i) => !_emptyCatalogs.contains(i));
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final hPad = AppScale.catalogHPadRatio(screenW);
        // Metadata block anchored from top-left
        final metaTop = screenH * 0.085;

        // Section header (carousel title + dots) height — topPad +
        // max(barH, textLineH) + bottomPad. Hoisted out of the carouselTop
        // closure so the performance hero box can extend its bottom edge
        // down over the header row.
        final ts = MediaQuery.textScalerOf(context).scale(1.0);
        final secBarH = screenH * 0.033;
        final secTextH = screenH * 0.030 * ts * 1.20;
        final headerH = screenH * 0.017 +
            (secBarH > secTextH ? secBarH : secTextH) +
            screenH * 0.011;

        final carouselTop = () {
          final spacersH =
              screenH * (44.0 / 1080.0); // SizedBox(20) + SizedBox(24)
          // cardH is identical either way (kFeaturedCarouselResizeEnabled is
          // off, so visibleCards is always _kVisibleCards regardless of
          // branch) — only each strip's own focus-scale overflow reservation
          // differs (0.08 for Continue Watching's own SizedBox padding vs.
          // 0.10 for a regular carousel's, see their own widgets). That real
          // but small difference used to feed straight into carouselTop,
          // which the header (title/dots) and the plot's own font-fit math
          // both anchor to — so switching in/out of Continue Watching
          // visibly nudged the header's position and re-fit the plot to a
          // very slightly different height, reading as everything getting
          // "resized". carouselTop only needs a safe amount of headroom
          // here, not each strip's exact figure, so always using the larger
          // of the two keeps it — and everything anchored to it — identical
          // regardless of which strip is actually showing.
          final visibleCards =
              isFeaturedCatalog(cat) && kFeaturedCarouselResizeEnabled
                  ? _kVisibleCardsFeatured
                  : _kVisibleCards;
          final cCardW = (screenW -
                  hPad * 2 -
                  (AppScale.catalogGapRatio(screenW)) * (visibleCards - 1)) /
              visibleCards;
          final cardH = cCardW * 1.5;
          final scaleOvf = cardH * 0.10;
          final stripH = headerH + scaleOvf + cardH + scaleOvf + spacersH;
          return screenH - stripH;
        }();

        return Stack(
          fit: StackFit.expand,
          children: [
            // Focus is parked here during a row switch (see _switchParkFn /
            // _focusFirstAfterSwitch) so the primary focus is never null
            // while the outgoing row's card is disposed and the incoming
            // one hasn't been built — a null focus is what let an arrow key
            // drift up to the quick-search bar. Zero-size, skip-traversal;
            // it just swallows keydowns until _consumePendingSwitchFocus
            // moves focus onto the real card.
            Focus(
              focusNode: _switchParkFn,
              skipTraversal: true,
              onKeyEvent: (_, event) =>
                  (_pendingSwitchFocus && event is KeyDownEvent)
                      ? KeyEventResult.handled
                      : KeyEventResult.ignored,
              child: const SizedBox.shrink(),
            ),
            // ── Hero: fanart + vignettes + metadata ──────────────────────────────
            // The only region that depends on which card is focused, so the
            // only thing that rebuilds on a D-pad move — via this
            // ValueListenableBuilder. Everything below it in the Stack
            // (section header, carousel strip) stays put.
            Positioned.fill(
              child: ValueListenableBuilder<CatalogItem?>(
                valueListenable: widget.displayItem,
                builder: (context, rowItem, _) {
                  final item = _effectiveItem(rowItem);
                  // Narrower metadata column in performance mode leaves room
                  // for a bigger fanart box on the right.
                  final metaW = screenW * (lowPowerUi ? 0.38 : 0.42);
                  final metaLayers = _buildMetaLayers(
                    item: item,
                    left: hPad,
                    metaW: metaW,
                    screenW: screenW,
                    topBase: metaTop,
                    screenH: screenH,
                    textScale: MediaQuery.textScalerOf(context).scale(1.0),
                    isLive: _isLivePlugin,
                    carouselTop: carouselTop,
                  );

                  // "Performance" hero: no full-screen fanart + no
                  // full-screen black vignettes/gradients (each is a
                  // screen-sized fill + a gradient shader). Flat app
                  // background, and the image confined to a small box
                  // top-right, above the carousel and beside the metadata —
                  // a fraction of the pixels to decode / composite.
                  if (lowPowerUi) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // A touch lighter than AppTheme.bg (0xFF0D0D1A) —
                        // that read too near-black, and a black-lettered
                        // logo (glow disabled here) needs some contrast.
                        const ColoredBox(color: Color(0xFF181528)),
                        if (!_isLivePlugin && !_heroBackgroundDisabled)
                          Positioned(
                            // Sits a bit below the search bar, not flush with
                            // the metadata title. `left` clears the
                            // (now-narrower) metadata column + a gap.
                            top: metaTop + screenH * 0.022,
                            right: hPad,
                            left: hPad + metaW + screenW * 0.025,
                            // Bottom edge dips ~30% into the carousel-title
                            // row's top padding (not over the text itself) —
                            // a bit bigger poster, clean clipped edge (no
                            // fade), title stays on the flat background.
                            bottom: (screenH - carouselTop - headerH * 0.30)
                                .clamp(0.0, screenH),
                            child: RepaintBoundary(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: HomeHeroBackground(
                                  item: item,
                                  sportCat: item?.extra['sport_cat'] ?? '',
                                  forceAnonymous: _heroBackgroundDisabled,
                                  confined: true,
                                ),
                              ),
                            ),
                          ),
                        ...metaLayers,
                      ],
                    );
                  }

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: HomeHeroBackground(
                          item: item,
                          sportCat: item?.extra['sport_cat'] ?? '',
                          forceAnonymous: _heroBackgroundDisabled,
                        ),
                      ),
                      // Left vignette — hidden for live plugins
                      if (!_isLivePlugin)
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [0.0, 0.6],
                                colors: [Color(0xAA000000), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      // Left meta panel gradient — hidden for live plugins
                      if (!_isLivePlugin)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: screenW * 0.55,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [0.0, 0.55, 1.0],
                                colors: [
                                  Color(0xCC000000),
                                  Color(0x80000000),
                                  Colors.transparent
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Metadata zones — each layer is independent, fixed
                      // position. Heights are fixed so nothing shifts on
                      // content length.
                      ...metaLayers,
                    ],
                  );
                },
              ),
            ),

            // ── Row header — its own fixed-position layer, not a sibling of the
            // carousel body inside a shared bottom-anchored Column. It used to
            // be exactly that, and the body's own transitional height (old vs.
            // new card heights briefly coexist mid-crossfade — e.g. switching
            // into/out of a "live" catalog's taller cards) changed the whole
            // Column's total height every time, which visibly dragged the
            // header — dots included — up and down as a side effect of
            // geometry, not of any animation on the header itself. Anchoring
            // it at the same carouselTop the body's own reserved-height math
            // already computes makes its position immune to whatever the body
            // does under it.
            Positioned(
              left: 0,
              right: 0,
              top: carouselTop,
              // RepaintBoundary: the hero background crossfade and the
              // metadata AnimatedSwitchers above repaint on every card focus
              // change; without this the header (and the carousel below)
              // gets re-rasterised along with them each frame. Costly on a
              // Fire TV Stick.
              child: RepaintBoundary(
                child: _SectionHeader(
                  title: isShowingCW
                      ? 'Continua a guardare'
                      : (cat.name.isNotEmpty ? cat.name : cat.id),
                  isFirst: true,
                  large: !isShowingCW && cat.type == 'live',
                  rowsTotal: (hasCW ? 1 : 0) + widget.plugin.catalogs.length,
                  rowsActive:
                      isShowingCW ? 0 : (hasCW ? 1 : 0) + _activeCatalog,
                ),
              ),
            ),

            // ── Carousel strip ────────────────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: AnimatedSwitcher(
                  // Row-to-row switch. Was 260ms with a fade + a 15%
                  // slide-in — the slide especially read badly on every
                  // Up/Down. Now just a short, plain crossfade; instant
                  // under "hardware modesto".
                  switchInCurve: AppScale.fadeCurve,
                  switchOutCurve: AppScale.fadeCurve,
                  duration: lowPowerUi
                      ? Duration.zero
                      : const Duration(milliseconds: 120),
                  // Anchored bottomCenter, not AnimatedSwitcher.defaultLayoutBuilder's
                  // Alignment.center — this strip is Positioned(bottom: 0), so a
                  // shorter incoming row (e.g. switching from a live/poster
                  // catalog of one card height to another) must stay flush at
                  // the bottom during the crossfade, not centered against the
                  // taller outgoing row. Same class of bug as the plot/_MetaZone
                  // crossfades above.
                  layoutBuilder: (cur, prev) => Stack(
                    alignment: Alignment.bottomCenter,
                    children: [...prev, if (cur != null) cur],
                  ),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: isShowingCW
                      ? _ContinueWatchingStrip(
                          key: _cwStripKey,
                          items: cwItems,
                          onFirstCardFocus: (fn) {
                            _firstCard.set(fn);
                            widget.onFirstCardFocus(fn);
                            _consumePendingSwitchFocus();
                          },
                          onItemFocused: _onCwItemFocused,
                          onOpenNav: widget.onOpenNav,
                          onNavigateUp: _onCarouselUp,
                          onNavigateDown: _goNext,
                          onNavigateHoldChanged: _onCarouselHoldChanged,
                        )
                      : _CarouselBody(
                          key: ValueKey(
                              '${widget.plugin.pluginId}_$_activeCatalog'),
                          plugin: widget.plugin,
                          catalogIndex: _activeCatalog,
                          catalogDef: cat,
                          bloc: widget.sectionBlocs[_activeCatalog],
                          onItemFocused: widget.onItemFocused,
                          onFirstCardFocus: (fn) {
                            _firstCard.set(fn);
                            widget.onFirstCardFocus(fn);
                            _consumePendingSwitchFocus();
                          },
                          onOpenNav: widget.onOpenNav,
                          onNavigateUp: _onCarouselUp,
                          onNavigateDown: hasNext ? _goNext : null,
                          onNavigateHoldChanged: _onCarouselHoldChanged,
                          onEmpty: () => onCatalogEmpty(_activeCatalog),
                        ),
                ),
              ),
            ),
          ],
        );
      }, // LayoutBuilder builder
    ); // LayoutBuilder
  }
}

// _HeroBackground/_SportGradientBg were extracted to
// widgets/home_hero_background.dart (HomeHeroBackground) — first piece
// split out per the design audit's file-size recommendation (§08).

