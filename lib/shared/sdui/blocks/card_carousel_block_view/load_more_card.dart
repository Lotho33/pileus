// Part of card_carousel_block_view.dart — split out for readability (plan
// 2e). The library file holds the shared imports, the baseline ratio consts
// and the public API (CardCarouselInteraction, CarouselLoadMore,
// CardCarouselBlockView); private identifiers are shared across all parts.
part of '../card_carousel_block_view.dart';

// ── trailing "load more" card ──────────────────────────────────────────────
// Same footprint as a poster card so it sits in the row as its last slot and
// scrolls/focuses with everything else. Icon + label rather than art; a
// spinner while a page is in flight.
class _LoadMoreCardView extends StatefulWidget {
  final FocusNode focusNode;
  final double width;
  final double height;
  final bool isLoading;
  final VoidCallback onActivate;
  final VoidCallback onFocused;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onEsc;
  // See _PosterCardView.onHoldChanged's doc in card_carousel_block_view.dart.
  // Missing here was the actual bug: landing on this card
  // (the trailing slot of a row) while a shell-level Up/Down hold-repeat
  // timer was armed left that timer's matching "release" signal with nowhere
  // to go — this card, on the old TvFocusable (deliberately KeyDownEvent-only,
  // see its own doc), silently dropped the trailing KeyUpEvent instead of
  // forwarding it. The timer then had no way to ever stop itself for the
  // Down direction (unlike Up, which self-limits via _upWouldEscapeToSearch),
  // so a single press that happened to end up here kept re-firing every
  // ~300ms — "one click, and it won't stop scrolling until the last row".
  final void Function(LogicalKeyboardKey key, bool isDown)? onHoldChanged;

  const _LoadMoreCardView({
    required this.focusNode,
    required this.width,
    required this.height,
    required this.isLoading,
    required this.onActivate,
    required this.onFocused,
    required this.onLeft,
    required this.onRight,
    this.onUp,
    this.onDown,
    this.onEsc,
    this.onHoldChanged,
  });

  @override
  State<_LoadMoreCardView> createState() => _LoadMoreCardViewState();
}

class _LoadMoreCardViewState extends State<_LoadMoreCardView> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final glyph = widget.width * 0.32;
    final labelFs = (widget.width * 0.11).clamp(11.0, 20.0);
    final focused = _focused;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) widget.onFocused();
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          if (!widget.isLoading) widget.onActivate();
          return KeyEventResult.handled;
        }
        // See _PosterCardView's onKeyEvent in card_carousel_block_view.dart
        // for why arrowUp/arrowDown report onHoldChanged on both press and
        // release instead of relying on native key-repeat.
        if (event is KeyUpEvent &&
            (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown)) {
          widget.onHoldChanged?.call(event.logicalKey, false);
          return KeyEventResult.ignored;
        }
        // Swallow held-arrow repeats when the parent drives its own
        // hold-repeat timer — see the matching note in
        // card_carousel_block_view.dart's _PosterCardView: an unhandled
        // KeyRepeatEvent bubbles to Flutter's default directional traversal
        // and ping-pongs focus between this row and the search bar,
        // flickering quick search while Up is held.
        if (event is KeyRepeatEvent &&
            widget.onHoldChanged != null &&
            (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown)) {
          return KeyEventResult.handled;
        }
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          widget.onLeft();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          widget.onRight();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          widget.onUp?.call();
          widget.onHoldChanged?.call(event.logicalKey, true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          widget.onDown?.call();
          widget.onHoldChanged?.call(event.logicalKey, true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          final cb = widget.onEsc ?? widget.onUp;
          cb?.call();
          return cb != null ? KeyEventResult.handled : KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: focused ? AppScale.focusScaleCard : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: AnimatedContainer(
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: focused ? AppTheme.primary : Colors.white12,
              width: 3,
            ),
            boxShadow:
                focused ? AppScale.focusGlow(AppTheme.primary, blur: 16) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.isLoading
                  ? PileusSpinner(size: glyph, color: Colors.white70)
                  : Icon(Icons.refresh_rounded,
                      size: glyph,
                      color:
                          Colors.white.withValues(alpha: focused ? 1.0 : 0.6)),
              SizedBox(height: widget.width * 0.08),
              Text(
                widget.isLoading ? 'Carico…' : 'Carica altri',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: focused ? 1.0 : 0.65),
                  fontSize: labelFs,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
