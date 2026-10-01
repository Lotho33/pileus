import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/bloc/auth_state.dart';

/// Desktop splash: fire [AppStartedEvent], route on the resolved [AuthState].
class DesktopSplashScreen extends StatefulWidget {
  const DesktopSplashScreen({super.key});

  @override
  State<DesktopSplashScreen> createState() => _DesktopSplashScreenState();
}

class _DesktopSplashScreenState extends State<DesktopSplashScreen> {
  late final AuthBloc _auth = getIt<AuthBloc>();
  Timer? _bootTimeout;
  bool _went = false;

  @override
  void initState() {
    super.initState();
    _auth.add(const AppStartedEvent());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeRoute(_auth.state));
    _bootTimeout = Timer(const Duration(seconds: 20),
        () => _maybeRoute(_auth.state, fallback: '/discovery'));
  }

  @override
  void dispose() {
    _bootTimeout?.cancel();
    super.dispose();
  }

  static String? _routeForState(AuthState s) {
    if (s is ServerDiscoveryRequired || s is AuthError) return '/discovery';
    if (s is DevicePairingRequired) return '/pairing';
    if (s is ProfileSelectionRequired) return '/profiles';
    if (s is AuthenticatedState) return '/home';
    return null;
  }

  void _maybeRoute(AuthState s, {String? fallback}) {
    final route = _routeForState(s) ?? fallback;
    if (route != null) _go(route);
  }

  void _go(String route) {
    if (_went || !mounted) return;
    _went = true;
    _bootTimeout?.cancel();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      bloc: _auth,
      listener: (context, state) => _maybeRoute(state),
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/branding/pileus_icon.svg',
                height: 112,
                colorFilter:
                    const ColorFilter.mode(AppTheme.textHigh, BlendMode.srcIn),
              ),
              const SizedBox(height: 28),
              SvgPicture.asset(
                'assets/branding/pileus_wordmark.svg',
                height: 40,
                colorFilter:
                    const ColorFilter.mode(AppTheme.textHigh, BlendMode.srcIn),
              ),
              const SizedBox(height: 44),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A centred card on the dark ground — the shared frame for the desktop
/// discovery / pairing screens.
class DesktopAuthCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const DesktopAuthCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SvgPicture.asset(
                  'assets/branding/pileus_wordmark.svg',
                  height: 30,
                  colorFilter: const ColorFilter.mode(
                      AppTheme.textHigh, BlendMode.srcIn),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(subtitle,
                          style: const TextStyle(
                              color: AppTheme.textMid,
                              fontSize: 13,
                              height: 1.4)),
                      const SizedBox(height: 20),
                      ...children,
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
