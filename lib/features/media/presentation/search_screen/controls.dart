// Part of search_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the ratio/threshold constants and
// the public SearchScreen entry point; private identifiers are shared across
// all parts.
part of '../search_screen.dart';


// ─────────────────────────────────────────────────────────────────────────────

// Shown only in the brief moment before the on-open search resolves (or if
// it fails outright). No filter chips here — genre/order/year live in the
// filter panel (the toolbar button), not duplicated under the keyboard.
class _EmptyPrompt extends StatelessWidget {
  final String pluginName;

  const _EmptyPrompt({required this.pluginName});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, bc) {
      final hPad = bc.maxWidth * _rSrHPad;
      return Padding(
        padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 32),
        child: Row(children: [
          Icon(Icons.search_rounded,
              size: AppScale.space(context, 28),
              color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Cerca in $pluginName',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: AppScale.space(context, 17)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );
    });
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onRight;
  final VoidCallback? onDown;
  const _IconBtn({
    required this.icon,
    required this.size,
    required this.onTap,
    this.focusNode,
    this.onRight,
    this.onDown,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: widget.focusNode,
      onActivate: widget.onTap,
      onRight: widget.onRight,
      onDown: widget.onDown,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.all(widget.size * 0.50),
        decoration: BoxDecoration(
          color: focused
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(widget.icon,
            size: widget.size, color: Colors.white.withValues(alpha: 0.8)),
      ),
    );
  }
}

// ─── Filter button ────────────────────────────────────────────────────────────

class _FilterBtn extends StatefulWidget {
  final double barH;
  final int activeCount;
  final VoidCallback onTap;
  final bool enabled;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateLeft;
  final VoidCallback? onNavigateDown;
  const _FilterBtn({
    required this.barH,
    required this.activeCount,
    required this.onTap,
    this.enabled = true,
    this.focusNode,
    this.onNavigateLeft,
    this.onNavigateDown,
  });
  @override
  State<_FilterBtn> createState() => _FilterBtnState();
}

class _FilterBtnState extends State<_FilterBtn> {
  @override
  Widget build(BuildContext context) {
    final hasActive = widget.activeCount > 0;
    // Kept in the toolbar even when the plugin has no filters (stable
    // layout), just not focusable and dimmed.
    if (!widget.enabled) {
      return Opacity(
        opacity: 0.35,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: widget.barH * 0.30, vertical: widget.barH * 0.24),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(Icons.tune_rounded,
              size: widget.barH * 0.32, color: AppTheme.textMid),
        ),
      );
    }
    return TvFocusable(
      focusNode: widget.focusNode,
      onActivate: widget.onTap,
      onLeft: widget.onNavigateLeft,
      onDown: widget.onNavigateDown,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
            horizontal: widget.barH * 0.30, vertical: widget.barH * 0.24),
        decoration: BoxDecoration(
          color: hasActive
              ? _kFocusColor.withValues(alpha: focused ? 0.5 : 0.28)
              : (focused
                  ? _kFocusColor.withValues(alpha: 0.16)
                  : AppTheme.surface2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: focused
                ? _kFocusColor
                : (hasActive
                    ? _kFocusColor.withValues(alpha: 0.6)
                    : AppTheme.border),
            width: focused ? 2 : 1,
          ),
          boxShadow: focused ? AppScale.focusGlow(_kFocusColor) : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded,
                size: widget.barH * 0.32,
                color: focused || hasActive
                    ? AppTheme.textHigh
                    : AppTheme.textMid),
            if (hasActive) ...[
              SizedBox(width: widget.barH * 0.10),
              Text(
                '${widget.activeCount}',
                style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: widget.barH * 0.26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Active filter chip ───────────────────────────────────────────────────────

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 12),
          vertical: AppScale.space(context, 6)),
      decoration: BoxDecoration(
        color: _kFocusColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kFocusColor.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: AppScale.caption(context),
                  fontWeight: FontWeight.w500)),
          SizedBox(width: AppScale.space(context, 6)),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: AppScale.caption(context), color: AppTheme.textMid),
          ),
        ],
      ),
    );
  }
}

