import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'core/app_lifecycle.dart';
import 'core/di/injection.dart';
import 'core/perf_profile.dart';
import 'core/utils/perf_log.dart';
import 'features/settings/data/settings_repository.dart';
import 'main.dart' show PileusApp;

/// Entry point for the **TV web / packaged smart-TV** build (Samsung Tizen
/// `.wgt`, LG webOS `.ipk` — see docs/TIZEN_WEBOS.md).
///
///   flutter run   -d chrome -t lib/main_web_tv.dart
///   flutter build web        -t lib/main_web_tv.dart
///
/// Unlike `main_web.dart` (which reuses the mouse/keyboard-oriented desktop
/// UI, `lib/desktop/`), this reuses the real D-pad-navigable TV UI —
/// `PileusApp`/`appRouter`, the exact same widget tree `main.dart` boots on
/// Android TV/Fire TV — instead of building a third UI from scratch.
/// `flutter build web` already compiles that tree fine (every native-only
/// call in it is already `kIsWeb`-gated — verified see
/// server_discovery_screen.dart's `_sweepLan`/`_isAndroid` for the
/// pattern); the pieces that needed actual fixing for a *packaged* app
/// (never served by mycelium itself, so there is no "same-origin" host to
/// default to — every connection goes through the manual/remote-mode path)
/// were the web gRPC-Web channel factory and the `x-http-host` header
/// always assuming a LAN `http://`, fixed in grpc_channel_web.dart and
/// auth_interceptor.dart alongside remote server mode itself.
///
/// Transport is gRPC-Web (`core/grpc/grpc_channel_web.dart`) — same as
/// `main_web.dart` — against whatever host the discovery screen's manual
/// field resolves (LAN or remote/HTTPS, see server_address.dart); there is
/// no UDP/mDNS discovery on web (host_resolver_stub.dart's
/// discoverViaBroadcast/canReach are no-ops), and a packaged app is never
/// "served by mycelium" the way a browser visiting its own /app/ is, so
/// manual entry is the *only* path here, not a fallback.
void main() => runWebTvApp();

Future<void> runWebTvApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 200;

  try {
    await configureDependencies();
  } catch (e, st) {
    runApp(_WebTvStartupError(error: e, trace: st));
    return;
  }

  AppLifecycleReactor.instance.attach();

  final settings = getIt<SettingsRepository>();
  kPerfDiagnostics = kDebugMode || settings.getDiagnostics();
  installJankLogger();

  // A real TV, always — unlike main.dart's Android build, there is no
  // native FEATURE_LEANBACK channel to actually ask, so this is simply
  // assumed true for this dedicated entrypoint (see PileusApp's
  // MaterialApp.router builder in main.dart: it only reads this on
  // `!kIsWeb && Platform.isAndroid`, so today it's a no-op on any web
  // build regardless — kept true here anyway so it reads correctly the
  // moment that builder's condition is ever extended to cover web/TV too).
  isAndroidTv = true;
  // No device-profile channel to weigh "is this hardware weak" against,
  // the way main.dart's readDeviceProfile() does on real Android TV — smart
  // TV chipsets span a decade of hardware generations with no reliable way
  // to tell from a web page which end a given TV is on. Defaults to on
  // (shed blur/shader work) rather than off, same conservative choice
  // device_profile.dart makes for a known-weak Amlogic box; the Preferenze
  // toggle still lets a capable TV's owner turn it back off, same as any
  // other platform.
  lowPowerUi = settings.isLowPowerModeSet()
      ? settings.getLowPowerMode()
      : true;
  if (lowPowerUi) {
    PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20;
    PaintingBinding.instance.imageCache.maximumSize = 140;
  }

  runApp(const PileusApp());
}

class _WebTvStartupError extends StatelessWidget {
  final Object error;
  final StackTrace trace;
  const _WebTvStartupError({required this.error, required this.trace});

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
