// Part of search_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the ratio/threshold constants and
// the public SearchScreen entry point; private identifiers are shared across
// all parts.
part of '../search_screen.dart';

// ─── Filter panel ─────────────────────────────────────────────────────────────

class _FilterPanel extends StatefulWidget {
  final List<SearchFilter> filters;
  final Map<String, String> activeFilters;
  final void Function(String id, String value) onApply;
  final VoidCallback onClose;
  final double width;
  // Landing spot when the panel opens (the close button below) — the
  // caller owns it since it also needs to request focus back onto
  // whatever opened the panel (_FilterBtn) once this closes.
  final FocusNode firstFocusNode;

  const _FilterPanel({
    required this.filters,
    required this.activeFilters,
    required this.onApply,
    required this.onClose,
    required this.width,
    required this.firstFocusNode,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  final _resetFn = FocusNode();
  // One FocusNode per selectable control in each filter row — 1 per select
  // option, 1 for bool, 2 (−/+) for the number stepper. Addressed as
  // [row][col] by _moveHorizontal/_moveVertical, the same row/col idiom
  // on_screen_keyboard.dart uses for its own key grid.
  late List<List<FocusNode>> _rowNodes;

  @override
  void initState() {
    super.initState();
    _rowNodes = [
      for (final f in widget.filters)
        List.generate(_nodeCountFor(f), (_) => FocusNode()),
    ];
  }

  int _nodeCountFor(SearchFilter f) {
    switch (f.type) {
      case 'select':
      case 'multiselect':
        return f.options.length;
      case 'bool':
        return 1;
      case 'number':
        return 2;
      case 'range':
        return 4; // "Da" −/+ , "A" −/+
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _resetFn.dispose();
    for (final row in _rowNodes) {
      for (final n in row) {
        n.dispose();
      }
    }
    super.dispose();
  }

  void _moveHorizontal(int row, int col, int dir) {
    final newCol = col + dir;
    if (newCol < 0 || newCol >= _rowNodes[row].length) {
      return; // stop at row edges
    }
    _rowNodes[row][newCol].requestFocus();
  }

  void _moveVertical(int row, int col, int dir) {
    // A row with an unrecognized SearchFilter.type (see _nodeCountFor's
    // default case) has zero nodes and can't take focus — nextFocusableIndex
    // (lib/shared/utils/safe_focus.dart) keeps walking past it in the same
    // direction instead of stopping dead, same idiom as home_screen.dart's
    // onCatalogEmpty skipping empty catalogs. Without this, any row after
    // an unrecognized-type filter was permanently unreachable from that side.
    final newRow = nextFocusableIndex(
      from: row,
      direction: dir,
      length: _rowNodes.length,
      isSkippable: (i) => _rowNodes[i].isEmpty,
    );
    if (newRow == null) {
      // Walked off an edge of the row list. Up → close button. Down → the
      // "Reset" button if it's showing, otherwise wrap to the close button
      // so Down from the last filter (e.g. genres, often the last one) with
      // no active filter yet still goes somewhere instead of dead-ending.
      if (dir > 0 && widget.activeFilters.isNotEmpty) {
        _resetFn.requestFocus();
      } else {
        widget.firstFocusNode.requestFocus(); // close button
      }
      return;
    }
    // Land on the first control of the section moved into — predictable,
    // rather than a clamped column from wherever you were in the old row.
    _rowNodes[newRow][0].requestFocus();
  }

  void _resetAll() {
    for (final f in widget.filters) {
      widget.onApply(f.id, '');
    }
    // The reset button only exists while activeFilters is non-empty — it's
    // about to remove itself from the tree, so focus needs somewhere to
    // land instead of dangling on a now-unmounted node.
    widget.firstFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      // Safety net (same rationale as home_screen.dart's quick-search
      // scope catch-all): any arrow key nothing below claims would
      // otherwise bubble past this panel and let Flutter's default
      // directional-focus-traversal jump focus to an unrelated widget
      // behind the panel. Escape/Back closes just the panel here instead
      // of falling through to the search screen's own handler and popping
      // the whole screen.
      onKeyEvent: (_, ev) {
        final k = ev.logicalKey;
        if (ev is KeyDownEvent &&
            (k == LogicalKeyboardKey.escape ||
                k == LogicalKeyboardKey.goBack)) {
          if (consumeBackEvent()) widget.onClose();
          return KeyEventResult.handled;
        }
        final isArrow = k == LogicalKeyboardKey.arrowUp ||
            k == LogicalKeyboardKey.arrowDown ||
            k == LogicalKeyboardKey.arrowLeft ||
            k == LogicalKeyboardKey.arrowRight;
        // Swallow held arrows (KeyRepeatEvent) too, not just the first
        // KeyDown — a repeat that bubbles past here reaches Flutter's
        // default directional traversal, which walks focus by screen
        // geometry into the next chip in the genre Wrap instead of the next
        // filter section.
        return isArrow ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: Container(
        width: widget.width,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(left: BorderSide(color: AppTheme.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppScale.space(context, 20),
                  AppScale.space(context, 22),
                  AppScale.space(context, 10),
                  AppScale.space(context, 10)),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: AppScale.iconS(context), color: _kFocusColor),
                  SizedBox(width: AppScale.space(context, 10)),
                  Expanded(
                    child: Text('Filtri',
                        style: TextStyle(
                            color: AppTheme.textHigh,
                            fontSize: AppScale.label(context),
                            fontWeight: FontWeight.w700)),
                  ),
                  TvFocusable(
                    focusNode: widget.firstFocusNode,
                    onActivate: widget.onClose,
                    onDown: () => _moveVertical(-1, 0, 1),
                    builder: (context, focused) => AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: EdgeInsets.all(AppScale.space(context, 8)),
                      decoration: BoxDecoration(
                        color: focused
                            ? _kFocusColor.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: focused ? _kFocusColor : Colors.transparent),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: AppScale.iconS(context),
                          color:
                              focused ? AppTheme.textHigh : AppTheme.textMid),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.border, height: 1),
            // Filters — SingleChildScrollView, NOT ListView: a filter with a
            // dense chip Wrap (e.g. a long genres list) makes the row taller
            // than the panel, which pushed the *next* filter row outside a lazy
            // ListView's build area — so _moveVertical's requestFocus landed
            // on a node whose element wasn't built yet (context == null) and
            // silently did nothing ("Down stuck in genres"). A handful of
            // filter rows is cheap to keep all built; ensureVisible still
            // scrolls to whichever one gets focus.
            Expanded(
              child: SingleChildScrollView(
                // Right inset so a focused chip's scale + glow near the panel
                // edge (which sits flush against the screen edge) has room to
                // paint instead of being clipped.
                padding: EdgeInsets.fromLTRB(0, AppScale.space(context, 8),
                    AppScale.space(context, 14), AppScale.space(context, 8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var row = 0; row < widget.filters.length; row++) ...[
                      if (row > 0)
                        Divider(
                            color: AppTheme.border.withValues(alpha: 0.5),
                            height: 1,
                            indent: AppScale.space(context, 14),
                            endIndent: AppScale.space(context, 14)),
                      _buildFilter(widget.filters[row], row),
                    ],
                  ],
                ),
              ),
            ),
            // Reset all
            if (widget.activeFilters.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    AppScale.space(context, 16),
                    AppScale.space(context, 8),
                    AppScale.space(context, 16),
                    AppScale.space(context, 16)),
                child: TvFocusable(
                  focusNode: _resetFn,
                  onActivate: _resetAll,
                  onUp: () => _moveVertical(_rowNodes.length, 0, -1),
                  builder: (context, focused) => AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: EdgeInsets.symmetric(
                        vertical: AppScale.space(context, 12)),
                    decoration: BoxDecoration(
                      color: focused
                          ? _kFocusColor.withValues(alpha: 0.16)
                          : Colors.transparent,
                      border: Border.all(
                          color: focused ? _kFocusColor : AppTheme.border,
                          width: focused ? 2 : 1),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow:
                          focused ? AppScale.focusGlow(_kFocusColor) : const [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_off_rounded,
                            size: AppScale.caption(context),
                            color:
                                focused ? AppTheme.textHigh : AppTheme.textMid),
                        SizedBox(width: AppScale.space(context, 6)),
                        Text('Rimuovi filtri',
                            style: TextStyle(
                                color: focused
                                    ? AppTheme.textHigh
                                    : AppTheme.textMid,
                                fontSize: AppScale.caption(context),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilter(SearchFilter f, int row) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 16),
          vertical: AppScale.space(context, 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label.toUpperCase(),
              style: TextStyle(
                  color: AppTheme.textLow,
                  fontSize: AppScale.caption(context),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          SizedBox(height: AppScale.space(context, 10)),
          if (f.type == 'select') _buildSelect(f, row),
          if (f.type == 'multiselect') _buildMultiselect(f, row),
          if (f.type == 'bool') _buildBool(f, row),
          if (f.type == 'number') _buildNumber(f, row),
          if (f.type == 'range') _buildRange(f, row),
        ],
      ),
    );
  }

  Widget _buildSelect(SearchFilter f, int row) {
    final current = widget.activeFilters[f.id] ?? '';
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var col = 0; col < f.options.length; col++)
          _FilterChipBtn(
            focusNode: _rowNodes[row][col],
            label: f.options[col].label,
            selected: current == f.options[col].id,
            onTap: () => widget.onApply(
                f.id, current == f.options[col].id ? '' : f.options[col].id),
            onNavigateLeft: () => _moveHorizontal(row, col, -1),
            onNavigateRight: () => _moveHorizontal(row, col, 1),
            onNavigateUp: () => _moveVertical(row, col, -1),
            onNavigateDown: () => _moveVertical(row, col, 1),
          ),
      ],
    );
  }

  // Multi-select: the active value is a comma-separated list of option ids —
  // the shape the server's search-filter parser expects back.
  // Tapping a chip toggles its id in/out of the list.
  Widget _buildMultiselect(SearchFilter f, int row) {
    final selected = (widget.activeFilters[f.id] ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var col = 0; col < f.options.length; col++)
          _FilterChipBtn(
            focusNode: _rowNodes[row][col],
            label: f.options[col].label,
            selected: selected.contains(f.options[col].id),
            onTap: () {
              final id = f.options[col].id;
              final next = {...selected};
              if (!next.remove(id)) next.add(id);
              widget.onApply(f.id, next.join(','));
            },
            onNavigateLeft: () => _moveHorizontal(row, col, -1),
            onNavigateRight: () => _moveHorizontal(row, col, 1),
            onNavigateUp: () => _moveVertical(row, col, -1),
            onNavigateDown: () => _moveVertical(row, col, 1),
          ),
      ],
    );
  }

  // Range: the active value is "lo..hi" — the shape the server's
  // search-filter parser expects. `options` carries the bounds as pseudo-entries keyed
  // min / max / step. Rendered as two D-pad steppers ("Da" / "A"); a full
  // span (lo<=min && hi>=max) clears the filter rather than sending a no-op.
  Widget _buildRange(SearchFilter f, int row) {
    double optNum(String id, double fallback) {
      for (final o in f.options) {
        if (o.id == id) return double.tryParse(o.label) ?? fallback;
      }
      return fallback;
    }

    final loBound = optNum('min', 0);
    // A plugin can ship malformed range metadata (min > max, or a stored
    // filter value outside a newly-narrowed span). `num.clamp(lo, hi)`
    // throws ArgumentError when lo > hi and takes the whole filter panel
    // down with it — so normalise the bounds and the current values here
    // before any clamp runs against them.
    final hiBound = optNum('max', 100) < loBound ? loBound : optNum('max', 100);
    final rawStep = optNum('step', 1);
    final step = rawStep > 0 ? rawStep : 1.0;

    final parts = (widget.activeFilters[f.id] ?? '').split('..');
    double? lo = parts.isNotEmpty ? double.tryParse(parts[0].trim()) : null;
    double? hi = parts.length > 1 ? double.tryParse(parts[1].trim()) : null;
    if (parts.length == 1 && lo != null) hi = lo; // bare "2010" → both ends

    String fmt(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

    void emit(double newLo, double newHi) {
      final l = newLo.clamp(loBound, hiBound).toDouble();
      final h = newHi.clamp(loBound, hiBound).toDouble();
      if (l <= loBound && h >= hiBound) {
        widget.onApply(f.id, ''); // full span = no constraint
        return;
      }
      widget.onApply(f.id, '${fmt(l)}..${fmt(h)}');
    }

    final curLo = (lo ?? loBound).clamp(loBound, hiBound).toDouble();
    final curHi = (hi ?? hiBound).clamp(loBound, hiBound).toDouble();

    Widget stepper(String label, double value, int baseCol,
        void Function(double) onChange) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: AppScale.space(context, 32),
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.textLow,
                    fontSize: AppScale.caption(context),
                    fontWeight: FontWeight.w600)),
          ),
          _FilterChipBtn(
            focusNode: _rowNodes[row][baseCol],
            label: '−',
            selected: false,
            onTap: () => onChange(value - step),
            onNavigateLeft: () => _moveHorizontal(row, baseCol, -1),
            onNavigateRight: () => _moveHorizontal(row, baseCol, 1),
            onNavigateUp: () => _moveVertical(row, baseCol, -1),
            onNavigateDown: () => _moveVertical(row, baseCol, 1),
          ),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppScale.space(context, 12)),
            child: Text(fmt(value),
                style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: AppScale.label(context),
                    fontWeight: FontWeight.w700)),
          ),
          _FilterChipBtn(
            focusNode: _rowNodes[row][baseCol + 1],
            label: '+',
            selected: false,
            onTap: () => onChange(value + step),
            onNavigateLeft: () => _moveHorizontal(row, baseCol + 1, -1),
            onNavigateRight: () => _moveHorizontal(row, baseCol + 1, 1),
            onNavigateUp: () => _moveVertical(row, baseCol + 1, -1),
            onNavigateDown: () => _moveVertical(row, baseCol + 1, 1),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stepper('Da', curLo, 0,
            (v) => emit(v.clamp(loBound, curHi).toDouble(), curHi)),
        SizedBox(height: AppScale.space(context, 8)),
        stepper('A', curHi, 2,
            (v) => emit(curLo, v.clamp(curLo, hiBound).toDouble())),
      ],
    );
  }

  Widget _buildBool(SearchFilter f, int row) {
    final current = widget.activeFilters[f.id];
    final isOn = current == 'true';
    return _FilterChipBtn(
      focusNode: _rowNodes[row][0],
      label: isOn ? 'Attivo' : 'Non attivo',
      selected: isOn,
      onTap: () => widget.onApply(f.id, isOn ? '' : 'true'),
      onNavigateLeft: () {},
      onNavigateRight: () {},
      onNavigateUp: () => _moveVertical(row, 0, -1),
      onNavigateDown: () => _moveVertical(row, 0, 1),
    );
  }

  // A bare TextField here used to mean a D-pad-only remote had no way to
  // type into it at all (no on-screen keyboard paired to it, unlike every
  // other text entry point in the app). A +/− stepper is fully D-pad
  // native and matches what this field is used for in practice (the
  // hint it replaced, "es. 2023", was always a year).
  Widget _buildNumber(SearchFilter f, int row) {
    final current = int.tryParse(widget.activeFilters[f.id] ?? '');
    // This field is always a release year in practice (see the comment
    // above) — nothing stops it from stepping past the current year and
    // producing a search for a movie/show that can't exist yet.
    final maxYear = DateTime.now().year;
    const minYear = 1900;
    void setValue(int v) => widget.onApply(f.id, v <= 0 ? '' : '$v');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterChipBtn(
          focusNode: _rowNodes[row][0],
          label: '−',
          selected: false,
          onTap: () =>
              setValue(((current ?? maxYear) - 1).clamp(minYear, maxYear)),
          onNavigateLeft: () => _moveHorizontal(row, 0, -1),
          onNavigateRight: () => _moveHorizontal(row, 0, 1),
          onNavigateUp: () => _moveVertical(row, 0, -1),
          onNavigateDown: () => _moveVertical(row, 0, 1),
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: AppScale.space(context, 14)),
          child: Text(
            current != null ? '$current' : 'es. $maxYear',
            style: TextStyle(
                color: current != null ? AppTheme.textHigh : AppTheme.textLow,
                fontSize: AppScale.label(context),
                fontWeight:
                    current != null ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
        _FilterChipBtn(
          focusNode: _rowNodes[row][1],
          label: '+',
          selected: false,
          onTap: () =>
              setValue(((current ?? maxYear) + 1).clamp(minYear, maxYear)),
          onNavigateLeft: () => _moveHorizontal(row, 1, -1),
          onNavigateRight: () => _moveHorizontal(row, 1, 1),
          onNavigateUp: () => _moveVertical(row, 1, -1),
          onNavigateDown: () => _moveVertical(row, 1, 1),
        ),
      ],
    );
  }
}

class _FilterChipBtn extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onNavigateLeft;
  final VoidCallback onNavigateRight;
  final VoidCallback onNavigateUp;
  final VoidCallback onNavigateDown;
  const _FilterChipBtn({
    required this.focusNode,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onNavigateLeft,
    required this.onNavigateRight,
    required this.onNavigateUp,
    required this.onNavigateDown,
  });
  @override
  State<_FilterChipBtn> createState() => _FilterChipBtnState();
}

class _FilterChipBtnState extends State<_FilterChipBtn> {
  // TvFocusable (below) only fires on the first KeyDown of an arrow. On a
  // box whose remote emits KeyRepeatEvents, a held key therefore did
  // nothing (the repeats were then swallowed by the panel's Focus). This
  // outer Focus acts on those repeats so a held key flies: Left/Right
  // through the options of a filter, Up/Down through the filters
  // themselves. (Boxes that repeat as a KeyDown cascade already step fast,
  // since TvFocusable acts on every KeyDown.)
  KeyEventResult _onRepeat(FocusNode node, KeyEvent event) {
    if (event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        widget.onNavigateLeft();
      case LogicalKeyboardKey.arrowRight:
        widget.onNavigateRight();
      case LogicalKeyboardKey.arrowUp:
        widget.onNavigateUp();
      case LogicalKeyboardKey.arrowDown:
        widget.onNavigateDown();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onRepeat,
      child: TvFocusable(
        focusNode: widget.focusNode,
        onActivate: widget.onTap,
        onLeft: widget.onNavigateLeft,
        onRight: widget.onNavigateRight,
        onUp: widget.onNavigateUp,
        onDown: widget.onNavigateDown,
        // The panel's Focus swallows every arrow key, so its ListView never
        // scrolls itself — bring the focused control (and the label above it)
        // into view here, the same way plugin_nav.dart's rows do.
        onFocusChange: (focused) {
          if (!focused || !mounted) return;
          final ctx = context;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final box = ctx.findRenderObject();
            if (box == null || !box.attached) return;
            if (Scrollable.maybeOf(ctx) == null) return;
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.35,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          });
        },
        builder: (context, focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: EdgeInsets.symmetric(
              horizontal: AppScale.space(context, 14),
              vertical: AppScale.space(context, 9)),
          decoration: BoxDecoration(
            color: widget.selected
                ? _kFocusColor.withValues(alpha: focused ? 0.42 : 0.28)
                : (focused
                    ? _kFocusColor.withValues(alpha: 0.16)
                    : AppTheme.surface2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused
                  ? _kFocusColor
                  : (widget.selected
                      ? _kFocusColor.withValues(alpha: 0.6)
                      : AppTheme.border),
              width: focused ? 2 : 1,
            ),
            // No focus scale here (chips sit in a Wrap tight against the panel
            // edge) — the border + a soft glow are enough of a highlight.
            boxShadow:
                focused ? AppScale.focusGlow(_kFocusColor, blur: 10) : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selected)
                Padding(
                  padding: EdgeInsets.only(right: AppScale.space(context, 5)),
                  child: Icon(Icons.check_rounded,
                      size: AppScale.caption(context),
                      color: AppTheme.textHigh),
                ),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected || focused
                      ? AppTheme.textHigh
                      : AppTheme.textMid,
                  fontSize: AppScale.caption(context),
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
