import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/media/my_list.dart';
import 'widgets/mobile_poster_card.dart';

/// "La mia lista" tab: every saved title of the profile, whatever the
/// plugin — the home row only shows the active plugin's.
class MobileMyListScreen extends StatelessWidget {
  const MobileMyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: MyList.instance,
        builder: (context, _) {
          final list = MyList.instance;
          final items = list.items;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  list.supported
                      ? 'Non hai ancora salvato nessun titolo.'
                      : 'Questo server non supporta ancora La mia lista.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMid),
                ),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Text('La mia lista',
                      style: TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 118,
                    childAspectRatio: 0.48,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => MobilePosterCard(
                      pluginId: items[i].pluginId,
                      item: MyList.toCatalogItem(items[i]),
                      width: 118,
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
