// Declarative layout schema for server-driven UI.
//
// Pure Dart, no Flutter imports — parseable/testable without a widget-test
// harness. The vocabulary mirrors the visual components already hard-coded
// across home_screen.dart / details_screen.dart; v1 only ever constructs
// [CardCarouselBlock] (see sdui_parser.dart), the rest of the sealed set is
// reserved for later migrations so the interpreter (sdui_block_view.dart)
// can stay exhaustive as those land, instead of growing a parallel type.
//
// Unknown/unrecognized wire values must always degrade gracefully, never
// throw — this mirrors the forward-compat contract already documented on
// CatalogDef.section_kind/style_hint in proto/media.proto.

/// Master switch for whether `style_hint=="featured"` actually changes
/// carousel rendering (bigger cards, fewer per row). Detection of the hint
/// (`CardCarouselBlock.featured`, `isFeaturedCatalog` in sdui_parser.dart)
/// stays correct and tested regardless of this flag — only the visual
/// effect is gated, here, in one place, so home_screen.dart's space
/// reservation (`carouselTop`/`_SkeletonRow`) and the actual card renderer
/// (card_carousel_block_view.dart) can never disagree about which is live.
///
/// Off for now (2026-07-13): the 7→5 card size bump looked disproportionate
/// in practice on the one live "featured" carousel we had to test against —
/// off while the effect's intensity gets rethought, not because detection
/// was wrong.
const bool kFeaturedCarouselResizeEnabled = false;

sealed class SduiBlock {
  const SduiBlock();
}

enum SduiCardVariant { poster, live, unknown }

/// A single card's rendering data — deliberately NOT the raw `CatalogItem`
/// proto class, so the card-view widgets stay decoupled from the wire
/// format. Also centralizes `extra[...]` parsing (lang/subtitle/live/sport)
/// that was previously duplicated slightly differently across widgets.
class SduiCardItem {
  final String id;
  final String title;
  final String imageUrl;
  final String lang; // '', 'ita', 'jap' — poster-variant language badge
  final String
      subtype; // 'movie'|'ova'|'ona'|'special'|'music'|'tv-short' — poster-variant subtype badge
  final String subtitle; // live-variant only
  final bool isLive; // live-variant "LIVE" badge
  final String sportCat; // live-variant accent color/emoji key

  const SduiCardItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.lang = '',
    this.subtype = '',
    this.subtitle = '',
    this.isLive = false,
    this.sportCat = '',
  });
}

class CardCarouselBlock extends SduiBlock {
  final String sectionId;
  final String pluginId;
  final SduiCardVariant variant;
  final List<SduiCardItem> items;
  final bool isFirstSection;

  /// Layout hint orthogonal to [variant]: `variant` decides WHICH card
  /// widget renders (content-type driven, from `catalogDef.type`);
  /// `featured` decides HOW that same card renders (presentation-only,
  /// from `catalogDef.style_hint == "featured"`). Today the only
  /// recognized style_hint value — bigger cards, fewer per row.
  final bool featured;

  const CardCarouselBlock({
    required this.sectionId,
    required this.pluginId,
    required this.variant,
    required this.items,
    required this.isFirstSection,
    this.featured = false,
  });
}

// ── Vocabulary reserved for future migrations ──────────────────────────────
// Not constructed by any parser yet; SduiBlockView renders them as empty
// until a parser/renderer pair lands for each (details screen, hero, etc).

class HeroBackgroundBlock extends SduiBlock {
  const HeroBackgroundBlock();
}

class TitleLogoBlock extends SduiBlock {
  const TitleLogoBlock();
}

class MetaChipRowBlock extends SduiBlock {
  const MetaChipRowBlock();
}

class GenrePillWrapBlock extends SduiBlock {
  const GenrePillWrapBlock();
}

class PlotTextBlock extends SduiBlock {
  const PlotTextBlock();
}

class PrimaryActionButtonBlock extends SduiBlock {
  const PrimaryActionButtonBlock();
}

class PosterPanelBlock extends SduiBlock {
  const PosterPanelBlock();
}

class PillSelectorRowBlock extends SduiBlock {
  const PillSelectorRowBlock();
}

class PaginatedTileListBlock extends SduiBlock {
  const PaginatedTileListBlock();
}

class ModalPopupShellBlock extends SduiBlock {
  const ModalPopupShellBlock();
}

class ColumnBlock extends SduiBlock {
  final List<SduiBlock> children;
  const ColumnBlock(this.children);
}

class RowBlock extends SduiBlock {
  final List<SduiBlock> children;
  const RowBlock(this.children);
}

class StackBlock extends SduiBlock {
  final List<SduiBlock> children;
  const StackBlock(this.children);
}

/// Forward-compat catch-all for a hint value the parser didn't recognize.
/// Always degrades to "render nothing" — see SduiBlockView.
class UnknownBlock extends SduiBlock {
  final String rawKind;
  final Map<String, String> rawParams;
  const UnknownBlock(this.rawKind, [this.rawParams = const {}]);
}
