import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Last-resort error handling for the store builds (TV + mobile + desktop).
///
/// - Uncaught async errors (a fire-and-forget RPC that threw, a missing
///   try/catch) are logged with their stack and marked handled instead of
///   only surfacing as an anonymous "Unhandled Exception" line. They never
///   crashed the app, but they also left no trace to diagnose from a user's
///   `adb logcat`.
/// - Framework errors keep Flutter's own reporting (red screen in debug,
///   console dump), plus the same tag so both are greppable together.
/// - In release, a widget that throws during build renders a quiet dark
///   placeholder instead of Flutter's default flat grey box.
///
/// Logs go through [debugPrint] (it reaches logcat in release too) under
/// the `pileus/error` tag. Nothing leaves the device — no crash-reporting
/// service is involved (see docs/PRIVACY.md).
void installErrorHooks() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint('pileus/error flutter: ${details.exceptionAsString()}');
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('pileus/error uncaught: $error\n$stack');
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const ColoredBox(
          color: Color(0xFF0D0D1A),
          child: Center(
            child: Icon(Icons.error_outline_rounded,
                color: Color(0x55FFFFFF), size: 28),
          ),
        );
  }
}
