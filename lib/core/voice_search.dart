import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Voice search through the system's speech recognizer (native half:
/// android/app/src/main/kotlin/.../VoiceSearch.kt): its own dialog listens —
/// on a TV through the remote's microphone — and hands back the text. Pileus
/// never records audio. Android only; where there's no recognizer (some Fire
/// TV, every other platform) [available] is false and no microphone shows.
class VoiceSearch {
  VoiceSearch._();

  static const _channel = MethodChannel('pileus/voice');
  static bool? _available;

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Whether to show the microphone. Asked once per run.
  static Future<bool> available() async {
    if (!_android) return false;
    return _available ??= await () async {
      try {
        return await _channel.invokeMethod<bool>('available') ?? false;
      } catch (_) {
        return false;
      }
    }();
  }

  /// The words heard, or null (cancelled, nothing heard, no recognizer).
  static Future<String?> listen({String prompt = 'Cosa vuoi guardare?'}) async {
    if (!_android) return null;
    try {
      final text =
          await _channel.invokeMethod<String>('listen', {'prompt': prompt});
      final t = text?.trim() ?? '';
      return t.isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }
}
