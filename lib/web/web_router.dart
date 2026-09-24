import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/router/auth_guard.dart';
import '../core/theme/app_theme.dart';
// The responsive UI is shared with the desktop build. These screens are
// dart:io-free, so they link fine for web.
import '../desktop/desktop_details_screen.dart';
import '../desktop/desktop_pairing_screen.dart';
import '../desktop/desktop_profiles_screen.dart';
import '../desktop/desktop_shell.dart';
import '../desktop/desktop_splash_screen.dart';
// Below `Breakpoint.compact` width (phone/PWA), the mobile flavor's own
// screens render instead — see web_responsive.dart. Also dart:io-free
// (mobile_discovery_screen.dart is the one exception in lib/mobile/, and
// nothing here pulls it in — web keeps its own WebDiscoveryScreen).
import '../features/media/presentation/browse_screen.dart';
import '../features/media/presentation/episode_detail_screen.dart';
import '../features/media/presentation/plugin_settings_screen.dart';
import '../mobile/mobile_details_screen.dart';
import '../mobile/mobile_plugins_screen.dart';
import '../mobile/mobile_preferences_screen.dart';
import '../mobile/mobile_profile_settings_screen.dart';
import '../mobile/mobile_settings_screen.dart';
import '../mobile/mobile_shell.dart';
import 'web_discovery_screen.dart';
import 'web_playback_screen.dart';
import 'web_responsive.dart';

/// Web router. Same shape as the desktop router, but discovery + player are
/// web-native (no `dart:io` socket probe, HTML5 `<video>` playback), and
/// `/home` + `/details` switch between the desktop and mobile shells by
/// viewport width (see web_responsive.dart). The `/settings/*` sub-routes
/// and `/browse`, `/episode`, `/plugin-settings` only exist for the mobile
/// shell's own navigation (DesktopShell keeps settings as an in-shell pane,
/// never pushes to them) — harmless to register unconditionally either way.
final GoRouter webRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const DesktopSplashScreen()),
    GoRoute(path: '/discovery', builder: (_, __) => const WebDiscoveryScreen()),
    GoRoute(path: '/pairing', builder: (_, __) => const DesktopPairingScreen()),
    GoRoute(
        path: '/profiles', builder: (_, __) => const DesktopProfilesScreen()),
    GoRoute(
      path: '/home',
      builder: (context, __) => webResponsive(
        context,
        mobile: (_) => const MobileShell(),
        desktop: (_) => const DesktopShell(),
      ),
    ),
    GoRoute(
      path: '/details/:pluginId/:mediaId',
      builder: (context, state) {
        final pluginId = state.pathParameters['pluginId']!;
        final mediaId = Uri.decodeComponent(state.pathParameters['mediaId']!);
        final preview =
            state.extra is CatalogItem ? state.extra as CatalogItem : null;
        return webResponsive(
          context,
          mobile: (_) => MobileDetailsScreen(
              pluginId: pluginId, mediaId: mediaId, preview: preview),
          desktop: (_) => DesktopDetailsScreen(
              pluginId: pluginId, mediaId: mediaId, preview: preview),
        );
      },
    ),
    GoRoute(
      path: '/browse/:pluginId/:parentId',
      builder: (_, state) => BrowseScreen(
        pluginId: state.pathParameters['pluginId']!,
        parentId: Uri.decodeComponent(state.pathParameters['parentId']!),
        title: state.extra as String? ?? '',
      ),
    ),
    GoRoute(
      path: '/episode/:pluginId/:mediaId',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return EpisodeDetailScreen(
          pluginId: state.pathParameters['pluginId']!,
          mediaId: Uri.decodeComponent(state.pathParameters['mediaId']!),
          episodeList:
              (extra?['episodeList'] as List?)?.cast<String>() ?? const [],
          episodeTitles:
              (extra?['episodeTitles'] as List?)?.cast<String>() ?? const [],
          episodeIndex: extra?['episodeIndex'] as int? ?? -1,
          allSeasonIds:
              (extra?['allSeasonIds'] as List?)?.cast<String>() ?? const [],
          allSeasonLabels:
              (extra?['allSeasonLabels'] as List?)?.cast<String>() ?? const [],
          seasonIndex: extra?['seasonIndex'] as int? ?? 0,
          showTitle: extra?['showTitle'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/player/:pluginId/:mediaId',
      name: 'player',
      builder: (_, state) => WebPlaybackScreen(
        pluginId: state.pathParameters['pluginId']!,
        mediaId: Uri.decodeComponent(state.pathParameters['mediaId']!),
        extra: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(
      path: '/plugin-settings/:pluginId',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return PluginSettingsScreen(
          pluginId: state.pathParameters['pluginId']!,
          pluginName: extra?['pluginName'] as String? ?? '',
        );
      },
    ),
    GoRoute(
        path: '/settings', builder: (_, __) => const MobileSettingsScreen()),
    GoRoute(
        path: '/settings/profile',
        builder: (_, __) => const MobileProfileSettingsScreen()),
    GoRoute(
        path: '/settings/preferences',
        builder: (_, __) => const MobilePreferencesScreen()),
    GoRoute(
        path: '/settings/plugins',
        builder: (_, __) => const MobilePluginsScreen()),
  ],
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: AppTheme.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pagina non trovata',
              style: TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 8),
          Text('${state.uri}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => webRouter.go('/home'),
            child: const Text('Home'),
          ),
        ],
      ),
    ),
  ),
  redirect: (context, state) => authGuardRedirect(state),
);
