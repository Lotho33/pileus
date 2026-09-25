import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/theme/app_theme.dart';
import '../core/utils/image_sizing.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/media/active_plugin_controller.dart';
import '../features/media/bloc/continue_watching_bloc.dart';
import '../features/media/bloc/continue_watching_event.dart';
import '../features/media/bloc/continue_watching_state.dart';
import '../features/media/bloc/discovery_bloc.dart';
import '../features/media/bloc/discovery_event.dart';
import '../features/media/bloc/discovery_state.dart';
import '../features/media/bloc/plugin_bloc.dart';
import '../features/media/bloc/plugin_event.dart';
import '../features/media/bloc/plugin_state.dart';
import '../features/media/data/continue_watching_item.dart';
import '../features/media/data/media_repository.dart';
import '../features/player/episode_poster.dart' show episodeBadge;
import 'widgets/mobile_hero.dart';
import 'widgets/mobile_poster_card.dart';
import 'widgets/plugin_switcher_pill.dart';
import 'widgets/press_scale.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

class MobileHomeScreen extends StatelessWidget {
  const MobileHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pluginBloc = getIt<PluginBloc>();
    if (pluginBloc.state is PluginInitial) {
      pluginBloc.add(const LoadPluginsEvent());
    }
    final cwBloc = getIt<ContinueWatchingBloc>();
    if (cwBloc.state is ContinueWatchingInitial) {
      cwBloc.add(const LoadContinueWatchingEvent());
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: pluginBloc),
        BlocProvider.value(value: cwBloc),
      ],
      child: const _MobileHomeView(),
    );
  }
}

class _MobileHomeView extends StatefulWidget {
  const _MobileHomeView();

  @override
  State<_MobileHomeView> createState() => _MobileHomeViewState();
}

class _MobileHomeViewState extends State<_MobileHomeView> {
  // Shared with MobileSearchScreen (see the class doc) — replaces a local
  // `_activeId` field that only this screen ever saw.
  final _activePlugin = getIt<ActivePluginController>();

  // Continue-watching auto-refresh on return from the player — mirrors
  // _HomeViewState._onNav on TV (home_view.dart). Without this, the home
  // (kept alive in mobile_shell's IndexedStack) never re-loads the CW row
  // after watching something: it only reloads once, in build() above, and
  // the only other trigger is the user's own pull-to-refresh.
  bool _playerWasActive = false;
  Timer? _cwReloadTimer;
  Timer? _cwReloadTimer2;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _activePlugin.addListener(_onActiveChanged);
  }

  void _onActiveChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onNav);
      _router = router;
      router.routerDelegate.addListener(_onNav);
    }
  }

  void _onNav() {
    if (!mounted || _router == null) return;
    final path = _router!.routeInformationProvider.value.uri.path;
    if (path.startsWith('/player')) {
      _playerWasActive = true;
    } else if (_playerWasActive) {
      _playerWasActive = false;
      final bloc = getIt<ContinueWatchingBloc>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) bloc.add(const LoadContinueWatchingEvent());
      });
      // Retry after the player's fire-and-forget dispose-time save has had
      // time to reach mycelium and commit (same reasoning as TV's
      // home_view.dart:_onNav).
      _cwReloadTimer?.cancel();
      _cwReloadTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) bloc.add(const LoadContinueWatchingEvent());
      });
      // Safety net for a slow/loaded server where even the 1.5s retry above
      // loses the race against the player's fire-and-forget save.
      _cwReloadTimer2?.cancel();
      _cwReloadTimer2 = Timer(const Duration(milliseconds: 4000), () {
        if (mounted) bloc.add(const LoadContinueWatchingEvent());
      });
    }
  }

  @override
  void dispose() {
    _cwReloadTimer?.cancel();
    _cwReloadTimer2?.cancel();
    _router?.routerDelegate.removeListener(_onNav);
    _activePlugin.removeListener(_onActiveChanged);
    super.dispose();
  }

  List<PluginInfo> _pluginsOf(PluginState s) =>
      s is PluginsLoaded ? s.plugins : const [];

  /// Resolves the active plugin by identity, same as the pre-shared-state
  /// version — and re-seeds the shared controller (post-frame, not during
  /// build) whenever its current value doesn't match a real plugin: unset
  /// on first load, or pointing at one that's since vanished server-side.
  PluginInfo? _active(List<PluginInfo> plugins) {
    if (plugins.isEmpty) return null;
    final id = _activePlugin.value;
    PluginInfo? match;
    for (final p in plugins) {
      if (p.pluginId == id) match = p;
    }
    final found = match ??
        plugins.firstWhere((p) => p.isReady, orElse: () => plugins.first);
    if (found.pluginId != id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activePlugin.value = found.pluginId;
      });
    }
    return found;
  }

  void _profileSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_alt_outlined,
                  color: AppTheme.textMid),
              title: const Text('Cambia profilo',
                  style: TextStyle(color: AppTheme.textHigh)),
              onTap: () {
                Navigator.of(ctx).pop();
                getIt<AuthBloc>().add(const SwitchProfileEvent());
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
              title: const Text('Esci',
                  style: TextStyle(color: Color(0xFFFF6B6B))),
              onTap: () {
                Navigator.of(ctx).pop();
                getIt<AuthBloc>().add(const LogoutEvent());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PluginBloc, PluginState>(
      builder: (context, state) {
        final plugins = _pluginsOf(state);
        final active = _active(plugins);

        final Widget body = switch (state) {
          PluginLoading() ||
          PluginInitial() =>
            const Center(child: CircularProgressIndicator()),
          PluginError(:final message, :final certMismatch) => _ErrorBody(
              // certMismatch: see grpc_errors.dart:looksLikeCertificateMismatch
              // — the server IS reachable, the pinned TLS fingerprint just no
              // longer matches (e.g. mycelium reinstalled/reset).
              message: certMismatch
                  ? 'Il certificato del server è cambiato — probabilmente è '
                      'stato reinstallato o resettato. Ripeti la ricerca per '
                      'abbinarlo di nuovo.'
                  : message,
              onRetry: () =>
                  context.read<PluginBloc>().add(const LoadPluginsEvent()),
              onSecondary: certMismatch
                  ? () => getIt<AuthBloc>().add(const ChangeServerEvent())
                  : null,
              secondaryLabel: certMismatch ? 'Ripeti ricerca' : null,
            ),
          _ when plugins.isEmpty => const _ErrorBody(
              message: 'Nessun plugin configurato sul server.',
            ),
          _ when active != null => _PluginContent(
              key: ValueKey(active.pluginId),
              plugin: active,
            ),
          _ => const SizedBox.shrink(),
        };

        // A plain Column, not a Stack: the bar owns real layout height, so
        // nothing (hero backdrop, a hero-less live plugin's first row) ever
        // renders behind the wordmark or the plugin pills.
        return Column(
          children: [
            _HomeTopBar(
              plugins: plugins,
              active: active,
              onSelect: (id) => _activePlugin.value = id,
              onProfile: _profileSheet,
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

/// Opaque top bar: wordmark + profile button + the active-plugin switcher
/// pill, sitting above the scrolling content (never over it).
class _HomeTopBar extends StatelessWidget {
  final List<PluginInfo> plugins;
  final PluginInfo? active;
  final ValueChanged<String> onSelect;
  final VoidCallback onProfile;

  const _HomeTopBar({
    required this.plugins,
    required this.active,
    required this.onSelect,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bg,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/branding/pileus_wordmark.svg',
                        height: 26,
                        colorFilter: const ColorFilter.mode(
                            AppTheme.textHigh, BlendMode.srcIn),
                      ),
                      // The pill sits between the wordmark and the profile
                      // button rather than on a row of its own below
                      // (2026-09-16) — Expanded+Center so it's free to be
                      // absent (plugins.length <= 1) without leaving a gap,
                      // and doesn't fight the wordmark/profile button for
                      // space when its label is long.
                      Expanded(
                        child: Center(
                          child: PluginSwitcherPill(
                            plugins: plugins,
                            active: active,
                            onSelect: onSelect,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onProfile,
                        tooltip: 'Profilo',
                        icon: const CircleAvatar(
                          radius: 15,
                          backgroundColor: AppTheme.surface,
                          child: Icon(Icons.person_rounded,
                              size: 18, color: AppTheme.textMid),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppTheme.border),
        ],
      ),
    );
  }
}

class _PluginContent extends StatefulWidget {
  final PluginInfo plugin;
  const _PluginContent({super.key, required this.plugin});

  @override
  State<_PluginContent> createState() => _PluginContentState();
}

class _PluginContentState extends State<_PluginContent> {
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
  void didUpdateWidget(_PluginContent old) {
    super.didUpdateWidget(old);
    // Same plugin id (the parent keys us by it) but its catalog set can
    // still change — a plugin that becomes ready gains catalogs, or the
    // admin edits them. Reconcile: close blocs for gone catalogs, spawn
    // blocs for new ones. Without this, build's `_blocs[c.id]!` throws.
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
    context.read<PluginBloc>().add(const RefreshPluginsEvent(force: true));
    context.read<ContinueWatchingBloc>().add(const LoadContinueWatchingEvent());
    for (final c in _catalogs) {
      _blocs[c.id]?.add(LoadCatalogEvent(
        pluginId: widget.plugin.pluginId,
        catalogId: c.id,
        cacheTtlSeconds: c.cacheTtlSeconds,
        forceRefresh: true,
      ));
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plugin;

    // Not-ready plugin (needsConfig / syncing / error / no catalogs) — the
    // mobile parallel to the TV _PluginNotReadyPage. Without this the home
    // just shows the top bar over an empty list.
    final ({IconData icon, String title, String sub})? notReady = p.needsConfig
        ? (
            icon: Icons.settings_outlined,
            title: 'Configurazione richiesta',
            sub: 'Configura ${p.name} dal pannello admin.'
          )
        : p.statusLabel == 'syncing'
            ? (
                icon: Icons.sync_rounded,
                title: 'Sincronizzazione in corso…',
                sub: p.statusDetail.isNotEmpty
                    ? p.statusDetail
                    : '${p.name} sta sincronizzando i contenuti.'
              )
            : p.statusLabel == 'error'
                ? (
                    icon: Icons.error_outline_rounded,
                    title: 'Errore plugin',
                    sub: p.statusDetail.isNotEmpty
                        ? p.statusDetail
                        : '${p.name} ha segnalato un errore.'
                  )
                : _catalogs.isEmpty
                    ? (
                        icon: Icons.inbox_outlined,
                        title: 'Nessun contenuto',
                        sub: 'Questo plugin non espone cataloghi.'
                      )
                    : null;

    if (notReady != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
            Icon(notReady.icon, size: 48, color: AppTheme.textLow),
            const SizedBox(height: 16),
            Text(notReady.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(notReady.sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMid)),
            ),
          ],
        ),
      );
    }

    final hero = _heroCatalog;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (hero != null)
            BlocBuilder<DiscoveryBloc, DiscoveryState>(
              bloc: _blocs[hero.id],
              builder: (context, s) {
                if (s is DiscoveryLoaded && s.items.isNotEmpty) {
                  return MobileHero(
                    pluginId: widget.plugin.pluginId,
                    item: s.items.first,
                  );
                }
                return SizedBox(
                  height: (MediaQuery.sizeOf(context).height * 0.56)
                      .clamp(420.0, 560.0),
                  child: const ColoredBox(color: AppTheme.surface),
                );
              },
            ),
          _CwRail(pluginId: widget.plugin.pluginId),
          for (final c in _catalogs)
            _CatalogRow(
              pluginId: widget.plugin.pluginId,
              def: c,
              bloc: _blocs[c.id]!,
              skipFirst: c.id == hero?.id,
            ),
        ],
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  final String pluginId;
  final CatalogDef def;
  final DiscoveryBloc bloc;
  final bool skipFirst;

  const _CatalogRow({
    required this.pluginId,
    required this.def,
    required this.bloc,
    required this.skipFirst,
  });

  @override
  Widget build(BuildContext context) {
    final landscape = def.cardLayout == 'landscape' || def.type == 'live';
    final cardW = landscape ? 240.0 : 124.0;
    final rowH = (landscape ? cardW * 9 / 16 : cardW * 3 / 2) + 44;

    return BlocBuilder<DiscoveryBloc, DiscoveryState>(
      bloc: bloc,
      builder: (context, s) {
        Widget body;
        if (s is DiscoveryLoaded) {
          var items = s.items;
          // Drop the item promoted to the hero — even when it's the only one
          // in this catalog (else it shows both as hero and as a lone card).
          if (skipFirst && items.isNotEmpty) items = items.sublist(1);
          if (items.isEmpty) return const SizedBox.shrink();
          body = ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => MobilePosterCard(
              pluginId: pluginId,
              item: items[i],
              width: cardW,
              landscape: landscape,
            ),
          );
        } else if (s is DiscoveryError) {
          return const SizedBox.shrink();
        } else {
          body = ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: cardW,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  def.name,
                  style: const TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: rowH, child: body),
            ],
          ),
        );
      },
    );
  }
}

class _CwRail extends StatelessWidget {
  final String pluginId;
  const _CwRail({required this.pluginId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContinueWatchingBloc, ContinueWatchingState>(
      builder: (context, s) {
        if (s is! ContinueWatchingLoaded) return const SizedBox.shrink();
        // Only this plugin's own resume entries — a title from another
        // plugin belongs on that plugin's home, not here.
        final items = s.items.where((i) => i.providerID == pluginId).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Continua a guardare',
                  style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                // +14 over the old constant: room for the series-name
                // overline the card can now show above the episode title.
                height: 240 * 9 / 16 + 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _CwCard(item: items[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CwCard extends StatelessWidget {
  final ContinueWatchingItem item;
  const _CwCard({required this.item});

  void _resume(BuildContext context) => context.push(
        '/player/${item.providerID}/${Uri.encodeComponent(item.playableID)}',
        extra: <String, dynamic>{
          // playableID is an already-resolved stream id — pass it as
          // streamId so the player calls ResolveStream directly instead of
          // re-running GetStreams on a stream id (which some plugins reject).
          'streamId': item.playableID,
          'title': item.title,
          'showTitle': item.showTitle,
          'poster': item.poster,
          'parentId': item.parentID,
          // A "next episode" CW row parked at ~31s (just to clear mycelium's
          // progress_time >= 30 filter) is not a real resume point.
          'seekTo': (item.totalTime <= 0 && item.progressTime <= 35)
              ? 0
              : item.progressTime.toInt(),
        },
      );

  void _sheet(BuildContext context) {
    final cwBloc = context.read<ContinueWatchingBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                item.showTitle.isNotEmpty ? item.showTitle : item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded,
                  color: AppTheme.textHigh),
              title: const Text('Riprendi',
                  style: TextStyle(color: AppTheme.textHigh)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _resume(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded,
                  color: AppTheme.textMid),
              title: const Text('Dettagli',
                  style: TextStyle(color: AppTheme.textHigh)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                // For an episode, parentID is the season/show directory —
                // that's what getDetails resolves to the series page (with
                // its season picker). Movies have no parent → the item id.
                final target =
                    item.parentID.isNotEmpty ? item.parentID : item.playableID;
                context.push(
                    '/details/${item.providerID}/${Uri.encodeComponent(target)}');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
              title: const Text('Rimuovi da Continua a guardare',
                  style: TextStyle(color: Color(0xFFFF6B6B))),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                cwBloc.add(RemoveContinueWatchingEvent(
                    item.providerID, item.playableID));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Rimosso da Continua a guardare'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const w = 240.0;
    final imgW = cacheWidthFor(context, w);
    return SizedBox(
      width: w,
      child: PressScale(
        onTap: () => _resume(context),
        onLongPress: () => _sheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: item.poster.isNotEmpty
                        ? CachedNetworkImage(
                            // Web-only, no-op on every other platform — see image_sizing.dart's
                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                            // CachedNetworkImage call site in the app sets this.
                            imageRenderMethodForWeb:
                                ImageRenderMethodForWeb.HttpGet,
                            imageUrl: posterSrc(item.poster, imgW, proxy: true),
                            memCacheWidth: imgW,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 180),
                            placeholder: (_, __) =>
                                const ColoredBox(color: AppTheme.surface2),
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: AppTheme.surface2),
                          )
                        : const ColoredBox(color: AppTheme.surface2),
                  ),
                  if (item.progressFraction > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: item.progressFraction,
                        minHeight: 3,
                        backgroundColor: Colors.black45,
                        color: AppTheme.primary,
                      ),
                    ),
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white70, size: 40),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Series name (overline) + what's actually playing (episode/movie
            // title) — was collapsed to just the series name before, which
            // silently dropped the episode number/name entirely. Matches the
            // TV card's overline+title convention. "S{x} · E{y}" rides on
            // the same line when known — see episode_poster.dart's
            // episodeBadge().
            Builder(builder: (_) {
              final showOverline = item.showTitle.isNotEmpty &&
                  item.showTitle.toLowerCase() != item.title.toLowerCase();
              final badge = episodeBadge(item.seasonNumber, item.episodeNumber);
              if (!showOverline && badge.isEmpty) {
                return const SizedBox.shrink();
              }
              final text = showOverline
                  ? (badge.isEmpty
                      ? item.showTitle
                      : '${item.showTitle} · $badge')
                  : badge;
              return Text(
                text,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textLow, fontSize: 11),
              );
            }),
            Text(
              item.title,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMid, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  const _ErrorBody({
    required this.message,
    this.onRetry,
    this.onSecondary,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppTheme.textLow, size: 44),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMid)),
            if (onRetry != null || onSecondary != null) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                children: [
                  if (onRetry != null)
                    FilledButton(
                        onPressed: onRetry, child: const Text('Riprova')),
                  if (onSecondary != null && secondaryLabel != null)
                    OutlinedButton(
                        onPressed: onSecondary, child: Text(secondaryLabel!)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
