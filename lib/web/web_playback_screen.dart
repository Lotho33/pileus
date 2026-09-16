import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../core/di/injection.dart';
import '../features/media/data/media_repository.dart';
import '../features/player/bloc/playback_bloc.dart';
import '../features/player/bloc/playback_event.dart';
import '../features/player/bloc/playback_state.dart';
import '../features/player/models/playback_args.dart';

// ── hls.js interop ─────────────────────────────────────────────────────────
// hls.min.js is bundled in web/ and loaded from index.html (a <script> tag),
// so `globalThis.Hls` is defined by the time the app runs. It's only needed
// where the browser can't play HLS natively (Chrome/Firefox); Safari plays
// HLS in a bare <video> and this stays dormant.

@JS('Hls')
external JSAny? get _hlsGlobal;

@JS('Hls.isSupported')
external bool _hlsIsSupportedRaw();

bool get _hlsUsable {
  if (_hlsGlobal == null) return false;
  try {
    return _hlsIsSupportedRaw();
  } catch (_) {
    return false;
  }
}

@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external factory _Hls();
  external void loadSource(String url);
  external void attachMedia(web.HTMLVideoElement media);
  external void destroy();
  external void on(String event, JSFunction listener);
}

// hls.js's error-event payload — only the fields read here. `type`/`details`
// are its own error taxonomy (e.g. "networkError"/"manifestLoadError",
// "mediaError"/"bufferStalledError"); `fatal` is whether hls.js gave up on
// this instance entirely vs. is retrying/recovering on its own. `response`
// is only present on network errors (HTTP status + a text body, useful for
// telling a 403/CORS rejection from a genuine timeout).
extension type _HlsErrorData._(JSObject _) implements JSObject {
  external String? get type;
  external String? get details;
  external bool? get fatal;
  external _HlsErrorResponse? get response;
}

extension type _HlsErrorResponse._(JSObject _) implements JSObject {
  external int? get code;
  external String? get text;
}

extension type _HlsManifestParsedData._(JSObject _) implements JSObject {
  external JSArray? get levels;
}

// hls.js's own event-name constants (Hls.Events.*) — these values are the
// literal strings every hls.js release uses; hardcoded rather than pulled
// off the JS object to dodge extension-type static-getter interop for a
// handful of constants.
const _hlsErrorEvent = 'hlsError';
const _hlsManifestParsedEvent = 'hlsManifestParsed';
// Minimal lifecycle trace, not full hls.js debug logging (which is far
// noisier): confirms whether hls.js ever attempts to load a level/fragment
// after parsing the manifest at all — the open question left after
// vixseries/vixmovie's master playlist turned out to parse and rewrite fine
// server-side (2026-09-14) but nothing past it ever reached the server.
const _hlsTraceEvents = [
  'hlsLevelLoading',
  'hlsLevelLoaded',
  'hlsFragLoading',
  'hlsFragLoaded',
];

/// Web player — a plain HTML5 `<video>` behind an [HtmlElementView].
///
/// SPIKE-LEVEL. Known limits (see docs/WEB.md):
///  * HLS: native where the browser supports it (Safari), else hls.js
///    (bundled). Progressive MP4/WebM plays directly everywhere.
///  * `<video>` can't send custom HTTP headers, so header-authenticated
///    streams won't load. The mycelium proxy is expected to hand back a
///    directly-playable URL.
///  * Uses the browser's own transport controls for now.
class WebPlaybackScreen extends StatelessWidget {
  final String pluginId;
  final String mediaId;
  final Map<String, dynamic>? extra;

  const WebPlaybackScreen({
    super.key,
    required this.pluginId,
    required this.mediaId,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final args =
        PlaybackArgs.fromExtra(extra, pluginId: pluginId, mediaId: mediaId);
    return BlocProvider(
      create: (_) {
        final bloc = getIt<PlaybackBloc>();
        final direct = args.directStreamId;
        if (direct != null && direct.isNotEmpty) {
          bloc.add(SelectStreamEvent(pluginId: pluginId, streamId: direct));
        } else {
          bloc.add(InitializeVideoEvent(
            pluginId: pluginId,
            mediaId: mediaId,
            preferredLabel: args.sourceLabel,
          ));
        }
        return bloc;
      },
      child: _View(pluginId: pluginId, mediaId: mediaId, args: args),
    );
  }
}

class _View extends StatefulWidget {
  final String pluginId;
  final String mediaId;
  final PlaybackArgs args;
  const _View(
      {required this.pluginId, required this.mediaId, required this.args});

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  late final String _viewType =
      'pileus-video-${DateTime.now().microsecondsSinceEpoch}';
  final web.HTMLVideoElement _video = web.HTMLVideoElement()..autoplay = true;

  _Hls? _hls;
  Timer? _progressTimer;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _video
      ..controls = true
      ..setAttribute('playsinline', 'true')
      ..style.setProperty('width', '100%')
      ..style.setProperty('height', '100%')
      ..style.setProperty('background', 'black');
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _video);
    // Catches a failure on *either* path _attachSource can take: the plain
    // `_video.src = url` assignment (no listener anywhere before this), and
    // — since hls.js ultimately still feeds this same element via MSE — a
    // fatal decode/format error hls.js's own error event (see _attachSource)
    // didn't already report as fatal. MediaError.code: 1 ABORTED, 2 NETWORK,
    // 3 DECODE, 4 SRC_NOT_SUPPORTED (spec numbering).
    _video.addEventListener(
      'error',
      ((web.Event _) {
        final err = _video.error;
        debugPrint('[web player] <video> element error: '
            'code=${err?.code} message=${err?.message}');
      }).toJS,
    );
    if (!widget.args.isLive) {
      _progressTimer =
          Timer.periodic(const Duration(seconds: 15), (_) => _saveProgress());
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    if (!widget.args.isLive) _saveProgress();
    _hls?.destroy();
    _hls = null;
    _video
      ..pause()
      ..removeAttribute('src')
      ..load();
    super.dispose();
  }

  void _onReady(PlaybackReady s) {
    if (_opened) return;
    _opened = true;
    _attachSource(s.resolvedUrl);
    if (!widget.args.isLive) _markOpened();
    final seek = widget.args.seekTo;
    if (seek > 2) {
      _video.addEventListener(
        'loadedmetadata',
        (web.Event _) {
          try {
            _video.currentTime = seek.toDouble();
          } catch (_) {}
        }.toJS,
      );
    }
    _video.play().toDart.catchError((_) => null);
  }

  /// Picks how to feed the URL to the element:
  ///  * progressive (mp4/webm/…) or HLS the browser plays natively → `src`;
  ///  * HLS in a browser without native support → hls.js (if bundled).
  void _attachSource(String url) {
    final looksHls = url.toLowerCase().contains('.m3u8');
    // canPlayType returns "" (no), "maybe", or "probably" per spec — only
    // Safari genuinely plays HLS natively and returns "probably" for it.
    // Chromium (so Brave/Chrome/Edge too) has no native HLS decoder at all
    // but, because "application/vnd.apple.mpegurl" is a generic-enough MIME
    // string, sometimes hedges with "maybe" rather than committing to "" —
    // checking .isNotEmpty treated that hedge as "yes, native", skipped
    // hls.js entirely, and left the browser to fail outright on its own
    // (confirmed 2026-09-14 on Brave: `<video> element error: code=4`
    // MEDIA_ERR_SRC_NOT_SUPPORTED — the exact playlist played back fine in
    // VLC seconds later, so this was never a server-side/playlist problem).
    final nativeHls =
        _video.canPlayType('application/vnd.apple.mpegurl') == 'probably';
    // The actual branch decision — without this there was no way to tell
    // "hls.js never got a chance to run" (wrong looksHls, or nativeHls true
    // so the browser's own HLS support was trusted instead) apart from
    // absence of every hls.js log line, which is exactly the ambiguity that
    // came up investigating vixseries/vixmovie not playing on web
    // (2026-09-14): PlaybackReady fired, nothing after it, no hls.js event
    // ever printed — this line is what would have settled it immediately.
    debugPrint('[web player] attachSource: looksHls=$looksHls '
        'nativeHls=$nativeHls hlsUsable=$_hlsUsable url=$url');
    if (looksHls && !nativeHls && _hlsUsable) {
      try {
        _hls?.destroy();
        final h = _Hls();
        // Registered before loadSource/attachMedia so an error on the very
        // first manifest fetch can't fire before this is wired up. hls.js
        // otherwise fails a lot of this silently from Dart's side — no
        // exception crosses the JS/Dart boundary, so without this listener
        // a manifest parse failure, a blocked/rejected request, or a fatal
        // media error all look identical to "nothing happens": the <video>
        // just sits on its own idle grey chrome forever (reported on
        // vixseries/vixmovie specifically, 2026-09-14 — root cause not yet
        // identified; this is what's needed to actually see it next time).
        h.on(
            _hlsErrorEvent,
            ((JSAny? _, _HlsErrorData data) {
              final resp = data.response;
              debugPrint('[web player] hls.js error: type=${data.type} '
                  'details=${data.details} fatal=${data.fatal ?? false}'
                  '${resp == null ? '' : ' httpStatus=${resp.code} body=${resp.text}'}'
                  ' url=$url');
            }).toJS);
        // How many renditions hls.js actually extracted from the master —
        // if this never fires, or fires with 0 levels, the manifest parse
        // itself is the failure point, not anything past it.
        h.on(
            _hlsManifestParsedEvent,
            ((JSAny? _, _HlsManifestParsedData data) {
              debugPrint('[web player] hls.js manifest parsed: '
                  '${data.levels?.length ?? 0} level(s) url=$url');
            }).toJS);
        // If parsing found levels but none of these ever fire, hls.js
        // decided not to load anything — a level/autoStartLoad config
        // issue, not a network or parse failure.
        for (final evt in _hlsTraceEvents) {
          h.on(
              evt,
              ((JSAny? _, JSAny? __) {
                debugPrint('[web player] hls.js event: $evt url=$url');
              }).toJS);
        }
        h.loadSource(url);
        h.attachMedia(_video);
        _hls = h;
        return;
      } catch (_) {
        // fall through to a plain src assignment
      }
    }
    _video.src = url;
  }

  void _saveProgress() {
    if (widget.args.isLive) return;
    final pos = _video.currentTime;
    final dur = _video.duration;
    if (pos.isNaN || pos <= 0) return;
    final a = widget.args;
    getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: widget.mediaId,
      parentId: a.parentId,
      position: Duration(seconds: pos.toInt()),
      totalDuration:
          dur.isFinite ? Duration(seconds: dur.toInt()) : Duration.zero,
      title: (a.title?.isNotEmpty ?? false) ? a.title! : a.showTitle,
      showTitle: a.showTitle,
      poster: a.poster,
      rating: a.rating,
      genres: a.genres,
      plot: a.plot,
      year: a.year,
    );
  }

  /// Writes a continue-watching row the instant the stream opens, even at
  /// position 0 — mycelium no longer gates Continue Watching on a minimum
  /// position, so a title should appear there as soon as it's opened rather
  /// than waiting for the first 15s heartbeat.
  void _markOpened() {
    final a = widget.args;
    getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: widget.mediaId,
      parentId: a.parentId,
      position: Duration.zero,
      totalDuration: Duration.zero,
      title: (a.title?.isNotEmpty ?? false) ? a.title! : a.showTitle,
      showTitle: a.showTitle,
      poster: a.poster,
      rating: a.rating,
      genres: a.genres,
      plot: a.plot,
      year: a.year,
    );
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.showTitle.isNotEmpty
        ? '${widget.args.showTitle}  ·  ${widget.args.title ?? ''}'
        : (widget.args.title ?? '');
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocListener<PlaybackBloc, PlaybackState>(
        listener: (context, s) {
          if (s is PlaybackReady) _onReady(s);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            HtmlElementView(viewType: _viewType),
            BlocBuilder<PlaybackBloc, PlaybackState>(
              builder: (context, s) {
                if (s is PlaybackFailed) {
                  return _Overlay(
                    icon: Icons.error_outline_rounded,
                    text: s.errorMessage,
                    onBack: _exit,
                  );
                }
                if (s is! PlaybackReady) {
                  return _Overlay(
                    spinner: true,
                    text: switch (s) {
                      FetchingStreams() => 'Ricerca sorgenti…',
                      ResolvingMediaStream() => 'Risoluzione stream…',
                      PlaybackResolveProgress(:final message) => message,
                      _ => 'Avvio riproduzione…',
                    },
                    onBack: _exit,
                  );
                }
                return Align(
                  alignment: Alignment.topLeft,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: _exit,
                          ),
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool spinner;
  final VoidCallback onBack;
  const _Overlay({
    required this.text,
    required this.onBack,
    this.icon,
    this.spinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (spinner)
                  const CircularProgressIndicator(color: Colors.white),
                if (icon != null)
                  Icon(icon, color: const Color(0xFFFF5252), size: 48),
                const SizedBox(height: 16),
                Text(text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
          ),
        ],
      ),
    );
  }
}
