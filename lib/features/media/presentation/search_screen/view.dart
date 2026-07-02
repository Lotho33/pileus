// Part of search_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the ratio/threshold constants and
// the public SearchScreen entry point; private identifiers are shared across
// all parts.
part of '../search_screen.dart';

class _SearchView extends StatefulWidget {
  final String pluginId;
  final String pluginName;
  final String initialQuery;

  const _SearchView({
    required this.pluginId,
    required this.pluginName,
    this.initialQuery = '',
  });

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  // Attached to the (display-only) search field but never focused — see
  // initState. Kept only so the TextField has a stable node.
  final _focusNode = FocusNode();
  // Manual back button in the toolbar — now the screen's initial focus and
  // the top of the D-pad chain.
  final _backBtnFn = FocusNode();
  // Captured from _SearchCarousel once results build their first card —
  // lets an explicit down-arrow from the search bar reach the results
  // without the carousel ever auto-stealing focus on its own. SafeFocusRef
  // (see lib/shared/utils/safe_focus.dart) since _SearchCarousel isn't
  // rendered in every DiscoveryState (loading/error/empty all fall through
  // to other widgets below without ever re-setting this) — same dangling-
  // FocusNode pattern home_screen.dart's quick search had before it was
  // fixed and migrated onto this same utility.
  final _firstResultFocus = SafeFocusRef();
  final _keyboardKey = GlobalKey<OnScreenKeyboardState>();
  final _filterBtnFn = FocusNode();
  // Landing spot inside the filter panel once it opens — without this,
  // pressing select on _FilterBtn just slides the panel open while focus
  // stays behind on the button that opened it, leaving every filter chip
  // inside completely unreachable by remote.
  final _filterPanelFirstFn = FocusNode();
  String _lastQuery = '';
  Timer? _debounceTimer;
  // True from the moment a keystroke changes the query until the debounced
  // _submit actually runs — surfaced as the same loading spinner
  // DiscoveryLoading drives, so typing a new character visibly
  // acknowledges/interrupts whatever was on screen right away instead of
  // leaving the previous (now stale) results looking unchanged for the
  // whole debounce + network round trip.
  bool _pendingSearch = false;
  // Keyboard recedes once the user is browsing results — otherwise it
  // permanently eats the vertical space the results carousel and the
  // focused-item info panel below it need to be readable.
  bool _keyboardVisible = true;

  List<SearchFilter> _availableFilters = [];
  final Map<String, String> _activeFilters = {};
  bool _filterPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    // Open with results already on screen: an empty query is a valid
    // request — every plugin answers it with its default (popularity)
    // ordering — so fire it now rather than showing a bare prompt until
    // the user types. A real initialQuery (came from the quick-search bar)
    // takes over below.
    if (widget.initialQuery.isEmpty) {
      context.read<DiscoveryBloc>().add(SearchRequestEvent(
            pluginId: widget.pluginId,
            query: '',
            filters: const {},
          ));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Land on the keyboard — that's what a search screen is for. The back
      // button (initial focus's old home was the now-unfocusable field) sits
      // one Up away from the keyboard's top row.
      _focusKeyboard();
      if (widget.initialQuery.isNotEmpty) {
        _controller.text = widget.initialQuery;
        _submit(widget.initialQuery);
      }
    });
  }

  /// Moves focus into the on-screen keyboard, revealing it first if it has
  /// receded behind the results.
  void _focusKeyboard() {
    if (_keyboardVisible) {
      _keyboardKey.currentState?.firstFocusNode.requestFocus();
    } else {
      setState(() => _keyboardVisible = true);
      // The keyboard needs a frame to mount before its first key's
      // FocusNode is actually attached to the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _keyboardKey.currentState?.firstFocusNode.requestFocus();
      });
    }
  }

  Future<void> _loadFilters() async {
    try {
      final repo = getIt<MediaRepository>();
      final resp = await repo.getSearchFilters(widget.pluginId);
      if (!mounted) return;
      setState(() => _availableFilters = resp.filters);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _backBtnFn.dispose();
    _filterBtnFn.dispose();
    _filterPanelFirstFn.dispose();
    super.dispose();
  }

  // Live search — fires ~350ms after the last keystroke (hardware or the
  // on-screen keyboard, both just mutate _controller) instead of waiting
  // for Invio/tap. onSubmitted below still exists for an immediate search.
  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    // Don't show the pending spinner for a query that's too short to
    // actually dispatch (and won't, unless a filter is active) — same
    // rationale as quick search.
    final willSearch =
        value.trim().length >= _kMinSearchLength || _activeFilters.isNotEmpty;
    if (willSearch && !_pendingSearch) {
      setState(() => _pendingSearch = true);
    } else if (!willSearch && _pendingSearch) {
      setState(() => _pendingSearch = false);
    }
    _debounceTimer =
        Timer(const Duration(milliseconds: 350), () => _submit(value));
  }

  void _submit(String query) {
    _debounceTimer?.cancel();
    if (_pendingSearch) setState(() => _pendingSearch = false);
    final q = query.trim();
    if (q.length < _kMinSearchLength && _activeFilters.isEmpty) {
      // Too short to search and no filter carrying it — backspaced the query
      // down to (near) nothing. Fall back to the same empty-query request
      // the screen opened with (plugin default = popularity) so the results
      // never go blank once they've been shown.
      if (_lastQuery.isNotEmpty) {
        _lastQuery = '';
        context.read<DiscoveryBloc>().add(SearchRequestEvent(
              pluginId: widget.pluginId,
              query: '',
              filters: const {},
            ));
      }
      return;
    }
    final currentFilters = context.read<DiscoveryBloc>().state
            is DiscoveryLoaded
        ? (context.read<DiscoveryBloc>().state as DiscoveryLoaded).activeFilters
        : const <String, String>{};
    if (q == _lastQuery &&
        _activeFilters.toString() == currentFilters.toString()) {
      return;
    }
    _lastQuery = q;
    context.read<DiscoveryBloc>().add(SearchRequestEvent(
        pluginId: widget.pluginId,
        query: q,
        filters: Map.from(_activeFilters)));
  }

  void _applyFilter(String id, String value) {
    setState(() {
      if (value.isEmpty) {
        _activeFilters.remove(id);
      } else {
        _activeFilters[id] = value;
      }
    });
    if (_lastQuery.isNotEmpty || _activeFilters.isNotEmpty) {
      context.read<DiscoveryBloc>().add(SearchRequestEvent(
          pluginId: widget.pluginId,
          query: _lastQuery,
          filters: Map.from(_activeFilters)));
    }
  }

  void _toggleFilterPanel() {
    setState(() => _filterPanelOpen = !_filterPanelOpen);
    if (_filterPanelOpen) {
      // The panel mounts fresh this frame — its first focusable node isn't
      // attached yet, so this needs a frame delay (same idiom as the
      // on-screen keyboard hand-off above).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _filterPanelFirstFn.requestFocus();
      });
    } else {
      _filterBtnFn.requestFocus();
    }
  }

  void _closeFilterPanel() {
    setState(() => _filterPanelOpen = false);
    _filterBtnFn.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.goBack)) {
            if (consumeBackEvent()) context.pop();
            return KeyEventResult.handled;
          }
          // The toolbar row (back button + filter button) and the on-screen
          // keyboard now own their own D-pad wiring — the search field is no
          // longer a focus stop, so there's nothing to hand off from here.
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final hPad = w * _rSrHPad;
              final barH = h * _rSrBarH;
              final vPad = h * _rSrHeaderVPad;

              return Stack(
                children: [
                  Column(
                    children: [
                      // ── Toolbar ──────────────────────────────────────────────
                      Container(
                        color: const Color(0xFF12121A),
                        padding:
                            EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad * 0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _IconBtn(
                                  icon: Icons.arrow_back_rounded,
                                  size: barH * 0.50,
                                  onTap: () => context.pop(),
                                  focusNode: _backBtnFn,
                                  onRight: () {
                                    if (_availableFilters.isNotEmpty) {
                                      _filterBtnFn.requestFocus();
                                    } else {
                                      _focusKeyboard();
                                    }
                                  },
                                  onDown: _focusKeyboard,
                                ),
                                SizedBox(width: w * 0.006),
                                Expanded(
                                  child: Container(
                                    height: barH,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E2E),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.12)),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(width: barH * 0.22),
                                        Icon(Icons.search_rounded,
                                            size: barH * 0.40,
                                            color: Colors.white
                                                .withValues(alpha: 0.4)),
                                        SizedBox(width: barH * 0.18),
                                        Expanded(
                                          // Display-only: it can't take focus,
                                          // so Left from the toolbar row now
                                          // reaches the manual back button
                                          // instead of being swallowed by the
                                          // field's own caret handling. Input
                                          // comes solely from the on-screen
                                          // keyboard, which mutates
                                          // _controller directly (still fires
                                          // onChanged for live search).
                                          child: ExcludeFocus(
                                            child: TextField(
                                              controller: _controller,
                                              focusNode: _focusNode,
                                              // OnScreenKeyboard below is the
                                              // only intended input source —
                                              // readOnly stops Android's own
                                              // IME from also popping up on
                                              // top of it.
                                              readOnly: true,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: barH * 0.30),
                                              cursorColor: Colors.white,
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                hintText:
                                                    'Cerca in ${widget.pluginName}...',
                                                hintStyle: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.35),
                                                  fontSize: barH * 0.30,
                                                ),
                                                isDense: true,
                                              ),
                                              onChanged: _onQueryChanged,
                                              onSubmitted: _submit,
                                              textInputAction:
                                                  TextInputAction.search,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: barH * 0.22),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: w * 0.006),
                                _FilterBtn(
                                  barH: barH,
                                  enabled: _availableFilters.isNotEmpty,
                                  activeCount: _activeFilters.length,
                                  onTap: _toggleFilterPanel,
                                  focusNode: _filterBtnFn,
                                  onNavigateLeft: () =>
                                      _backBtnFn.requestFocus(),
                                  onNavigateDown: _focusKeyboard,
                                ),
                              ],
                            ),
                            // ── Active filter chips ─────────────────────────
                            if (_activeFilters.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: vPad * 0.3),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _activeFilters.entries.map((e) {
                                      final filter = _availableFilters
                                          .where((f) => f.id == e.key)
                                          .firstOrNull;
                                      final label = filter != null
                                          ? '${filter.label}: ${_optionLabel(filter, e.value)}'
                                          : '${e.key}: ${e.value}';
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: _ActiveFilterChip(
                                          label: label,
                                          onRemove: () =>
                                              _applyFilter(e.key, ''),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ── On-screen keyboard ──────────────────────────────────
                      // Visible while typing, recedes once the user moves down
                      // into the results — otherwise it permanently eats the
                      // vertical space the carousel and the focused-item info
                      // panel below it need to stay readable.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: !_keyboardVisible
                            ? const SizedBox(
                                width: double.infinity,
                                key: ValueKey('kb-hidden'))
                            : Container(
                                key: const ValueKey('kb-visible'),
                                color: const Color(0xFF12121A),
                                padding: EdgeInsets.fromLTRB(
                                    hPad, 0, hPad, vPad * 0.6),
                                child: OnScreenKeyboard(
                                  key: _keyboardKey,
                                  controller: _controller,
                                  // No Invio key — the debounced live search
                                  // dispatches on its own past _kMinSearchLength.
                                  showEnter: false,
                                  onNavigateUp: () => _backBtnFn.requestFocus(),
                                  onNavigateDown: () {
                                    setState(() => _keyboardVisible = false);
                                    _firstResultFocus.requestFocus();
                                  },
                                ),
                              ),
                      ),

                      // ── Results ───────────────────────────────────────────
                      Expanded(
                        child: BlocBuilder<DiscoveryBloc, DiscoveryState>(
                          builder: (context, state) {
                            if (state is DiscoveryInitial) {
                              // _SearchCarousel isn't rendered here, so any
                              // FocusNode it previously handed up is about to be
                              // disposed with it — see this field's doc comment.
                              _firstResultFocus.clear();
                              return _EmptyPrompt(
                                  pluginName: widget.pluginName);
                            }
                            if (state is DiscoveryLoading) {
                              _firstResultFocus.clear();
                              return Center(
                                  child: PileusSpinner(
                                      size: AppScale.spinnerL(context),
                                      color: Colors.white54));
                            }
                            if (state is DiscoveryError) {
                              _firstResultFocus.clear();
                              return ErrorRetryView(
                                message: 'Ricerca non riuscita.',
                                detail: state.errorCode,
                                autofocus: false,
                                onRetry: _lastQuery.isEmpty
                                    ? null
                                    : () => context
                                        .read<DiscoveryBloc>()
                                        .add(SearchRequestEvent(
                                          pluginId: widget.pluginId,
                                          query: _lastQuery,
                                          filters: Map.from(_activeFilters),
                                        )),
                              );
                            }
                            if (state is DiscoveryLoaded) {
                              if (state.items.isEmpty) {
                                _firstResultFocus.clear();
                                return ErrorRetryView(
                                  title: 'Nessun risultato',
                                  message: _lastQuery.isEmpty
                                      ? 'Prova con un altro termine o filtro.'
                                      : 'Niente per "$_lastQuery".',
                                  icon: Icons.search_off_rounded,
                                  autofocus: false,
                                );
                              }
                              return _SearchCarousel(
                                pluginId: widget.pluginId,
                                items: state.items.cast<CatalogItem>(),
                                hasMore: state.hasMore,
                                isLoadingMore: state.isLoadingMore,
                                screenH: h,
                                onFirstCardFocus: (fn) =>
                                    _firstResultFocus.set(fn),
                                onNavigateUp: () {
                                  // Back up out of the results → land on the
                                  // keyboard (re-shown), the natural place to
                                  // keep refining the query.
                                  _focusKeyboard();
                                },
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ],
                  ),

                  // ── Filter panel overlay ───────────────────────────────────
                  if (_filterPanelOpen && _availableFilters.isNotEmpty)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _closeFilterPanel,
                        behavior: HitTestBehavior.opaque,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {}, // consume tap to prevent closing
                                child: _FilterPanel(
                                  filters: _availableFilters,
                                  activeFilters: _activeFilters,
                                  onApply: _applyFilter,
                                  onClose: _closeFilterPanel,
                                  firstFocusNode: _filterPanelFirstFn,
                                  width: (w * 0.32).clamp(360.0, 560.0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        )); // Scaffold + Focus
  }

  String _optionLabel(SearchFilter filter, String value) {
    if (filter.type == 'bool') return value == 'true' ? 'Sì' : 'No';
    if (filter.type == 'range') {
      final p = value.split('..');
      if (p.length == 2) return p[0] == p[1] ? p[0] : '${p[0]}–${p[1]}';
      return value;
    }
    if (filter.type == 'multiselect') {
      final labels = value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((id) {
        for (final o in filter.options) {
          if (o.id == id) return o.label;
        }
        return id;
      });
      return labels.join(', ');
    }
    for (final opt in filter.options) {
      if (opt.id == value) return opt.label;
    }
    return value;
  }
}
