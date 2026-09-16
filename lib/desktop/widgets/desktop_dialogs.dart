import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_sizing.dart';
import '../../features/media/data/media_repository.dart';
import '../../features/player/resolve_and_play.dart';
import '../../shared/widgets/open_catalog_item.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Centered surface used by all the desktop dialogs — replaces the mobile
/// bottom sheets, which read wrong in a window.
Future<T?> _panel<T>(BuildContext context, Widget child, {double maxW = 520}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => Dialog(
      backgroundColor: AppTheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: 640),
        child: child,
      ),
    ),
  );
}

// ── Generic action dialog ──────────────────────────────────────────────────

class DesktopAction {
  final String id;
  final IconData icon;
  final String label;
  final bool danger;
  const DesktopAction(this.id, this.icon, this.label, {this.danger = false});
}

/// A centred list of actions — used for the Continue Watching card menu so
/// it matches the rest of the desktop dialogs (source picker, live panel)
/// instead of a pointer-anchored popup.
Future<String?> showDesktopActionDialog(
  BuildContext context, {
  required String title,
  required List<DesktopAction> actions,
}) {
  return _panel<String>(
    context,
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final a in actions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(a.icon,
                  color: a.danger ? const Color(0xFFFF6B6B) : AppTheme.textMid),
              title: Text(a.label,
                  style: TextStyle(
                      color: a.danger
                          ? const Color(0xFFFF6B6B)
                          : AppTheme.textHigh)),
              onTap: () => Navigator.of(context).pop(a.id),
            ),
        ],
      ),
    ),
    maxW: 420,
  );
}

// ── Item quick-info ─────────────────────────────────────────────────────────

/// Right-click / hover-info panel for a catalog card (desktop equivalent of
/// the mobile `showItemSheet` bottom sheet).
Future<void> showDesktopItemDialog(
    BuildContext context, String pluginId, CatalogItem item) {
  return _panel(context, _ItemPanel(pluginId: pluginId, item: item));
}

class _ItemPanel extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  const _ItemPanel({required this.pluginId, required this.item});

  @override
  State<_ItemPanel> createState() => _ItemPanelState();
}

class _ItemPanelState extends State<_ItemPanel> {
  List<String> _genres = const [];
  String _plot = '';

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

  void _play() {
    final mt = widget.item.mediaType;
    Navigator.of(context).pop();
    if (mt == 'movie' || mt == 'episode') {
      resolveAndPlay(context, widget.pluginId, widget.item.id, extra: {
        'title': widget.item.title,
        'poster': widget.item.posterUrl,
        'mediaType': mt,
      });
    } else {
      openCatalogItem(context, widget.pluginId, widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final meta = <String>[
      if (it.rating > 0) '★ ${it.rating.toStringAsFixed(1)}',
      if (it.year > 0) '${it.year}',
      ..._genres.take(3),
    ].join('   ·   ');

    return Padding(
      padding: const EdgeInsets.all(20),
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
                  width: 96,
                  height: 144,
                  child: it.posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          // Web-only, no-op on every other platform — see image_sizing.dart's
                          // "ImageRenderMethodForWeb.HttpGet" section for why every
                          // CachedNetworkImage call site in the app sets this.
                          imageRenderMethodForWeb:
                              ImageRenderMethodForWeb.HttpGet,
                          imageUrl: posterSrc(
                              it.posterUrl, cacheWidthFor(context, 96)),
                          memCacheWidth: cacheWidthFor(context, 96),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: AppTheme.surface2),
                        )
                      : const ColoredBox(color: AppTheme.surface2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textHigh,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(meta,
                          style: const TextStyle(
                              color: AppTheme.textMid, fontSize: 12.5)),
                    ],
                    if (_plot.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(_plot,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textLow,
                              fontSize: 12.5,
                              height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _play,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Riproduci'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _info,
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Dettagli'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Live event ─────────────────────────────────────────────────────────────

/// Live-event panel: header + the stream-source list. The **only** live
/// entry point on desktop — click a live card opens this; there's no
/// separate "info" vs "play" surface.
Future<void> showDesktopLiveDialog(
    BuildContext context, String pluginId, CatalogItem item) {
  return _panel(context, _LivePanel(pluginId: pluginId, item: item), maxW: 460);
}

class _LivePanel extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  const _LivePanel({required this.pluginId, required this.item});

  @override
  State<_LivePanel> createState() => _LivePanelState();
}

class _LivePanelState extends State<_LivePanel> {
  List<StreamSource> _sources = const [];
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _failed = false;
    });
    try {
      final res = await getIt<MediaRepository>()
          .getStreams(widget.pluginId, widget.item.id);
      if (mounted) {
        setState(() {
          _sources = res.sources;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
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
    final ex = it.extra;
    final competition = ex['competition'] ?? '';
    final sportCat = (ex['sport_cat'] ?? '').replaceAll('-', ' ');
    final plot = ex['plot'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _LiveDot(),
              SizedBox(width: 6),
              Text('IN DIRETTA',
                  style: TextStyle(
                      color: Color(0xFFFF3B3B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 6),
          Text(it.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          if (competition.isNotEmpty || sportCat.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [competition, sportCat].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(color: AppTheme.textMid, fontSize: 12),
              ),
            ),
          if (plot.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(plot,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textLow, fontSize: 12, height: 1.35)),
          ],
          const SizedBox(height: 16),
          const Text('SORGENTI',
              style: TextStyle(
                  color: AppTheme.textLow,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 6),
          if (!_loaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_failed)
            Row(children: [
              const Expanded(
                child: Text('Impossibile caricare le sorgenti.',
                    style: TextStyle(color: AppTheme.textMid)),
              ),
              TextButton(onPressed: _load, child: const Text('Riprova')),
            ])
          else if (_sources.isEmpty)
            const Text('Nessuna sorgente disponibile',
                style: TextStyle(color: AppTheme.textMid))
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
                    hoverColor: Colors.white10,
                    onTap: () => _play(s),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
            color: Color(0xFFFF3B3B), shape: BoxShape.circle),
      );
}

// ── Source picker (for resolveAndPlay) ──────────────────────────────────────

Future<StreamSource?> showDesktopSourcePicker(
    BuildContext context, List<StreamSource> sources) {
  return _panel<StreamSource>(
    context,
    Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SCEGLI LA SORGENTE',
              style: TextStyle(
                  color: AppTheme.textLow,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sources.length,
              itemBuilder: (ctx, i) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow_rounded,
                    color: AppTheme.textHigh),
                title: Text(
                  sources[i].label.isNotEmpty
                      ? sources[i].label
                      : 'Sorgente ${i + 1}',
                  style: const TextStyle(color: AppTheme.textHigh),
                ),
                onTap: () => Navigator.of(ctx).pop(sources[i]),
              ),
            ),
          ),
        ],
      ),
    ),
    maxW: 420,
  );
}
