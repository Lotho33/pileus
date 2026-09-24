// Part of home_screen.dart — split out for readability (plan 2e). The library
// file holds the shared imports plus the _HomeFsm enum and the HomeScreen
// entry point; private identifiers are shared across all parts.
part of '../home_screen.dart';

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  int _selectedPlugin = 0;
  // Which plugin page is currently painted, and (briefly, during the 200ms
  // crossfade) the one being faded out. Every other page is Offstage — see
  // the plugin-pages Stack in build().
  int _paintedPluginIdx = 0;
  int? _fadingOutPluginIdx;
  Timer? _fadeOutTimer;
  // Identity behind _selectedPlugin — PluginBloc polls every 30s (even while
  // /player is on top of this still-mounted screen) and can hand back a
  // reordered list with the same length, which would otherwise leave
  // _selectedPlugin numerically unchanged but pointing at a different
  // plugin (e.g. exiting the player lands on a different tab than the one
  // left). Resolved back to an index every time PluginsLoaded arrives.
  String? _selectedPluginId;
  // Side-nav open state. A ValueNotifier, not setState: toggling the menu
  // must not rebuild this whole screen (hero, carousels, quick search) — only
  // the ValueListenableBuilders around the focus-blocking wrappers and the
  // nav panel / scrim react to it. Opening the menu was a visible spike on a
  // Fire TV Stick.
  final ValueNotifier<bool> _navVisibleVN = ValueNotifier(false);
  bool _playerWasActive = false;
  // Second and third, delayed continue-watching reloads after the player
  // closes — see _onNav. The player's final progress save (in its
  // dispose()) is a fire-and-forget gRPC call, so the immediate reload right
  // after the pop often reaches mycelium before that write commits and comes
  // back with the pre-watch list. The 1.5s retry picks up the fresh row in
  // the common case; the 4s one is a safety net for a slow/loaded server
  // where even that isn't enough — cheap to add, and better than silently
  // showing a stale row if the first retry loses the race.
  Timer? _cwReloadTimer;
  Timer? _cwReloadTimer2;
  GoRouter? _router;

  List<FocusNode> _pluginFocusNodes = [];
  // Keyed by pluginId (not position): a background refresh can reorder the
  // plugin list without changing its length, and a GlobalKey keyed by index
  // would then get silently reassigned to a different plugin at the same
  // position — Flutter just updates the Element in place instead of moving
  // it, and _PluginPageBodyState.didUpdateWidget sees a pluginId mismatch
  // and does a full reset (blocs recreated, loading spinner, focus/scroll
  // lost) for whatever plugin now lands on the currently-visible index. That
  // was the visible flicker on every reorder. Keying by pluginId means a
  // reorder just changes which key is at which list index — the same
  // GlobalKey (and its Element/state) stays matched to the same plugin no
  // matter where it moves, so Flutter relocates the existing Element instead
  // of resetting it.
  Map<String, GlobalKey<_PluginPageBodyState>> _pageKeys = {};
  // One per plugin, mirroring _pageKeys — but _pageKeys[i].currentState is
  // null whenever plugin i is currently showing _PluginNotReadyPage instead
  // of _PluginPageBody (needsConfig/syncing/error/no-catalogs). _closeNav()
  // used to only ever re-focus via _pageKeys, so closing the nav back onto
  // a not-ready plugin left NOTHING focused at all (its own autofocus only
  // fires once, the first time it's built — not on every return visit).
  // With no focused node left in the tree, every subsequent key press
  // (including Escape/Back to reopen the nav) went nowhere: a real dead
  // end, not just "can't use this one plugin". This list lets _closeNav()
  // re-focus the not-ready page's own Focus node explicitly in that case.
  List<FocusNode> _notReadyFocusNodes = [];

  // Landing spot for "arrow up from the first catalog row" (see
  // onNavigateUpFromCarousel below) and for the top search bar's own tap
  // target — moved here from the old _PluginNav sub-panel, which used to be
  // the only way to reach search.
  final FocusNode _searchBarFocusNode = FocusNode();
  // Whatever card had focus the instant quick search was entered — captured
  // so leaving search (Esc or an explicit D-pad exit, see
  // _QuickSearchArea.onDismiss below) can land back on that exact item
  // instead of always resetting to the row's first card. SafeFocusRef (see
  // lib/shared/utils/safe_focus.dart) since a catalog reload while search
  // was open can dispose the very node captured here before it's used.
  final _preSearchFocus = SafeFocusRef();
  // Guards onNavigateToSearch below against a held (not tapped) Up: on
  // this environment a physical hold can arrive as a fast cascade of real
  // KeyDownEvents rather than the KeyRepeatEvent TvFocusable already
  // ignores by design, so reaching the top row and continuing to hold kept
  // re-firing this after focus had already left the carousel. requestFocus()
  // doesn't move focus synchronously (it's reconciled on the next frame),
  // so a second trigger arriving before that reconciliation still read the
  // stale primaryFocus — sometimes the search bar itself — and captured
  // that as _preSearchFocus, which then made leaving search re-focus
  // search. Absorbing any repeat within this window at the boundary means
  // only the first, genuine arrival opens search.
  DateTime? _lastNavToSearchAt;
  // Was 280ms — shorter than a real remote's initial key-repeat delay
  // (~400-500ms before repeats start on the Android TV hardware this was
  // tested on). A held Up at the boundary fired once correctly, then the
  // first hardware repeat arrived *after* this guard had already expired
  // and fired a second, spurious open — reopening/relanding on search a
  // moment after the first genuine trigger. Set above the real repeat
  // delay so only genuine held-key repeats (which land well under this) get
  // absorbed, not the first legitimate one.
  static const _navToSearchGuard = Duration(milliseconds: 600);

  bool _updateCheckDone = false;

  @override
  void initState() {
    super.initState();
    // One "newer release available" check per home mount — best-effort,
    // rate-limited and a silent no-op unless UpdateConfig is configured.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _updateCheckDone) return;
      _updateCheckDone = true;
      maybePromptForUpdate(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onNav);
      _router = router;
      router.routerDelegate.addListener(_onNav);
    }
  }

  void _onNav() {
    if (!mounted || _router == null) return;
    final path = _router!.routeInformationProvider.value.uri.path;
    if (path.startsWith('/player')) {
      _playerWasActive = true;
    } else if (_playerWasActive) {
      _playerWasActive = false;
      final bloc = context.read<ContinueWatchingBloc>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) bloc.add(const LoadContinueWatchingEvent());
      });
      // Retry after the player's fire-and-forget dispose-time save has had
      // time to reach mycelium and commit — otherwise a just-watched item
      // (or its updated position) won't be in the list the immediate reload
      // above gets back.
      _cwReloadTimer?.cancel();
      _cwReloadTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) bloc.add(const LoadContinueWatchingEvent());
      });
      _cwReloadTimer2?.cancel();
      _cwReloadTimer2 = Timer(const Duration(milliseconds: 4000), () {
        if (mounted) bloc.add(const LoadContinueWatchingEvent());
      });
    }
  }

  @override
  void dispose() {
    _cwReloadTimer?.cancel();
    _cwReloadTimer2?.cancel();
    _fadeOutTimer?.cancel();
    _router?.routerDelegate.removeListener(_onNav);
    for (final n in _pluginFocusNodes) {
      n.dispose();
    }
    for (final n in _notReadyFocusNodes) {
      n.dispose();
    }
    _searchBarFocusNode.dispose();
    _navVisibleVN.dispose();
    super.dispose();
  }

  void _ensurePluginFocusNodes(int count) {
    if (_pluginFocusNodes.length == count) return;
    for (final n in _pluginFocusNodes) {
      n.dispose();
    }
    _pluginFocusNodes = List.generate(count, (_) => FocusNode());
  }

  void _ensureNotReadyFocusNodes(int count) {
    if (_notReadyFocusNodes.length == count) return;
    for (final n in _notReadyFocusNodes) {
      n.dispose();
    }
    _notReadyFocusNodes = List.generate(count, (_) => FocusNode());
  }

  void _ensurePageKeys(List<String> pluginIds) {
    final next = <String, GlobalKey<_PluginPageBodyState>>{};
    for (final id in pluginIds) {
      next[id] = _pageKeys[id] ?? GlobalKey<_PluginPageBodyState>();
    }
    _pageKeys = next;
  }

  void _openNav() {
    _navVisibleVN.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pluginFocusNodes[_selectedPlugin.clamp(0, _pluginFocusNodes.length - 1)]
          .requestFocus();
    });
  }

  void _closeNav() {
    _navVisibleVN.value = false;
    final body = _selectedPluginId == null
        ? null
        : _pageKeys[_selectedPluginId]?.currentState;
    if (body != null) {
      body._transition(_HomeFsm.browsing);
      body._focusFirstCard();
    } else {
      // Plugin isn't ready (needsConfig/syncing/error/no-catalogs) — no
      // _PluginPageBodyState to hand focus to, so focus its own not-ready
      // placeholder directly instead of leaving nothing focused at all.
      _notReadyFocusNodes[_selectedPlugin].requestFocus();
    }
  }

  // Guards against Back exiting the app from here — Android's own
  // FlutterActivity.onBackPressed() sends its own "pop the root route"
  // system request independently of whatever a focused TvFocusable's onEsc
  // already did with the same physical press (that's Flutter's normal key-
  // event path, entirely separate from the platform channel this reacts
  // to), so a single Back press here could otherwise pop this route too —
  // reading as "Back acts like it was pressed several times" right before
  // dropping out of the app, since /home has nothing left above it for
  // go_router to pop to. The standard Android pattern: the first Back here
  // only shows a reminder; only a second one within the window actually
  // exits.
  DateTime? _lastBackPressAt;
  static const _exitConfirmWindow = Duration(milliseconds: 2000);

  void _handleRootBack(BuildContext context) {
    final now = DateTime.now();
    final last = _lastBackPressAt;
    if (last != null && now.difference(last) < _exitConfirmWindow) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressAt = now;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Premi di nuovo per uscire'),
        duration: Duration(milliseconds: 1800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleRootBack(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: BlocBuilder<PluginBloc, PluginState>(
          builder: (context, state) {
            if (state is PluginLoading || state is PluginInitial) {
              return Center(
                  child: PileusSpinner(
                      size: AppScale.spinnerL(context),
                      color: AppTheme.primary));
            }
            if (state is PluginError) {
              // certMismatch: the server IS reachable, it's the pinned TLS
              // fingerprint that no longer matches (e.g. mycelium was
              // reinstalled/reset) — the generic "check the server is on"
              // message was actively misleading for this case. "Ripeti
              // ricerca" reuses the same safe recovery path the manual
              // "Cambia server" settings row already uses (ChangeServerEvent
              // → AuthBloc resets the prefetch blocs and routes to
              // /discovery), rather than trying to rebuild the gRPC channel
              // in place from here.
              return ErrorRetryView(
                icon: Icons.cloud_off_rounded,
                title: state.certMismatch
                    ? 'Il certificato del server è cambiato'
                    : 'Impossibile raggiungere il server',
                message: state.certMismatch
                    ? 'Il dispositivo era abbinato a un server con un certificato diverso — probabilmente è stato reinstallato o resettato. Ripeti la scoperta per abbinarlo di nuovo.'
                    : 'Controlla che il server Mycelium sia acceso e sulla stessa rete, poi riprova.',
                detail: state.message,
                onRetry: () =>
                    context.read<PluginBloc>().add(const LoadPluginsEvent()),
                onSecondary: state.certMismatch
                    ? () => getIt<AuthBloc>().add(const ChangeServerEvent())
                    : () => context.push('/settings'),
                secondaryLabel:
                    state.certMismatch ? 'Ripeti ricerca' : 'Impostazioni',
              );
            }
            if (state is PluginsLoaded && state.plugins.isNotEmpty) {
              _ensurePluginFocusNodes(state.plugins.length);
              _ensurePageKeys(state.plugins.map((p) => p.pluginId).toList());
              _ensureNotReadyFocusNodes(state.plugins.length);
              // Resolve the active plugin by identity first — a background
              // refresh can reorder the list (same length, different order)
              // without ever touching _selectedPlugin's numeric value.
              var safeIdx = _selectedPlugin.clamp(0, state.plugins.length - 1);
              if (_selectedPluginId == null) {
                _selectedPluginId = state.plugins[safeIdx].pluginId;
              } else {
                final idIdx = state.plugins
                    .indexWhere((p) => p.pluginId == _selectedPluginId);
                if (idIdx != -1) {
                  safeIdx = idIdx;
                } else {
                  // Plugin disappeared entirely — fall back to the clamped
                  // index and adopt whatever it now points at as the identity.
                  _selectedPluginId = state.plugins[safeIdx].pluginId;
                }
              }
              if (safeIdx != _selectedPlugin) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => setState(() => _selectedPlugin = safeIdx));
              }
              // Track the plugin page we're crossfading away from so it keeps
              // painting for the 200ms transition; everything else that isn't
              // the active page goes Offstage (below) — no layout/paint/
              // compositing, and its off-screen poster images become
              // evictable. On a RAM-starved Fire Stick (device logs show the
              // OS SIGKILLing background apps during use) pinning every
              // mounted plugin's ~15 decoded posters is a real cost.
              if (safeIdx != _paintedPluginIdx) {
                _fadingOutPluginIdx = _paintedPluginIdx;
                _paintedPluginIdx = safeIdx;
                _fadeOutTimer?.cancel();
                _fadeOutTimer = Timer(
                    lowPowerUi
                        ? const Duration(milliseconds: 16)
                        : const Duration(milliseconds: 260), () {
                  if (!mounted) return;
                  setState(() => _fadingOutPluginIdx = null);
                  // The plugin we just left is Offstage now — un-pin its
                  // posters so the LRU cache can drop them under pressure
                  // (the plugin in front re-pins its own visible ~15 on the
                  // next frame).
                  if (lowPowerUi) {
                    PaintingBinding.instance.imageCache.clearLiveImages();
                  }
                });
              }
              final navW = MediaQuery.sizeOf(context).width * _sideNavRatio;
              return Stack(
                children: [
                  // Content — focus blocked when nav open. VLB so a nav
                  // toggle only flips ExcludeFocus, doesn't rebuild the pages.
                  ValueListenableBuilder<bool>(
                    valueListenable: _navVisibleVN,
                    builder: (context, navVisible, child) =>
                        ExcludeFocus(excluding: navVisible, child: child!),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        for (var i = 0; i < state.plugins.length; i++)
                          // Offstage every page that's neither the active one
                          // nor the one currently fading out — skips its
                          // layout/paint/compositing and lets its off-screen
                          // posters be evicted under memory pressure.
                          Offstage(
                            offstage: i != safeIdx && i != _fadingOutPluginIdx,
                            // AnimatedOpacity OUTSIDE TickerMode so the
                            // crossfade always runs — with it inside, the
                            // outgoing page's fade-out froze the instant it
                            // was deselected and it stayed fully opaque on
                            // top, which read as "selecting a plugin doesn't
                            // switch". TickerMode still freezes the *hidden*
                            // page's own animations (shimmer loops, settling
                            // AnimatedContainers, carousel tweens) once it's
                            // off screen.
                            child: AnimatedOpacity(
                              opacity: i == safeIdx ? 1.0 : 0.0,
                              duration: lowPowerUi
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: TickerMode(
                                enabled: i == safeIdx,
                                child: IgnorePointer(
                                  ignoring: i != safeIdx,
                                  child: ExcludeFocus(
                                    excluding: i != safeIdx,
                                    child: _PluginPage(
                                      plugin: state.plugins[i],
                                      onOpenNav: _openNav,
                                      onNavigateToSearch: () {
                                        // A held Up climbing through the carousel
                                        // rows must stop at the top row, not fall
                                        // through into opening search — enforced
                                        // by _StandardHomeShellState._onCarouselUp,
                                        // which only ever calls this for an Up that
                                        // arrives after a real pause (see its own
                                        // doc), so by the time this runs it's
                                        // always a genuine fresh press. The guard
                                        // below still absorbs a rapid double-press
                                        // of that fresh key.
                                        final now = DateTime.now();
                                        final recent =
                                            _lastNavToSearchAt != null &&
                                                now.difference(
                                                        _lastNavToSearchAt!) <
                                                    _navToSearchGuard;
                                        _lastNavToSearchAt = now;
                                        if (recent) return;
                                        // Captured before focus actually moves —
                                        // primaryFocus here is still whatever card
                                        // the user was just on.
                                        _preSearchFocus.set(
                                            FocusManager.instance.primaryFocus);
                                        _searchBarFocusNode.requestFocus();
                                      },
                                      bodyKey:
                                          _pageKeys[state.plugins[i].pluginId]!,
                                      notReadyFocusNode: _notReadyFocusNodes[i],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Quick search — focus blocked when nav open, same as the
                  // catalog content above. Also hidden entirely while the
                  // active plugin isn't ready (see _isPluginReady) — nothing
                  // to search yet, and its backdrop would otherwise sit on
                  // top of that plugin's "syncing…"/error message and hide it.
                  if (_selectedPluginId != null &&
                      _isPluginReady(state.plugins[safeIdx]))
                    ValueListenableBuilder<bool>(
                      valueListenable: _navVisibleVN,
                      builder: (context, navVisible, child) =>
                          ExcludeFocus(excluding: navVisible, child: child!),
                      child: Positioned(
                        // A bit of breathing room off the top edge — Android
                        // TV/Fire TV guidance keeps primary controls out of
                        // the outermost title-safe band; flush against y=0
                        // read as clipped/cramped, especially once the bar
                        // expands into the keyboard.
                        top: AppScale.space(context, 22),
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Center(
                            child: QuickSearchArea(
                              // Fresh controller/bloc/state per plugin — avoids a
                              // stale query or stale results bleeding into the
                              // next plugin the user switches to.
                              key: ValueKey(_selectedPluginId),
                              pluginId: _selectedPluginId!,
                              pluginName: pluginLabel(state.plugins[safeIdx]),
                              barFocusNode: _searchBarFocusNode,
                              onDismiss: () {
                                // Restore focus to whatever card the user was
                                // actually on before opening search — falls
                                // back to the row's first card only if that
                                // node no longer exists (e.g. the catalog
                                // reloaded while search was open and rebuilt
                                // its FocusNodes from scratch).
                                final restored = _preSearchFocus.requestFocus();
                                _preSearchFocus.clear();
                                if (restored) return;
                                final body = _selectedPluginId == null
                                    ? null
                                    : _pageKeys[_selectedPluginId]
                                        ?.currentState;
                                if (body != null) {
                                  body._focusFirstCard();
                                  return;
                                }
                                // Not-ready plugin (needsConfig/syncing/error/
                                // no-catalogs) — _pageKeys[i].currentState is
                                // null in that case (see its own doc comment
                                // above), same gap _closeNav() was already
                                // patched for. Without this, dismissing quick
                                // search here (Escape/Back or the X, both
                                // funnel through this callback) left no focus
                                // anywhere: _expanded never flips back to
                                // false since that depends on focus actually
                                // leaving this subtree, so the panel stayed
                                // visibly open and unresponsive — reachable
                                // any time search gets entered on a not-ready
                                // plugin (see _PluginNotReadyPageState's
                                // arrowUp handling below for how that happens).
                                _notReadyFocusNodes[_selectedPlugin]
                                    .requestFocus();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Nav overlay — focus blocked when hidden.
                  // AnimatedSlide (transform-only, no per-frame Stack
                  // relayout like AnimatedPositioned) + a RepaintBoundary so
                  // the panel's SVG wordmark and gradient are rasterised once
                  // and the slide is a pure GPU layer translate. Opening the
                  // menu was visibly heavy on a Fire TV Stick before this.
                  ValueListenableBuilder<bool>(
                    valueListenable: _navVisibleVN,
                    builder: (context, navVisible, child) => ExcludeFocus(
                      excluding: !navVisible,
                      child: Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: navW,
                        child: AnimatedSlide(
                          offset:
                              navVisible ? Offset.zero : const Offset(-1, 0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: child!,
                        ),
                      ),
                    ),
                    child: RepaintBoundary(
                      child: PluginNav(
                        plugins: state.plugins,
                        selectedIndex: _selectedPlugin,
                        pluginFocusNodes: _pluginFocusNodes,
                        onPluginSelected: (i) {
                          setState(() {
                            _selectedPlugin = i;
                            _selectedPluginId = state.plugins[i].pluginId;
                          });
                          _navVisibleVN.value = false;
                          final body = _pageKeys[state.plugins[i].pluginId]
                              ?.currentState;
                          // Always land on the topmost carousel (continue
                          // watching if present) when a plugin is picked from
                          // the nav — including re-picking the current one.
                          body?._resetToFirstCatalog();
                          body?._transition(_HomeFsm.browsing);
                          body?._focusFirstCard();
                        },
                        onPluginFocused: (_) {},
                        onClose: _closeNav,
                      ),
                    ),
                  ),

                  // Scrim — plain (no per-frame color tween); the panel
                  // slide carries the "opening" motion.
                  ValueListenableBuilder<bool>(
                    valueListenable: _navVisibleVN,
                    builder: (context, navVisible, _) => navVisible
                        ? Positioned.fill(
                            child: GestureDetector(
                              onTap: _closeNav,
                              child: const ColoredBox(color: Color(0x73000000)),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            }
            return const Center(
              child: Text('Nessun plugin disponibile',
                  style: TextStyle(color: AppTheme.textLow)),
            );
          },
        ),
      ),
    );
  }
}

// Mirrors _PluginPage.build()'s own not-ready gates below — used by
// _HomeViewState to decide whether quick search should even be offered for
// the active plugin (see its build() below): searching a plugin with no
// data yet returns nothing useful, and worse, quick search's dark backdrop
// used to render on top of the "Sincronizzazione in corso…"/"Errore
// plugin" message, hiding it entirely with no way to see it was even there.
bool _isPluginReady(PluginInfo p) =>
    !p.needsConfig &&
    p.statusLabel != 'syncing' &&
    p.statusLabel != 'error' &&
    p.catalogs.isNotEmpty;
