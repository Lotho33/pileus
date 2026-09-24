import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/theme/app_theme.dart';
import '../core/utils/image_sizing.dart';
import '../features/media/data/media_repository.dart';
import '../shared/sdui/sport_theme.dart' show isLiveNow, liveStartTimeLabel;
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Mobile live-event sheet — replaces the TV `showLiveEventPopup` (D-pad,
/// AppScale) for phones. Event header + the list of stream sources
/// (`GetStreams`); tap a source to play it.
Future<void> showLiveSheet(
    BuildContext context, String pluginId, CatalogItem item) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _LiveSheet(pluginId: pluginId, item: item),
  );
}

class _LiveSheet extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  const _LiveSheet({required this.pluginId, required this.item});

  @override
  State<_LiveSheet> createState() => _LiveSheetState();
}

class _LiveSheetState extends State<_LiveSheet> {
  List<StreamSource> _sources = const [];
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<MediaRepository>()
          .getStreams(widget.pluginId, widget.item.id);
      if (mounted) {
        setState(() {
          _sources = res.sources;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loaded = true;
        });
      }
    }
  }

  void _play(StreamSource src) {
    final ids = _sources.map((s) => s.id).toList();
    final labels = _sources.map((s) => s.label).toList();
    Navigator.of(context).pop();
    context.push(
      '/player/${widget.pluginId}/${Uri.encodeComponent(src.id)}',
      extra: <String, dynamic>{
        'streamId': src.id,
        'title': widget.item.title,
        'sourceLabel': src.label,
        'isLive': true,
        'liveSources': ids,
        'liveSourceLabels': labels,
        'livePluginId': widget.pluginId,
        'liveMediaId': widget.item.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final isLive = isLiveNow(it.extra);
    final startTime = liveStartTimeLabel(it.extra);
    final sportCat = it.extra['sport_cat'] ?? '';
    final competition = it.extra['competition'] ?? '';
    final plot = it.extra['plot'] ?? '';
    final poster = it.posterUrl;

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
                if (poster.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 96,
                      height: 54,
                      child: CachedNetworkImage(
                        // Web-only, no-op on every other platform — see image_sizing.dart's
                        // "ImageRenderMethodForWeb.HttpGet" section for why every
                        // CachedNetworkImage call site in the app sets this.
                        imageRenderMethodForWeb:
                            ImageRenderMethodForWeb.HttpGet,
                        imageUrl: posterSrc(poster, cacheWidthFor(context, 96),
                            proxy: true),
                        memCacheWidth: cacheWidthFor(context, 96),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: AppTheme.surface2),
                      ),
                    ),
                  ),
                if (poster.isNotEmpty) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLive)
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFFF3B3B),
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            const Text('IN DIRETTA',
                                style: TextStyle(
                                    color: Color(0xFFFF3B3B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2)),
                          ],
                        )
                      else if (startTime != null)
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 13, color: AppTheme.textMid),
                            const SizedBox(width: 4),
                            Text('Inizio $startTime',
                                style: const TextStyle(
                                    color: AppTheme.textMid,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Text(it.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      if (competition.isNotEmpty || sportCat.isNotEmpty)
                        Text(
                          [competition, sportCat.replaceAll('-', ' ')]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(
                              color: AppTheme.textMid, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (plot.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plot,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textLow, fontSize: 12, height: 1.35)),
            ],
            const SizedBox(height: 14),
            const Text('SORGENTI',
                style: TextStyle(
                    color: AppTheme.textLow,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Impossibile caricare le sorgenti.',
                          style: TextStyle(color: AppTheme.textMid)),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loaded = false;
                          _error = null;
                        });
                        _load();
                      },
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              )
            else if (_sources.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nessuna sorgente disponibile',
                    style: TextStyle(color: AppTheme.textMid)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sources.length,
                  itemBuilder: (_, i) {
                    final s = _sources[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_arrow_rounded,
                          color: AppTheme.textHigh),
                      title: Text(s.label,
                          style: const TextStyle(color: AppTheme.textHigh)),
                      trailing: i == 0
                          ? const Text('MIGLIORE',
                              style: TextStyle(
                                  color: AppTheme.textLow,
                                  fontSize: 10,
                                  letterSpacing: 1))
                          : null,
                      onTap: () => _play(s),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
