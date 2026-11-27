import 'voice_search_io.dart'
    if (dart.library.js_interop) 'voice_search_web.dart' as impl;

/// How this device can turn speech into a search, if at all.
enum VoiceMode {
  /// No speech recognition here: no microphone button.
  none,

  /// The system's own dictation dialog listens and hands back the text
  /// (Android's RecognizerIntent).
  system,

  /// A recognizer without a dialog of its own (Android's recognition
  /// service, a browser's Web Speech API): the app shows its "listening"
  /// dialog meanwhile (voice_search_flow.dart).
  app,
}

/// Voice search, per platform (voice_search_io.dart, voice_search_web.dart):
/// Android through the system's recognition (android/.../VoiceSearch.kt),
/// the web through the browser's (Chrome, Edge, Safari), nothing elsewhere.
/// Pileus never records or keeps audio itself.
class VoiceSearch {
  VoiceSearch._();

  static VoiceMode? _mode;

  /// Asked once per run.
  static Future<VoiceMode> mode() async =>
      _mode ??= await impl.voiceMode().catchError((_) => VoiceMode.none);

  /// Whether to show the microphone.
  static Future<bool> available() async => await mode() != VoiceMode.none;

  /// The words heard, or null (cancelled, nothing heard, no recognizer).
  /// Callers with a [VoiceMode.app] recognizer go through
  /// voice_search_flow.dart, which shows the listening dialog.
  static Future<String?> listen({String prompt = 'Cosa vuoi guardare?'}) async {
    if (await mode() == VoiceMode.none) return null;
    try {
      final t = (await impl.listen(prompt))?.trim() ?? '';
      return t.isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }

  /// Stops a listen in progress; it then answers null.
  static Future<void> cancel() async {
    try {
      await impl.cancel();
    } catch (_) {}
  }
}
