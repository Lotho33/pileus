import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/grpc/auth_interceptor.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_state.dart';
import 'web_router.dart';

/// Root of the web / PWA build — mirrors `PileusDesktopApp`, against
/// [webRouter].
class PileusWebApp extends StatelessWidget {
  const PileusWebApp({super.key});

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
            webRouter.go('/pairing');
          } else if (state is ServerDiscoveryRequired) {
            webRouter.go('/discovery');
          } else if (state is ProfileSelectionRequired) {
            webRouter.go('/profiles');
          } else if (state is AuthenticatedState) {
            webRouter.go('/home');
          }
        },
        child: MaterialApp.router(
          title: 'Pileus',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          routerConfig: webRouter,
          scrollBehavior: const _WebScrollBehavior(),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final base = mq.textScaler.scale(1.0);
            final w = mq.size.width;
            final f = (w / 1280).clamp(1.0, 1.32);
            return MediaQuery(
              data: mq.copyWith(
                textScaler:
                    TextScaler.linear(math.min(base * f, base + 0.7)),
              ),
              child: child!,
            );
          },
        ),
      ),
    );
  }
}

class _WebScrollBehavior extends MaterialScrollBehavior {
  const _WebScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
