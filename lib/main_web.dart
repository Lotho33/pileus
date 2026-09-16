import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'core/app_lifecycle.dart';
import 'core/di/injection.dart';
import 'core/perf_profile.dart';
import 'core/utils/perf_log.dart';
import 'features/settings/data/settings_repository.dart';
import 'web/web_app.dart';

/// Entry point for the **web / PWA** build.
///
///   flutter run  -d chrome -t lib/main_web.dart
///   flutter build web       -t lib/main_web.dart
///
/// Reuses the responsive desktop UI (`lib/desktop/`). The transport is
/// gRPC-Web (`lib/core/grpc/grpc_channel_web.dart`) against `<origin>/grpc`,
/// so the page must be served by mycelium (or a reverse proxy that exposes
/// a gRPC-Web endpoint there). Playback uses a plain HTML5 `<video>` — see
/// `lib/web/web_playback_screen.dart` and `docs/WEB.md` for the HLS caveat.
void main() => runWebApp();

Future<void> runWebApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSizeBytes = 120 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 500;

  try {
    await configureDependencies();
  } catch (e, st) {
    runApp(_WebStartupError(error: e, trace: st));
    return;
  }

  AppLifecycleReactor.instance.attach();

  final settings = getIt<SettingsRepository>();
  kPerfDiagnostics = kDebugMode || settings.getDiagnostics();
  installJankLogger();

  isAndroidTv = false;
  lowPowerUi = false;

  runApp(const PileusWebApp());
}

class _WebStartupError extends StatelessWidget {
  final Object error;
  final StackTrace trace;
  const _WebStartupError({required this.error, required this.trace});

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
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
