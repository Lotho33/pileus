import 'package:flutter/material.dart';

import '../../../core/theme/app_scale.dart';
import '../tv_focusable.dart';

/// D-pad-focusable action button for the bottom row of a settings dialog
/// (Annulla / Salva / Elimina, ...) — plain TextButton/ElevatedButton don't
/// reliably react to a TV remote's `select` key and show no focus cue,
/// unlike every other control in the app.
class DialogActionButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback? onPressed;
  final Color? primaryColor;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onUp;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  const DialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.primaryColor,
    this.autofocus = false,
    this.focusNode,
    this.onUp,
    this.onLeft,
    this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final accent = primaryColor ?? const Color(0xFF7C6AF7);
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: enabled ? onPressed : null,
      onUp: onUp,
      onLeft: onLeft,
      onRight: onRight,
      builder: (context, focused) => AnimatedContainer(
        // No focus scale-up here on purpose. The 1.04 AnimatedScale this
        // used to have — plus the primary's blurred glow — grew each
        // button past its own margin and visibly overlapped its neighbour
        // in the actions row (reported twice). Dialog buttons sit in a
        // tight fixed row with no reflow room; every other dialog-family
        // control (CwMenuButton) already cues focus with colour + a
        // contained border and no growth, so this matches that. Sizes go
        // through AppScale now so the buttons don't render tiny against a
        // scaled dialog on a 4K panel.
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        margin: EdgeInsets.symmetric(horizontal: AppScale.space(context, 8)),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 20),
            vertical: AppScale.space(context, 13)),
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.white12
              : primary
                  ? (focused
                      ? Color.lerp(accent, Colors.white, 0.18)!
                      : accent)
                  // Secondary: a faint resting fill so it reads as a button
                  // next to the filled primary, not bare text; a clear
                  // accent wash on focus.
                  : (focused
                      ? accent.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(AppScale.space(context, 10)),
          // Constant-width contained border (never a spreading glow — that's
          // what bled onto the neighbour). Secondary carries a faint one at
          // rest so its edges are visible; both brighten on focus.
          border: Border.all(
            color: primary
                ? (focused
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.transparent)
                : (focused ? accent : Colors.white24),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: !enabled
                ? Colors.white38
                : primary
                    ? Colors.white
                    : (focused ? Colors.white : Colors.white70),
            fontSize: AppScale.space(context, 15),
            fontWeight:
                primary || focused ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
