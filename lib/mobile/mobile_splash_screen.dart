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

/// Portrait splash for the mobile flavor. Same job as the TV splash — fire
/// [AppStartedEvent], route on the resolved [AuthState] — but a plain
/// vertical lockup instead of the TV's animated horizontal one.
class MobileSplashScreen extends StatefulWidget {
  const MobileSplashScreen({super.key});

  @override
  State<MobileSplashScreen> createState() => _MobileSplashScreenState();
}

class _MobileSplashScreenState extends State<MobileSplashScreen> {
  late final AuthBloc _auth = getIt<AuthBloc>();
  Timer? _bootTimeout;
  bool _went = false;

  @override
  void initState() {
    super.initState();
    _auth.add(const AppStartedEvent());
    // BlocListener only fires on state *changes*. If AuthBloc (a get_it
    // singleton) already holds a resolved state when this screen mounts —
    // hot restart, back-navigation to /splash, or AppStartedEvent
    // re-emitting a state equal to the current one — the listener never
    // fires. Route off the current state once, post-frame.
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
                height: 96,
                colorFilter:
                    const ColorFilter.mode(AppTheme.textHigh, BlendMode.srcIn),
              ),
              const SizedBox(height: 24),
              SvgPicture.asset(
                'assets/branding/pileus_wordmark.svg',
                height: 34,
                colorFilter:
                    const ColorFilter.mode(AppTheme.textHigh, BlendMode.srcIn),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 26,
                height: 26,
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
