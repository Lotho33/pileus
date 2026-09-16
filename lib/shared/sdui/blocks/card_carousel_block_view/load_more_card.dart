// Part of card_carousel_block_view.dart — split out for readability (plan
// 2e). The library file holds the shared imports, the baseline ratio consts
// and the public API (CardCarouselInteraction, CarouselLoadMore,
// CardCarouselBlockView); private identifiers are shared across all parts.
part of '../card_carousel_block_view.dart';

// ── trailing "load more" card ──────────────────────────────────────────────
// Same footprint as a poster card so it sits in the row as its last slot and
// scrolls/focuses with everything else. Icon + label rather than art; a
// spinner while a page is in flight.
class _LoadMoreCardView extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final glyph = width * 0.32;
    final labelFs = (width * 0.11).clamp(11.0, 20.0);
    return TvFocusable(
      focusNode: focusNode,
      onActivate: isLoading ? null : onActivate,
      onLeft: onLeft,
      onRight: onRight,
      onUp: onUp,
      onDown: onDown,
      onEsc: onEsc,
      onFocusChange: (f) {
        if (f) onFocused();
      },
      builder: (context, focused) => AnimatedScale(
        scale: focused ? AppScale.focusScaleCard : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: AnimatedContainer(
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          width: width,
          height: height,
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
              isLoading
                  ? PileusSpinner(size: glyph, color: Colors.white70)
                  : Icon(Icons.refresh_rounded,
                      size: glyph,
                      color:
                          Colors.white.withValues(alpha: focused ? 1.0 : 0.6)),
              SizedBox(height: width * 0.08),
              Text(
                isLoading ? 'Carico…' : 'Carica altri',
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
