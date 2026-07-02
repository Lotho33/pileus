import 'package:flutter/material.dart';

import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../tv_focusable.dart';

/// A tappable settings row (hub entry, profile action, etc) — purple
/// focus border/glow, matching the app's dominant TV-focus convention
/// (profile_selection_screen.dart, _PluginNavItem in home_screen.dart).
class SettingsNavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final VoidCallback? onEsc;

  const SettingsNavRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.onFocusUp,
    this.onFocusDown,
    this.onEsc,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: enabled ? onTap : null,
      onUp: onFocusUp,
      onDown: onFocusDown,
      onEsc: onEsc,
      // D-pad focus can land on a row below the fold — nothing scrolls the
      // enclosing ListView to follow it on its own (the same gap fixed for
      // the plugin nav list, episode list, etc). No-op when this row isn't
      // inside a Scrollable (some hosts lay a few rows out in a plain Column).
      onFocusChange: (focused) {
        if (!focused || !context.mounted) return;
        if (Scrollable.maybeOf(context) == null) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      },
      builder: (context, focused) {
        final active = enabled && focused;
        return AnimatedScale(
          // Scale + glow on focus, same idiom as the catalog cards in
          // card_carousel_block_view.dart — see AppScale.focusScaleRow's doc
          // for why a row uses a subtler scale than a card.
          scale: active ? AppScale.focusScaleRow : 1.0,
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          child: AnimatedContainer(
            duration: AppScale.focusDuration,
            curve: AppScale.focusCurve,
            margin: EdgeInsets.symmetric(
                horizontal: AppScale.space(context, 16),
                vertical: AppScale.space(context, 4)),
            padding: EdgeInsets.symmetric(
                horizontal: AppScale.space(context, 24),
                vertical: AppScale.space(context, 20)),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primary.withValues(alpha: 0.18)
                  : AppTheme.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow:
                  active ? AppScale.focusGlow(AppTheme.primary) : const [],
            ),
            child: Row(
              children: [
                // A bare icon floating in the row read as flat next to the
                // rest of the app's TV chrome (poster cards, focus chips —
                // everything else has some kind of container/background
                // behind its glyph). A small rounded chip gives it the same
                // visual weight as a settings row typically has elsewhere
                // (Android/iOS system settings both do this).
                AnimatedContainer(
                  duration: AppScale.focusDuration,
                  curve: AppScale.focusCurve,
                  padding: EdgeInsets.all(AppScale.space(context, 8)),
                  decoration: BoxDecoration(
                    color: !enabled
                        ? Colors.white.withValues(alpha: 0.04)
                        : active
                            ? AppTheme.primary.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      size: AppScale.iconL(context),
                      color: enabled
                          ? (active ? Colors.white : AppTheme.textMid)
                          : AppTheme.textLow),
                ),
                SizedBox(width: AppScale.space(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: enabled
                              ? (active ? Colors.white : AppTheme.textMid)
                              : AppTheme.textLow,
                          fontSize: AppScale.label(context),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: AppScale.space(context, 3)),
                        Text(
                          subtitle!,
                          style: TextStyle(
                              color: AppTheme.textLow,
                              fontSize: AppScale.caption(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded,
                      size: AppScale.iconM(context),
                      color: enabled
                          ? AppTheme.textLow
                          : AppTheme.textLow.withValues(alpha: 0.4)),
              ],
            ),
          ),
        );
      },
    );
  }
}
