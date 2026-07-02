import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/back_dispatch.dart';

/// The shared focus/traversal widget the design audit's §01 asked for:
/// every simple D-pad-activatable control in this app (nav rows, settings
/// rows, small action buttons, badges...) hand-wired its own `Focus` +
/// `FocusNode` + `onKeyEvent` pattern-matching Select/Enter/Escape/arrows +
/// `GestureDetector` for tap parity — ~106 `onKeyEvent:` call sites across
/// 34 files at last count, most of them this exact shape. This wraps that
/// boilerplate once; [builder] gets the current focused state back and
/// keeps full control of visual treatment, so migrating a call site onto
/// this changes zero pixels — only the key-handling plumbing moves here.
///
/// Arrow-direction callbacks are optional and each independently default to
/// bubbling (`KeyEventResult.ignored`) when not supplied, so Flutter's own
/// default directional focus traversal still applies for any direction a
/// caller doesn't explicitly claim — the same "don't swallow what you don't
/// handle" rule that fixed the plugin-not-ready focus trap earlier in this
/// app's history (see home_screen.dart's `_PluginNotReadyPageState`).
class TvFocusable extends StatefulWidget {
  final Widget Function(BuildContext context, bool focused) builder;

  /// Select/Enter.
  final VoidCallback? onActivate;

  /// Escape/Back.
  final VoidCallback? onEsc;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  /// Supply to share a node's lifecycle with the caller (e.g. a GlobalKey
  /// elsewhere needs to call requestFocus() on it); otherwise this manages
  /// its own and disposes it.
  final FocusNode? focusNode;
  final bool autofocus;
  final bool canRequestFocus;
  final ValueChanged<bool>? onFocusChange;

  const TvFocusable({
    super.key,
    required this.builder,
    this.onActivate,
    this.onEsc,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.onFocusChange,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _ownNode;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  @override
  void didUpdateWidget(TvFocusable old) {
    super.didUpdateWidget(old);
    // The caller swapped the FocusNode under us — e.g. on_screen_keyboard.dart
    // rebuilds its whole key grid with fresh nodes when it switches between
    // the letters and numbers/symbols layouts. Our cached `_focused` still
    // reflects the *old* node (the key that was focused when the toggle was
    // pressed), and no onFocusChange fires for the swap, so without this the
    // stale highlight sticks on a key that isn't focused anymore. Re-derive
    // it from the node actually in effect now. Safe to assign directly:
    // didUpdateWidget runs immediately before build().
    if (old.focusNode != widget.focusNode) {
      _focused = (widget.focusNode ?? _ownNode)?.hasFocus ?? false;
    }
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  KeyEventResult _dispatch(VoidCallback? cb) {
    if (cb == null) return KeyEventResult.ignored;
    cb();
    return KeyEventResult.handled;
  }

  // KeyDownEvent-only, deliberately — this widget stays a plain single-fire
  // dispatcher. A caller that needs hold-to-repeat (this platform doesn't
  // reliably deliver native key-repeat — see player_seek_bar.dart's
  // _holdTickInterval doc, and series_page_layout.dart's
  // _onEpisodeHoldChanged for the pattern) drives its own Timer instead,
  // since that needs to survive focus moving to a *different* widget as
  // the hold advances — state this single-widget dispatcher can't hold.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter) {
      return _dispatch(widget.onActivate);
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (widget.onEsc == null) return KeyEventResult.ignored;
      // Swallow (but still report handled, so the event doesn't also fall
      // through to the platform back) when this is the echo of a press the
      // other Back path already acted on. See back_dispatch.dart.
      if (consumeBackEvent()) widget.onEsc!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) return _dispatch(widget.onUp);
    if (key == LogicalKeyboardKey.arrowDown) return _dispatch(widget.onDown);
    if (key == LogicalKeyboardKey.arrowLeft) return _dispatch(widget.onLeft);
    if (key == LogicalKeyboardKey.arrowRight) return _dispatch(widget.onRight);
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      canRequestFocus: widget.canRequestFocus,
      onFocusChange: (v) {
        setState(() => _focused = v);
        widget.onFocusChange?.call(v);
      },
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        onTap: widget.onActivate,
        child: Builder(
          builder: (context) => widget.builder(context, _focused),
        ),
      ),
    );
  }
}
