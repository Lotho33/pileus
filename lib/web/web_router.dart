import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/grpc/auth_interceptor.dart';
import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/theme/app_theme.dart';
// The responsive UI is shared with the desktop build. These screens are
// dart:io-free, so they link fine for web.
import '../desktop/desktop_details_screen.dart';
import '../desktop/desktop_pairing_screen.dart';
import '../desktop/desktop_profiles_screen.dart';
import '../desktop/desktop_shell.dart';
import '../desktop/desktop_splash_screen.dart';
import 'web_discovery_screen.dart';
import 'web_playback_screen.dart';

/// Web router. Same shape as the desktop router, but discovery + player are
/// web-native (no `dart:io` socket probe, HTML5 `<video>` playback).
final GoRouter webRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const DesktopSplashScreen()),
    GoRoute(
        path: '/discovery',
        builder: (_, __) => const WebDiscoveryScreen()),
    GoRoute(
        path: '/pairing', builder: (_, __) => const DesktopPairingScreen()),
    GoRoute(
        path: '/profiles',
        builder: (_, __) => const DesktopProfilesScreen()),
    GoRoute(path: '/home', builder: (_, __) => const DesktopShell()),
    GoRoute(
      path: '/details/:pluginId/:mediaId',
      builder: (_, state) => DesktopDetailsScreen(
        pluginId: state.pathParameters['pluginId']!,
        mediaId: Uri.decodeComponent(state.pathParameters['mediaId']!),
        preview: state.extra is CatalogItem ? state.extra as CatalogItem : null,
      ),
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
  redirect: (context, state) {
    const authFlow = {'/splash', '/discovery', '/pairing', '/profiles'};
    if (authFlow.contains(state.uri.path)) return null;
    if (!getIt<AuthInterceptor>().hasCredentials) return '/splash';
    return null;
  },
);
