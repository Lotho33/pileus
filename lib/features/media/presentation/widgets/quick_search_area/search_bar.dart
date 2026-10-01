// Part of quick_search_area.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the two consts and the
// QuickSearchArea widget; private identifiers are shared across all parts.
part of '../quick_search_area.dart';

class _QuickSearchBar extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final String pluginName;
  final bool expanded;
  final VoidCallback onSubmitted;
  final VoidCallback onNavigateDown;
  final VoidCallback onDismiss;
  final VoidCallback onOpenFilters;

  const _QuickSearchBar({
    super.key,
    required this.focusNode,
    required this.controller,
    required this.pluginName,
    required this.expanded,
    required this.onSubmitted,
    required this.onNavigateDown,
    required this.onDismiss,
    required this.onOpenFilters,
  });

  @override
  State<_QuickSearchBar> createState() => _QuickSearchBarState();
}

class _QuickSearchBarState extends State<_QuickSearchBar> {
  final _filtersFn = FocusNode();
  final _closeFn = FocusNode();

  @override
  void dispose() {
    _filtersFn.dispose();
    _closeFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final barH = sh * 0.052;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          // Never itself focused — catches arrowDown/arrowRight/escape
          // bubbling up unhandled from the TextField's own FocusNode
          // (EditableText only binds left/right for the caret and typing
          // itself), same idiom as plugin_settings_screen.dart's up/down
          // catcher around a caret-editable field.
          child: TvFocusable(
            canRequestFocus: false,
            onDown: widget.onNavigateDown,
            onRight: widget.expanded ? () => _filtersFn.requestFocus() : null,
            // Only Escape/Back exits search — an arrow key doing the same
            // was a trap: any direction that didn't have somewhere to go
            // could bubble past this widget and land on an unrelated,
            // still-focusable card far away in the catalog underneath
            // (see the outer scope Focus's catch-all below, which is the
            // actual fix for that; this still exists as a dedicated,
            // predictable exit key).
            onEsc: widget.onDismiss,
            builder: (context, _) => Container(
              height: barH,
              padding: EdgeInsets.symmetric(horizontal: barH * 0.28),
              // Deliberately NOT a focus treatment (primary border + glow):
              // this bar is never a D-pad focus stop, and dressing it like a
              // focused control while the real focus is on the keyboard/close
              // button below just read as "two things are selected". A plain,
              // static box — the blinking caret (shown only once expanded)
              // and the keyboard appearing are enough to signal "typing here".
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.textHigh
                      .withValues(alpha: widget.expanded ? 0.20 : 0.12),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: barH * 0.42,
                      color: AppTheme.textHigh.withValues(alpha: 0.5)),
                  SizedBox(width: barH * 0.2),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      // OnScreenKeyboard below is the only intended input
                      // source — readOnly stops Android's own IME from also
                      // popping up on top of it. widget.focusNode never
                      // actually gains D-pad focus (canRequestFocus: false,
                      // see _textFieldFocusNode's own doc), so showCursor is
                      // forced on explicitly — otherwise the caret would never
                      // render at all. Only while expanded, though: a blinking
                      // caret in the collapsed bar (which just shows the
                      // "Cerca in …" hint) read as the bar being focused.
                      readOnly: true,
                      showCursor: widget.expanded,
                      style: TextStyle(
                          color: AppTheme.textHigh, fontSize: barH * 0.32),
                      cursorColor: AppTheme.textHigh,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Cerca in ${widget.pluginName}…',
                        hintStyle: TextStyle(
                          color: AppTheme.textHigh.withValues(alpha: 0.4),
                          fontSize: barH * 0.32,
                        ),
                      ),
                      onSubmitted: (_) => widget.onSubmitted(),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.expanded) ...[
          SizedBox(width: barH * 0.16),
          TvFocusable(
            focusNode: _filtersFn,
            onActivate: widget.onOpenFilters,
            // The TextField itself can no longer take focus (see
            // _textFieldFocusNode) — reuse the same "jump to the keyboard's
            // first key" target already wired for onNavigateDown above,
            // rather than a request that would now silently do nothing.
            onLeft: widget.onNavigateDown,
            onRight: () => _closeFn.requestFocus(),
            // Down from the top-row buttons drops into the keyboard, same as
            // Down from the search field itself — previously the only way
            // off these buttons was sideways.
            onDown: widget.onNavigateDown,
            onEsc: widget.onDismiss,
            builder: (context, filtersFocused) => Container(
              height: barH,
              width: barH,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: filtersFocused
                      ? AppTheme.primary
                      : AppTheme.textHigh.withValues(alpha: 0.12),
                  width: filtersFocused ? 1.6 : 1,
                ),
                boxShadow: filtersFocused
                    ? AppScale.focusGlow(AppTheme.primary)
                    : null,
              ),
              child: Icon(Icons.tune_rounded,
                  size: barH * 0.44,
                  color: AppTheme.textHigh.withValues(alpha: 0.7)),
            ),
          ),
          SizedBox(width: barH * 0.16),
          // Explicit close — the only other way out is Escape/Back, which a
          // D-pad-only remote without a reliable back key might not have.
          TvFocusable(
            focusNode: _closeFn,
            onActivate: widget.onDismiss,
            onLeft: () => _filtersFn.requestFocus(),
            onDown: widget.onNavigateDown,
            onEsc: widget.onDismiss,
            builder: (context, closeFocused) => Container(
              height: barH,
              width: barH,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: closeFocused
                      ? AppTheme.primary
                      : AppTheme.textHigh.withValues(alpha: 0.12),
                  width: closeFocused ? 1.6 : 1,
                ),
                boxShadow:
                    closeFocused ? AppScale.focusGlow(AppTheme.primary) : null,
              ),
              child: Icon(Icons.close_rounded,
                  size: barH * 0.44,
                  color: AppTheme.textHigh.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ],
    );
  }
}
