import 'package:flutter/material.dart';

import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/tv_focusable.dart';

class SkipIntroButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onSkip;
  final VoidCallback onDismiss;
  // Up off either button hands focus back to the player overlay, so the user
  // isn't stranded on the floating Skip-intro button once they land on it.
  final VoidCallback? onExitUp;

  const SkipIntroButton({
    super.key,
    required this.label,
    required this.onSkip,
    required this.onDismiss,
    this.icon = Icons.fast_forward_rounded,
    this.onExitUp,
  });

  @override
  State<SkipIntroButton> createState() => SkipIntroButtonState();
}

class SkipIntroButtonState extends State<SkipIntroButton> {
  final _skipFn = FocusNode();
  final _dismissFn = FocusNode();

  // autofocus alone is a no-op when this mounts while another node in the
  // same FocusScope (the player overlay's controls) already holds real
  // focus — same idiom as PlayerSettingsPanelState.requestInitialFocus(),
  // called explicitly by playback_screen.dart right after this button
  // first appears.
  void requestInitialFocus() => _skipFn.requestFocus();

  @override
  void dispose() {
    _skipFn.dispose();
    _dismissFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TvFocusable(
          focusNode: _skipFn,
          // Timed prompt — needs to be reachable the instant it appears.
          autofocus: true,
          onActivate: widget.onSkip,
          onUp: widget.onExitUp,
          onRight: () => _dismissFn.requestFocus(),
          builder: (context, focused) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
                horizontal: AppScale.space(context, 24),
                vertical: AppScale.space(context, 14)),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: focused ? AppTheme.primary : Colors.white54,
                  width: 1.5),
              boxShadow: focused ? AppScale.focusGlow(AppTheme.primary) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon,
                    color: Colors.white, size: AppScale.space(context, 22)),
                SizedBox(width: AppScale.space(context, 10)),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppScale.space(context, 17),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: AppScale.space(context, 8)),
        TvFocusable(
          focusNode: _dismissFn,
          onActivate: widget.onDismiss,
          onUp: widget.onExitUp,
          onLeft: () => _skipFn.requestFocus(),
          builder: (context, focused) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.all(AppScale.space(context, 10)),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                  color: focused ? AppTheme.primary : Colors.white30),
              boxShadow: focused ? AppScale.focusGlow(AppTheme.primary) : null,
            ),
            child: Icon(Icons.close_rounded,
                color: Colors.white54, size: AppScale.space(context, 18)),
          ),
        ),
      ],
    );
  }
}
