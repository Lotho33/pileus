// Part of card_carousel_block_view.dart — split out for readability (plan
// 2e). The library file holds the shared imports, the baseline ratio consts
// and the public API (CardCarouselInteraction, CarouselLoadMore,
// CardCarouselBlockView); private identifiers are shared across all parts.
part of '../card_carousel_block_view.dart';

// ── live card ────────────────────────────────────────────────────────────

class _LiveCardView extends StatefulWidget {
  final FocusNode? focusNode;
  final String title;
  final String posterUrl;
  final double width;
  final double height;
  final bool isActuallyLive;
  final String sportCat;
  final VoidCallback onTap;
  final VoidCallback? onFocused;
  final VoidCallback? onLeft;
  // See _PosterCardView.onLeftRepeat's doc — same reasoning.
  final VoidCallback? onLeftRepeat;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  // See _PosterCardView.onEsc's doc — same reasoning.
  final VoidCallback? onEsc;
  // See _PosterCardView.onHoldChanged's doc — same reasoning.
  final void Function(LogicalKeyboardKey key, bool isDown)? onHoldChanged;

  const _LiveCardView({
    required this.title,
    required this.posterUrl,
    required this.width,
    required this.height,
    required this.onTap,
    this.focusNode,
    this.isActuallyLive = false,
    this.sportCat = '',
    this.onFocused,
    this.onLeft,
    this.onLeftRepeat,
    this.onRight,
    this.onUp,
    this.onDown,
    this.onEsc,
    this.onHoldChanged,
  });

  @override
  State<_LiveCardView> createState() => _LiveCardViewState();
}

class _LiveCardViewState extends State<_LiveCardView> {
  bool _focused = false;
  final _leftGate = HeldKeyGate();

  @override
  void dispose() {
    _leftGate.dispose();
    super.dispose();
  }

  void _setFocus(bool v) {
    if (_focused == v) return;
    setState(() => _focused = v);
    if (v) widget.onFocused?.call();
  }

  @override
  Widget build(BuildContext context) {
    final accent = sportAccentColor(widget.sportCat);
    final hasSport = widget.sportCat.isNotEmpty;
    final sh = MediaQuery.sizeOf(context).height;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: _setFocus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        // See _PosterCardView's onKeyEvent above for the same KeyUpEvent
        // hold-release reporting.
        if (event is KeyUpEvent &&
            (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown)) {
          widget.onHoldChanged?.call(event.logicalKey, false);
          return KeyEventResult.ignored;
        }
        if (event is! KeyDownEvent) {
          // When a parent is driving its own Up/Down hold-repeat timer
          // (onHoldChanged is wired — the home carousels), swallow raw held
          // Up/Down KeyRepeatEvents: they're redundant with that timer, and
          // if left to bubble they reach Flutter's default directional focus
          // traversal, which jumps focus by screen geometry — near the top of
          // the home screen that ping-pongs between this row and the search
          // bar, flickering quick search open/closed for as long as Up is
          // held. Left/Right (no synthetic timer) and every context without
          // the timer (search results etc.) still let repeats bubble, so
          // default traversal keeps providing hold-to-scroll there.
          final k = event.logicalKey;
          // Feed the Left key-up into the gate so the next Left press reads
          // as fresh (see HeldKeyGate).
          if (event is KeyUpEvent && k == LogicalKeyboardKey.arrowLeft) {
            _leftGate.isRepeat(event);
            return KeyEventResult.ignored;
          }
          if (event is KeyRepeatEvent &&
              widget.onHoldChanged != null &&
              (k == LogicalKeyboardKey.arrowUp ||
                  k == LogicalKeyboardKey.arrowDown)) {
            return KeyEventResult.handled;
          }
          // Held Left/Right steps card-to-card through the carousel's own
          // index-based navigation, exactly like a single press — rather
          // than bubbling to Flutter's default directional traversal, which
          // walked focus onto other rows / the search bar near the windowed
          // edge, and only on remotes that emit KeyRepeatEvents (so held
          // horizontal scroll behaved differently device to device).
          if (event is KeyRepeatEvent && k == LogicalKeyboardKey.arrowLeft) {
            _leftGate.isRepeat(event); // a repeat by definition
            (widget.onLeftRepeat ?? widget.onLeft)?.call();
            return KeyEventResult.handled;
          }
          if (event is KeyRepeatEvent && k == LogicalKeyboardKey.arrowRight) {
            widget.onRight?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          // Fresh KeyDown → onLeft (may open the side nav on the first card);
          // a KeyDown that's really a held-key cascade → onLeftRepeat.
          final cb = _leftGate.isRepeat(event)
              ? (widget.onLeftRepeat ?? widget.onLeft)
              : widget.onLeft;
          cb?.call();
          return cb != null ? KeyEventResult.handled : KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          widget.onRight?.call();
          return widget.onRight != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          widget.onUp?.call();
          widget.onHoldChanged?.call(event.logicalKey, true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          widget.onDown?.call();
          widget.onHoldChanged?.call(event.logicalKey, true);
          return KeyEventResult
              .handled; // always consume — no stray focus traversal
        }
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          (widget.onEsc ?? widget.onUp)?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1.0,
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Image
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    child: widget.posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: posterSrc(widget.posterUrl,
                                cacheWidthFor(context, widget.width),
                                proxy: true),
                            fit: BoxFit.cover,
                            memCacheWidth: cacheWidthFor(context, widget.width),
                            fadeInDuration: Duration.zero,
                            placeholder: (_, __) => const _PosterSkeleton(),
                            errorWidget: (_, __, ___) =>
                                _LivePlaceholder(sportCat: widget.sportCat),
                          )
                        : _LivePlaceholder(sportCat: widget.sportCat),
                  ),
                ),
                // Bottom gradient
                const Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xD9000000)],
                          stops: [0.30, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Sport accent strip at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child:
                        SizedBox(height: 3, child: ColoredBox(color: accent)),
                  ),
                ),
                // Sport icon chip — top left
                if (hasSport)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Icon(sportIcon(widget.sportCat),
                          size: 18, color: Colors.white),
                    ),
                  ),
                // LIVE badge — top right
                if (widget.isActuallyLive)
                  const Positioned(top: 12, right: 12, child: _LiveBadge()),
                // Title
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (sh * (22.0 / 1080.0)).clamp(11.0, 30.0),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black)
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Focus border
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: AppScale.focusDuration,
                    curve: AppScale.focusCurve,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(
                        color: _focused
                            ? accent.withValues(alpha: 0.9)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.red, borderRadius: BorderRadius.circular(6)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 8),
          SizedBox(width: 5),
          Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

class _PosterSkeleton extends StatelessWidget {
  const _PosterSkeleton();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppTheme.surface2);
}

class _LivePlaceholder extends StatelessWidget {
  final String sportCat;
  const _LivePlaceholder({this.sportCat = ''});

  @override
  Widget build(BuildContext context) {
    final accent = sportAccentColor(sportCat);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.35),
            accent.withValues(alpha: 0.10)
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(sportIcon(sportCat),
            size: 56, color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }
}
