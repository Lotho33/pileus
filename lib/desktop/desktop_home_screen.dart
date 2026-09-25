import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/theme/app_theme.dart';
import '../core/utils/image_sizing.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/media/bloc/continue_watching_bloc.dart';
import '../features/media/bloc/continue_watching_event.dart';
import '../features/media/bloc/continue_watching_state.dart';
import '../features/media/bloc/discovery_bloc.dart';
import '../features/media/bloc/discovery_event.dart';
import '../features/media/bloc/discovery_state.dart';
import '../features/media/data/continue_watching_item.dart';
import '../features/media/data/media_repository.dart';
import '../features/player/episode_poster.dart' show episodeBadge;
import '../shared/responsive.dart';
import 'widgets/desktop_card.dart';
import 'widgets/desktop_dialogs.dart';
import 'widgets/desktop_hero.dart';
import 'widgets/media_row.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Home for the active plugin: a wide hero + horizontal rows (Continue
/// watching, then each catalog). One [DiscoveryBloc] per catalog, reconciled
/// on plugin/catalog change — same pattern as the mobile home.
class DesktopHomeScreen extends StatefulWidget {
  final PluginInfo plugin;
  const DesktopHomeScreen({super.key, required this.plugin});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  final _blocs = <String, DiscoveryBloc>{};

  List<CatalogDef> get _catalogs => widget.plugin.catalogs;

  CatalogDef? get _heroCatalog {
    for (final c in _catalogs) {
      if (c.type != 'live' && !c.disableHeroBackground) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _syncBlocs();
  }

  @override
  void didUpdateWidget(DesktopHomeScreen old) {
    super.didUpdateWidget(old);
    _syncBlocs();
  }

  @override
  void dispose() {
    for (final b in _blocs.values) {
      b.close();
    }
    super.dispose();
  }

  void _syncBlocs() {
    final wanted = _catalogs.map((c) => c.id).toSet();
    for (final gone in _blocs.keys.where((k) => !wanted.contains(k)).toList()) {
      _blocs.remove(gone)?.close();
    }
    for (final c in _catalogs) {
      if (_blocs.containsKey(c.id)) continue;
      _blocs[c.id] = DiscoveryBloc(
        getIt<MediaRepository>(),
        onSessionExpired: () =>
            getIt<AuthBloc>().add(const SessionExpiredEvent()),
      )..add(LoadCatalogEvent(
          pluginId: widget.plugin.pluginId,
          catalogId: c.id,
          cacheTtlSeconds: c.cacheTtlSeconds,
        ));
    }
  }

  Future<void> _refresh() async {
    context.read<ContinueWatchingBloc>().add(const LoadContinueWatchingEvent());
    for (final c in _catalogs) {
      _blocs[c.id]?.add(LoadCatalogEvent(
        pluginId: widget.plugin.pluginId,
        catalogId: c.id,
        cacheTtlSeconds: c.cacheTtlSeconds,
        forceRefresh: true,
      ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plugin;
    final notReady = _notReadyCopy(p);
    if (notReady != null) {
      return _CenteredNotice(
          icon: notReady.$1, title: notReady.$2, sub: notReady.$3);
    }

    final hero = _heroCatalog;

    return ResponsiveBuilder(
      builder: (context, bp, c) {
        return RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: 0,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              if (hero != null)
                BlocBuilder<DiscoveryBloc, DiscoveryState>(
                  bloc: _blocs[hero.id],
                  builder: (context, s) {
                    if (s is DiscoveryLoaded && s.items.isNotEmpty) {
                      return DesktopHero(
                        pluginId: p.pluginId,
                        item: s.items.first,
                        bp: bp,
                        height: (c.maxHeight * 0.62).clamp(440.0, 760.0),
                      );
                    }
                    return SizedBox(
                      height: (c.maxHeight * 0.62).clamp(420.0, 720.0),
                      child: const ColoredBox(color: AppTheme.surface),
                    );
                  },
                ),
              _MaxWidth(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _CwRow(pluginId: p.pluginId, bp: bp),
                    for (final cat in _catalogs)
                      _CatalogRowView(
                        pluginId: p.pluginId,
                        def: cat,
                        bloc: _blocs[cat.id]!,
                        skipFirst: cat.id == hero?.id,
                        bp: bp,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  (IconData, String, String)? _notReadyCopy(PluginInfo p) {
    if (p.needsConfig) {
      return (
        Icons.settings_outlined,
        'Configurazione richiesta',
        'Configura ${p.name} dal pannello admin.'
      );
    }
    if (p.statusLabel == 'syncing') {
      return (
        Icons.sync_rounded,
        'Sincronizzazione in corso…',
        p.statusDetail.isNotEmpty
            ? p.statusDetail
            : '${p.name} sta sincronizzando i contenuti.'
      );
    }
    if (p.statusLabel == 'error') {
      return (
        Icons.error_outline_rounded,
        'Errore plugin',
        p.statusDetail.isNotEmpty
            ? p.statusDetail
            : '${p.name} ha segnalato un errore.'
      );
    }
    if (_catalogs.isEmpty) {
      return (
        Icons.inbox_outlined,
        'Nessun contenuto',
        'Questo plugin non espone cataloghi.'
      );
    }
    return null;
  }
}

/// Clamp row content to a sane max width and pin it to the LEFT — so the
/// rows line up with the hero's copy instead of drifting to screen centre
/// on a wide monitor.
class _MaxWidth extends StatelessWidget {
  final Widget child;
  const _MaxWidth({required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: child,
      ),
    );
  }
}

class _CatalogRowView extends StatelessWidget {
  final String pluginId;
  final CatalogDef def;
  final DiscoveryBloc bloc;
  final bool skipFirst;
  final Breakpoint bp;

  const _CatalogRowView({
    required this.pluginId,
    required this.def,
    required this.bloc,
    required this.skipFirst,
    required this.bp,
  });

  @override
  Widget build(BuildContext context) {
    final landscape = def.cardLayout == 'landscape' || def.type == 'live';
    final cardW = landscape ? bp.cardWidth * 1.8 : bp.cardWidth;
    final imgH = landscape ? cardW * 9 / 16 : cardW * 3 / 2;
    final capH = captionBoxHeight(context, bp.cardTitleSize);
    // + 8 gap + 24 headroom so the hover scale / shadow isn't clipped.
    final rowH = imgH + 8 + capH + 24;

    return BlocBuilder<DiscoveryBloc, DiscoveryState>(
      bloc: bloc,
      builder: (context, s) {
        if (s is! DiscoveryLoaded) {
          if (s is DiscoveryError) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 22),
            child: SizedBox(
              height: rowH,
              child: _SkeletonRow(cardW: cardW, gutter: bp.gutter),
            ),
          );
        }
        var items = s.items;
        if (skipFirst && items.isNotEmpty) items = items.sublist(1);
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: MediaRow(
            title: def.name,
            rowHeight: rowH,
            pageStep: cardW + 14,
            gutter: bp.gutter,
            titleSize: bp.rowTitleSize,
            itemCount: items.length,
            itemBuilder: (_, i) => DesktopCard(
              pluginId: pluginId,
              item: items[i],
              width: cardW,
              landscape: landscape,
              titleSize: bp.cardTitleSize,
              captionHeight: capH,
            ),
          ),
        );
      },
    );
  }
}

class _CwRow extends StatelessWidget {
  final String pluginId;
  final Breakpoint bp;
  const _CwRow({required this.pluginId, required this.bp});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContinueWatchingBloc, ContinueWatchingState>(
      builder: (context, s) {
        if (s is! ContinueWatchingLoaded) return const SizedBox.shrink();
        final items = s.items.where((i) => i.providerID == pluginId).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final cardW = bp.cardWidth * 1.8;
        // 16:9 art + 1-line caption + gap + hover headroom.
        final rowH = cardW * 9 / 16 +
            8 +
            MediaQuery.textScalerOf(context).scale(13) * 1.3 +
            24;
        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: MediaRow(
            title: 'Continua a guardare',
            rowHeight: rowH,
            pageStep: cardW + 14,
            gutter: bp.gutter,
            titleSize: bp.rowTitleSize,
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final it = items[i];
              // "S{x} · E{y}" rides on the same single-line caption this
              // tile has room for, rather than adding a new row — see
              // episode_poster.dart's episodeBadge().
              final badge = episodeBadge(it.seasonNumber, it.episodeNumber);
              final baseTitle =
                  it.showTitle.isNotEmpty ? it.showTitle : it.title;
              return _CwTile(
                width: cardW,
                title: badge.isEmpty ? baseTitle : '$baseTitle · $badge',
                poster: it.poster,
                fraction: it.progressFraction,
                onResume: () => _resume(ctx, it),
                onDetails: () => _details(ctx, it),
                onRemove: () => _remove(ctx, it),
              );
            },
          ),
        );
      },
    );
  }

  void _resume(BuildContext context, ContinueWatchingItem it) {
    // playableID is an already-resolved stream id — pass it as streamId so
    // the player calls ResolveStream directly (same as the mobile CW tap).
    context.push(
      '/player/${it.providerID}/${Uri.encodeComponent(it.playableID)}',
      extra: <String, dynamic>{
        'streamId': it.playableID,
        'title': it.title,
        'showTitle': it.showTitle,
        'poster': it.poster,
        'parentId': it.parentID,
        'seekTo': (it.totalTime <= 0 && it.progressTime <= 35)
            ? 0
            : it.progressTime.toInt(),
      },
    );
  }

  void _details(BuildContext context, ContinueWatchingItem it) {
    // For an episode, parentID resolves to the series page; movies use the id.
    final target = it.parentID.isNotEmpty ? it.parentID : it.playableID;
    context.push('/details/${it.providerID}/${Uri.encodeComponent(target)}');
  }

  void _remove(BuildContext context, ContinueWatchingItem it) {
    context
        .read<ContinueWatchingBloc>()
        .add(RemoveContinueWatchingEvent(it.providerID, it.playableID));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Rimosso da Continua a guardare'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }
}

class _CwTile extends StatefulWidget {
  final double width;
  final String title;
  final String poster;
  final double fraction;
  final VoidCallback onResume;
  final VoidCallback onDetails;
  final VoidCallback onRemove;
  const _CwTile({
    required this.width,
    required this.title,
    required this.poster,
    required this.fraction,
    required this.onResume,
    required this.onDetails,
    required this.onRemove,
  });

  @override
  State<_CwTile> createState() => _CwTileState();
}

class _CwTileState extends State<_CwTile> {
  bool _hover = false;

  Future<void> _menu() async {
    final picked = await showDesktopActionDialog(
      context,
      title: widget.title,
      actions: const [
        DesktopAction('resume', Icons.play_arrow_rounded, 'Riprendi'),
        DesktopAction('details', Icons.info_outline_rounded, 'Dettagli'),
        DesktopAction('remove', Icons.delete_outline_rounded,
            'Rimuovi da Continua a guardare',
            danger: true),
      ],
    );
    switch (picked) {
      case 'resume':
        widget.onResume();
      case 'details':
        widget.onDetails();
      case 'remove':
        widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onResume,
          onSecondaryTap: _menu,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _hover ? 1.04 : 1,
                duration: const Duration(milliseconds: 130),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.poster.isNotEmpty
                            ? CachedNetworkImage(
                                // Web-only, no-op on every other platform — see image_sizing.dart's
                                // "ImageRenderMethodForWeb.HttpGet" section for why every
                                // CachedNetworkImage call site in the app sets this.
                                imageRenderMethodForWeb:
                                    ImageRenderMethodForWeb.HttpGet,
                                imageUrl: posterSrc(widget.poster,
                                    cacheWidthFor(context, widget.width),
                                    proxy: true),
                                memCacheWidth:
                                    cacheWidthFor(context, widget.width),
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const ColoredBox(color: AppTheme.surface2),
                                errorWidget: (_, __, ___) =>
                                    const ColoredBox(color: AppTheme.surface2))
                            : const ColoredBox(color: AppTheme.surface2),
                        const Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white70, size: 42),
                        ),
                        if (_hover)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: _menu,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.6),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.more_horiz_rounded,
                                    size: 16, color: AppTheme.textHigh),
                              ),
                            ),
                          ),
                        if (widget.fraction > 0)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              value: widget.fraction,
                              minHeight: 3,
                              backgroundColor: Colors.black45,
                              color: AppTheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _hover ? AppTheme.textHigh : AppTheme.textMid,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  final double cardW;
  final double gutter;
  const _SkeletonRow({required this.cardW, required this.gutter});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (_, __) => Container(
        width: cardW,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _CenteredNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _CenteredNotice(
      {required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppTheme.textLow),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMid)),
          ],
        ),
      ),
    );
  }
}
