import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'voice_search.dart' show VoiceMode;

// The browser's Web Speech API (Chrome, Edge, Safari; not Firefox). Only in
// a secure context: on plain http from a LAN address the browser refuses the
// microphone, so no button shows there.

JSFunction? _ctor() {
  final c = globalContext['SpeechRecognition'] ??
      globalContext['webkitSpeechRecognition'];
  return c.isA<JSFunction>() ? c as JSFunction : null;
}

bool get _secure =>
    (globalContext['isSecureContext'] as JSBoolean?)?.toDart ?? false;

JSObject? _active;
Completer<String?>? _done;

Future<VoiceMode> voiceMode() async =>
    _ctor() != null && _secure ? VoiceMode.app : VoiceMode.none;

Future<String?> listen(String prompt) {
  final ctor = _ctor();
  if (ctor == null) return Future.value(null);
  _finish(null);
  final done = Completer<String?>();
  _done = done;
  final r = ctor.callAsConstructor<JSObject>();
  _active = r;
  final nav = globalContext['navigator'] as JSObject?;
  final lang = nav?['language'];
  r['lang'] = lang.isA<JSString>() ? lang : 'it-IT'.toJS;
  r['interimResults'] = false.toJS;
  r['maxAlternatives'] = 1.toJS;
  r['onresult'] = ((JSObject e) {
    String? text;
    try {
      final results = e['results'] as JSObject;
      final first = results['0'] as JSObject;
      final alt = first['0'] as JSObject;
      text = (alt['transcript'] as JSString).toDart;
    } catch (_) {}
    _finish(text);
  }).toJS;
  r['onerror'] = ((JSObject _) => _finish(null)).toJS;
  r['onend'] = ((JSObject _) => _finish(null)).toJS;
  try {
    r.callMethod('start'.toJS);
  } catch (_) {
    _finish(null);
  }
  return done.future;
}

Future<void> cancel() async {
  final r = _active;
  try {
    r?.callMethod('abort'.toJS);
  } catch (_) {}
  _finish(null);
}

void _finish(String? text) {
  _active = null;
  final d = _done;
  _done = null;
  if (d != null && !d.isCompleted) d.complete(text);
}
