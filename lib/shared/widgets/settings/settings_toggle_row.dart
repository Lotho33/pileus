import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../tv_focusable.dart';
import 'settings_card.dart';

/// A focusable label + Switch row, in the shared [SettingsCard] look.
class SettingsToggleRow extends StatelessWidget {
  final String label;
  // Inside the card, under the label.
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChanged;
  final FocusNode? focusNode;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;

  const SettingsToggleRow({
    super.key,
    required this.label,
    this.caption,
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
      // On/off for screen readers (merged into the row by TvFocusable).
      builder: (context, focused) => Semantics(
        toggled: value,
        child: SettingsCard(
          focused: focused,
          label: label,
          caption: caption,
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppTheme.textLow),
            trackColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppTheme.primary
                    : Colors.white12),
          ),
        ),
      ),
    );
  }
}
