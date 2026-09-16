// Part of card_carousel_block_view.dart — split out for readability (plan
// 2e). The library file holds the shared imports, the baseline ratio consts
// and the public API (CardCarouselInteraction, CarouselLoadMore,
// CardCarouselBlockView); private identifiers are shared across all parts.
part of '../card_carousel_block_view.dart';

// ── poster card — fixed-size card for _FixedCarouselView ───────────────────

class _PosterCardView extends StatefulWidget {
  final FocusNode focusNode;
  final SduiCardItem item;
  final double width;
  final double height;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onFocused;
  final VoidCallback? onLeft;
  // Left while the key is *held* (repeat) — steps card-to-card but, unlike
  // onLeft, never opens the side nav at the first card. Falls back to onLeft
  // when a host doesn't distinguish the two.
  final VoidCallback? onLeftRepeat;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  // Distinct from onUp — Back/Escape used to reuse onUp, which on the
  // topmost row means "focus the search bar", so pressing Back from any
  // card in that row silently opened search instead of the side nav every
  // TV app trains a user to expect Back to reach. Wired to the row's
  // onOpenNav directly (see the carousel state's call sites) so Back
  // behaves the same regardless of which row/card it's pressed from.
  final VoidCallback? onEsc;
  // Fired on every KeyDownEvent/KeyUpEvent for arrowUp/arrowDown, alongside
  // the single-step onUp/onDown above — see
  // series_page_layout.dart's _onEpisodeHoldChanged for why (this row's own
  // parent needs to drive its own hold-repeat timer for row-to-row
  // switching, and needs to know when the key is actually released).
  final void Function(LogicalKeyboardKey key, bool isDown)? onHoldChanged;

  const _PosterCardView({
    required this.focusNode,
    required this.item,
    required this.width,
    required this.height,
    required this.onTap,
    this.onLongPress,
    required this.onFocused,
    this.onLeft,
    this.onLeftRepeat,
    this.onRight,
    this.onUp,
    this.onDown,
    this.onEsc,
    this.onHoldChanged,
  });

  @override
  State<_PosterCardView> createState() => _PosterCardViewState();
}

class _PosterCardViewState extends State<_PosterCardView> {
  bool _focused = false;
  bool _selectHeld = false;
  bool _contextMenuShown = false;
  Timer? _longPressTimer;
  Timer? _tapTimer;
  final _leftGate = HeldKeyGate();

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _tapTimer?.cancel();
    _leftGate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) widget.onFocused();
      },
      onKeyEvent: (node, event) {
        final isOk = event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter;
        if (isOk) {
          if (event is KeyDownEvent) {
            // Cancel any pending debounced tap (synthetic X11 repeat sends rapid
            // KeyDown+KeyUp pairs; a new KeyDown arriving cancels the tap).
            _tapTimer?.cancel();
            _tapTimer = null;
            if (!_selectHeld) {
              _selectHeld = true;
              _contextMenuShown = false;
              _longPressTimer?.cancel();
              _longPressTimer = Timer(const Duration(milliseconds: 700), () {
                if (!mounted) return;
                _contextMenuShown = true;
                widget.onLongPress?.call();
              });
            }
            return KeyEventResult.handled;
          }
          // True OS-level repeat (TV remotes): fire long press immediately.
          if (event is KeyRepeatEvent && _selectHeld && !_contextMenuShown) {
            _tapTimer?.cancel();
            _tapTimer = null;
            _longPressTimer?.cancel();
            _longPressTimer = null;
            _contextMenuShown = true;
            widget.onLongPress?.call();
            return KeyEventResult.handled;
          }
          if (event is KeyUpEvent && _selectHeld) {
            if (!_contextMenuShown) {
              // Debounce: wait 60ms before confirming tap. If a new KeyDown
              // arrives within that window (synthetic repeat), cancel the tap.
              _tapTimer?.cancel();
              _tapTimer = Timer(const Duration(milliseconds: 60), () {
                if (!mounted) return;
                _longPressTimer?.cancel();
                _longPressTimer = null;
                widget.onTap();
                _selectHeld = false;
                _contextMenuShown = false;
              });
            } else {
              _longPressTimer?.cancel();
              _longPressTimer = null;
              _selectHeld = false;
              _contextMenuShown = false;
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }
        // Release of a held Up/Down — reported regardless of KeyDownEvent
        // gating below, so whoever's driving a hold-repeat timer off
        // onHoldChanged finds out even though this card no longer needs to
        // *act* on the key itself.
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
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          // Falls back to onUp when a host hasn't opted into onEsc — keeps
          // existing hosts (e.g. search results, where "back" landing on
          // the search bar via onUp is already correct) unchanged.
          (widget.onEsc ?? widget.onUp)?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _focused ? 1.07 : 1.0,
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          child: AnimatedContainer(
            duration: AppScale.focusDuration,
            curve: AppScale.focusCurve,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _focused ? AppTheme.primary : Colors.transparent,
                width: 3,
              ),
              // Focus cue is the border + scale; no blurred glow (see
              // AppScale.focusGlow).
              boxShadow: const [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.item.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          // Web-only, no-op on every other platform — see image_sizing.dart's
                          // "ImageRenderMethodForWeb.HttpGet" section for why every
                          // CachedNetworkImage call site in the app sets this.
                          imageRenderMethodForWeb:
                              ImageRenderMethodForWeb.HttpGet,
                          imageUrl: posterSrc(widget.item.imageUrl,
                              cacheWidthFor(context, widget.width),
                              proxy: true),
                          fit: BoxFit.cover,
                          memCacheWidth: cacheWidthFor(context, widget.width),
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) =>
                              const ColoredBox(color: AppTheme.surface2),
                          errorWidget: (_, __, ___) =>
                              _PosterFallback(title: widget.item.title),
                        )
                      : _PosterFallback(title: widget.item.title),
                  ..._langBadge(widget.item.lang),
                  ..._subtypeBadge(widget.item.subtype),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final String title;
  const _PosterFallback({required this.title});
  @override
  Widget build(BuildContext context) => Container(
        color: AppTheme.surface2,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Text(title,
            style: const TextStyle(color: AppTheme.textLow, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
      );
}

// ── language badge — top-right ITA/JAP pill, poster variant only ───────────

List<Widget> _langBadge(String lang) {
  if (lang == 'both' || lang.isEmpty) return const [];
  final label = lang == 'ita' ? 'ITA' : 'JAP';
  final color =
      lang == 'ita' ? const Color(0xFF38bdf8) : const Color(0xFFf97316);
  return [
    Positioned(
      top: 8,
      right: 8,
      child: _StatusPill(label: label, color: color),
    ),
  ];
}

// ── subtype badge — top-left Film/OVA/ONA/Special/Music/Short pill ─────────

List<Widget> _subtypeBadge(String subtype) {
  final label = switch (subtype) {
    'movie' => 'Film',
    'ova' => 'OVA',
    'ona' => 'ONA',
    'special' => 'Special',
    'music' => 'Music',
    'tv-short' => 'Short',
    _ => '',
  };
  if (label.isEmpty) return const [];
  return [
    Positioned(
      top: 8,
      left: 8,
      child: _StatusPill(label: label, color: const Color(0xFFa78bfa)),
    ),
  ];
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final fs = (sh * (10.0 / 1080.0)).clamp(8.0, 26.0);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: sh * (6.0 / 1080.0), vertical: sh * (2.0 / 1080.0)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: Colors.white, fontSize: fs, fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
