import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../perf_profile.dart';
import 'auth_guard.dart';

import '../../features/auth/presentation/device_pairing_screen.dart';
import '../../features/auth/presentation/server_discovery_screen.dart';
import '../../features/auth/presentation/profile_selection_screen.dart';
import '../../features/media/presentation/browse_screen.dart';
import '../../features/media/presentation/details_screen.dart';
import '../../features/media/presentation/episode_detail_screen.dart';
import '../../features/media/presentation/home_screen.dart';
import '../../features/media/presentation/plugin_settings_screen.dart';
import '../../features/media/presentation/search_screen.dart';
import '../../features/player/presentation/playback_screen.dart';
import '../../features/settings/presentation/preferences_screen.dart';
import '../../features/settings/presentation/profile_settings_screen.dart';
import '../../features/settings/presentation/settings_plugins_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../shared/presentation/splash_screen.dart';

// THE screen transition — used for every route so navigating anywhere in
// the app looks identical (the auth flow and /home used to get a different,
// longer plain fade). 200ms, symmetric forward/back, no slide: a pure
// cross-fade paired with a very small scale-up (0.97→1.0, well short of a
// slide) that gives incoming content a "settling into place" feel.
Page<T> _fadePage<T>(GoRouterState state, Widget child) =>
    CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      // "Hardware modesto": no route transition at all. The fade/scale
      // composites the incoming screen into an offscreen layer for 200ms
      // right while it's doing its heaviest build — worst possible overlap
      // on a weak, RAM-starved box. Instant swap instead.
      transitionDuration:
          lowPowerUi ? Duration.zero : const Duration(milliseconds: 200),
      reverseTransitionDuration:
          lowPowerUi ? Duration.zero : const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) {
        if (lowPowerUi) return child;
        // Fade only — the old 0.97→1.0 ScaleTransition put a transform on the
        // whole incoming screen for 200ms right as it does its heaviest
        // build; the fade alone reads just as smooth for a fraction of the
        // compositing cost.
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: '/discovery',
      pageBuilder: (_, state) =>
          _fadePage(state, const ServerDiscoveryScreen()),
    ),
    GoRoute(
      path: '/pairing',
      pageBuilder: (_, state) => _fadePage(state, const DevicePairingScreen()),
    ),
    GoRoute(
      path: '/profiles',
      pageBuilder: (_, state) =>
          _fadePage(state, const ProfileSelectionScreen()),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/details/:pluginId/:mediaId',
      pageBuilder: (_, state) => _fadePage(
          state,
          DetailsScreen(
            pluginId: state.pathParameters['pluginId']!,
            mediaId: Uri.decodeComponent(state.pathParameters['mediaId']!),
          )),
    ),
    GoRoute(
      path: '/browse/:pluginId/:parentId',
      pageBuilder: (_, state) => _fadePage(
          state,
          BrowseScreen(
            pluginId: state.pathParameters['pluginId']!,
            parentId: Uri.decodeComponent(state.pathParameters['parentId']!),
            title: state.extra as String? ?? '',
          )),
    ),
    GoRoute(
      path: '/episode/:pluginId/:mediaId',
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _fadePage(
            state,
            EpisodeDetailScreen(
              pluginId: state.pathParameters['pluginId']!,
              mediaId: Uri.decodeComponent(state.pathParameters['mediaId']!),
              episodeList:
                  (extra?['episodeList'] as List?)?.cast<String>() ?? const [],
              episodeTitles:
                  (extra?['episodeTitles'] as List?)?.cast<String>() ??
                      const [],
              episodeThumbs:
                  (extra?['episodeThumbs'] as List?)?.cast<String>() ??
                      const [],
              episodeNumbers:
                  (extra?['episodeNumbers'] as List?)?.cast<int>() ?? const [],
              seasonNumbers:
                  (extra?['seasonNumbers'] as List?)?.cast<int>() ?? const [],
              episodeIndex: extra?['episodeIndex'] as int? ?? -1,
              allSeasonIds:
                  (extra?['allSeasonIds'] as List?)?.cast<String>() ?? const [],
              allSeasonLabels:
                  (extra?['allSeasonLabels'] as List?)?.cast<String>() ??
                      const [],
              seasonIndex: extra?['seasonIndex'] as int? ?? 0,
              showTitle: extra?['showTitle'] as String? ?? '',
            ));
      },
    ),
    GoRoute(
      path: '/player/:pluginId/:mediaId',
      pageBuilder: (_, state) => _fadePage(
          state,
          PlaybackScreen(
            pluginId: state.pathParameters['pluginId']!,
            mediaId: Uri.decodeComponent(state.pathParameters['mediaId']!),
          )),
    ),
    GoRoute(
      path: '/search/:pluginId',
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _fadePage(
            state,
            SearchScreen(
              pluginId: state.pathParameters['pluginId']!,
              pluginName: extra?['pluginName'] as String? ?? '',
              initialQuery: extra?['initialQuery'] as String? ?? '',
            ));
      },
    ),
    GoRoute(
      path: '/plugin-settings/:pluginId',
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _fadePage(
            state,
            PluginSettingsScreen(
              pluginId: state.pathParameters['pluginId']!,
              pluginName: extra?['pluginName'] as String? ?? '',
            ));
      },
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (_, state) => _fadePage(state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/settings/profile',
      pageBuilder: (_, state) =>
          _fadePage(state, const ProfileSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/preferences',
      pageBuilder: (_, state) => _fadePage(state, const PreferencesScreen()),
    ),
    GoRoute(
      path: '/settings/plugins',
      pageBuilder: (_, state) =>
          _fadePage(state, const SettingsPluginsScreen()),
    ),
  ],
  errorBuilder: (context, state) => _RouteNotFound(uri: state.uri),
  redirect: (context, state) => authGuardRedirect(state),
);

class _RouteNotFound extends StatelessWidget {
  final Uri uri;
  const _RouteNotFound({required this.uri});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_rounded,
                color: Color(0xFF7C6AF7), size: 56),
            const SizedBox(height: 20),
            const Text('Pagina non trovata',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(uri.toString(),
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
              autofocus: true,
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Torna alla home'),
            ),
          ],
        ),
      ),
    );
  }
}
