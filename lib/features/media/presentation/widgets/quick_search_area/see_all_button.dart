// Part of quick_search_area.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the two consts and the
// QuickSearchArea widget; private identifiers are shared across all parts.
part of '../quick_search_area.dart';

// ── "vedi tutti" (open full search) ─────────────────────────────────────
// Was a plain TextButton — tap-only, so a remote could never reach it (no
// Focus wrapper at all). Wired into the quick-search results row's
// onNavigateDown above so arrow-down from any result lands here.

class _SeeAllResultsButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final double fontSize;
  final VoidCallback onActivate;
  final VoidCallback? onNavigateUp;

  const _SeeAllResultsButton({
    required this.focusNode,
    required this.label,
    required this.fontSize,
    required this.onActivate,
    this.onNavigateUp,
  });

  @override
  State<_SeeAllResultsButton> createState() => _SeeAllResultsButtonState();
}

class _SeeAllResultsButtonState extends State<_SeeAllResultsButton> {
  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: widget.focusNode,
      onActivate: widget.onActivate,
      onUp: widget.onNavigateUp,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 10),
            vertical: AppScale.space(context, 4)),
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: focused ? AppTheme.primary : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded,
                size: AppScale.iconS(context),
                color: focused ? AppTheme.textHigh : Colors.white54),
            SizedBox(width: AppScale.space(context, 6)),
            Text(
              widget.label,
              style: TextStyle(
                color: focused
                    ? AppTheme.textHigh
                    : AppTheme.textHigh.withValues(alpha: 0.6),
                fontSize: widget.fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
