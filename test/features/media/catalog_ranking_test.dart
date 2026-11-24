// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/generated/media.pb.dart';
import 'package:pileus/features/media/catalog_ranking.dart';
import 'package:pileus/shared/sdui/blocks/card_carousel_block_view.dart';
import 'package:pileus/shared/sdui/sdui_parser.dart';
import 'package:pileus/shared/widgets/card_badge.dart';
import 'package:pileus/shared/widgets/rank_number.dart';

List<CatalogItem> items(int n) =>
    [for (var i = 0; i < n; i++) CatalogItem(id: 'i$i', title: 'T$i')];

void main() {
  test('ranked catalogs and rank numbers', () {
    expect(isRankedCatalog(CatalogDef(styleHint: 'ranked')), isTrue);
    expect(isRankedCatalog(CatalogDef(styleHint: 'featured')), isFalse);
    expect(rankFor(0, 0), 1);
    expect(rankFor(0, 4), 5);
    expect(rankFor(7, 4), 7); // the plugin's own number wins
  });

  test('badge labels; unknown values show nothing', () {
    expect(cardBadgeLabel('new'), 'Novità');
    expect(cardBadgeLabel('new_episode'), 'Nuovo episodio');
    expect(cardBadgeLabel(''), '');
    expect(cardBadgeLabel('hot'), '');
    expect(cardBadgeOverlay('hot'), isEmpty);
    expect(cardBadgeOverlay('new'), hasLength(1));
  });

  test('a ranked catalog becomes at most 10 numbered cards', () {
    final block = sduiSchemaForCatalogDef(
        CatalogDef(id: 'top', styleHint: 'ranked'),
        pluginId: 'p',
        items: items(14),
        isFirstSection: false);
    expect(block.ranked, isTrue);
    expect(block.items, hasLength(kRankedMaxItems));
    expect(block.items.map((i) => i.rank), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

    final plain = sduiSchemaForCatalogDef(CatalogDef(id: 'x'),
        pluginId: 'p', items: items(14), isFirstSection: false);
    expect(plain.ranked, isFalse);
    expect(plain.items, hasLength(14));
    expect(plain.items.first.rank, 0);
  });

  testWidgets('the TV row lays out a Top 10 with its numbers', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final block = sduiSchemaForCatalogDef(
        CatalogDef(id: 'top', styleHint: 'ranked'),
        pluginId: 'p',
        items: items(10),
        isFirstSection: false);
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: CardCarouselBlockView(block: block))));
    expect(t.takeException(), isNull);
    final numbers = t.widgetList<RankNumber>(find.byType(RankNumber));
    expect(numbers.first.rank, 1);
    expect(numbers.length, greaterThanOrEqualTo(5));
  });
}
