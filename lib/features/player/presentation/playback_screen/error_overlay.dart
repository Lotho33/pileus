// Part of playback_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports and the PlaybackScreen entry point
// (resolves PlaybackArgs from the GoRouter extra); private identifiers are
// shared across all parts. _PlaybackViewState is still one large class —
// candidate for a real refactor (D-pad / resume / skip mixins) later.
part of '../playback_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// In-player error overlay (sostituisce context.pop() su errore)
// ─────────────────────────────────────────────────────────────────────────────

class _InPlayerErrorOverlay extends StatefulWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const _InPlayerErrorOverlay({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onExit,
  });

  @override
  State<_InPlayerErrorOverlay> createState() => _InPlayerErrorOverlayState();
}

class _InPlayerErrorOverlayState extends State<_InPlayerErrorOverlay> {
  final _retryFn = FocusNode();

  // Same idiom as SkipIntroButtonState/_NextEpisodeBannerState: the Scaffold
  // body's root Focus(autofocus:true) already holds real focus in this
  // scope by the time an error can surface, so the Riprova button's own
  // `autofocus` is a no-op — a TV remote had no way to reach this overlay
  // without an explicit push once it's mounted (reported 2026-09-11).
  void requestInitialFocus() => _retryFn.requestFocus();

  @override
  void dispose() {
    _retryFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: EdgeInsets.all(AppScale.space(context, 40)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: AppScale.space(context, 56)),
                SizedBox(height: AppScale.space(context, 20)),
                Text(
                  'Stream non disponibile',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: AppScale.space(context, 22),
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppScale.space(context, 12)),
                Text(
                  widget.error,
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: AppScale.space(context, 14),
                      height: 1.5),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: AppScale.space(context, 32)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ErrorButton(
                      focusNode: _retryFn,
                      label: 'Riprova',
                      icon: Icons.refresh_rounded,
                      primary: true,
                      onTap: widget.onRetry,
                    ),
                    SizedBox(width: AppScale.space(context, 16)),
                    _ErrorButton(
                      label: 'Esci',
                      icon: Icons.arrow_back_rounded,
                      primary: false,
                      onTap: widget.onExit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  const _ErrorButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: primary,
      onActivate: onTap,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 24),
            vertical: AppScale.space(context, 14)),
        decoration: BoxDecoration(
          color: primary
              ? (focused ? Colors.white : Colors.white.withValues(alpha: 0.9))
              : (focused
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(10),
          border: primary
              ? null
              : Border.all(color: focused ? Colors.white54 : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppScale.space(context, 18),
              color: primary ? Colors.black : Colors.white,
            ),
            SizedBox(width: AppScale.space(context, 8)),
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.black : Colors.white,
                fontSize: AppScale.space(context, 15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
