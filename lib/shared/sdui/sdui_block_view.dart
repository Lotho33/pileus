import 'package:flutter/widgets.dart';

import 'blocks/card_carousel_block_view.dart';
import 'sdui_block.dart';

export 'blocks/card_carousel_block_view.dart' show CardCarouselInteraction;

/// Single interpreter for the [SduiBlock] tree: an exhaustive switch, not a
/// string-keyed widget map. The widget vocabulary is fixed at compile time
/// (Dart AOT — no dynamic class loading), so a `Map<Type, WidgetBuilder>`
/// registry would only lose Dart's exhaustiveness checking for no benefit —
/// adding a new [SduiBlock] subtype without a render case here is a
/// compile error, not a silent runtime gap.
class SduiBlockView extends StatelessWidget {
  final SduiBlock block;

  /// Only consulted when [block] is a [CardCarouselBlock] — see that
  /// class's own doc comment for why these callbacks live outside the
  /// schema. Other block kinds aren't implemented yet (see sdui_block.dart)
  /// so they don't need their own interaction bag today.
  final CardCarouselInteraction? carouselInteraction;

  const SduiBlockView(
      {super.key, required this.block, this.carouselInteraction});

  @override
  Widget build(BuildContext context) {
    final b = block;
    return switch (b) {
      CardCarouselBlock() => CardCarouselBlockView(
          block: b,
          interaction: carouselInteraction ?? const CardCarouselInteraction(),
        ),
      ColumnBlock(children: final children) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in children)
              SduiBlockView(block: c, carouselInteraction: carouselInteraction),
          ],
        ),
      RowBlock(children: final children) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in children)
              SduiBlockView(block: c, carouselInteraction: carouselInteraction),
          ],
        ),
      StackBlock(children: final children) => Stack(
          children: [
            for (final c in children)
              SduiBlockView(block: c, carouselInteraction: carouselInteraction),
          ],
        ),
      // Not yet implemented (v1 only migrates catalog rows — see
      // sdui_block.dart) and unrecognized hint payloads both degrade to
      // "render nothing": fail-closed for whole block *types*, distinct
      // from the fail-open default used for unrecognized *variants* inside
      // an already-known block (see sdui_parser.dart).
      HeroBackgroundBlock() ||
      TitleLogoBlock() ||
      MetaChipRowBlock() ||
      GenrePillWrapBlock() ||
      PlotTextBlock() ||
      PrimaryActionButtonBlock() ||
      PosterPanelBlock() ||
      PillSelectorRowBlock() ||
      PaginatedTileListBlock() ||
      ModalPopupShellBlock() ||
      UnknownBlock() =>
        const SizedBox.shrink(),
    };
  }
}
