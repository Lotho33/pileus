// Part of player_overlay.dart — split out for readability (plan 2e). The
// library file holds the shared imports and the PlayerOverlay widget;
// private identifiers are shared across all parts.
part of '../player_overlay.dart';

// What a screen reader says for the icon-only player buttons below.
final _iconLabels = <IconData, String>{
  Icons.arrow_back_ios_new: 'Indietro',
  Icons.settings_rounded: 'Impostazioni di riproduzione',
  Icons.skip_previous_rounded: 'Episodio precedente',
  Icons.skip_next_rounded: 'Episodio successivo',
  Icons.replay_10: 'Indietro di 10 secondi',
  Icons.forward_10: 'Avanti di 10 secondi',
  Icons.swap_horiz_rounded: 'Cambia sorgente',
  Icons.restart_alt_rounded: 'Riavvia la diretta',
};

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

  const _FocusableIconButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    required this.focusNode,
    this.onLeft,
    this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      semanticLabel: _iconLabels[icon],
      focusNode: focusNode,
      onActivate: onPressed,
      onLeft: onLeft,
      onRight: onRight,
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

/// A round control in the bottom row — the Vega OS player's ControlButton
/// (pileus-vega PlayerScreen): 72/1080 of the screen tall, a light 12% disc;
/// focused, a solid off-white disc with a dark glyph and a 1.08 scale. An
/// icon, a short label ("−10"), or both. Disabled (no previous/next episode):
/// dimmed and skipped by focus.
class _ShakaButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final FocusNode focusNode;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  const _ShakaButton({
    this.icon,
    this.label,
    required this.semanticLabel,
    required this.onPressed,
    required this.focusNode,
    this.onLeft,
    this.onRight,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final sh = MediaQuery.sizeOf(context).height;
    final d = sh * (72 / 1080);
    return TvFocusable(
      semanticLabel: semanticLabel,
      focusNode: focusNode,
      canRequestFocus: enabled,
      onActivate: onPressed,
      onLeft: onLeft,
      onRight: onRight,
      onUp: onUp,
      onDown: onDown,
      builder: (context, focused) {
        final fg = focused ? AppTheme.bg : AppTheme.textHigh;
        return AnimatedScale(
          scale: focused ? 1.08 : 1.0,
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.35,
            duration: AppScale.focusDuration,
            child: AnimatedContainer(
              duration: AppScale.focusDuration,
              curve: AppScale.focusCurve,
              height: d,
              constraints: BoxConstraints(minWidth: d),
              padding: label != null
                  ? EdgeInsets.symmetric(horizontal: sh * (28 / 1080))
                  : null,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: focused
                    ? AppTheme.textHigh
                    : AppTheme.textHigh.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(d / 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Icon(icon, size: sh * (36 / 1080), color: fg),
                  if (icon != null && label != null)
                    SizedBox(width: sh * (10 / 1080)),
                  if (label != null)
                    Text(label!,
                        style: TextStyle(
                          color: fg,
                          fontSize: sh * (22 / 1080),
                          fontWeight: FontWeight.w600,
                        )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
