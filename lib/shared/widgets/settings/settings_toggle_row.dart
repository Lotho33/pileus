import 'package:flutter/material.dart';

import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../tv_focusable.dart';

/// A focusable label + Switch row, styled like the toggle already used in
/// player_settings_panel.dart's subtitle-background switch.
class SettingsToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final FocusNode? focusNode;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;

  const SettingsToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.onFocusUp,
    this.onFocusDown,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: () => onChanged(!value),
      onUp: onFocusUp,
      onDown: onFocusDown,
      // Same scale + glow idiom as SettingsNavRow / the catalog cards.
      builder: (context, focused) => AnimatedScale(
        scale: focused ? AppScale.focusScaleRow : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: AnimatedContainer(
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          margin: EdgeInsets.symmetric(
              horizontal: AppScale.space(context, 16), vertical: AppScale.space(context, 4)),
          padding: EdgeInsets.symmetric(
              horizontal: AppScale.space(context, 24), vertical: AppScale.space(context, 20)),
          decoration: BoxDecoration(
            color: focused ? AppTheme.primary.withValues(alpha: 0.18) : AppTheme.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: focused ? AppScale.focusGlow(AppTheme.primary) : const [],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: focused ? Colors.white : AppTheme.textMid,
                    fontSize: AppScale.label(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? Colors.white : AppTheme.textLow),
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? AppTheme.primary : Colors.white12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
