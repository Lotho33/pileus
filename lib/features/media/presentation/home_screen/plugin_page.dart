// Part of home_screen.dart — split out for readability (plan 2e). The library
// file holds the shared imports plus the _HomeFsm enum and the HomeScreen
// entry point; private identifiers are shared across all parts.
part of '../home_screen.dart';

// ── plugin page ────────────────────────────────────────────────────────────────

class _PluginPage extends StatelessWidget {
  final PluginInfo plugin;
  final VoidCallback onOpenNav;
  final VoidCallback onNavigateToSearch;
  final GlobalKey<_PluginPageBodyState>? bodyKey;
  final FocusNode notReadyFocusNode;

  const _PluginPage({
    required this.plugin,
    required this.onOpenNav,
    required this.onNavigateToSearch,
    required this.notReadyFocusNode,
    this.bodyKey,
  });

  @override
  Widget build(BuildContext context) {
    // needsConfig — requires admin intervention before the plugin can work.
    if (plugin.needsConfig) {
      return _PluginNotReadyPage(
        focusNode: notReadyFocusNode,
        onOpenNav: onOpenNav,
        icon: Icons.settings_outlined,
        title: 'Configurazione richiesta',
        subtitle: 'Apri l\'admin per configurare ${plugin.name}.',
      );
    }

    // NOTE: deliberately NOT gating on `!plugin.reachable` here — that
    // field is the automatic backend health check, and it's turned out to
    // false-positive on plugins that are actually fine (see the reachability
    // badge in the side-nav and in plugin_settings_screen.dart — both shown
    // as informational only, via PluginStatusIndicator). Blocking the whole
    // plugin page on it locked out working plugins. A real failure still
    // surfaces naturally: LoadCatalogEvent fails and DiscoveryError shows
    // through the carousel, which is the actually-reliable signal.

    // syncing — plugin is working in the background; show progress.
    if (plugin.statusLabel == 'syncing') {
      return _PluginNotReadyPage(
        focusNode: notReadyFocusNode,
        onOpenNav: onOpenNav,
        icon: Icons.sync_rounded,
        animate: true,
        title: 'Sincronizzazione in corso…',
        subtitle: plugin.statusDetail.isNotEmpty
            ? plugin.statusDetail
            : '${plugin.name} sta sincronizzando i contenuti.',
      );
    }

    // error — plugin itself reported an error.
    if (plugin.statusLabel == 'error') {
      return _PluginNotReadyPage(
        focusNode: notReadyFocusNode,
        onOpenNav: onOpenNav,
        icon: Icons.error_outline_rounded,
        title: 'Errore plugin',
        subtitle: plugin.statusDetail.isNotEmpty
            ? plugin.statusDetail
            : '${plugin.name} ha riportato un errore.',
        isError: true,
        onRetry: () =>
            context.read<PluginBloc>().add(const RefreshPluginsEvent()),
      );
    }

    if (plugin.catalogs.isEmpty) {
      return _PluginNotReadyPage(
        focusNode: notReadyFocusNode,
        onOpenNav: onOpenNav,
        icon: Icons.inventory_2_outlined,
        title: 'Nessun catalogo',
        subtitle: '${plugin.name} non ha cataloghi disponibili.',
      );
    }

    return _PluginPageBody(
      key: bodyKey,
      plugin: plugin,
      onOpenNav: onOpenNav,
      onNavigateToSearch: onNavigateToSearch,
    );
  }
}

// ── plugin not-ready placeholder ──────────────────────────────────────────────

class _PluginNotReadyPage extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onOpenNav;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool animate;
  final bool isError;
  // When set, OK/Select on this page re-runs it (the page itself is the only
  // focus stop here — see _PluginNotReadyPageState's arrow-swallowing
  // onKeyEvent — so there's no separate focusable button to land on).
  final VoidCallback? onRetry;

  const _PluginNotReadyPage({
    required this.focusNode,
    required this.onOpenNav,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.animate = false,
    this.isError = false,
    this.onRetry,
  });

  @override
  State<_PluginNotReadyPage> createState() => _PluginNotReadyPageState();
}

class _PluginNotReadyPageState extends State<_PluginNotReadyPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      // Flutter's own AnimationController docs warn a repeating animation
      // needs this: AnimationBehavior.normal (the default) scales duration
      // by ~0.05 when the system "disattiva animazioni" toggle is on, so a
      // 2s loop would repeat every ~100ms instead of stopping — a rapid
      // flicker instead of the still icon that setting is asking for
      // (2026-09 audit).
      animationBehavior: AnimationBehavior.preserve,
    );
    if (widget.animate) _rotCtrl.repeat();
  }

  @override
  void didUpdateWidget(_PluginNotReadyPage old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_rotCtrl.isAnimating) {
      _rotCtrl.repeat();
    } else if (!widget.animate && _rotCtrl.isAnimating) {
      _rotCtrl.stop();
    }
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isError
        ? const Color(0xFFef4444)
        : widget.animate
            ? const Color(0xFF38bdf8)
            : AppTheme.textLow;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowLeft ||
            k == LogicalKeyboardKey.escape ||
            k == LogicalKeyboardKey.goBack) {
          widget.onOpenNav();
          return KeyEventResult.handled;
        }
        if (widget.onRetry != null &&
            (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter)) {
          widget.onRetry!();
          return KeyEventResult.handled;
        }
        // arrowUp previously fell through unhandled here, and Flutter's
        // default directional focus traversal picked it up and jumped
        // focus by raw screen geometry to the nearest focusable widget
        // above — the quick search bar, being the topmost thing on this
        // screen — silently opening search on a plugin with nothing
        // searchable. Swallowing every arrow key (not just the ones with
        // an explicit action) keeps this page's only exits the ones it
        // actually offers: Left/Escape/Back to the nav.
        if (k == LogicalKeyboardKey.arrowUp ||
            k == LogicalKeyboardKey.arrowDown ||
            k == LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns:
                    widget.animate ? _rotCtrl : const AlwaysStoppedAnimation(0),
                child: Icon(widget.icon,
                    size: AppScale.space(context, 56), color: iconColor),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: AppScale.space(context, 22),
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                widget.subtitle,
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: AppScale.space(context, 15)),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 24),
                // The page itself owns focus (arrows are swallowed above), so
                // this reads as "press OK to retry" rather than a thing to
                // navigate onto — styled as the app's focused-button state to
                // make that obvious.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: AppScale.space(context, 20),
                          color: AppTheme.textHigh),
                      const SizedBox(width: 8),
                      Text('Riprova',
                          style: TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: AppScale.space(context, 15),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text('Indietro per il menù plugin',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: AppScale.space(context, 12))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── plugin page body ───────────────────────────────────────────────────────────

class _PluginPageBody extends StatefulWidget {
  final PluginInfo plugin;
  final VoidCallback onOpenNav;
  final VoidCallback onNavigateToSearch;

  const _PluginPageBody({
    super.key,
    required this.plugin,
    required this.onOpenNav,
    required this.onNavigateToSearch,
  });

  @override
  State<_PluginPageBody> createState() => _PluginPageBodyState();
}

class _PluginPageBodyState extends State<_PluginPageBody> {
  _HomeFsm _fsm = _HomeFsm.loading;

  // First item of the first loaded catalog — the hero's fallback until the
  // user focuses a card.
  CatalogItem? _heroItem;
  // The item the hero currently reflects (focused card, or _heroItem). A
  // ValueNotifier, not setState: focusing a card must NOT rebuild this whole
  // page (hero + metadata + every carousel) — only the ValueListenableBuilder
  // around the hero/metadata in _StandardHomeShell listens to it, so a D-pad
  // move repaints just the hero, not the carousels underneath.
  final ValueNotifier<CatalogItem?> _displayItemVN = ValueNotifier(null);

  late List<DiscoveryBloc> _sectionBlocs;
  // SafeFocusRef (see lib/shared/utils/safe_focus.dart) — a catalog switch
  // disposes the previous carousel's FocusNodes before the new one reports
  // its own via onFirstCardFocus below, and _focusFirstCard can fire in
  // that gap (called from _closeNav / quick search's dismiss, not tightly
  // coupled to the catalog-switch timing).
  final _firstCardFocus = SafeFocusRef();
  bool _pendingFocusFirstCard = false;

  // Plugin pages stay mounted the whole time (home_screen.dart toggles
  // opacity/pointer-events rather than rebuilding on plugin switch — see
  // _HomeViewState.build()), so _StandardHomeShellState's row-navigation
  // state (_activeCatalog) would otherwise survive across switches. This
  // key lets _resetToFirstCatalog() reach in and reset it explicitly.
  final GlobalKey<_StandardHomeShellState> _shellKey = GlobalKey();

  // Called from _HomeViewState.onPluginSelected when switching TO this
  // plugin — returns row navigation to the first catalog instead of
  // resuming wherever the user last left it.
  void _resetToFirstCatalog() {
    _shellKey.currentState?.resetToFirstCatalog();
  }

  @override
  void initState() {
    super.initState();
    _initBlocs(widget.plugin);
  }

  @override
  void didUpdateWidget(_PluginPageBody old) {
    super.didUpdateWidget(old);
    // PluginBloc's 30s background poll can hand back a fresh PluginInfo for
    // the *same* pluginId with a different set of catalogs (a plugin still
    // indexing progressively adds rows, or one disappears) — not just on an
    // actual plugin switch. _sectionBlocs must stay in lockstep with
    // plugin.catalogs whenever either changes, or _StandardHomeShellState
    // ends up indexing a stale bloc list against the new catalog count
    // (RangeError, or a row's title/content silently mismatched).
    if (old.plugin.pluginId != widget.plugin.pluginId) {
      // A real plugin switch — nothing carries over, so a full reset is
      // correct here (unlike the reconcile path below).
      for (final b in _sectionBlocs) {
        b.close();
      }
      _initBlocs(widget.plugin);
      _heroItem = null;
      _displayItemVN.value = null;
      setState(() {
        _fsm = _HomeFsm.loading;
        _firstCardFocus.clear();
        _pendingFocusFirstCard = false;
      });
      return;
    }
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
      // Same plugin — this is the "still indexing" case above, most often
      // seen on sport (a live category appearing/disappearing as events
      // start/end). Reconciling instead of tearing every row down means a
      // catalog whose data didn't change keeps its bloc — no reload flash,
      // no lost scroll/focus position — while only the rows that actually
      // appeared or disappeared touch the network or the widget tree.
      _reconcileBlocs(old.plugin, widget.plugin);
      setState(() {});
    }
  }

  void _reconcileBlocs(PluginInfo oldPlugin, PluginInfo newPlugin) {
    final oldIds = oldPlugin.catalogs.map((c) => c.id).toList();
    final byId = <String, DiscoveryBloc>{
      for (var i = 0; i < oldIds.length; i++) oldIds[i]: _sectionBlocs[i],
    };
    final keptIds = <String>{};
    final newBlocs = <DiscoveryBloc>[];
    for (final cat in newPlugin.catalogs) {
      final existing = byId[cat.id];
      if (existing != null) {
        keptIds.add(cat.id);
        newBlocs.add(existing);
      } else {
        newBlocs.add(_acquireDiscoveryBloc(newPlugin.pluginId, cat));
      }
    }
    for (var i = 0; i < oldIds.length; i++) {
      if (!keptIds.contains(oldIds[i])) _sectionBlocs[i].close();
    }
    _sectionBlocs = newBlocs;
  }

  // Splash may have prewarmed (and already dispatched LoadCatalogEvent for)
  // the very first catalog of the very first plugin under a *named* getIt
  // registration keyed '$pluginId::${cat.id}' (see
  // AuthBloc._prewarmFirstCatalog) — so the first carousel the user sees
  // already has real items instead of sitting on its own empty state for
  // another round-trip after the splash is already gone. Adopt that
  // instance here instead of creating (and redundantly reloading) a fresh
  // one, then unregister the name so this bloc's lifecycle reverts to
  // normal — owned and closed by this State like every other
  // _sectionBlocs entry, not left dangling in getIt under that name.
  DiscoveryBloc _acquireDiscoveryBloc(String pluginId, CatalogDef cat) {
    final key = '$pluginId::${cat.id}';
    if (getIt.isRegistered<DiscoveryBloc>(instanceName: key)) {
      final bloc = getIt<DiscoveryBloc>(instanceName: key);
      getIt.unregister<DiscoveryBloc>(instanceName: key);
      return bloc;
    }
    return getIt<DiscoveryBloc>()
      ..add(LoadCatalogEvent(
        pluginId: pluginId,
        catalogId: cat.id,
        cacheTtlSeconds: cat.cacheTtlSeconds,
      ));
  }

  // Called from _closeNav and from quick search's dismiss: restores focus
  // to the first card of the active carousel.
  void _focusFirstCard() {
    _pendingFocusFirstCard = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pendingFocusFirstCard) return;
      if (_firstCardFocus.requestFocus()) {
        _pendingFocusFirstCard = false;
      }
      // else: catalog not yet loaded (or its FocusNode is stale/disposed)
      // — _pendingFocusFirstCard stays true and onFirstCardFocus will
      // handle it when cards build
    });
    // addPostFrameCallback alone doesn't make a frame happen — it only
    // fires once one occurs for some other reason. _closeNav's caller pairs
    // this with a setState that schedules one incidentally; quick search's
    // dismiss doesn't touch any state here, so without this the callback
    // above sits pending indefinitely on an otherwise-idle screen (this is
    // why escape/down out of quick search looked like it did nothing).
    SchedulerBinding.instance.scheduleFrame();
  }

  void _initBlocs(PluginInfo p) {
    _sectionBlocs = [
      for (final cat in p.catalogs) _acquireDiscoveryBloc(p.pluginId, cat),
    ];
  }

  @override
  void dispose() {
    for (final b in _sectionBlocs) {
      b.close();
    }
    _displayItemVN.dispose();
    super.dispose();
  }

  // Called from _HomeViewState via GlobalKey
  void _transition(_HomeFsm next) {
    if (_fsm == next) return;
    final effective = next == _HomeFsm.heroFocused ? _HomeFsm.browsing : next;
    if (_fsm == effective) return;
    final previous = _fsm;
    setState(() => _fsm = effective);
    switch (effective) {
      case _HomeFsm.browsing:
        // Focus is handled by _focusFirstCard() (called from _closeNav).
        // On initial catalog load, focus the first card here.
        if (previous == _HomeFsm.loading) _focusFirstCard();
      case _HomeFsm.navOpen:
        widget.onOpenNav();
      case _HomeFsm.heroFocused:
      case _HomeFsm.loading:
        break;
    }
  }

  void _onCatalogLoaded(List<CatalogItem> items) {
    if (items.isEmpty) return;
    final first = items.first;
    if (_heroItem == null) {
      _heroItem = first;
      // Seed the hero before the user has focused anything — no setState, the
      // ValueListenableBuilder in the shell picks it up.
      _displayItemVN.value ??= first;
    }
    if (_fsm == _HomeFsm.loading) _transition(_HomeFsm.browsing);
  }

  void _onItemFocused(CatalogItem item) {
    // No setState: only the hero/metadata ValueListenableBuilder reacts.
    if (_displayItemVN.value?.id == item.id) return;
    _displayItemVN.value = item;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DiscoveryBloc, DiscoveryState>(
      // Explicit bloc, not an implicit context lookup — this used to rely
      // on an ancestor BlocProvider that _PluginPage.build() created
      // solely to feed this listener, with its own LoadCatalogEvent for
      // the plugin's first catalog. That was a genuine duplicate: this
      // page's first catalog was already being fetched by _sectionBlocs
      // below (same pluginId/catalogId), so every plugin page fired that
      // GetCatalog request twice on every mount for no reason.
      bloc: _sectionBlocs.first,
      listener: (_, state) {
        if (state is DiscoveryLoaded) _onCatalogLoaded(state.items);
      },
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            _StandardHomeShell(
              key: _shellKey,
              plugin: widget.plugin,
              displayItem: _displayItemVN,
              sectionBlocs: _sectionBlocs,
              onItemFocused: _onItemFocused,
              onFirstCardFocus: (fn) {
                _firstCardFocus.set(fn);
                if (_pendingFocusFirstCard) {
                  _pendingFocusFirstCard = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _firstCardFocus.requestFocus();
                  });
                }
              },
              onOpenNav: () => _transition(_HomeFsm.navOpen),
              // heroFocused used to be routed through _transition() here, but
              // that state has always collapsed straight back to `browsing`
              // (see the `effective` remap in _transition) — arrow-up from the
              // topmost catalog row silently did nothing. Now it hands focus
              // directly to the search bar instead.
              onNavigateUpFromCarousel: widget.onNavigateToSearch,
            ),
            // Non-blocking: `reachable` is a health-check ping that has
            // turned out to false-positive on plugins that work fine (see
            // main gate removed from _PluginPage.build()), and even when
            // accurate, an unreachable ping often means "flaky", not "the
            // plugin is completely gone" — cached catalogs may still browse
            // and play just fine. So this is a heads-up, not a block: no
            // Focus/FocusNode, IgnorePointer'd, D-pad navigation underneath
            // is entirely unaffected.
            if (!widget.plugin.reachable)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: _PluginDegradedBanner()),
              ),
          ],
        ),
      ),
    );
  }
}

class _PluginDegradedBanner extends StatelessWidget {
  const _PluginDegradedBanner();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFf59e0b).withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: const Color(0xFFf59e0b),
                  size: AppScale.space(context, 16)),
              const SizedBox(width: 8),
              Text(
                'Plugin instabile: alcuni contenuti potrebbero non caricarsi',
                style: TextStyle(
                  color: AppTheme.textHigh.withValues(alpha: 0.9),
                  fontSize: AppScale.space(context, 12),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
