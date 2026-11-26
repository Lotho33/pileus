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
  // The microphone (voice_search.dart); null when there's no recognizer.
  final VoidCallback? onVoice;

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
    this.onVoice,
  });

  @override
  State<_QuickSearchBar> createState() => _QuickSearchBarState();
}

class _QuickSearchBarState extends State<_QuickSearchBar> {
  final _voiceFn = FocusNode();
  final _filtersFn = FocusNode();
  final _closeFn = FocusNode();

  @override
  void dispose() {
    _voiceFn.dispose();
    _filtersFn.dispose();
    _closeFn.dispose();
    super.dispose();
  }

  // The square buttons right of the bar (microphone, filters, close).
  Widget _button({
    required double barH,
    required FocusNode focusNode,
    required IconData icon,
    required VoidCallback onActivate,
    VoidCallback? onLeft,
    VoidCallback? onRight,
  }) =>
      TvFocusable(
        focusNode: focusNode,
        onActivate: onActivate,
        onLeft: onLeft,
        onRight: onRight,
        // Down from the top-row buttons drops into the keyboard, same as
        // Down from the search field itself.
        onDown: widget.onNavigateDown,
        onEsc: widget.onDismiss,
        builder: (context, focused) => Container(
          height: barH,
          width: barH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused
                  ? AppTheme.primary
                  : AppTheme.textHigh.withValues(alpha: 0.12),
              width: focused ? 1.6 : 1,
            ),
            boxShadow: focused ? AppScale.focusGlow(AppTheme.primary) : null,
          ),
          child: Icon(icon,
              size: barH * 0.44,
              color: AppTheme.textHigh.withValues(alpha: 0.7)),
        ),
      );

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
            onRight: widget.expanded
                ? () => (widget.onVoice != null ? _voiceFn : _filtersFn)
                    .requestFocus()
                : null,
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
              // Closed, on the home, it is tinted with the accent instead
              // (fill, a faint border, the icon) so it stands out without a
              // focus ring; open, it goes back to neutral while the focus
              // is on the keyboard.
              decoration: BoxDecoration(
                color: widget.expanded
                    ? const Color(0xFF1E1E2E)
                    : Color.alphaBlend(AppTheme.primary.withValues(alpha: 0.16),
                        const Color(0xFF1E1E2E)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.expanded
                      ? AppTheme.textHigh.withValues(alpha: 0.20)
                      : AppTheme.primary.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: barH * 0.42,
                      color: widget.expanded
                          ? AppTheme.textHigh.withValues(alpha: 0.5)
                          : AppTheme.primary),
                  SizedBox(width: barH * 0.2),
                  Expanded(
                    // OnScreenKeyboard below is the only intended input
                    // source — this used to be a real TextField with
                    // readOnly+keyboardType.none, which on web still left a
                    // real EditableText/DOM input behind for a browser to
                    // attach an unwanted IME to (confirmed on webOS); a
                    // plain reactive Text has nothing for one to attach to.
                    // That also drops the real blinking caret this had while
                    // expanded — no EditableText means no caret to blink —
                    // the keyboard itself being visible/expanded is left to
                    // carry the "you're typing here" signal on its own.
                    child: Focus(
                      focusNode: widget.focusNode,
                      child: ListenableBuilder(
                        listenable: widget.controller,
                        builder: (context, _) {
                          final text = widget.controller.text;
                          return Text(
                            text.isEmpty
                                ? 'Cerca in ${widget.pluginName}…'
                                : text,
                            style: TextStyle(
                              color: text.isEmpty
                                  ? AppTheme.textHigh.withValues(alpha: 0.4)
                                  : AppTheme.textHigh,
                              fontSize: barH * 0.32,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.expanded) ...[
          if (widget.onVoice != null) ...[
            SizedBox(width: barH * 0.16),
            _button(
              barH: barH,
              focusNode: _voiceFn,
              icon: Icons.mic_rounded,
              onActivate: widget.onVoice!,
              // The bar itself can't take focus: left goes to the keyboard.
              onLeft: widget.onNavigateDown,
              onRight: () => _filtersFn.requestFocus(),
            ),
          ],
          SizedBox(width: barH * 0.16),
          _button(
            barH: barH,
            focusNode: _filtersFn,
            icon: Icons.tune_rounded,
            onActivate: widget.onOpenFilters,
            // The TextField itself can no longer take focus (see
            // _textFieldFocusNode) — reuse the same "jump to the keyboard's
            // first key" target already wired for onNavigateDown above,
            // rather than a request that would now silently do nothing.
            onLeft: widget.onVoice != null
                ? () => _voiceFn.requestFocus()
                : widget.onNavigateDown,
            onRight: () => _closeFn.requestFocus(),
          ),
          SizedBox(width: barH * 0.16),
          // Explicit close — the only other way out is Escape/Back, which a
          // D-pad-only remote without a reliable back key might not have.
          _button(
            barH: barH,
            focusNode: _closeFn,
            icon: Icons.close_rounded,
            onActivate: widget.onDismiss,
            onLeft: () => _filtersFn.requestFocus(),
          ),
        ],
      ],
    );
  }
}
