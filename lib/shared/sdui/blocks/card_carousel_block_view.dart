// Renderer for [CardCarouselBlock] — promoted from home_screen.dart's
// previously-private `_FixedCarousel`/`_LiveRow`/`_PosterCard`/`_LiveCard`
// (a pure move + parameterize on [SduiCardItem]/[SduiCardVariant] instead of
// the raw `CatalogItem`/`isLive` bool). Visual/animation behavior is
// unchanged from before this migration.
//
// Deliberately presentational only: routing (what a tap/long-press does) is
// NOT decided here — it's a navigation/business-logic concern that stays in
// home_screen.dart's `_CatalogSection`, threaded in via [CardCarouselInteraction].
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/image_sizing.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../utils/held_key_gate.dart';
import '../../utils/safe_focus.dart';
import '../../widgets/pileus_spinner.dart';
import '../../widgets/tv_focusable.dart';
import '../sdui_block.dart';
import '../sport_theme.dart';

part 'card_carousel_block_view/fixed_carousel.dart';
part 'card_carousel_block_view/load_more_card.dart';
part 'card_carousel_block_view/live_row.dart';
part 'card_carousel_block_view/poster_card.dart';
part 'card_carousel_block_view/live_card.dart';


// Baseline 1920×1080 ratios — see home_screen.dart's own copy of these for
// the non-carousel parts of the screen; duplicated here (not shared) since
// this module should stay independent of home_screen.dart's private consts.
const int _kVisibleCards = 7;
const int _kVisibleLiveCards = 3;
// Featured rows (CardCarouselBlock.featured, from style_hint=="featured")
// show fewer, proportionally bigger cards instead of a separate widget —
// same widget, same animation code, just a different slot count.
const int _kVisibleCardsFeatured = 5;
const int _kVisibleLiveCardsFeatured = 2;
// _rHPad/_rCardGap used to be duplicated here and in home_screen.dart —
// both now pull from AppScale.catalogHPadRatio/catalogGapRatio, the single
// source (see its doc comment for why this is width-based, not converted
// onto AppScale.screenHPad's height-based one).
const double _rLiveGap = 40 / 1920;
// How much of the next off-window card peeks past the trailing edge, as a
// fraction of a card's own width — the standard "there's more here" scroll
// cue TV design guidance calls for (Fire TV/Smashing Magazine). Reserving
// this in the card-width formula itself (see both _computeDims methods)
// means the existing windowed-rendering loop (which already lays out a
// buffer of off-screen cards past the visible count) needs no change at
// all — the sliver just falls where ClipRect already cuts the row off.
const double _kPeekFraction = 0.16;

/// Callbacks a [CardCarouselBlock] needs from its host screen. Kept out of
/// the schema itself — these are navigation/focus plumbing, not layout
/// description (see sdui_block.dart's top comment).
class CardCarouselInteraction {
  final void Function(String itemId)? onItemFocused;
  final void Function(String itemId)? onItemTap;
  final void Function(String itemId)? onItemLongPress;
  final void Function(FocusNode)? onFirstCardFocus;
  // Fired whenever the last item's index changes (initial build, or an
  // append via load-more) — lets a host that places something past the row
  // (see onNavigateRightAtEnd) hand focus straight back to the real last
  // card without reaching into this widget's internal FocusNode map.
  final void Function(FocusNode)? onLastCardFocus;
  final VoidCallback? onOpenNav;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  // See _PosterCardView.onHoldChanged's doc — lets the host drive its own
  // row-to-row hold-repeat timer (native key-repeat isn't reliable here).
  final void Function(LogicalKeyboardKey key, bool isDown)?
      onNavigateHoldChanged;
  // Back/Escape on a focused card: `onEsc` is the explicit handler (quick
  // search wires it to dismiss its own overlay). When null, it falls back
  // to `onBack` — the home rows point that at the route's own back handling
  // (exit-confirm), so Back no longer toggles the side nav (opening the nav
  // is a deliberate Left on the first card). When both are null the card
  // leaves Back to its `onUp` fallback / the focus tree.
  final VoidCallback? onEsc;
  final VoidCallback? onBack;
  // Right-arrow pressed on the last laid-out card — mirrors onOpenNav's role
  // at the opposite (left, index 0) edge. Lets a host place something past
  // the last card (e.g. search's "load more" arrow) and make it reachable
  // by D-pad instead of only by an off-screen "scroll near the end" trigger.
  final VoidCallback? onNavigateRightAtEnd;

  const CardCarouselInteraction({
    this.onItemFocused,
    this.onItemTap,
    this.onItemLongPress,
    this.onFirstCardFocus,
    this.onLastCardFocus,
    this.onOpenNav,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onNavigateHoldChanged,
    this.onNavigateRightAtEnd,
    this.onEsc,
    this.onBack,
  });
}

/// Opt-in trailing "load more" slot rendered as a real card at the end of a
/// [CardCarouselBlockView] — it scrolls, focuses and windows exactly like a
/// poster card (D-pad Right off the last real card lands on it), instead of
/// a separate control the host hangs beside the row. When a load it triggers
/// appends items, focus returns to the first card.
class CarouselLoadMore {
  final bool isLoading;
  final VoidCallback onActivate;
  const CarouselLoadMore({required this.isLoading, required this.onActivate});
}

class CardCarouselBlockView extends StatelessWidget {
  final CardCarouselBlock block;
  final CardCarouselInteraction interaction;

  /// Caller-supplied slot-count override (e.g. search results use 6 instead
  /// of the home screen's 7/5) — a host-screen layout constraint, not part
  /// of the content schema, same rationale as [CardCarouselInteraction].
  /// When null, falls back to the default (or featured) visible-card count.
  final int? visibleCardsOverride;

  /// Card sizing is anchored to [MediaQuery]'s full screen width by design
  /// (see the class-level comment) — correct for every full-bleed row this
  /// backs (home screen, full SearchScreen), but wrong for a host that
  /// embeds this in a narrower container (e.g. home screen's quick-search
  /// preview panel): the row would still size itself for the full screen
  /// and spill past the container's edge. Pass the host's actual available
  /// width (e.g. from a LayoutBuilder) to size against that instead.
  /// [hPadOverride] should normally accompany this with `0` — the host
  /// container already owns its own padding in that case.
  final double? availableWidthOverride;
  final double? hPadOverride;

  /// When non-null, a trailing load-more card is appended as the row's last
  /// slot (poster variant only). See [CarouselLoadMore].
  final CarouselLoadMore? loadMore;

  const CardCarouselBlockView({
    super.key,
    required this.block,
    this.interaction = const CardCarouselInteraction(),
    this.visibleCardsOverride,
    this.availableWidthOverride,
    this.hPadOverride,
    this.loadMore,
  });

  @override
  Widget build(BuildContext context) {
    // `unknown` fails open onto the poster rendering — always show
    // something rather than a blank row.
    if (block.variant == SduiCardVariant.live) {
      return _LiveRowView(
        block: block,
        interaction: interaction,
        visibleCardsOverride: visibleCardsOverride,
        availableWidthOverride: availableWidthOverride,
        hPadOverride: hPadOverride,
      );
    }
    return _FixedCarouselView(
      block: block,
      interaction: interaction,
      visibleCardsOverride: visibleCardsOverride,
      availableWidthOverride: availableWidthOverride,
      hPadOverride: hPadOverride,
      loadMore: loadMore,
    );
  }
}
