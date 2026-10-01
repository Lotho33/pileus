// Part of series_page_layout.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the _dmax helper and the public
// AnimeLayout / SeriesLayout entry points; private identifiers are shared
// across all parts.
part of '../series_page_layout.dart';

// ── Season pill ───────────────────────────────────────────────────────────────

class _SeasonPill extends StatefulWidget {
  final String label;
  final bool selected;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onDown;
  final VoidCallback? onFocused;

  const _SeasonPill({
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    this.autofocus = false,
    this.onLeft,
    this.onRight,
    this.onDown,
    this.onFocused,
  });

  @override
  State<_SeasonPill> createState() => _SeasonPillState();
}

class _SeasonPillState extends State<_SeasonPill> {
  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (v) {
        if (v) widget.onFocused?.call();
      },
      onActivate: widget.onTap,
      onLeft: widget.onLeft,
      onRight: widget.onRight,
      onDown: widget.onDown,
      builder: (context, focused) {
        final sh = MediaQuery.sizeOf(context).height;
        final pillFs = (sh * (18.0 / 1080.0)).clamp(12.0, 36.0);
        final hPad = (sh * (22.0 / 1080.0)).clamp(12.0, 44.0);
        final vPad = (sh * (10.0 / 1080.0)).clamp(6.0, 20.0);
        // Width is reserved at the SELECTED (larger) font size for both
        // states and stays fixed across the selection toggle — otherwise
        // the pill's own layout width animates along with its font size,
        // reflowing every pill after it in the horizontal list (visible as
        // a small drift of whichever pill you're navigating TO, only when
        // a pill BEFORE it is the one shrinking — i.e. only going to the
        // next season, never back to a previous one).
        final tp = TextPainter(
          text: TextSpan(
            text: widget.label,
            style:
                TextStyle(fontSize: pillFs * 1.1, fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final pillW = tp.width + hPad * 2;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: pillW,
          padding: EdgeInsets.symmetric(vertical: vPad),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primary
                : focused
                    ? AppTheme.primary.withValues(alpha: 0.30)
                    : AppTheme.surface2.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: widget.selected || focused
                  ? AppTheme.primary
                  : AppTheme.textHigh.withValues(alpha: 0.30),
              width: widget.selected ? 0 : 1.5,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              color: widget.selected
                  ? AppTheme.textHigh
                  : (focused ? AppTheme.textHigh : AppTheme.textMid),
              // A visible size bump on top of the existing weight/color
              // change, not just heavier-but-same-size text — animated
              // via AnimatedDefaultTextStyle so it doesn't jump.
              fontSize: widget.selected ? pillFs * 1.1 : pillFs,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
