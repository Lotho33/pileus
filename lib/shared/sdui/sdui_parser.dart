import '../../core/grpc/generated/media.pb.dart' show CatalogDef, CatalogItem;
import 'sdui_block.dart';

/// Parses a [CatalogDef] + its loaded items into a [CardCarouselBlock].
///
/// Three independent axes:
/// - **variant selection** (WHICH card widget renders — poster 2:3 vs
///   landscape 16:9) reads `catalogDef.card_layout` (`"landscape"` → wide),
///   falling back to the legacy `catalogDef.type == 'live'` signal for
///   plugins that don't set the new field yet. This is purely a card-aspect
///   decision — it does NOT imply live-TV player behavior (no seek, no
///   continue-watching): that stays driven independently by
///   `CatalogItem.media_type` at the item level (see open_catalog_item.dart)
///   and by `catalogDef.type == 'live'` for the live-TV row styling/
///   continue-watching suppression in home_screen.dart — neither of which
///   this function touches.
/// - **layout hint** (HOW that card renders) reads `catalogDef.style_hint`
///   — today only `"featured"` is recognized and set on
///   [CardCarouselBlock.featured]. Detection is always correct/tested
///   regardless of whether the visual effect is currently switched on —
///   see [kFeaturedCarouselResizeEnabled] for that separate gate. Any
///   other value, or an empty one, means "no hint" — never throws
///   (forward-compat contract documented on CatalogDef in
///   proto/media.proto).
/// `section_kind` is not read by anything yet — reserved for a future
/// structural switch (e.g. "grid" vs "carousel"), out of scope here.
CardCarouselBlock sduiSchemaForCatalogDef(
  CatalogDef catalogDef, {
  required String pluginId,
  required List<CatalogItem> items,
  required bool isFirstSection,
}) {
  return CardCarouselBlock(
    sectionId: '${pluginId}_${catalogDef.id}',
    pluginId: pluginId,
    variant: _variantFor(catalogDef),
    items: items.map(sduiCardItemFromCatalogItem).toList(growable: false),
    isFirstSection: isFirstSection,
    featured: isFeaturedCatalog(catalogDef),
  );
}

SduiCardVariant _variantFor(CatalogDef catalogDef) {
  switch (catalogDef.cardLayout) {
    case 'landscape':
      return SduiCardVariant.live;
    case 'poster':
      return SduiCardVariant.poster;
    default:
      // Unset, or a future value this client doesn't recognize yet —
      // forward-compat contract: fall back to the legacy type-based
      // inference rather than crash or silently drop content.
      return catalogDef.type == 'live' ? SduiCardVariant.live : SduiCardVariant.poster;
  }
}

/// Single source of truth for "is this catalog row featured" — also used
/// by home_screen.dart's `_StandardHomeShell` to reserve the correct amount
/// of vertical space above the carousel *before* the carousel widget
/// itself is built (that layout math can't go through
/// [sduiSchemaForCatalogDef] because it runs before the row's items are
/// loaded). Keeping both call sites on this one function is what stops
/// them drifting apart.
bool isFeaturedCatalog(CatalogDef catalogDef) => catalogDef.styleHint == 'featured';

/// Centralizes `extra[...]` parsing for a catalog card. Single source of
/// truth for both the home-screen catalog rows and the search results
/// carousel (search_screen.dart) — previously duplicated slightly
/// differently between home_screen.dart's old `_PosterCard`/`_LiveRow` and
/// fixed_carousel.dart's `PosterCard`. `media_catalog_card.dart` (browse
/// screen's grid, a different layout shape) is intentionally not unified
/// here — out of scope for the carousel block.
SduiCardItem sduiCardItemFromCatalogItem(CatalogItem item) {
  return SduiCardItem(
    id: item.id,
    title: item.title,
    imageUrl: item.posterUrl,
    lang: item.extra['lang'] ?? '',
    subtype: item.extra['subtype'] ?? '',
    subtitle: (item.extra['plot'] ?? '').split('\n').first,
    isLive: item.extra['is_live'] == '1',
    sportCat: item.extra['sport_cat'] ?? '',
  );
}
