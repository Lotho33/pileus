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
  // Explicit node (not TvFocusable's own auto-created one) so _retryFn's
  // onRight below can request it directly — see this file's own doc on why
  // arrow keys otherwise never reach this button at all (the same root
  // cause fixed here for _TakeoverOverlay below): TvFocusable's
  // onLeft/onRight/onUp/onDown are opt-in per instance, and this screen's
  // own root Focus(onKeyEvent: _onKey) claims un-consumed left/right as a
  // ±10s seek before Flutter's own default directional traversal ever gets
  // a chance to run — so without wiring this explicitly, "Esci" was
  // reachable by touch/mouse only, never by D-pad.
  final _exitFn = FocusNode();

  // Same idiom as SkipIntroButtonState/_NextEpisodeBannerState: the Scaffold
  // body's root Focus(autofocus:true) already holds real focus in this
  // scope by the time an error can surface, so the Riprova button's own
  // `autofocus` is a no-op — a TV remote had no way to reach this overlay
  // without an explicit push once it's mounted.
  void requestInitialFocus() => _retryFn.requestFocus();

  @override
  void dispose() {
    _retryFn.dispose();
    _exitFn.dispose();
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
                      onRight: _exitFn.requestFocus,
                    ),
                    SizedBox(width: AppScale.space(context, 16)),
                    _ErrorButton(
                      focusNode: _exitFn,
                      label: 'Esci',
                      icon: Icons.arrow_back_rounded,
                      primary: false,
                      onTap: widget.onExit,
                      onLeft: _retryFn.requestFocus,
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

// ─────────────────────────────────────────────────────────────────────────────
// Playback taken over by another device (contract "One device playing per
// profile") — pre-play ABORTED ("Guarda qui"/"Annulla") and mid-playback
// take-over ("Riprendi qui"/"Esci") share this one overlay, only the
// message/labels differ; see _PlaybackViewState._onPlaybackTakenOver and its
// PlaybackPlayingElsewhere BlocListener branch.
// ─────────────────────────────────────────────────────────────────────────────

class _TakeoverPrompt {
  final String message;
  final String actionLabel;
  final String backLabel;
  final VoidCallback onAction;
  const _TakeoverPrompt({
    required this.message,
    required this.actionLabel,
    required this.backLabel,
    required this.onAction,
  });
}

class _TakeoverOverlay extends StatefulWidget {
  final _TakeoverPrompt prompt;
  final VoidCallback onBack;

  const _TakeoverOverlay({
    super.key,
    required this.prompt,
    required this.onBack,
  });

  @override
  State<_TakeoverOverlay> createState() => _TakeoverOverlayState();
}

class _TakeoverOverlayState extends State<_TakeoverOverlay> {
  final _actionFn = FocusNode();
  // See _InPlayerErrorOverlayState's identical field for why this needs to
  // be explicit rather than left to TvFocusable's own default (opt-in
  // onLeft/onRight, otherwise swallowed by this screen's root seek shortcut
  // before Flutter's own directional traversal ever runs).
  final _backFn = FocusNode();

  // Same idiom as _InPlayerErrorOverlayState — the Scaffold body's root
  // Focus(autofocus:true) already holds real focus by the time this can
  // show, so the action button's own `autofocus` is a no-op without an
  // explicit push once mounted.
  void requestInitialFocus() => _actionFn.requestFocus();

  @override
  void dispose() {
    _actionFn.dispose();
    _backFn.dispose();
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
                Icon(Icons.devices_rounded,
                    color: Colors.white70, size: AppScale.space(context, 56)),
                SizedBox(height: AppScale.space(context, 20)),
                Text(
                  widget.prompt.message,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: AppScale.space(context, 18),
                      fontWeight: FontWeight.w600,
                      height: 1.4),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppScale.space(context, 32)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ErrorButton(
                      focusNode: _actionFn,
                      label: widget.prompt.actionLabel,
                      icon: Icons.login_rounded,
                      primary: true,
                      onTap: widget.prompt.onAction,
                      onRight: _backFn.requestFocus,
                    ),
                    SizedBox(width: AppScale.space(context, 16)),
                    _ErrorButton(
                      focusNode: _backFn,
                      label: widget.prompt.backLabel,
                      icon: Icons.arrow_back_rounded,
                      primary: false,
                      onTap: widget.onBack,
                      onLeft: _actionFn.requestFocus,
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
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  const _ErrorButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
    this.focusNode,
    this.onLeft,
    this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: primary,
      onActivate: onTap,
      onLeft: onLeft,
      onRight: onRight,
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
