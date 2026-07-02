import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/generated/media.pb.dart';
import 'package:pileus/shared/sdui/sdui_block.dart';
import 'package:pileus/shared/sdui/sdui_parser.dart';

void main() {
  group('sduiSchemaForCatalogDef', () {
    test('falls back to poster when type/hints are empty (today\'s wire shape)', () {
      final def = CatalogDef(id: 'trending', name: 'Trending', type: '');
      final block = sduiSchemaForCatalogDef(
        def,
        pluginId: 'vix.movie',
        items: const [],
        isFirstSection: true,
      );
      expect(block.variant, SduiCardVariant.poster);
    });

    test('selects live variant from catalogDef.type=="live" (today\'s only signal)', () {
      final def = CatalogDef(id: 'now', name: 'In diretta', type: 'live');
      final block = sduiSchemaForCatalogDef(
        def,
        pluginId: 'sport',
        items: const [],
        isFirstSection: false,
      );
      expect(block.variant, SduiCardVariant.live);
    });

    test('never throws on an unrecognized section_kind/style_hint value', () {
      final def = CatalogDef(
        id: 'weird',
        name: 'Weird',
        type: 'grid', // not 'live' — must not crash, must degrade to poster
      )
        ..sectionKind = 'some_future_kind_the_client_has_never_seen'
        ..styleHint = 'some_future_style';

      expect(
        () => sduiSchemaForCatalogDef(
          def,
          pluginId: 'plugin',
          items: const [],
          isFirstSection: false,
        ),
        returnsNormally,
      );
      final block = sduiSchemaForCatalogDef(
        def,
        pluginId: 'plugin',
        items: const [],
        isFirstSection: false,
      );
      expect(block.variant, SduiCardVariant.poster);
      expect(block.featured, isFalse);
    });

    test('style_hint can never flip the variant, even with a confusing value', () {
      // A plugin author mistakenly setting style_hint to something that
      // *looks* like a variant name must not switch poster->live — variant
      // selection reads type only, per the mycelium-core session's
      // clarification (variant-selection vs layout-hint are separate axes).
      final def = CatalogDef(id: 'x', name: 'X', type: 'movie', styleHint: 'live');
      final block = sduiSchemaForCatalogDef(
        def,
        pluginId: 'vix.movie',
        items: const [],
        isFirstSection: false,
      );
      expect(block.variant, SduiCardVariant.poster);
    });

    test('style_hint=="featured" sets CardCarouselBlock.featured (vix.movie trending_week shape)', () {
      // Mirrors the real manifest.yaml entry already live on mycelium-core:
      // catalogs: [{id: trending_week, type: movie, style_hint: featured}].
      final def = CatalogDef(
        id: 'trending_week',
        name: 'Popolari',
        type: 'movie',
        styleHint: 'featured',
      );
      final block = sduiSchemaForCatalogDef(
        def,
        pluginId: 'vix.movie',
        items: const [],
        isFirstSection: true,
      );
      expect(block.variant, SduiCardVariant.poster);
      expect(block.featured, isTrue);
    });

    test('featured defaults to false for any non-"featured" style_hint', () {
      final def = CatalogDef(id: 'x', name: 'X', type: 'movie', styleHint: 'compact');
      final block = sduiSchemaForCatalogDef(
        def,
        pluginId: 'plugin',
        items: const [],
        isFirstSection: false,
      );
      expect(block.featured, isFalse);
    });

    test('kFeaturedCarouselResizeEnabled is off (2026-07-13: bump looked '
        'disproportionate on the one live case, detection stays correct '
        'above regardless — see sdui_block.dart)', () {
      expect(kFeaturedCarouselResizeEnabled, isFalse);
    });
  });

  group('sduiCardItemFromCatalogItem', () {
    test('parses extra[] fields into typed SduiCardItem fields', () {
      final item = CatalogItem(
        id: 'abc',
        title: 'Some Title',
        posterUrl: 'https://example.com/poster.jpg',
        extra: {
          'lang': 'ita',
          'subtype': 'ova',
          'plot': 'First line.\nSecond line.',
          'is_live': '1',
          'sport_cat': 'football',
        }.entries,
      );

      final card = sduiCardItemFromCatalogItem(item);

      expect(card.id, 'abc');
      expect(card.title, 'Some Title');
      expect(card.imageUrl, 'https://example.com/poster.jpg');
      expect(card.lang, 'ita');
      expect(card.subtype, 'ova');
      expect(card.subtitle, 'First line.');
      expect(card.isLive, isTrue);
      expect(card.sportCat, 'football');
    });

    test('defaults to empty/false when extra[] is absent', () {
      final item = CatalogItem(id: 'x', title: 'X');
      final card = sduiCardItemFromCatalogItem(item);

      expect(card.lang, '');
      expect(card.subtype, '');
      expect(card.subtitle, '');
      expect(card.isLive, isFalse);
      expect(card.sportCat, '');
    });
  });
}
