import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/theme/app_theme.dart';
import '../core/utils/image_sizing.dart';
import '../features/media/data/media_repository.dart';
import '../shared/widgets/open_catalog_item.dart';
import '../features/player/resolve_and_play.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Long-press context sheet for a catalog item (home cards, search results):
/// poster + quick metadata + Info / Riproduci. The mobile equivalent of the
/// TV hover popup.
Future<void> showItemSheet(
    BuildContext context, String pluginId, CatalogItem item) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ItemSheet(pluginId: pluginId, item: item),
  );
}

class _ItemSheet extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  const _ItemSheet({required this.pluginId, required this.item});

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  List<String> _genres = const [];
  String _plot = '';
  bool _preparing = false;

  @override
  void initState() {
    super.initState();
    _enrich();
  }

  Future<void> _enrich() async {
    try {
      final d = await getIt<MediaRepository>()
          .getDetails(widget.pluginId, widget.item.id);
      if (!mounted) return;
      setState(() {
        if (d.hasSeries()) {
          _genres = d.series.genres;
          _plot = d.series.plot;
        } else if (d.hasMovie()) {
          _genres = d.movie.genres;
          _plot = d.movie.plot;
        }
      });
    } catch (_) {}
  }

  void _info() {
    Navigator.of(context).pop();
    openCatalogItem(context, widget.pluginId, widget.item);
  }

  Future<void> _play() async {
    final it = widget.item;
    if (it.mediaType == 'series') {
      setState(() => _preparing = true);
      final repo = getIt<MediaRepository>();
      try {
        final d = await repo.getDetails(widget.pluginId, it.id);
        final List<SeasonInfo> seasons =
            d.hasSeries() ? d.series.seasons : const <SeasonInfo>[];
        if (seasons.isNotEmpty) {
          final s = seasons.firstWhere((x) => x.episodeCount > 0,
              orElse: () => seasons.first);
          final b = await repo.browse(widget.pluginId, s.directoryId, '');
          if (mounted && b.episodes.isNotEmpty) {
            final eps = b.episodes;
            Navigator.of(context).pop();
            await resolveAndPlay(
              context,
              widget.pluginId,
              eps.first.id,
              extra: <String, dynamic>{
                'title': eps.first.title,
                'showTitle': it.title,
                'poster': it.posterUrl,
                'parentId': s.directoryId,
                'episodeList': eps.map((e) => e.id).toList(),
                'episodeTitles': eps.map((e) => e.title).toList(),
                'episodeIndex': 0,
              },
            );
            return;
          }
        }
      } catch (_) {}
      if (mounted) _info();
      return;
    }
    Navigator.of(context).pop();
    await resolveAndPlay(
      context,
      widget.pluginId,
      it.id,
      extra: <String, dynamic>{
        'title': it.title,
        'poster': it.posterUrl,
        'mediaType': it.mediaType,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final meta = <String>[
      if (it.rating > 0) '★ ${it.rating.toStringAsFixed(1)}',
      if (it.year > 0) '${it.year}',
      ..._genres.take(2),
    ].join('  ·  ');

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 108,
                    child: it.posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            // Web-only, no-op on every other platform — see image_sizing.dart's
                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                            // CachedNetworkImage call site in the app sets this.
                            imageRenderMethodForWeb:
                                ImageRenderMethodForWeb.HttpGet,
                            imageUrl: posterSrc(
                                it.posterUrl, cacheWidthFor(context, 72)),
                            memCacheWidth: cacheWidthFor(context, 72),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: AppTheme.surface2),
                          )
                        : const ColoredBox(color: AppTheme.surface2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(meta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textMid, fontSize: 12)),
                      ],
                      if (_plot.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(_plot,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textLow,
                                fontSize: 12,
                                height: 1.35)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _preparing ? null : _play,
                    icon: _preparing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Riproduci'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _info,
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Info'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
