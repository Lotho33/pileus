import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_lifecycle.dart';
import 'core/di/injection.dart';
import 'core/perf_profile.dart';
import 'core/utils/perf_log.dart';
import 'features/settings/data/settings_repository.dart';
import 'mobile/mobile_app.dart';

/// Entry point for the **mobile** flavor (phone / tablet).
///
///   flutter run --flavor mobile
///
/// `lib/main.dart` also delegates here when `appFlavor == 'mobile'`, so the
/// `-t lib/main_mobile.dart` form is optional — either way the mobile UI
/// runs whenever the `mobile` flavor is selected.
///
/// Shares everything below the presentation layer with the TV app
/// (`lib/main.dart`): DI, gRPC/proto, repositories, BLoCs, the player engine.
/// Only the UI shell differs — see `lib/mobile/`.
void main() => runMobileApp();

Future<void> runMobileApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-locked everywhere except playback (the player screen widens
  // this to landscape on mount and restores it on pop). Fire-and-forget —
  // don't gate the first frame on a platform-channel round-trip.
  SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );

  // Decoded-image memory bounds. Phones have far more RAM than a Fire Stick,
  // and the home/details/search grids can hold well over 200 live
  // ImageStreams — a tight cap causes decode/evict/re-decode thrash on
  // scroll-back.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 110 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 400;

  try {
    await configureDependencies();
  } catch (e, st) {
    runApp(_MobileStartupError(error: e, trace: st));
    return;
  }

  AppLifecycleReactor.instance.attach();

  final settings = getIt<SettingsRepository>();
  kPerfDiagnostics = kDebugMode || settings.getDiagnostics();
  installJankLogger();

  // The phone build has no "hardware modesto" mode and no HDMI overscan —
  // both are TV-box concerns. Force the full-fidelity UI path.
  isAndroidTv = false;
  lowPowerUi = false;

  runApp(const PileusMobileApp());
}

class _MobileStartupError extends StatelessWidget {
  final Object error;
  final StackTrace trace;
  const _MobileStartupError({required this.error, required this.trace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: Color(0xFFFF5252), size: 56),
                const SizedBox(height: 20),
                const Text('Avvio non riuscito',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text('$error',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
