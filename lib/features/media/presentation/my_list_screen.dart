// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/media_catalog_card.dart';
import '../../../shared/widgets/open_catalog_item.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../my_list.dart';

/// "La mia lista" on the TV: every saved title of the profile, whatever the
/// plugin — the home row only shows the active plugin's. Reached from the
/// single entry above Impostazioni in the side menu.
class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  static const _columns = 7;

  final _backFn = FocusNode();

  @override
  void dispose() {
    _backFn.dispose();
    super.dispose();
  }

  // With nothing in the grid Back is the only stop: on opening, and when the
  // last title was removed from its details page. autofocus alone loses to
  // the menu entry still holding focus while the route comes in.
  void _focusBackIfEmpty(bool empty) {
    if (!empty || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_backFn.hasPrimaryFocus) _backFn.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hPad = AppScale.catalogHPadRatio(size.width);
    final gap = AppScale.catalogGapRatio(size.width);
    final cardW = (size.width - hPad * 2 - gap * (_columns - 1)) / _columns;
    final cardH = cardW * 3 / 2;
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => context.pop(),
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: MyList.instance,
          builder: (context, _) {
            final items = MyList.instance.items;
            _focusBackIfEmpty(items.isEmpty);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      hPad, AppScale.space(context, 40), hPad, 0),
                  child: Row(
                    children: [
                      TvFocusable(
                        focusNode: _backFn,
                        autofocus: items.isEmpty,
                        onActivate: () => context.pop(),
                        builder: (context, focused) => Container(
                          padding: EdgeInsets.all(AppScale.space(context, 10)),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: focused ? 0.15 : 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_back_rounded,
                              size: AppScale.iconM(context),
                              color: Colors.white
                                  .withValues(alpha: focused ? 1.0 : 0.7)),
                        ),
                      ),
                      SizedBox(width: AppScale.space(context, 16)),
                      Text('La mia lista',
                          style: TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: AppScale.title(context),
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'Non hai ancora salvato nessun titolo.',
                            style: TextStyle(
                                color: AppTheme.textMid,
                                fontSize: AppScale.label(context)),
                          ),
                        )
                      : FocusTraversalGroup(
                          child: GridView.builder(
                            // Top padding: a focused card grows and the
                            // scrollable clips hard at its own edge.
                            padding: EdgeInsets.fromLTRB(
                                hPad, cardH * 0.08, hPad, gap),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columns,
                              mainAxisSpacing: gap,
                              crossAxisSpacing: gap,
                              mainAxisExtent:
                                  MediaCatalogCard.cellHeight(context, cardH),
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final it = items[i];
                              return MediaCatalogCard(
                                key: ValueKey('${it.pluginId}|${it.mediaId}'),
                                title: it.title,
                                posterUrl: it.posterUrl,
                                width: cardW,
                                height: cardH,
                                autofocus: i == 0,
                                centerTitle: true,
                                onNavigateUp: i < _columns
                                    ? _backFn.requestFocus
                                    : null,
                                onTap: () => openCatalogItem(context,
                                    it.pluginId, MyList.toCatalogItem(it)),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
