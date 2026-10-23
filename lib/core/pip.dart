import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:flutter/services.dart';

/// Picture-in-picture for the phone player (native half: android/app/src/
/// mobile/kotlin/.../Pip.kt). The player says when PiP is wanted — a video
/// is actually playing — and hides its controls while [active]. A no-op
/// everywhere but the Android mobile flavor.
class Pip {
  Pip._();

  static const _channel = MethodChannel('pileus/pip');

  /// True while the app is shown in the PiP window.
  static final active = ValueNotifier<bool>(false);

  static bool get _enabled =>
      !kIsWeb && Platform.isAndroid && appFlavor == 'mobile';

  static String? _last;

  /// Call once from main_mobile.dart.
  static void init() {
    if (!_enabled) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pipChanged') active.value = call.arguments == true;
    });
  }

  /// Whether leaving the app now should keep the video in a PiP window.
  /// [width]/[height]: the video's proportions (16:9 when unknown). Cheap
  /// to call on every player tick: an unchanged request isn't resent.
  static void setEligible(bool eligible, {int width = 16, int height = 9}) {
    if (!_enabled) return;
    final key = '$eligible:$width:$height';
    if (key == _last) return;
    _last = key;
    unawaited(_channel.invokeMethod('setEligible', {
      'eligible': eligible,
      'width': width,
      'height': height,
    }).catchError((Object _) => null));
  }
}
