import 'dart:js_interop';

import 'package:web/web.dart' as web;

// navigator.mediaSession — see media_session.dart. Every call is guarded:
// older TV browsers (Tizen 6.5's Chromium) may lack parts of the API, and a
// missing media session must never break playback.

const _actions = [
  'play',
  'pause',
  'seekbackward',
  'seekforward',
  'previoustrack',
  'nexttrack',
];

web.MediaSession? get _session {
  try {
    return web.window.navigator.mediaSession;
  } catch (_) {
    return null;
  }
}

void _handle(web.MediaSession s, String action, void Function()? f) {
  try {
    s.setActionHandler(action, f == null ? null : ((JSAny? _) => f()).toJS);
  } catch (_) {
    // Action not supported by this browser — just not offered.
  }
}

void update({
  required String title,
  String subtitle = '',
  String artworkUrl = '',
  void Function()? onPlay,
  void Function()? onPause,
  void Function(int seconds)? onSeekBy,
  void Function()? onNext,
  void Function()? onPrevious,
}) {
  final s = _session;
  if (s == null) return;
  try {
    s.metadata = web.MediaMetadata(web.MediaMetadataInit(
      title: title,
      artist: subtitle,
      artwork: [
        if (artworkUrl.isNotEmpty) web.MediaImage(src: artworkUrl),
      ].toJS,
    ));
  } catch (_) {}
  _handle(s, 'play', onPlay);
  _handle(s, 'pause', onPause);
  _handle(s, 'seekbackward', onSeekBy == null ? null : () => onSeekBy(-10));
  _handle(s, 'seekforward', onSeekBy == null ? null : () => onSeekBy(10));
  _handle(s, 'previoustrack', onPrevious);
  _handle(s, 'nexttrack', onNext);
}

void setPlaying(bool playing) {
  try {
    _session?.playbackState = playing ? 'playing' : 'paused';
  } catch (_) {}
}

void clear() {
  final s = _session;
  if (s == null) return;
  try {
    s.metadata = null;
    s.playbackState = 'none';
  } catch (_) {}
  for (final a in _actions) {
    _handle(s, a, null);
  }
}
