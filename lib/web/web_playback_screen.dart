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

// hls.js's own event-name constant (Hls.Events.ERROR) — its value is this
// literal string in every hls.js release; hardcoded rather than pulled off
// the JS object to dodge extension-type static-getter interop for one
// constant.
const _hlsErrorEvent = 'hlsError';

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
    if (!widget.args.isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _saveProgress());
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
    final nativeHls =
        _video.canPlayType('application/vnd.apple.mpegurl').isNotEmpty;
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
        h.on(_hlsErrorEvent, ((JSAny? _, _HlsErrorData data) {
          final resp = data.response;
          debugPrint('[web player] hls.js error: type=${data.type} '
              'details=${data.details} fatal=${data.fatal ?? false}'
              '${resp == null ? '' : ' httpStatus=${resp.code} body=${resp.text}'}'
              ' url=$url');
        }).toJS);
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
