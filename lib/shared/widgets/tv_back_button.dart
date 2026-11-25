// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_scale.dart';
import '../../core/theme/app_theme.dart';
import 'tv_focusable.dart';

/// The square "back" button of the TV pages (Impostazioni, La mia lista,
/// Calendario): an arrow in a rounded square, accent fill and glow when
/// focused. Back/Escape on it goes back too.
class TvBackButton extends StatelessWidget {
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final VoidCallback? onFocusDown;
  final bool autofocus;

  const TvBackButton({
    super.key,
    this.focusNode,
    required this.onTap,
    this.onFocusDown,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onTap,
      onEsc: onTap,
      onDown: onFocusDown,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? AppScale.focusScaleIcon : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: AnimatedContainer(
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          padding: EdgeInsets.all(AppScale.space(context, 10)),
          decoration: BoxDecoration(
            color: focused
                ? AppTheme.primary.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow:
                focused ? AppScale.focusGlow(AppTheme.primary, blur: 14) : null,
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: Colors.white.withValues(alpha: focused ? 1.0 : 0.7),
            size: AppScale.iconM(context),
          ),
        ),
      ),
    );
  }
}
