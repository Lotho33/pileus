// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/media/my_list.dart';
import '../shared/responsive.dart';
import 'widgets/desktop_card.dart';

/// "La mia lista" pane: every saved title of the profile, whatever the
/// plugin — the home row only shows the active plugin's.
class DesktopMyListPane extends StatelessWidget {
  const DesktopMyListPane({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, bp, _) => ListenableBuilder(
        listenable: MyList.instance,
        builder: (context, _) {
          final list = MyList.instance;
          final items = list.items;
          if (items.isEmpty) {
            return Center(
              child: Text(
                list.supported
                    ? 'Non hai ancora salvato nessun titolo.'
                    : 'Questo server non supporta ancora La mia lista.',
                style: const TextStyle(color: AppTheme.textMid),
              ),
            );
          }
          final capH = captionBoxHeight(context, bp.cardTitleSize);
          final cellH = bp.cardWidth * 1.5 + 8 + capH + 20;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(bp.gutter, 28, bp.gutter, 16),
                sliver: const SliverToBoxAdapter(
                  child: Text('La mia lista',
                      style: TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: 26,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(bp.gutter, 0, bp.gutter, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: bp.cardWidth + 24,
                    mainAxisExtent: cellH,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 18,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Center(
                      child: DesktopCard(
                        pluginId: items[i].pluginId,
                        item: MyList.toCatalogItem(items[i]),
                        width: bp.cardWidth,
                        titleSize: bp.cardTitleSize,
                        captionHeight: capH,
                      ),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
