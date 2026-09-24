import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/media/bloc/continue_watching_bloc.dart';
import '../features/media/bloc/continue_watching_event.dart';
import '../features/media/bloc/continue_watching_state.dart';
import '../features/media/bloc/plugin_bloc.dart';
import '../features/media/bloc/plugin_event.dart';
import '../features/media/bloc/plugin_state.dart';
import '../shared/responsive.dart';
import 'desktop_home_screen.dart';
import 'desktop_search_screen.dart';
import 'desktop_settings_pane.dart';
import 'widgets/desktop_nav_rail.dart';

/// The desktop home destination: a left rail (Home / Cerca / plugin list /
/// Impostazioni) beside a content area that swaps between the three panes.
/// Details / player push as full-screen routes on top.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  DesktopSection _section = DesktopSection.home;
  String? _activePluginId;
  bool _railExtended = true;

  // Continue-watching auto-refresh on return from the player — mirrors
  // _HomeViewState._onNav on TV (home_screen/home_view.dart). DesktopShell
  // stays mounted under `/player` (pushed with context.push, see
  // desktop_home_screen.dart:_resume), so without this the CW row here only
  // ever loads once (below) and after an explicit pull-to-refresh.
  bool _playerWasActive = false;
  Timer? _cwReloadTimer;
  Timer? _cwReloadTimer2;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    final pb = getIt<PluginBloc>();
    if (pb.state is PluginInitial) pb.add(const LoadPluginsEvent());
    final cw = getIt<ContinueWatchingBloc>();
    if (cw.state is ContinueWatchingInitial) {
      cw.add(const LoadContinueWatchingEvent());
    }
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
    super.dispose();
  }

  List<PluginInfo> _pluginsOf(PluginState s) =>
      s is PluginsLoaded ? s.plugins : const [];

  PluginInfo? _active(List<PluginInfo> plugins) {
    if (plugins.isEmpty) return null;
    for (final p in plugins) {
      if (p.pluginId == _activePluginId) return p;
    }
    return plugins.firstWhere((p) => p.isReady, orElse: () => plugins.first);
  }

  void _profileMenu() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<PluginBloc>()),
        BlocProvider.value(value: getIt<ContinueWatchingBloc>()),
      ],
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: BlocBuilder<PluginBloc, PluginState>(
          builder: (context, ps) {
            final plugins = _pluginsOf(ps);
            final active = _active(plugins);

            return ResponsiveBuilder(
              builder: (context, bp, _) {
                // Auto-collapse the rail on smaller windows.
                final extended = _railExtended && bp.atLeastExpanded;

                return Row(
                  children: [
                    DesktopNavRail(
                      extended: extended,
                      labelSize: bp.railLabelSize,
                      onToggleExtended: () =>
                          setState(() => _railExtended = !_railExtended),
                      section: _section,
                      onSection: (s) => setState(() => _section = s),
                      plugins: plugins,
                      activePluginId: active?.pluginId,
                      onPluginSelect: (id) => setState(() {
                        _activePluginId = id;
                        _section = DesktopSection.home;
                      }),
                      onProfile: _profileMenu,
                    ),
                    const VerticalDivider(width: 1, color: AppTheme.border),
                    Expanded(
                      child: RepaintBoundary(
                        child: IndexedStack(
                          index: _section.index,
                          children: [
                            _homePane(ps, active),
                            const DesktopSearchScreen(),
                            const DesktopSettingsPane(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _homePane(PluginState ps, PluginInfo? active) {
    if (ps is PluginLoading || ps is PluginInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ps is PluginError) {
      return _ErrorPane(
        message: ps.message,
        onRetry: () => context.read<PluginBloc>().add(const LoadPluginsEvent()),
      );
    }
    if (active == null) {
      return const _ErrorPane(message: 'Nessun plugin configurato sul server.');
    }
    return DesktopHomeScreen(key: ValueKey(active.pluginId), plugin: active);
  }
}

class _ErrorPane extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorPane({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppTheme.textLow, size: 48),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: AppTheme.textMid)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ],
      ),
    );
  }
}
