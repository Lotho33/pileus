// Part of home_screen.dart — split out for readability (plan 2e). The library
// file holds the shared imports plus the _HomeFsm enum and the HomeScreen
// entry point; private identifiers are shared across all parts.
part of '../home_screen.dart';

// ── section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isFirst;
  final bool large; // true for live/TV layout — bigger text and more padding
  // Row position, leading the title in the same slot the plain accent bar
  // used to always occupy — null/≤1 falls back to that bar (single-row
  // plugins have nothing to indicate a position within). See
  // _RowPositionIndicator for why the dot count itself varies too.
  final int? rowsTotal;
  final int? rowsActive;
  const _SectionHeader({
    required this.title,
    required this.isFirst,
    this.large = false,
    this.rowsTotal,
    this.rowsActive,
  });

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final sw = MediaQuery.sizeOf(context).width;
    final topPad =
        sh * (isFirst ? (large ? 0.033 : 0.017) : (large ? 0.048 : 0.026));
    final barH = sh * (large ? 0.041 : 0.033);
    // Width scales with resolution too — a fixed 5/6 logical px read as a
    // hairline on a 4K panel where everything around it is ~2x.
    final barW = sh * ((large ? 6.0 : 5.0) / 1080.0);
    final fontSize = sh * (large ? 0.039 : 0.030);
    final bottomPad = sh * (large ? 0.017 : 0.011);
    final showDots = rowsTotal != null && rowsTotal! > 1;
    // Deliberately not barH — a plugin can mix "live" and regular catalogs
    // (sport does), and barH varies with `large`. Sizing the dots from it
    // meant the leading slot's width silently changed size switching
    // between catalog types, which pushed the title left/right right next
    // to it — exactly the kind of per-catalog repositioning this row
    // shouldn't have. A fixed reference keeps the slot (and the title's
    // start position) constant regardless of which catalog is showing.
    final dotsTrackHeight = sh * 0.037;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppScale.catalogHPadRatio(sw), topPad, 32, bottomPad),
      child: Row(
        children: [
          showDots
              ? _RowPositionIndicator(
                  total: rowsTotal!,
                  active: rowsActive ?? 0,
                  trackHeight: dotsTrackHeight,
                )
              : Container(
                  width: barW,
                  height: barH,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
          // Fixed, not large ? 20 : 16 — same reasoning as dotsTrackHeight
          // above: this gap varying with the current catalog's type shifted
          // the title's start position every time you crossed between a
          // "live" and a regular catalog.
          SizedBox(width: sh * (18.0 / 1080.0)),
          Flexible(
            child: AnimatedSwitcher(
              duration: lowPowerUi
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              switchInCurve: AppScale.fadeCurve,
              switchOutCurve: AppScale.fadeCurve,
              // AnimatedSwitcher.defaultLayoutBuilder stacks old/new
              // children with Alignment.center — catalog names are never
              // the same length, so the outgoing and incoming title kept
              // getting centered against each other's (different) widths
              // instead of both staying flush-left, which read as the
              // title sliding left/right on every single switch. Same bug
              // as the plot crossfade and the carousel body's own
              // bottomCenter override elsewhere in this file — missed
              // applying it here when the title got its own switcher.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Text(title,
                  key: ValueKey(title),
                  style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: fontSize,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

// Position readout, leading the title in place of the plain accent bar.
// A single dot — no static reference dots alongside it — gliding smoothly
// to active/(total-1) along a short fixed track. Earlier versions kept a
// handful of dim reference dots plus a highlight/marker that stretched
// toward them: the marker visually overlapped and blended with those
// static dots mid-transition (hard to tell which was which), and the
// stretch geometry made the motion read as larger/faster than it actually
// needed to be. One dot, one plain position tween, removes both problems
// at once — nothing for it to blend into, and the travel distance is just
// however far active actually moved, proportionally, nothing added on top.
class _RowPositionIndicator extends StatelessWidget {
  final int total;
  final int active;
  // The exact height _SectionHeader already reserves for this leading slot
  // (barH there — same value the plain accent bar uses). Sizing the track
  // from an independent screen-height ratio meant it could end up taller
  // than what the surrounding layout math actually budgeted for the header
  // row (that math assumes the old bar's height), which is what was
  // clipping it on shorter windows — fitting to this exact value instead
  // can never disagree with it.
  final double trackHeight;
  const _RowPositionIndicator({
    required this.total,
    required this.active,
    required this.trackHeight,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total <= 1 ? 0.0 : (active / (total - 1)).clamp(0.0, 1.0);
    // trackHeight already scales with screen height (it's sh * 0.037 from
    // _SectionHeader). Take a fixed fraction of it — ~9px on a 1080p panel,
    // ~18px on 4K — instead of the old (trackHeight * 0.5).clamp(4, 9),
    // whose 9px ceiling pinned the dot to one absolute size at every
    // resolution above ~486p. Keep a light clamp only for the extremes.
    final dotSize = (trackHeight * 0.225).clamp(5.0, 20.0);
    final trackSpan = trackHeight - dotSize;

    // A track line the dot slides along — without it, the dot alone gives
    // no sense of the full range (how far the top/bottom actually are), so
    // a move read as an isolated jump rather than progress along something.
    final trackW = (dotSize * 0.22).clamp(1.2, 6.0);

    return SizedBox(
      width: dotSize,
      height: trackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: dotSize / 2,
            left: (dotSize - trackW) / 2,
            child: Container(
              width: trackW,
              height: trackSpan,
              decoration: BoxDecoration(
                color: AppTheme.textHigh.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(trackW / 2),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOut,
            top: progress * trackSpan,
            left: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── catalog section ────────────────────────────────────────────────────────────

class _CatalogSection extends StatelessWidget {
  final String pluginId;
  final CatalogDef catalogDef;
  final DiscoveryBloc bloc;
  final bool isFirstSection;
  final void Function(CatalogItem) onItemFocused;
  final void Function(FocusNode)? onFirstCardFocus;
  final VoidCallback onOpenNav;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final void Function(LogicalKeyboardKey key, bool isDown)?
      onNavigateHoldChanged;
  final VoidCallback? onEmpty;

  const _CatalogSection({
    required this.pluginId,
    required this.catalogDef,
    required this.bloc,
    required this.isFirstSection,
    required this.onItemFocused,
    required this.onOpenNav,
    this.onFirstCardFocus,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onNavigateHoldChanged,
    this.onEmpty,
  });

  CatalogItem? _findItem(List<CatalogItem> items, String id) {
    for (final it in items) {
      if (it.id == id) return it;
    }
    return null;
  }

  void _handleTap(BuildContext ctx, List<CatalogItem> items, String id) {
    final item = _findItem(items, id);
    if (item == null) return;
    openCatalogItem(ctx, pluginId, item);
  }

  void _handleLongPress(BuildContext ctx, List<CatalogItem> items, String id) {
    final item = _findItem(items, id);
    if (item == null) return;
    final mt = item.mediaType;
    // Normally gated to types the menu's Dettagli/Episodi/Riproduci
    // actions were built for — but a live_refreshable catalog (today only
    // sport's "Live Ora") needs long-press to reach "Aggiorna ora" even on
    // a 'live' item, which would otherwise be excluded here entirely.
    if (mt != 'series' &&
        mt != 'movie' &&
        mt != 'episode' &&
        !catalogDef.liveRefreshable) {
      return;
    }
    showDialog<void>(
      context: ctx,
      barrierColor: Colors.black54,
      builder: (_) => _CardContextMenu(
        pluginId: pluginId,
        item: item,
        liveRefreshable: catalogDef.liveRefreshable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryBloc, DiscoveryState>(
      bloc: bloc,
      builder: (context, state) {
        if (state is DiscoveryLoaded && state.items.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onEmpty?.call());
          return const SizedBox.shrink();
        }

        if (state is DiscoveryLoading || state is DiscoveryInitial) {
          return _SkeletonRow(
              featured: isFeaturedCatalog(catalogDef) &&
                  kFeaturedCarouselResizeEnabled);
        }
        if (state is DiscoveryError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 20),
            child: Text(state.errorCode,
                style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.6),
                    fontSize: AppScale.space(context, 13))),
          );
        }
        if (state is DiscoveryLoaded) {
          final block = sduiSchemaForCatalogDef(
            catalogDef,
            pluginId: pluginId,
            items: state.items,
            isFirstSection: isFirstSection,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SduiBlockView(
                key: ValueKey('carousel_${pluginId}_${catalogDef.id}'),
                block: block,
                carouselInteraction: CardCarouselInteraction(
                  onItemFocused: (id) {
                    final item = _findItem(state.items, id);
                    if (item != null) onItemFocused(item);
                  },
                  onItemTap: (id) => _handleTap(context, state.items, id),
                  onItemLongPress: (id) =>
                      _handleLongPress(context, state.items, id),
                  onFirstCardFocus: onFirstCardFocus,
                  onOpenNav: onOpenNav,
                  // Back on a catalog card no longer opens the side nav (that
                  // stays a deliberate Left on the first card) — it hands the
                  // press to the route's own back handling: the PopScope in
                  // _HomeView shows "premi di nuovo per uscire", so Back
                  // means "leave", not "toggle the menu". consumeBackEvent()
                  // so the platform-channel back path (Android) doesn't also
                  // fire _handleRootBack for the same press — see
                  // back_dispatch.dart.
                  onBack: () {
                    if (consumeBackEvent()) Navigator.of(context).maybePop();
                  },
                  onNavigateUp: onNavigateUp,
                  onNavigateDown: onNavigateDown,
                  onNavigateHoldChanged: onNavigateHoldChanged,
                ),
              ),
              SizedBox(
                  height: MediaQuery.sizeOf(context).height * (20.0 / 1080.0)),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

