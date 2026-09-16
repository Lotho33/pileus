// Part of playback_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports and the PlaybackScreen entry point
// (resolves PlaybackArgs from the GoRouter extra); private identifiers are
// shared across all parts. _PlaybackViewState is still one large class —
// candidate for a real refactor (D-pad / resume / skip mixins) later.
part of '../playback_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Next episode countdown banner
// ─────────────────────────────────────────────────────────────────────────────

class _NextEpisodeBanner extends StatefulWidget {
  final int secsRemaining;
  final String? nextTitle;
  final VoidCallback onPlay;
  final VoidCallback onDismiss;

  const _NextEpisodeBanner({
    super.key,
    required this.secsRemaining,
    required this.onPlay,
    required this.onDismiss,
    this.nextTitle,
  });

  @override
  State<_NextEpisodeBanner> createState() => _NextEpisodeBannerState();
}

class _NextEpisodeBannerState extends State<_NextEpisodeBanner> {
  final _playFn = FocusNode();
  final _dismissFn = FocusNode();

  // Same idiom as SkipIntroButtonState.requestInitialFocus() — autofocus
  // alone is a no-op when the overlay already holds real focus.
  void requestInitialFocus() => _playFn.requestFocus();

  @override
  void dispose() {
    _playFn.dispose();
    _dismissFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Prossimo episodio in ${widget.secsRemaining}s',
            style: const TextStyle(
                color: Colors.white54, fontSize: 13, letterSpacing: 0.3),
          ),
          if (widget.nextTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.nextTitle!,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TvFocusable(
                focusNode: _playFn,
                autofocus: true,
                onActivate: widget.onPlay,
                onRight: () => _dismissFn.requestFocus(),
                builder: (context, focused) => AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: EdgeInsets.symmetric(
                      horizontal: AppScale.space(context, 20),
                      vertical: AppScale.space(context, 10)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow:
                        focused ? AppScale.focusGlow(AppTheme.primary) : null,
                    border: Border.all(
                        color: focused ? AppTheme.primary : Colors.transparent,
                        width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.skip_next_rounded,
                          color: Colors.black,
                          size: AppScale.space(context, 18)),
                      SizedBox(width: AppScale.space(context, 6)),
                      Text('Vai subito',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: AppScale.space(context, 14),
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: AppScale.space(context, 10)),
              TvFocusable(
                focusNode: _dismissFn,
                onActivate: widget.onDismiss,
                onLeft: () => _playFn.requestFocus(),
                builder: (context, focused) => AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: EdgeInsets.all(AppScale.space(context, 10)),
                  decoration: BoxDecoration(
                    color: focused
                        ? AppTheme.primary.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: focused ? AppTheme.primary : Colors.white24),
                    boxShadow:
                        focused ? AppScale.focusGlow(AppTheme.primary) : null,
                  ),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white54, size: AppScale.space(context, 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
