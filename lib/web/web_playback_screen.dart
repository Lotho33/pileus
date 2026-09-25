import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../core/app_lifecycle.dart';
import '../core/di/injection.dart';
import '../core/utils/perf_log.dart' show kPerfDiagnostics;
import '../features/media/data/media_repository.dart';
import '../features/player/bloc/playback_bloc.dart';
import '../features/player/bloc/playback_event.dart';
import '../features/player/bloc/playback_state.dart';
import '../features/player/episode_nav.dart';
import '../features/player/episode_poster.dart';
import '../features/player/live_stall_watchdog.dart';
import '../features/player/models/playback_args.dart';
import '../features/player/models/skip_interval.dart';
import '../features/player/presentation/widgets/pointer_next_episode_banner.dart';
import '../features/player/presentation/widgets/pointer_skip_button.dart';

/// Gated the same way as the rest of the app's diagnostics (perf_log.dart,
/// playback_bloc.dart) — these 5 call sites used to be plain `debugPrint`,
/// which (unlike an `assert`/`kDebugMode`-guarded block) ships in release
/// builds too and, for the ones logging a resolved stream URL, leaks it to
/// anyone with the browser's devtools open.
void _dlog(String message) {
  if (kDebugMode || kPerfDiagnostics) debugPrint(message);
}

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
  // Set once by _onVideoElementCreated, before anything else in this State
  // can possibly run (see that method's doc comment) — `late` throws loudly
  // rather than misbehaving silently if that guarantee is ever wrong.
  late web.HTMLVideoElement _video;

  _Hls? _hls;
  Timer? _progressTimer;
  bool _opened = false;
  bool _firstOpen = true;

  // ── episode navigation / AniSkip / CW closing / live watchdog ────────────
  // Ported from the mobile (episode-nav) and TV (AniSkip + live-stall
  // watchdog) players — see episode_nav.dart/skip_interval.dart/
  // live_stall_watchdog.dart. Web had none of this before; it also has no
  // prefetch (unlike desktop/mobile) — every episode change here resolves
  // cold through PlaybackBloc, same as the very first one.
  late String _curMediaId = widget.mediaId;
  // Never reassigned on web (unlike desktop): there's no client-side
  // getStreams/source-matching here, InitializeVideoEvent's preferredLabel
  // just keeps asking the bloc for the same source label on every episode.
  late final String _curSourceLabel = widget.args.sourceLabel;
  late String _curTitle = widget.args.title ?? '';
  late final EpisodeNavState _nav = EpisodeNavState.fromArgs(widget.args);
  bool _resolvingEpisode = false;
  bool _autoAdvanced = false;
  bool _nextEpisodeDismissed = false;
  int? _nextEpisodeSecs;
  // Mirrors PlaybackProgress._progressCleared (shared/player/playback_progress.dart)
  // — that helper takes a PlayerEngine, which this screen doesn't have, so
  // the same 90%/95% continue-watching close/roll-forward logic is
  // reimplemented here against _video.currentTime/duration instead (audit
  // finding A4: the web player never closed/advanced a CW entry at all).
  bool _progressCleared = false;

  List<SkipInterval> _skipIntervals = const [];
  SkipInterval? _activeSkip;
  bool _skipDismissed = false;

  // Audit finding A3: a fatal error after the stream had already opened
  // (token expiry, a decode error, a blocked mid-stream request) used to
  // only _dlog and leave the user on a frozen/black frame with no way to
  // retry short of leaving the player entirely.
  String? _fatalError;

  LiveStallWatchdog? _liveWatchdog;

  @override
  void initState() {
    super.initState();
    if (!widget.args.isLive) {
      _progressTimer =
          Timer.periodic(const Duration(seconds: 15), (_) => _saveProgress());
    }
    // The <video> element keeps playing regardless (browsers don't pause
    // media on a backgrounded tab) — this only gates the 15s heartbeat, same
    // reasoning as desktop/mobile.
    AppLifecycleReactor.instance.state.addListener(_onLifecycle);
    if (widget.args.isLive) {
      _liveWatchdog = LiveStallWatchdog(
        isHealthy: () => mounted && _fatalError == null && !_video.paused,
        onStallTier1: () {
          _video.pause();
          _video.play().toDart.catchError((_) => null);
        },
        onStallTier2: () {
          if (!mounted) return;
          _hls?.destroy();
          _hls = null;
          setState(() => _opened = false);
          context.read<PlaybackBloc>().add(InitializeVideoEvent(
                pluginId: widget.pluginId,
                mediaId: _curMediaId,
                preferredLabel: _curSourceLabel,
              ));
        },
      )..arm();
    }
  }

  /// `HtmlElementView.fromTagName`'s creation callback — fires once, with the
  /// freshly created `<video>`, before it's attached to the DOM. Replaces the
  /// previous `dart:ui_web` `registerViewFactory(_viewType, (int _) =>
  /// _video)` with a `viewType` unique per screen instance (a fresh
  /// timestamp every time this screen opened): `registerViewFactory` has no
  /// unregister API at all, so that pattern permanently pinned one `<video>`
  /// element + hls.js instance + every listener below in memory, once per
  /// player open, for the entire lifetime of the browser tab — the more
  /// titles you played in one session, the more piled up, never released
  /// (2026-09-25 finding). `fromTagName` creates the element the normal way
  /// per `HtmlElementView` instance instead, so it can actually be collected
  /// once this screen is gone.
  ///
  /// Nothing in this State can run before this — the bloc event that
  /// eventually produces PlaybackReady is dispatched by `WebPlaybackScreen`'s
  /// own `BlocProvider.create`, which needs this widget's subtree (this
  /// `HtmlElementView`, in particular) to finish its first build first, and
  /// its actual network round-trip takes far longer than that regardless —
  /// so `_video` is always set before `_onReady`/anything downstream of it
  /// can reference it.
  void _onVideoElementCreated(Object element) {
    _video = element as web.HTMLVideoElement;
    _video
      ..autoplay = true
      ..controls = true
      ..setAttribute('playsinline', 'true')
      ..style.setProperty('width', '100%')
      ..style.setProperty('height', '100%')
      ..style.setProperty('background', 'black');
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
        _dlog('[web player] <video> element error: '
            'code=${err?.code} message=${err?.message}');
        // Only a failure *after* the stream had already opened is "fatal" in
        // the sense of needing a retry affordance — an error racing the very
        // first open is already handled by PlaybackFailed/the loading path.
        if (_opened && mounted && _fatalError == null) {
          setState(() => _fatalError =
              'Riproduzione interrotta (errore ${err?.code ?? '?'}).');
        }
      }).toJS,
    );
    _video.addEventListener(
      'timeupdate',
      ((web.Event _) => _onTimeUpdate()).toJS,
    );
  }

  void _onLifecycle() {
    if (!mounted) return;
    if (AppLifecycleReactor.instance.isBackgrounded) {
      if (_progressTimer != null) {
        _progressTimer!.cancel();
        _progressTimer = null;
        if (!widget.args.isLive) _saveProgress();
      }
    } else if (_progressTimer == null && !widget.args.isLive) {
      _progressTimer =
          Timer.periodic(const Duration(seconds: 15), (_) => _saveProgress());
    }
  }

  @override
  void dispose() {
    AppLifecycleReactor.instance.state.removeListener(_onLifecycle);
    _progressTimer?.cancel();
    _liveWatchdog?.disarm();
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
    // Fires for both the very first stream and every subsequent episode
    // (see _openEpisode, which dispatches InitializeVideoEvent and resets
    // _opened) — so AniSkip markers refresh per-episode for free.
    setState(() {
      _skipIntervals = parseSkipTimes(s.extra['skip_times']);
      _activeSkip = null;
      _skipDismissed = false;
    });
    _attachSource(s.resolvedUrl);
    if (!widget.args.isLive) _markOpened();
    // The launch-time resume position only ever applies to the very first
    // episode opened — a later episode/season should start at 0, not
    // whatever position the original deep-link/continue-watching tap asked
    // for.
    if (_firstOpen) {
      _firstOpen = false;
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
    }
    _video.play().toDart.catchError((_) => null);
  }

  void _retryFatal() {
    setState(() {
      _fatalError = null;
      _opened = false;
    });
    context.read<PlaybackBloc>().add(InitializeVideoEvent(
          pluginId: widget.pluginId,
          mediaId: _curMediaId,
          preferredLabel: _curSourceLabel,
        ));
  }

  void _onTimeUpdate() {
    if (!mounted) return;
    _liveWatchdog?.recordProgress();
    if (widget.args.isLive) return;

    final pos = _video.currentTime;
    final dur = _video.duration;
    if (pos.isNaN || !dur.isFinite || dur <= 0) return;

    final active = activeSkipInterval(
        _skipIntervals, Duration(milliseconds: (pos * 1000).round()));
    if (active != _activeSkip) {
      setState(() {
        _activeSkip = active;
        if (active != null) _skipDismissed = false;
      });
    }

    _maybeClearProgress(pos, dur);

    if (dur <= 60 || !_nav.hasNext) return;
    final remaining = dur - pos;
    if (remaining > 0 && remaining <= 30 && !_nextEpisodeDismissed) {
      final r = remaining.round();
      if (_nextEpisodeSecs != r) setState(() => _nextEpisodeSecs = r);
    } else if (_nextEpisodeSecs != null) {
      setState(() => _nextEpisodeSecs = null);
    }
    if (remaining <= 0 && !_autoAdvanced && !_resolvingEpisode) {
      _autoAdvanced = true;
      _goToNextEpisode();
    }
  }

  /// Same 90%/95% thresholds as PlaybackProgress.maybeClear (shared/player/
  /// playback_progress.dart) — a same-season next episode rolls the CW entry
  /// forward to it at ≥90%; otherwise (movie or last episode of a season) it
  /// is dropped at ≥95% instead of lingering at ~100% forever.
  void _maybeClearProgress(double pos, double dur) {
    if (_progressCleared) return;
    final frac = pos / dur;
    final a = widget.args;
    final repo = getIt<MediaRepository>();
    final hasSameSeasonNext = _nav.episodeIndex >= 0 &&
        _nav.episodeIndex + 1 < _nav.episodeList.length;
    if (hasSameSeasonNext && frac >= 0.90) {
      _progressCleared = true;
      final nextId = _nav.episodeList[_nav.episodeIndex + 1];
      final nextTitle = _nav.episodeIndex + 1 < _nav.episodeTitles.length
          ? _nav.episodeTitles[_nav.episodeIndex + 1]
          : '';
      repo.updateProgress(
        pluginId: a.epPluginId,
        mediaId: nextId,
        parentId: _nav.parentId,
        position: const Duration(seconds: 31),
        title: nextTitle.isNotEmpty ? nextTitle : a.showTitle,
        showTitle: a.showTitle,
        // The *next* episode's own thumbnail, not the one currently
        // playing's — see episode_poster.dart's doc comment.
        poster: posterForEpisode(
          episodeThumbs: _nav.episodeThumbs,
          index: _nav.episodeIndex + 1,
          seriesCoverUrl: _nav.seriesCoverUrl,
          seriesPoster: _nav.seriesPoster,
          fallback: a.poster,
        ),
        rating: a.rating,
        genres: a.genres,
        // Always the series' own synopsis, never an episode's — see
        // PlaybackArgs.copyWith's doc comment.
        plot: a.plot,
        year: a.year,
        seasonNumber:
            numberForEpisode(_nav.seasonNumbers, _nav.episodeIndex + 1),
        episodeNumber:
            numberForEpisode(_nav.episodeNumbers, _nav.episodeIndex + 1),
      );
      repo.deleteProgress(providerID: a.epPluginId, playableID: _curMediaId);
    } else if (!hasSameSeasonNext && frac >= 0.95) {
      _progressCleared = true;
      repo.deleteProgress(providerID: a.epPluginId, playableID: _curMediaId);
    }
  }

  // ── episode navigation ────────────────────────────────────────────────

  Future<void> _goToNextEpisode() async {
    if (_resolvingEpisode || !_nav.hasNext) return;
    setState(() {
      _resolvingEpisode = true;
      _nextEpisodeSecs = null;
    });
    try {
      final target = await _nav.resolveNext(getIt<MediaRepository>());
      if (target == null) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      _openEpisode(target);
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvingEpisode = false;
          _fatalError = 'Impossibile cambiare episodio.';
        });
      }
    }
  }

  Future<void> _goToPreviousEpisode() async {
    if (_resolvingEpisode || !_nav.hasPrevious) return;
    setState(() {
      _resolvingEpisode = true;
      _nextEpisodeSecs = null;
    });
    try {
      final target = await _nav.resolvePrevious(getIt<MediaRepository>());
      if (target == null) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      _openEpisode(target);
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvingEpisode = false;
          _fatalError = 'Impossibile cambiare episodio.';
        });
      }
    }
  }

  /// No prefetch on web (unlike desktop/mobile) — always resolves cold via
  /// PlaybackBloc, same as the initial load. [_onReady] handles the actual
  /// `_attachSource` once PlaybackReady arrives.
  void _openEpisode(EpisodeNavTarget target) {
    if (!mounted) return;
    _hls?.destroy();
    _hls = null;
    setState(() {
      _curMediaId = target.mediaId;
      _curTitle = target.title.isNotEmpty ? target.title : _curTitle;
      _opened = false;
      _resolvingEpisode = false;
      _autoAdvanced = false;
      _nextEpisodeDismissed = false;
      _progressCleared = false;
      _fatalError = null;
    });
    context.read<PlaybackBloc>().add(InitializeVideoEvent(
          pluginId: widget.pluginId,
          mediaId: target.mediaId,
          preferredLabel: _curSourceLabel,
        ));
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
    _dlog('[web player] attachSource: looksHls=$looksHls '
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
              _dlog('[web player] hls.js error: type=${data.type} '
                  'details=${data.details} fatal=${data.fatal ?? false}'
                  '${resp == null ? '' : ' httpStatus=${resp.code} body=${resp.text}'}'
                  ' url=$url');
              // Same "only after the stream had already opened" reasoning as
              // the <video> 'error' listener above — a fatal error hls.js
              // itself gave up recovering from, at a point where the user
              // was already watching, needs a retry affordance (audit A3).
              if ((data.fatal ?? false) &&
                  _opened &&
                  mounted &&
                  _fatalError == null) {
                setState(() => _fatalError =
                    'Riproduzione interrotta (${data.details ?? data.type ?? 'errore hls.js'}).');
              }
            }).toJS);
        // How many renditions hls.js actually extracted from the master —
        // if this never fires, or fires with 0 levels, the manifest parse
        // itself is the failure point, not anything past it.
        h.on(
            _hlsManifestParsedEvent,
            ((JSAny? _, _HlsManifestParsedData data) {
              _dlog('[web player] hls.js manifest parsed: '
                  '${data.levels?.length ?? 0} level(s) url=$url');
            }).toJS);
        // If parsing found levels but none of these ever fire, hls.js
        // decided not to load anything — a level/autoStartLoad config
        // issue, not a network or parse failure.
        for (final evt in _hlsTraceEvents) {
          h.on(
              evt,
              ((JSAny? _, JSAny? __) {
                _dlog('[web player] hls.js event: $evt url=$url');
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
    // _progressCleared: once _maybeClearProgress has closed/rolled the entry
    // forward (≥95%/≥90%), the 15s heartbeat must not silently recreate it —
    // same guard PlaybackProgress.save uses on desktop/mobile.
    if (widget.args.isLive || _progressCleared) return;
    final pos = _video.currentTime;
    final dur = _video.duration;
    if (pos.isNaN || pos <= 0) return;
    final a = widget.args;
    getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: _curMediaId,
      parentId: _nav.parentId,
      position: Duration(seconds: pos.toInt()),
      totalDuration:
          dur.isFinite ? Duration(seconds: dur.toInt()) : Duration.zero,
      title: _curTitle.isNotEmpty ? _curTitle : a.showTitle,
      showTitle: a.showTitle,
      poster: _currentEpisodePoster(),
      rating: a.rating,
      genres: a.genres,
      plot: a.plot,
      year: a.year,
      seasonNumber: _currentSeasonNumber(),
      episodeNumber: _currentEpisodeNumber(),
    );
  }

  /// Writes a continue-watching row the instant the stream opens, even at
  /// position 0 — mycelium no longer gates Continue Watching on a minimum
  /// position, so a title should appear there as soon as it's opened rather
  /// than waiting for the first 15s heartbeat. Runs again for every episode
  /// change (see _onReady), each time with the now-current _curMediaId.
  void _markOpened() {
    final a = widget.args;
    getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: _curMediaId,
      parentId: _nav.parentId,
      position: Duration.zero,
      totalDuration: Duration.zero,
      title: _curTitle.isNotEmpty ? _curTitle : a.showTitle,
      showTitle: a.showTitle,
      poster: _currentEpisodePoster(),
      rating: a.rating,
      genres: a.genres,
      plot: a.plot,
      year: a.year,
      seasonNumber: _currentSeasonNumber(),
      episodeNumber: _currentEpisodeNumber(),
    );
  }

  /// This episode's Continue Watching cover — see episode_poster.dart's doc
  /// comment for the bug this replaces (the cover used to stay stuck on
  /// whichever episode the session started on).
  String _currentEpisodePoster() => posterForEpisode(
        episodeThumbs: _nav.episodeThumbs,
        index: _nav.episodeIndex,
        seriesCoverUrl: _nav.seriesCoverUrl,
        seriesPoster: _nav.seriesPoster,
        fallback: widget.args.poster,
      );

  // This episode's real "S{x}"/"E{y}" number — 0 when unknown (a movie, or a
  // plugin that doesn't tag episodes), which the CW card hides rather than
  // showing "S0 · E0".
  int _currentEpisodeNumber() =>
      numberForEpisode(_nav.episodeNumbers, _nav.episodeIndex);
  int _currentSeasonNumber() =>
      numberForEpisode(_nav.seasonNumbers, _nav.episodeIndex);

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
        ? '${widget.args.showTitle}  ·  $_curTitle'
        : _curTitle;
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocListener<PlaybackBloc, PlaybackState>(
        listener: (context, s) {
          if (s is PlaybackReady) _onReady(s);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            HtmlElementView.fromTagName(
              tagName: 'video',
              onElementCreated: _onVideoElementCreated,
            ),
            BlocBuilder<PlaybackBloc, PlaybackState>(
              builder: (context, s) {
                if (_fatalError != null) {
                  return _Overlay(
                    icon: Icons.error_outline_rounded,
                    text: _fatalError!,
                    onBack: _exit,
                    onRetry: _retryFatal,
                  );
                }
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
                          if (!widget.args.isLive && _nav.hasPrevious) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded,
                                  color: Colors.white70),
                              tooltip: 'Episodio precedente',
                              onPressed: _resolvingEpisode
                                  ? null
                                  : _goToPreviousEpisode,
                            ),
                          ],
                          if (!widget.args.isLive && _nav.hasNext) ...[
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded,
                                  color: Colors.white70),
                              tooltip: 'Episodio successivo',
                              onPressed:
                                  _resolvingEpisode ? null : _goToNextEpisode,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_activeSkip != null && !_skipDismissed)
              Positioned(
                right: 28,
                bottom: 28,
                child: Builder(builder: (_) {
                  final outroToNext = _activeSkip!.type == SkipType.ed &&
                      _nav.hasNext &&
                      !_resolvingEpisode;
                  return PointerSkipButton(
                    label:
                        outroToNext ? 'Prossimo episodio' : _activeSkip!.label,
                    icon: outroToNext
                        ? Icons.skip_next_rounded
                        : Icons.fast_forward_rounded,
                    onSkip: () {
                      if (outroToNext) {
                        setState(() => _skipDismissed = true);
                        _goToNextEpisode();
                      } else {
                        _video.currentTime = _activeSkip!.end;
                        setState(() => _skipDismissed = true);
                      }
                    },
                    onDismiss: () => setState(() => _skipDismissed = true),
                  );
                }),
              ),
            if (_nextEpisodeSecs != null)
              Positioned(
                right: 28,
                bottom: 92,
                child: PointerNextEpisodeBanner(
                  secsRemaining: _nextEpisodeSecs!,
                  nextTitle: _nav.episodeIndex + 1 < _nav.episodeTitles.length
                      ? _nav.episodeTitles[_nav.episodeIndex + 1]
                      : null,
                  onPlay: () {
                    setState(() => _nextEpisodeSecs = null);
                    _goToNextEpisode();
                  },
                  onDismiss: () => setState(() {
                    _nextEpisodeSecs = null;
                    _nextEpisodeDismissed = true;
                  }),
                ),
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
  final VoidCallback? onRetry;
  const _Overlay({
    required this.text,
    required this.onBack,
    this.icon,
    this.spinner = false,
    this.onRetry,
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
                if (onRetry != null) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Riprova'),
                  ),
                ],
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
