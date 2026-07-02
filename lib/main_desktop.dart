import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app_lifecycle.dart';
import 'core/di/injection.dart';
import 'core/perf_profile.dart';
import 'core/utils/perf_log.dart';
import 'desktop/desktop_app.dart';
import 'features/settings/data/settings_repository.dart';

/// Entry point for the **desktop / large-screen** build (Linux, Windows,
/// and later the responsive web/PWA target).
///
///   flutter run -d linux  -t lib/main_desktop.dart
///   flutter run -d windows -t lib/main_desktop.dart
///
/// Shares everything below the presentation layer with the TV and mobile
/// apps (DI, gRPC/proto, repositories, BLoCs, the player engine — which
/// resolves to media_kit/libmpv on desktop). Only the UI shell differs —
/// see `lib/desktop/`. Point-and-click, not D-pad; one layout that adapts
/// from a small window up to a 4K monitor (see `lib/shared/responsive.dart`).
void main() => runDesktopApp();

Future<void> runDesktopApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow(
    const WindowOptions(
      minimumSize: Size(880, 560),
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  // Decoded-image memory bounds — a desktop window can show a lot of art at
  // once across the home rows + search grid; keep the cache generous so
  // scroll-back doesn't thrash the decoder.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 160 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 600;

  try {
    await configureDependencies();
  } catch (e, st) {
    runApp(_DesktopStartupError(error: e, trace: st));
    return;
  }

  AppLifecycleReactor.instance.attach();

  final settings = getIt<SettingsRepository>();
  kPerfDiagnostics = kDebugMode || settings.getDiagnostics();
  installJankLogger();

  isAndroidTv = false;
  lowPowerUi = false;

  runApp(const PileusDesktopApp());
}

class _DesktopStartupError extends StatelessWidget {
  final Object error;
  final StackTrace trace;
  const _DesktopStartupError({required this.error, required this.trace});

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
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
