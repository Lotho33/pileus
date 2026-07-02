import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_sizing.dart';
import '../../features/player/resolve_and_play.dart';
import '../../shared/widgets/open_catalog_item.dart';
import 'desktop_dialogs.dart';

/// Point-and-click catalog card for the desktop rows. Hover lifts and scales
/// it and fades in a Play / Info overlay; left-click opens details,
/// right-click (or the ⋯ affordance) opens the quick-info panel. Live events
/// have a single surface (the live panel) — no separate info vs play.
class DesktopCard extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  final double width;
  final bool landscape;
  final double titleSize;

  /// Fixed height for the caption block (2 lines) — computed by the caller
  /// with the active text scale so the row height math can't be off.
  final double captionHeight;

  const DesktopCard({
    super.key,
    required this.pluginId,
    required this.item,
    required this.width,
    this.landscape = false,
    this.titleSize = 13.5,
    this.captionHeight = 40,
  });

  @override
  State<DesktopCard> createState() => _DesktopCardState();
}

class _DesktopCardState extends State<DesktopCard> {
  bool _hover = false;

  bool get _isLive => widget.item.mediaType == 'live';

  void _open() => _isLive
      ? showDesktopLiveDialog(context, widget.pluginId, widget.item)
      : openCatalogItem(context, widget.pluginId, widget.item);

  void _play() {
    final mt = widget.item.mediaType;
    if (_isLive) {
      showDesktopLiveDialog(context, widget.pluginId, widget.item);
    } else if (mt == 'movie' || mt == 'episode') {
      resolveAndPlay(
        context,
        widget.pluginId,
        widget.item.id,
        extra: {
          'title': widget.item.title,
          'poster': widget.item.posterUrl,
          'mediaType': mt,
        },
        sourcePicker: showDesktopSourcePicker,
      );
    } else {
      // Series / directory — the details page is where you pick an episode.
      _open();
    }
  }

  void _sheet() => _isLive
      ? showDesktopLiveDialog(context, widget.pluginId, widget.item)
      : showDesktopItemDialog(context, widget.pluginId, widget.item);

  @override
  Widget build(BuildContext context) {
    final ratio = widget.landscape ? 16 / 9 : 2 / 3;
    final imgW = cacheWidthFor(context, widget.width * 1.1);

    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _open,
          onSecondaryTap: _sheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _hover ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _hover
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: ratio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.item.posterUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: posterSrc(widget.item.posterUrl, imgW),
                              memCacheWidth: imgW,
                              fit: BoxFit.cover,
                              fadeInDuration:
                                  const Duration(milliseconds: 160),
                              placeholder: (_, __) =>
                                  const ColoredBox(color: AppTheme.surface2),
                              errorWidget: (_, __, ___) =>
                                  _Fallback(title: widget.item.title),
                            )
                          else
                            _Fallback(title: widget.item.title),
                          AnimatedOpacity(
                            opacity: _hover ? 1 : 0,
                            duration: const Duration(milliseconds: 130),
                            child: _HoverOverlay(
                              live: _isLive,
                              onPlay: _isLive ? _open : _play,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: widget.captionHeight,
                child: Text(
                  widget.item.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _hover ? AppTheme.textHigh : AppTheme.textMid,
                    fontSize: widget.titleSize,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverOverlay extends StatelessWidget {
  final bool live;
  final VoidCallback onPlay;
  const _HoverOverlay({required this.live, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    // A Play pill along the bottom of the poster — clicking the poster
    // itself already opens details, so there's no separate info button.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
          stops: [0.45, 1.0],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.textHigh.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        live
                            ? Icons.sensors_rounded
                            : Icons.play_arrow_rounded,
                        size: 18,
                        color: AppTheme.bg),
                    const SizedBox(width: 4),
                    Text(live ? 'Guarda' : 'Play',
                        style: const TextStyle(
                            color: AppTheme.bg,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String title;
  const _Fallback({required this.title});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface2,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            maxLines: 3,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textLow, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
