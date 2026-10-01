// Part of player_overlay.dart — split out for readability (plan 2e). The
// library file holds the shared imports and the PlayerOverlay widget;
// private identifiers are shared across all parts.
part of '../player_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Control buttons — all D-pad focusable: a FocusNode, select/enter activates,
// arrow keys delegate to the caller's onKey (row/chain navigation, see
// PlayerOverlayState/PlayerLiveOverlayState above), AppScale focus glow.
// ─────────────────────────────────────────────────────────────────────────────

/// Shared focus/activation chrome for a plain icon button (back/settings/
/// swap-source) — used by both PlayerOverlay and PlayerLiveOverlay.
class _FocusableIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onDown;

  const _FocusableIconButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    required this.focusNode,
    this.onLeft,
    this.onRight,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onLeft: onLeft,
      onRight: onRight,
      onDown: onDown,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? AppScale.focusScaleIcon : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: AnimatedContainer(
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Back/settings only had a scale + faint glow — hard to see over
            // bright video. A filled disc + ring makes the focused one
            // unmistakable, matching the play/pause button's treatment.
            color: focused
                ? AppTheme.primary.withValues(alpha: 0.28)
                : Colors.transparent,
            border: Border.all(
              color: focused ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: focused
                ? AppScale.focusGlow(AppTheme.primary, alpha: 0.5, blur: 18)
                : null,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool playing;
  final bool loading;
  final VoidCallback? onPressed;
  final FocusNode focusNode;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  // 0..1 buffer fill; when set (and loading) the centre spinner becomes a
  // determinate ring at this value instead of the indeterminate spin.
  final double? bufferProgress;
  const _PlayPauseButton({
    required this.playing,
    required this.onPressed,
    required this.focusNode,
    this.loading = false,
    this.bufferProgress,
    this.onLeft,
    this.onRight,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final sz = (h * 0.096).clamp(72.0, 120.0);
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onLeft: onLeft,
      onRight: onRight,
      onUp: onUp,
      onDown: onDown,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? AppScale.focusScaleIcon : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: loading ? 0.08 : 0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: focused ? AppTheme.primary : Colors.white30, width: 2),
            boxShadow: focused ? AppScale.focusGlow(AppTheme.primary) : null,
          ),
          // Loading is one of this button's own states, not a separate
          // overlay on top of it — swapping the icon for a spinner here
          // (instead of just disabling onActivate) is what actually tells
          // the user *why* pressing it right now won't do anything.
          child: loading
              ? Padding(
                  padding: EdgeInsets.all(sz * 0.28),
                  // Fills exactly what the padding above leaves inside this
                  // button's own sz×sz footprint — not AppScale.spinnerS/L,
                  // which are sized off screen height, not this specific
                  // button.
                  child: PileusSpinner(
                      size: sz * 0.44,
                      color: Colors.white70,
                      value: bufferProgress),
                )
              : Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: sz * 0.62,
                ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final FocusNode focusNode;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  const _SkipButton({
    required this.icon,
    required this.onPressed,
    required this.focusNode,
    this.onLeft,
    this.onRight,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final sz = (h * 0.074).clamp(56.0, 96.0);
    final disabled = onPressed == null;
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onLeft: onLeft,
      onRight: onRight,
      onUp: onUp,
      onDown: onDown,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? AppScale.focusScaleIcon : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            color: Colors.white
                .withValues(alpha: disabled ? 0.06 : (focused ? 0.2 : 0.1)),
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  focused && !disabled ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: focused && !disabled
                ? AppScale.focusGlow(AppTheme.primary)
                : null,
          ),
          child: Icon(icon,
              color: Colors.white.withValues(alpha: disabled ? 0.35 : 1),
              size: sz * 0.60),
        ),
      ),
    );
  }
}

class _NavEpisodeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final FocusNode focusNode;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  const _NavEpisodeButton({
    required this.icon,
    required this.focusNode,
    this.onPressed,
    this.onLeft,
    this.onRight,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final h = MediaQuery.sizeOf(context).height;
    final sz = (h * 0.063).clamp(48.0, 80.0);
    return TvFocusable(
      focusNode: focusNode,
      // A disabled nav button (no prev/next episode) still sits in the
      // chain — skip past it rather than letting focus land somewhere with
      // no visible activation.
      canRequestFocus: enabled,
      onActivate: enabled ? onPressed : null,
      onLeft: onLeft,
      onRight: onRight,
      onUp: onUp,
      onDown: onDown,
      builder: (context, focused) => AnimatedScale(
        scale: focused ? AppScale.focusScaleIcon : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            color: Colors.white
                .withValues(alpha: enabled ? (focused ? 0.22 : 0.12) : 0.04),
            shape: BoxShape.circle,
            border: Border.all(
              color: focused ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: focused ? AppScale.focusGlow(AppTheme.primary) : null,
          ),
          child: Icon(icon,
              color: enabled ? Colors.white : Colors.white24, size: sz * 0.59),
        ),
      ),
    );
  }
}
