import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/grpc/auth_interceptor.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_state.dart';
import 'desktop_router.dart';

/// Root of the desktop / large-screen build. Thin, like the mobile app: it
/// reuses the shared [AuthBloc] singleton and mirrors the same
/// "session state → top-level navigation" wiring, against [desktopRouter].
class PileusDesktopApp extends StatelessWidget {
  const PileusDesktopApp({super.key});

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
            desktopRouter.go('/pairing');
          } else if (state is ServerDiscoveryRequired) {
            desktopRouter.go('/discovery');
          } else if (state is ProfileSelectionRequired) {
            desktopRouter.go('/profiles');
          } else if (state is AuthenticatedState) {
            desktopRouter.go('/home');
          }
        },
        child: MaterialApp.router(
          title: 'Pileus',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          routerConfig: desktopRouter,
          // Desktop scrolls with the wheel and drags with a trackpad/mouse —
          // let both act as drag devices so horizontal rows can be flung.
          scrollBehavior: const _DesktopScrollBehavior(),
          // The base type sizes were tuned around a ~1280-wide window; on a
          // QHD/4K panel run at 100% OS scaling that leaves everything
          // looking tiny. Scale text up with window width (≈1.0 at 1280,
          // ≈1.15 at 1920, ≈1.28 at 2560), still honouring the user's own
          // system text-scale, capped so it can't run away.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final base = mq.textScaler.scale(1.0);
            final w = mq.size.width;
            final f = (w / 1280).clamp(1.0, 1.32);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(math.min(base * f, base + 0.7)),
              ),
              child: child!,
            );
          },
        ),
      ),
    );
  }
}

class _DesktopScrollBehavior extends MaterialScrollBehavior {
  const _DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
