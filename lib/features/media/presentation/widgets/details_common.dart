import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/perf_profile.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/tv_focusable.dart';

// ── Details layout ratios — baseline 1920×1080 ──────────────────────────────
// Shared between details_screen.dart (_MovieLayout, _AnimeMovieLayout) and
// series_page_layout.dart (_SeriesPageLayout) — moved here (public) rather
// than left duplicated privately in each, since they're the same numbers.
const double detailsVPadRatio = 12 / 1080; // vertical padding top
const double detailsPosterWRatio = 340 / 1920; // poster column width (~17.7%)
const double detailsInfoWRatio =
    560 / 1920; // info+trama column width (series, ~29%)
const double detailsGapRatio = 24 / 1920; // gap between columns
const double detailsEpisodeTileHRatio = 100 / 1080; // episode tile height

// Small, reused-across-layouts pieces of details_screen.dart — first step
// of splitting that file per the design audit's file-size recommendation
// (§08), starting with the two widgets actually shared across multiple of
// its per-media-type layouts (Movie/Series/LiveEvent/...) rather than the
// many single-use ones, which stayed put to avoid churn for no reuse payoff.

/// Back-navigation pill shown top-left on every details layout.
class DetailsBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const DetailsBackButton({super.key, required this.onTap});

  @override
  State<DetailsBackButton> createState() => _DetailsBackButtonState();
}

class _DetailsBackButtonState extends State<DetailsBackButton> {
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return TvFocusable(
      onActivate: widget.onTap,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
            horizontal: sh * (18.0 / 1080.0), vertical: sh * (12.0 / 1080.0)),
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.textHigh.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused ? Colors.white54 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded,
                size: sh * (24.0 / 1080.0),
                color: focused ? AppTheme.textHigh : AppTheme.textMid),
            SizedBox(width: sh * (10.0 / 1080.0)),
            Text('Indietro',
                style: TextStyle(
                  color: focused ? AppTheme.textHigh : AppTheme.textMid,
                  fontSize: sh * (16.0 / 1080.0),
                )),
          ],
        ),
      ),
    );
  }
}

/// Fallback tile shown in place of a poster image that's missing or failed
/// to load — a title on a flat tinted background instead of a broken-image
/// icon or blank space.
class PlaceholderPoster extends StatelessWidget {
  final String title;
  const PlaceholderPoster({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return Container(
      color: const Color(0xFF1E1E2E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(title,
          style: TextStyle(
              color: AppTheme.textLow, fontSize: sh * (11.0 / 1080.0)),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis),
    );
  }
}

/// Play button shown inside episode/source-selection popups.
class PopupPlayButton extends StatefulWidget {
  final String label;
  final bool autofocus;
  final VoidCallback onTap;
  // Optional so a caller can wire D-pad navigation to/from this button (e.g.
  // Up from the first play button lands on the popup's close ✕).
  final FocusNode? focusNode;
  final VoidCallback? onUp;
  const PopupPlayButton({
    super.key,
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    this.onUp,
  });

  @override
  State<PopupPlayButton> createState() => _PopupPlayButtonState();
}

class _PopupPlayButtonState extends State<PopupPlayButton> {
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return TvFocusable(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onActivate: widget.onTap,
      onUp: widget.onUp,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: sh * (24.0 / 1080.0), vertical: sh * (12.0 / 1080.0)),
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.primary
              : AppTheme.textHigh.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused ? AppTheme.primary : Colors.white24,
            width: 1.5,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded,
                size: sh * (20.0 / 1080.0),
                color: focused ? AppTheme.textHigh : AppTheme.textMid),
            SizedBox(width: sh * (8.0 / 1080.0)),
            Text(
              widget.label,
              style: TextStyle(
                color: focused ? AppTheme.textHigh : AppTheme.textMid,
                fontSize: sh * (15.0 / 1080.0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular ✕ shown top-right inside episode / source-selection popups —
/// mirrors the live-event popup's own close affordance (see
/// live_event_popup.dart's `_CloseButton`) so the two read the same. D-pad
/// focusable; the popup's own Esc/Back still closes it regardless.
class PopupCloseButton extends StatelessWidget {
  final VoidCallback onClose;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onDown;
  const PopupCloseButton({
    super.key,
    required this.onClose,
    this.focusNode,
    this.autofocus = false,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final d = (sh * (40.0 / 1080.0)).clamp(22.0, 52.0);
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onClose,
      onEsc: onClose,
      onDown: onDown,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: focused ? Colors.white70 : Colors.white24),
        ),
        child: Icon(Icons.close_rounded, color: Colors.white, size: d * 0.55),
      ),
    );
  }
}

/// Fades [child]'s top and/or bottom edge based on [controller]'s *live*
/// scroll position — only faded while there's actually more content past
/// that edge, not a flat always-on gradient: at rest on a short plot (or
/// freshly opened, still at the top) nothing fades; scroll partway through
/// a long one and both edges fade (there's hidden text both above and
/// below); reach the very end and the bottom edge stops fading (nothing
/// left beneath it) while the top stays faded. Wrap whatever ClipRRect/
/// Container already bounds the scroll view — this only needs the
/// controller and repaints itself on every scroll tick via AnimatedBuilder.
class ScrollEdgeFade extends StatelessWidget {
  final ScrollController controller;
  final Widget child;
  // Fraction of the box's own height each fade spans.
  final double fadeExtent;
  const ScrollEdgeFade({
    super.key,
    required this.controller,
    required this.child,
    this.fadeExtent = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    // "Hardware modesto": a ShaderMask(dstIn) rebuilds its gradient shader
    // and forces an offscreen saveLayer on every scroll frame — a real
    // per-frame GPU tax while the user scrolls the details list. The edge
    // fade is purely cosmetic; drop it entirely on weak boxes.
    if (lowPowerUi) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasClients = controller.hasClients;
        final atTop = !hasClients || controller.offset <= 0.5;
        final atBottom = !hasClients ||
            controller.offset >= controller.position.maxScrollExtent - 0.5;
        if (atTop && atBottom) return child; // fits without scrolling at all
        final topStop = atTop ? 0.0 : fadeExtent;
        final bottomStop = atBottom ? 1.0 : 1.0 - fadeExtent;
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, topStop, bottomStop, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
    );
  }
}

/// Flat placeholder shown while a poster image loads.
class PosterSkeleton extends StatelessWidget {
  const PosterSkeleton({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF1A1A2A));
}

// Makes [child] (a plot/synopsis block sitting below a scrollable region's
// fold) a D-pad focus stop: reachable via the platform's default directional
// focus traversal (nothing above this in the tree intercepts arrow keys —
// see _DetailsView's top-level Focus, which only handles escape/back), and
// on gaining focus scrolls itself into view within the nearest ancestor
// Scrollable — same mechanism TextField uses, just triggered manually since
// plain text isn't normally focusable.
//
// The block itself is also height-capped and independently scrollable: a
// long plot used to just get centered by ensureVisible above with whatever
// didn't fit off-screen and unreachable — there was nothing to focus *past*
// the block's own top edge to see the rest. Capping the height turns
// "scroll the outer view to reveal this" and "read the rest of a long
// plot" into two separate, both-solvable problems: the outer ensureVisible
// only ever has to fit this fixed-size window, and Up/Down while it's
// focused page through the text inside that window instead of leaving the
// block (falls through to normal traversal once you're at the start/end).
class FocusableScrollTarget extends StatefulWidget {
  final Widget child;
  // Defaults to 18% of the *screen* height — right for a plot sitting
  // alongside other content on a full details page, but wrong inside a
  // popup/dialog whose own available height is already smaller and known
  // exactly (e.g. from an ancestor LayoutBuilder): callers with that
  // information should pass it here instead of inheriting the screen-wide
  // default, or the text ends up truncated well short of the space it
  // actually has.
  final double? maxHeightOverride;
  const FocusableScrollTarget(
      {super.key, required this.child, this.maxHeightOverride});

  @override
  State<FocusableScrollTarget> createState() => _FocusableScrollTargetState();
}

class _FocusableScrollTargetState extends State<FocusableScrollTarget> {
  final _scrollCtrl = ScrollController();
  bool _focused = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    final max = _scrollCtrl.position.maxScrollExtent;
    final target = (_scrollCtrl.offset + delta).clamp(0.0, max);
    _scrollCtrl.animateTo(target,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final maxH =
        widget.maxHeightOverride ?? MediaQuery.sizeOf(context).height * 0.18;
    return Focus(
      onFocusChange: (focused) {
        // Plain text otherwise gives no indication the plot is even
        // reachable, let alone that it currently owns the D-pad — every
        // other focusable control in this app shows the same violet
        // border/tint, this one just never picked it up.
        setState(() => _focused = focused);
        // context here is this widget's own element, which sits ABOVE its
        // own inner SingleChildScrollView (built below) — so this would
        // always target the OUTER Scrollable if one exists. The info column
        // that hosts this widget is now a fixed-height, non-scrolling
        // SizedBox (see the Flexible-sized plot slot in
        // details_screen.dart/series_page_layout.dart) specifically so
        // nothing above this box ever needs to move when it gains focus —
        // there usually isn't an outer Scrollable to find at all anymore.
        // Scrollable.maybeOf (not ensureVisible's own lookup, which throws
        // if none exists) guards that: still useful if this widget is ever
        // reused somewhere that *does* sit inside a real scroll view, a
        // no-op everywhere else instead of a crash.
        if (focused && Scrollable.maybeOf(context) != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 200),
            alignment: 0.5,
          );
        }
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (!_scrollCtrl.hasClients) return KeyEventResult.ignored;
        final atTop = _scrollCtrl.offset <= 0;
        final atBottom =
            _scrollCtrl.offset >= _scrollCtrl.position.maxScrollExtent;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown && !atBottom) {
          _scrollBy(80);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && !atTop) {
          _scrollBy(-80);
          return KeyEventResult.handled;
        }
        // At an edge (or the text fits without scrolling): let it bubble so
        // default traversal moves on to the next/previous focusable widget,
        // same as leaving any other focus stop.
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        // AnimatedContainer asserts margin.isNonNegative — a negative
        // margin here (to keep the box's outer edge flush with the
        // surrounding text column while the padding below made room for
        // the focus border) throws on every single build, not just an
        // edge case. Padding alone is kept small enough that the resulting
        // ~4px inset reads as intentional breathing room instead.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _focused ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
          color: _focused ? AppTheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          // Text scrolled under/over the fold used to just vanish at this
          // box's hard edge — ScrollEdgeFade fades it instead, and only on
          // whichever edge still has more content past it (see its doc).
          child: ScrollEdgeFade(
            controller: _scrollCtrl,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              // Was NeverScrollableScrollPhysics ("D-pad only") — but
              // drag/wheel input (the desktop dev target, and any
              // touch-capable device) had no way to reach this box's own
              // scroll then, and bubbled straight to the outer
              // SingleChildScrollView instead, dragging the whole info
              // column (title included) instead of just this text. Normal
              // physics lets this scrollable claim the gesture itself while
              // it isn't already at an edge — standard nested-Scrollable
              // behavior, no extra plumbing needed — and still hands off to
              // the outer one once it is. The D-pad handler above is
              // unaffected either way: it always drives
              // _scrollCtrl.animateTo() directly, regardless of physics.
              physics: const ClampingScrollPhysics(),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
