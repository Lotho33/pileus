import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'voice_search.dart' show VoiceMode;

// Native half: android/app/src/main/kotlin/.../VoiceSearch.kt. Nothing on
// Linux, Windows or iOS.
const _channel = MethodChannel('pileus/voice');

Future<VoiceMode> voiceMode() async {
  if (!Platform.isAndroid) return VoiceMode.none;
  final m = await _channel.invokeMethod<String>('available');
  return switch (m) {
    'dialog' => VoiceMode.system,
    'service' => VoiceMode.app,
    _ => VoiceMode.none,
  };
}

Future<String?> listen(String prompt) =>
    _channel.invokeMethod<String>('listen', {'prompt': prompt});

Future<void> cancel() => _channel.invokeMethod<void>('cancel');
