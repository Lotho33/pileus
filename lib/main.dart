import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import 'main_mobile.dart' show runMobileApp;

import 'core/app_lifecycle.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_scale.dart';
import 'core/theme/app_theme.dart';
import 'shared/utils/back_dispatch.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/settings/data/settings_repository.dart';
import 'core/grpc/auth_interceptor.dart';
import 'core/device_profile.dart';
import 'core/perf_profile.dart';
import 'core/utils/perf_log.dart';
import 'shared/widgets/pileus_spinner.dart';

// kIsWeb must come first: on Flutter Web, defaultTargetPlatform reflects the
// browser's *host* OS (via user-agent sniffing), so a page opened in Chrome
// on Linux/macOS/Windows would otherwise read as "desktop" here too — and
// then reach for window_manager below, a desktop-only plugin with no web
// implementation. Its platform-channel call throws before runApp() is ever
// reached, which paints nothing at all (blank page, not even an error
// screen, since this runs ahead of the try/catch around configureDependencies).
bool _isDesktop() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

// windowManager.setFullScreen() calls GTK's gtk_window_fullscreen(), which
// just *asks* the window manager to resize the window and returns before
// that resize actually happens — the real resize lands later, asynchronously,
// whenever the WM gets to it. The Flutter Linux engine itself has a
// synchronization timeout that waits for a rendered frame matching the new
// window size and tears the whole app down if it doesn't show up in time
// (baked into libflutter_linux_gtk.so — not something this project can
// patch). Calling it against an *already-visible* window (mid-session, or
// right after the default window has already shown its first frame) races
// that timeout.
//
// A plain setBounds() sidesteps the crash but isn't real fullscreen — under
// Wayland (incl. XWayland) a client can't just reposition/resize itself;
// only the compositor grants geometry changes, and it only listens to the
// actual xdg_toplevel "request fullscreen" protocol that setFullScreen()
// triggers, not an arbitrary setBounds() call. So this app needs the real
// thing, just requested before there's a visible frame to race against:
// window_manager's own documented pattern is to create the window hidden,
// configure it (including fullScreen) via waitUntilReadyToShow, and only
// call show() once that settles — no size transition to desync from.
Future<void> _enterNativeFullscreen() async {
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      fullScreen: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

void main() async {
  // `flutter run/build --flavor mobile` defaults to this entrypoint; hand
  // off to the phone/tablet UI so the `-t lib/main_mobile.dart` argument is
  // optional. `appFlavor` is a compile-time const, so the branch not taken
  // is tree-shaken out of each flavor's binary.
  if (appFlavor == 'mobile') {
    await runMobileApp();
    return;
  }
  // No `disableAnimations` override: when the user turns off animations in
  // Android's Developer options / accessibility settings, Flutter collapses
  // every implicit animation and route transition to near-instant. On the
  // low-power TV boxes this app targets that toggle is a deliberate way to
  // shed CPU/GPU load per frame — Pileus honours it rather than forcing its
  // own motion back on top.
  WidgetsFlutterBinding.ensureInitialized();
  // Bound decoded-image memory: TV boxes (Fire Stick & co.) have ~1 GB of RAM
  // and Flutter's default cache is 100 MB of decoded bitmaps. Also cap the
  // entry count (default 1000): the carousels window their rendering so only
  // ~15 posters are ever on screen, and hundreds of retained ui.Image
  // handles carry per-object overhead on top of the bytes they already count
  // toward the limit above.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 200;
  if (_isDesktop()) {
    await windowManager.ensureInitialized();
    await _enterNativeFullscreen();
  }
  try {
    await configureDependencies();
  } catch (e, st) {
    runApp(_StartupErrorApp(error: e, trace: st));
    return;
  }
  // Shed background work (the 30 s plugin poll; the libmpv heartbeat via
  // AppLifecycleReactor.state) whenever the OS backgrounds the app.
  AppLifecycleReactor.instance.attach();
  // "Hardware modesto": shed shader/compositing work app-wide (see
  // core/perf_profile.dart) and shrink the decoded-image cache further —
  // these boxes are RAM-starved and the lowmemorykiller is active during
  // playback per device logs.
  final settings = getIt<SettingsRepository>();
  // Field diagnostics: silent in release unless the hidden toggle is on
  // (debug builds always trace). Set before the first perf()/jank sample.
  kPerfDiagnostics = kDebugMode || settings.getDiagnostics();
  // Slow-frame sampler → `adb logcat` (grep `pileus/jank`); rate-limited,
  // no-ops when kPerfDiagnostics is false.
  installJankLogger();
  // Never toggled by hand → let the hardware decide. Amlogic S905W/X-class
  // boxes (Tanix W2 & co., GLES2 Mali-450) can't sustain 1080p video +
  // Flutter compositing — the Vulkan path faults or the A/V clock drifts
  // seconds within a minute. Persist the result so the Preferenze toggle
  // reflects it and the user can still override.
  // Always read (not just on first launch): unlike the low-power flag below
  // — a one-time decision the user can override — `isTv` feeds a startup
  // condition every run (see the MaterialApp.router builder), so it can't
  // be skipped once the low-power flag has already been persisted.
  final profile = await readDeviceProfile();
  perf('main: device profile $profile');
  isAndroidTv = profile.isTv;
  if (!settings.isLowPowerModeSet() && profile.isWeak) {
    await settings.setLowPowerMode(true);
  }
  lowPowerUi = settings.getLowPowerMode();
  if (lowPowerUi) {
    PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20;
    PaintingBinding.instance.imageCache.maximumSize = 140;
  }
  runApp(const PileusApp());
}

class _StartupErrorApp extends StatefulWidget {
  final Object error;
  final StackTrace trace;
  const _StartupErrorApp({required this.error, required this.trace});

  @override
  State<_StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<_StartupErrorApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    // configureDependencies() registers singletons — a second run would throw
    // "already registered", so wipe the container first.
    try {
      await getIt.reset();
    } catch (_) {}
    try {
      await configureDependencies();
      runApp(const PileusApp());
    } catch (e, st) {
      runApp(_StartupErrorApp(error: e, trace: st));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: Color(0xFFFF5252), size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Avvio non riuscito',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Non è stato possibile inizializzare l\'app. Controlla la connessione e riprova.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.error.toString(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 28),
                if (_retrying)
                  PileusSpinner(
                      size: AppScale.spinnerS(context),
                      color: const Color(0xFF7C6AF7))
                else
                  ElevatedButton.icon(
                    autofocus: true,
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Riprova'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C6AF7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
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

class PileusApp extends StatefulWidget {
  const PileusApp({super.key});

  @override
  State<PileusApp> createState() => _PileusAppState();
}

class _PileusAppState extends State<PileusApp> with WidgetsBindingObserver {
  // See PileusDesktopApp's identical field (mobile/desktop/web apps) for why
  // this exists: lets the listener below show a SnackBar regardless of which
  // route is on screen.
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Registered here, before MaterialApp builds its Router, so this
    // observer is consulted first when the Android system Back arrives on
    // the platform channel. That Back also reaches the app as a `goBack`
    // key event the focus tree already handled — so a single press
    // otherwise pops twice (only on Android; Linux has no platform back).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    // true = "handled, don't pop". Swallow when a key-path Back handler just
    // acted on this same press (see back_dispatch.dart); otherwise return
    // false to let the Router / PopScope handle it (e.g. app-exit from the
    // root route, or a device that only delivers the platform back).
    return !consumeBackEvent();
  }

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
          // Forces navigation back to the start of the auth flow no matter
          // how deep the user currently is (home, player, settings, ...) —
          // previously only splash_screen.dart and server_discovery_screen.dart
          // listened for these two states, both screens that are never
          // mounted again once the user reaches /home. A session expiring
          // mid-use (SessionExpiredEvent, dispatched from several repository
          // clients on an auth error) — or a manual logout — cleared
          // credentials with nothing to actually navigate the user away,
          // leaving them stranded on a now-unauthenticated screen. appRouter
          // is used directly (not context.go) since this listener's own
          // context sits above MaterialApp.router, with no GoRouter in its
          // ancestry yet.
          if (state is DevicePairingRequired) {
            appRouter.go('/pairing');
            if (state.reason != null) {
              _scaffoldMessengerKey.currentState
                  ?.showSnackBar(SnackBar(content: Text(state.reason!)));
            }
          } else if (state is ServerDiscoveryRequired) {
            appRouter.go('/discovery');
          } else if (state is ProfileSelectionRequired) {
            // Same reasoning as above but for SwitchProfileEvent (see
            // profile_settings_screen.dart's "Cambia profilo" row) — that
            // can fire from deep inside /settings, way past the screens
            // (device_pairing_screen.dart, splash_screen.dart) that already
            // had their own local listener for this state.
            appRouter.go('/profiles');
          }
        },
        child: MaterialApp.router(
          title: 'Pileus',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          // No fixed design canvas / letterboxing here on purpose — Pileus
          // needs to look right on whatever aspect ratio a real TV or
          // monitor actually has (16:9 is the common case, not a
          // guarantee), so every screen sizes itself from the real
          // MediaQuery (mostly height-anchored: sh * ratio) and reflows
          // instead of scaling a fixed canvas with bars on the sides.
          // Text scaling on desktop must NOT compound with that proportional
          // sizing, or the result is quadratic: a smaller window shrinks text
          // twice and a 4K window grows it twice. So the readability
          // multiplier is a fixed 1.35 with only a *tight* window-height trim
          // (0.85‥1.0) — never a runaway. On Android TV the system density
          // already normalizes every panel (FHD/QHD/UHD) to ~960×540 dp, so a
          // fixed logical size looks identical on 1080p and 4K — leave text
          // untouched there. That normalization is a TV-firmware thing, not
          // an Android thing: a phone/tablet reports its own real logical
          // size, same as desktop, so it needs the same boost — `isAndroidTv`
          // (native FEATURE_LEANBACK/UiModeManager check, see
          // device_profile.dart) is what actually distinguishes them, not
          // `Platform.isAndroid` on its own (2026-09 audit: every non-TV
          // Android device was silently skipping this and reading small).
          builder: (ctx, child) {
            // kIsWeb short-circuits before Platform.isAndroid: dart:io's
            // Platform throws at runtime on web (see _isDesktop above for
            // the same class of bug) — this branch should run on web same
            // as desktop, just never by evaluating the native check there.
            if (kIsWeb || !Platform.isAndroid || !isAndroidTv) {
              final mq = MediaQuery.of(ctx);
              final base = mq.textScaler.scale(1.0);
              final trim = (mq.size.height / 1080.0).clamp(0.85, 1.0);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(base * 1.35 * trim),
                ),
                child: child!,
              );
            }
            // Android (TV): compensate for HDMI overscan — many TVs/boxes
            // crop the outer few % of the frame, so a full-bleed UI (home
            // hero, player) loses its edges. Desktop has no overscan, which
            // is why only desktop looked right. Inset amount is user-tunable
            // in Preferenze; the ValueListenable lets that slider reflow the
            // whole app live instead of on next launch. See
            // SettingsRepository.overscan.
            return ValueListenableBuilder<double>(
              valueListenable: getIt<SettingsRepository>().overscan,
              child: child!,
              builder: (ctx, pct, inner) {
                if (pct <= 0) return inner!;
                final mq = MediaQuery.of(ctx);
                final dx = mq.size.width * pct / 100.0;
                final dy = mq.size.height * pct / 100.0;
                // Shrink the reported size too, not just the paint box —
                // every screen scales itself off MediaQuery height
                // (AppScale.sh), so it has to see the usable area or it
                // lays out for the full panel inside a smaller box and
                // overflows.
                return MediaQuery(
                  data: mq.copyWith(
                    size: Size(mq.size.width - 2 * dx, mq.size.height - 2 * dy),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: dx, vertical: dy),
                    child: inner,
                  ),
                );
              },
            );
          },
          theme: AppTheme.dark(),
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
