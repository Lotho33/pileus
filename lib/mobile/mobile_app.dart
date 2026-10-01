import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/grpc/auth_interceptor.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_state.dart';
import 'mobile_router.dart';

/// Root of the mobile (phone/tablet) flavor. Deliberately thin: it reuses
/// the TV app's [AuthBloc] (a `get_it` singleton) and mirrors the same
/// "session state → top-level navigation" wiring as `lib/main.dart`, only
/// against [mobileRouter] instead of the TV router.
class PileusMobileApp extends StatelessWidget {
  const PileusMobileApp({super.key});

  // See PileusDesktopApp's identical field for why this exists.
  static final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: getIt<AuthBloc>(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthenticatedState) {
            getIt<AuthInterceptor>()
                .setCredentials(state.jwt, state.activeProfileId);
          } else if (state is DevicePairingRequired) {
            getIt<AuthInterceptor>().clear();
          }

          if (state is DevicePairingRequired) {
            mobileRouter.go('/pairing');
            if (state.reason != null) {
              _scaffoldMessengerKey.currentState
                  ?.showSnackBar(SnackBar(content: Text(state.reason!)));
            }
          } else if (state is ServerDiscoveryRequired) {
            mobileRouter.go('/discovery');
          } else if (state is ProfileSelectionRequired) {
            mobileRouter.go('/profiles');
          } else if (state is AuthenticatedState) {
            // The mobile pairing/profile screens don't self-navigate on
            // success (unlike the TV ones), so drive it from here.
            mobileRouter.go('/home');
          }
        },
        child: MaterialApp.router(
          title: 'Pileus',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          theme: AppTheme.dark(),
          routerConfig: mobileRouter,
          // Nudge every text size up ~13% (the base sizes read a touch small
          // on a phone), still honouring the user's own system text-scale on
          // top, capped so an accessibility-large setting doesn't blow the
          // fixed-height rows apart.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final base = mq.textScaler.scale(1.0);
            return MediaQuery(
              data: mq.copyWith(
                textScaler:
                    TextScaler.linear(math.min(base * 1.13, base + 0.6)),
              ),
              child: child!,
            );
          },
        ),
      ),
    );
  }
}
