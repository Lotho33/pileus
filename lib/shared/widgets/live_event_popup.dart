import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart';
import '../../core/theme/app_scale.dart';
import '../../core/utils/image_sizing.dart';
import '../../features/media/data/media_repository.dart';
import '../sdui/sport_theme.dart'
    show sportIcon, sportAccentColor, isLiveNow, liveStartTimeLabel;
import 'pileus_spinner.dart';
import 'tv_focusable.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

// ── Entry point ───────────────────────────────────────────────────────────────

void showLiveEventPopup(
    BuildContext context, String pluginId, CatalogItem item) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    builder: (_) => _LiveEventPopup(pluginId: pluginId, item: item),
  );
}

// ── Popup widget ──────────────────────────────────────────────────────────────

class _LiveEventPopup extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  const _LiveEventPopup({required this.pluginId, required this.item});

  @override
  State<_LiveEventPopup> createState() => _LiveEventPopupState();
}

class _LiveEventPopupState extends State<_LiveEventPopup> {
  List<StreamSource> _sources = [];
  bool _loaded = false;
  String? _error;
  final FocusNode _closeFocus = FocusNode();
  final FocusNode _firstSourceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closeFocus.dispose();
    _firstSourceFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = getIt<MediaRepository>();
      final res = await repo.getStreams(widget.pluginId, widget.item.id);
      if (mounted) {
        setState(() {
          _sources = res.sources;
          _loaded = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            (_sources.isNotEmpty ? _firstSourceFocus : _closeFocus)
                .requestFocus();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loaded = true;
        });
        // Same reasoning as the success path above: without this, a failed
        // getStreams (unstable network, backend plugin down) left the
        // popup's "Riprova" link with no focus anywhere in its tree —
        // D-pad dead until the physical Back key, since nothing here has
        // autofocus and _EpisodePopup's equivalent error path already
        // exists for exactly this reason.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _closeFocus.requestFocus();
        });
      }
    }
  }

  void _close() => Navigator.of(context).pop();

  void _play(StreamSource src) {
    final item = widget.item;
    final allIds = _sources.map((s) => s.id).toList();
    final allLabels = _sources.map((s) => s.label).toList();
    Navigator.of(context).pop();
    context.push(
      '/player/${widget.pluginId}/${Uri.encodeComponent(src.id)}',
      extra: {
        'streamId': src.id,
        'title': item.title,
        'sourceLabel': src.label,
        'isLive': true,
        'liveSources': allIds,
        'liveSourceLabels': allLabels,
        'livePluginId': widget.pluginId,
        'liveMediaId': item.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isLive = isLiveNow(item.extra);
    final startTime = liveStartTimeLabel(item.extra);
    final sportCat = item.extra['sport_cat'] ?? '';
    final plot = item.extra['plot'] ?? '';
    final poster = item.posterUrl;
    final homeBadge = item.extra['home_badge_url'] ?? '';
    final awayBadge = item.extra['away_badge_url'] ?? '';
    final hasBadges = homeBadge.isNotEmpty && awayBadge.isNotEmpty;
    final hasPoster = poster.isNotEmpty;
    final accent = sportAccentColor(sportCat);

    // Was a flat maxWidth: 620 + fixed 80/48 inset — pixel literals, unlike
    // the rest of the app's AppScale-relative (screen-height-anchored)
    // sizing. On a device whose logical screen size differs from the
    // 1080p-ish baseline these numbers were picked against, a fixed-pixel
    // dialog reads as comically oversized against everything else that
    // *does* scale with the screen — exactly this popup, reported as
    // enormous and squeezing the rest of the layout.
    final popupMaxW = AppScale.space(context, 620);
    final insetH = AppScale.space(context, 80);
    final insetV = AppScale.space(context, 48);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: insetH, vertical: insetV),
      child: TvFocusable(
        onEsc: _close,
        builder: (context, _) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: popupMaxW),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border:
                  Border.all(color: accent.withValues(alpha: 0.30), width: 1),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero image — full-width 16:9 ──────────────────────────────
                _HeroImage(
                  hasPoster: hasPoster,
                  poster: poster,
                  hasBadges: hasBadges,
                  homeBadge: homeBadge,
                  awayBadge: awayBadge,
                  accent: accent,
                  isLive: isLive,
                  onClose: _close,
                  closeFocus: _closeFocus,
                ),

                // ── Body ──────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sport chip + title row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (sportCat.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(6)),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.45)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(sportIcon(sportCat),
                                      size: AppScale.space(context, 12),
                                      color: accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    sportCat.toUpperCase().replaceAll('-', ' '),
                                    style: TextStyle(
                                        color: accent,
                                        fontSize: AppScale.space(context, 10),
                                        letterSpacing: 1.0,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (isLive)
                            const _LiveDot()
                          else if (startTime != null)
                            _LiveStartChip(startTime),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppScale.space(context, 20),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (plot.isNotEmpty && !isLive) ...[
                        const SizedBox(height: 6),
                        Text(plot,
                            maxLines: 2,
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: AppScale.space(context, 13),
                                height: 1.4)),
                      ],
                      const SizedBox(height: 16),
                      // Sources
                      if (!_loaded)
                        const _LoadingRow()
                      else if (_error != null)
                        _ErrorRow(
                            error: _error!,
                            onRetry: () {
                              setState(() {
                                _loaded = false;
                                _error = null;
                              });
                              _load();
                            })
                      else
                        _SourceRows(
                          sources: _sources,
                          accent: accent,
                          onPlay: _play,
                          firstFocus: _firstSourceFocus,
                          onNavigateUp: () => _closeFocus.requestFocus(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero image — full-width, covers poster or badges ─────────────────────────

class _HeroImage extends StatelessWidget {
  final bool hasPoster;
  final String poster;
  final bool hasBadges;
  final String homeBadge;
  final String awayBadge;
  final Color accent;
  final bool isLive;
  final VoidCallback onClose;
  final FocusNode closeFocus;

  const _HeroImage({
    required this.hasPoster,
    required this.poster,
    required this.hasBadges,
    required this.homeBadge,
    required this.awayBadge,
    required this.accent,
    required this.isLive,
    required this.onClose,
    required this.closeFocus,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.35),
                  const Color(0xFF111111)
                ],
              ),
            ),
          ),
          // Content
          if (hasPoster)
            CachedNetworkImage(
              // Web-only, no-op on every other platform — see image_sizing.dart's
              // "ImageRenderMethodForWeb.HttpGet" section for why every
              // CachedNetworkImage call site in the app sets this.
              imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
              imageUrl: poster,
              fit: BoxFit.cover,
              memCacheWidth: cacheWidthFor(context, 640),
              fadeInDuration: Duration.zero,
              errorWidget: (_, __, ___) => hasBadges
                  ? _BadgesContent(homeBadge: homeBadge, awayBadge: awayBadge)
                  : const SizedBox.shrink(),
            )
          else if (hasBadges)
            _BadgesContent(homeBadge: homeBadge, awayBadge: awayBadge),
          // Bottom fade into body
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF0E0E0E)],
                ),
              ),
            ),
          ),
          // Close button — top right
          Positioned(
            top: 10,
            right: 10,
            child: _CloseButton(onClose: onClose, focusNode: closeFocus),
          ),
        ],
      ),
    );
  }
}

class _BadgesContent extends StatelessWidget {
  final String homeBadge;
  final String awayBadge;
  const _BadgesContent({required this.homeBadge, required this.awayBadge});

  @override
  Widget build(BuildContext context) => Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgeLogo(url: homeBadge, size: AppScale.space(context, 90)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('vs',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: AppScale.space(context, 18),
                      fontWeight: FontWeight.w300)),
            ),
            _BadgeLogo(url: awayBadge, size: AppScale.space(context, 90)),
          ],
        ),
      );
}

// ── Live dot indicator ────────────────────────────────────────────────────────

class _LiveStartChip extends StatelessWidget {
  final String startTime;
  const _LiveStartChip(this.startTime);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: AppScale.space(context, 13), color: Colors.white54),
          const SizedBox(width: 4),
          Text('Inizio $startTime',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: AppScale.space(context, 11),
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: Color(0xFFFF3B3B), shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 5),
          Text('IN DIRETTA',
              style: TextStyle(
                  color: const Color(0xFFFF3B3B),
                  fontSize: AppScale.space(context, 11),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4)),
        ],
      );
}

// ── Close button ──────────────────────────────────────────────────────────────

class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;
  final FocusNode focusNode;
  const _CloseButton({required this.onClose, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onClose,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: focused
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: const BorderRadius.all(Radius.circular(17)),
          border: Border.all(color: focused ? Colors.white70 : Colors.white24),
        ),
        child: Icon(Icons.close_rounded,
            color: Colors.white, size: AppScale.space(context, 18)),
      ),
    );
  }
}

// ── Badge logo ────────────────────────────────────────────────────────────────

class _BadgeLogo extends StatelessWidget {
  final String url;
  final double size;
  const _BadgeLogo({required this.url, this.size = 72});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        // Web-only, no-op on every other platform — see image_sizing.dart's
        // "ImageRenderMethodForWeb.HttpGet" section for why every
        // CachedNetworkImage call site in the app sets this.
        imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        memCacheWidth: cacheWidthFor(context, size),
        fadeInDuration: Duration.zero,
        errorWidget: (_, __, ___) => SizedBox(width: size, height: size),
      );
}

// ── Loading / error rows ──────────────────────────────────────────────────────

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override
  Widget build(BuildContext context) => Row(children: [
        PileusSpinner(size: AppScale.spinnerS(context), color: Colors.white38),
        const SizedBox(width: 10),
        Text('Caricamento sorgenti...',
            style: TextStyle(
                color: Colors.white38, fontSize: AppScale.space(context, 13))),
      ]);
}

class _ErrorRow extends StatefulWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorRow({required this.error, required this.onRetry});

  @override
  State<_ErrorRow> createState() => _ErrorRowState();
}

class _ErrorRowState extends State<_ErrorRow> {
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Errore: ${widget.error}',
              style: TextStyle(
                  color: Colors.red, fontSize: AppScale.space(context, 12)),
              maxLines: 2),
          const SizedBox(height: 8),
          TvFocusable(
            onActivate: widget.onRetry,
            builder: (context, focused) => Text('Riprova',
                style: TextStyle(
                    color: focused ? Colors.white : Colors.white70,
                    fontSize: AppScale.space(context, 13),
                    fontWeight: focused ? FontWeight.w700 : FontWeight.normal,
                    decoration: TextDecoration.underline)),
          ),
        ],
      );
}

// ── Source rows ───────────────────────────────────────────────────────────────

class _SourceRows extends StatefulWidget {
  final List<StreamSource> sources;
  final Color accent;
  final void Function(StreamSource) onPlay;
  final FocusNode? firstFocus;
  final VoidCallback? onNavigateUp;
  const _SourceRows({
    required this.sources,
    required this.accent,
    required this.onPlay,
    this.firstFocus,
    this.onNavigateUp,
  });

  @override
  State<_SourceRows> createState() => _SourceRowsState();
}

class _SourceRowsState extends State<_SourceRows> {
  int _focused = 0;
  final _scroll = ScrollController();

  static const _kItemH = 50.0; // approximate height per row (padding + text)

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToItem(int i) {
    if (!_scroll.hasClients) return;
    final target = (i * _kItemH).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sources.isEmpty) {
      return Text('Nessuna sorgente disponibile',
          style: TextStyle(
              color: Colors.white38, fontSize: AppScale.space(context, 13)));
    }
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('SORGENTI',
            style: TextStyle(
                color: Colors.white38,
                fontSize: AppScale.space(context, 10),
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        ...List.generate(widget.sources.length, (i) {
          final src = widget.sources[i];
          final focused = _focused == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: TvFocusable(
              focusNode: i == 0 ? widget.firstFocus : null,
              onFocusChange: (v) {
                if (v) {
                  setState(() => _focused = i);
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToItem(i));
                }
              },
              onActivate: () => widget.onPlay(src),
              onUp: i == 0 ? () => widget.onNavigateUp?.call() : null,
              builder: (context, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: focused
                      ? widget.accent.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: focused
                        ? widget.accent.withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        color: focused ? Colors.white : Colors.white54,
                        size: AppScale.space(context, 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(src.label,
                          style: TextStyle(
                            color: focused ? Colors.white : Colors.white70,
                            fontSize: AppScale.space(context, 14),
                            fontWeight:
                                focused ? FontWeight.w600 : FontWeight.normal,
                          )),
                    ),
                    if (i == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.25),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5)),
                        ),
                        child: Text('MIGLIORE',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: AppScale.space(context, 9),
                                letterSpacing: 1)),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );

    // Cap the source list at ~6 visible rows; scrolls if more.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: AppScale.space(context, 320)),
      child: SingleChildScrollView(
        controller: _scroll,
        child: rows,
      ),
    );
  }
}
