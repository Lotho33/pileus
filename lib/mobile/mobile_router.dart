import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/grpc/auth_interceptor.dart';

import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../features/media/presentation/browse_screen.dart';
import '../features/media/presentation/episode_detail_screen.dart';
import '../features/media/presentation/plugin_settings_screen.dart';
import 'mobile_details_screen.dart';
import 'mobile_discovery_screen.dart';
import 'mobile_orientation_observer.dart';
import 'mobile_pairing_screen.dart';
import 'mobile_playback_screen.dart';
import 'mobile_plugins_screen.dart';
import 'mobile_preferences_screen.dart';
import 'mobile_profile_settings_screen.dart';
import 'mobile_profiles_screen.dart';
import 'mobile_settings_screen.dart';
import 'mobile_shell.dart';
import 'mobile_splash_screen.dart';

/// Mobile router. `/home` is the bottom-nav shell (Home / Cerca /
/// Impostazioni). Splash, discovery, pairing, profiles, home, search,
/// details, settings tree and player are mobile-native (`lib/mobile/`);
/// `/browse`, `/episode` and `/plugin-settings` still reuse the shared
/// `lib/features/media/presentation` screens (they lay out acceptably on a
/// phone even though they're D-pad-tuned).
final GoRouter mobileRouter = GoRouter(
  initialLocation: '/splash',
  observers: [MobileOrientationObserver()],
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const MobileSplashScreen()),
    GoRoute(
        path: '/discovery',
        builder: (_, __) => const MobileDiscoveryScreen()),
    GoRoute(
        path: '/pairing', builder: (_, __) => const MobilePairingScreen()),
    GoRoute(
        path: '/profiles',
        builder: (_, __) => const MobileProfilesScreen()),
    GoRoute(path: '/home', builder: (_, __) => const MobileShell()),
    GoRoute(
      path: '/details/:pluginId/:mediaId',
      builder: (_, state) => MobileDetailsScreen(
        pluginId: state.pathParameters['pluginId']!,
        mediaId: Uri.decodeComponent(state.pathParameters['mediaId']!),
        preview: state.extra is CatalogItem ? state.extra as CatalogItem : null,
      ),
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
      builder: (_, state) => MobilePlaybackScreen(
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
    GoRoute(path: '/settings', builder: (_, __) => const MobileSettingsScreen()),
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
    backgroundColor: const Color(0xFF0D0D1A),
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
            onPressed: () => mobileRouter.go('/home'),
            child: const Text('Home'),
          ),
        ],
      ),
    ),
  ),
  redirect: (context, state) {
    const authFlow = {'/splash', '/discovery', '/pairing', '/profiles'};
    if (authFlow.contains(state.uri.path)) return null;
    if (!getIt<AuthInterceptor>().hasCredentials) return '/splash';
    return null;
  },
);
