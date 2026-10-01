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
import '../core/grpc/clients/media_client.dart' show ProgressResponse;
import '../features/media/data/media_repository.dart';
import '../features/player/bloc/playback_bloc.dart';
import '../features/player/bloc/playback_event.dart';
import '../features/player/bloc/playback_state.dart';
import '../features/player/episode_nav.dart';
import '../features/player/episode_poster.dart';
import '../features/player/episode_prefetch.dart';
import '../features/player/live_stall_watchdog.dart';
import '../features/player/models/playback_args.dart';
import '../features/player/models/skip_interval.dart';
import '../features/player/player_tuning.dart';
import '../features/player/presentation/widgets/pointer_next_episode_banner.dart';
import '../features/player/presentation/widgets/pointer_skip_button.dart';
import '../features/player/profile_lease_conflict.dart';
import '../features/player/resume_seek.dart';

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
  external factory _Hls([_HlsConfig? config]);
  external void loadSource(String url);
  external void attachMedia(web.HTMLVideoElement media);
  external void destroy();
  external void on(String event, JSFunction listener);
}

// hls.js's own constructor config — only the one field this needs.
// `startPosition` (seconds, default -1 = hls.js's own "from the start/live
// edge") is hls.js's contract-level "open at position" hook, the same role
// mk.Media.start plays for mpv and BetterPlayerConfiguration/seekTo plays
// for ExoPlayer — see PlayerEngine.open's own doc. Passed once at
// construction time only, so — unlike mpv's `start` property (see
// player_engine.dart) — there's nothing to leak into a later _Hls() built
// fresh for the next episode/retry.
extension type _HlsConfig._(JSObject _) implements JSObject {
  external factory _HlsConfig({double startPosition});
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
// after parsing the manifest at all — useful when a master playlist parses
// and rewrites fine server-side but nothing past it ever reaches the
// server.
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
        final directUrl = args.directUrl;
        final direct = args.directStreamId;
        final startPositionSec =
            resolveStartPositionSec(isLive: args.isLive, seekTo: args.seekTo);
        if (directUrl != null && directUrl.isNotEmpty) {
          bloc.add(UseDirectUrlEvent(
              url: directUrl, httpHeaders: args.directUrlHeaders));
        } else if (direct != null && direct.isNotEmpty) {
          bloc.add(SelectStreamEvent(
              pluginId: pluginId,
              streamId: direct,
              startPositionSec: startPositionSec));
        } else {
          bloc.add(InitializeVideoEvent(
            pluginId: pluginId,
            mediaId: mediaId,
            preferredLabel: args.sourceLabel,
            startPositionSec: startPositionSec,
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
  // First real frame AND (if applicable) the resume seek confirmed landed —
  // see _onTimeUpdate's own gate and kResumeCoverSafetyTimeout's doc. Drives
  // the black cover in build() (mirrors TV's own "Cover nera fino al primo
  // frame", the one thing web never had — this platform has no PlayerEngine
  // to reveal a poster/black behind, just the bare <video> element).
  bool _videoStarted = false;
  // Backstop for _videoStarted's own resume-confirmation gate — re-armed on
  // every _attachSource, cancelled the moment _videoStarted flips on its
  // own.
  Timer? _resumeCoverSafetyTimer;

  // ── episode navigation / skip markers / CW closing / live watchdog ───────
  // See episode_nav.dart/skip_interval.dart/live_stall_watchdog.dart.
  late String _curMediaId = widget.mediaId;
  // NOT final — the warm path in _openEpisode reassigns this to whatever
  // label EpisodePrefetcher actually matched (it falls back to the first
  // available source if the current label has no equivalent on the next
  // episode), same as mobile/desktop. A stray `final` here was caught before
  // ever shipping — it's the exact same LateInitializationError
  // class of bug the desktop port had with `_progress`, see
  // desktop_playback_screen.dart's doc on that field. On the cold path this
  // still just keeps asking InitializeVideoEvent for the same label as
  // before, unchanged.
  late String _curSourceLabel = widget.args.sourceLabel;
  late String _curTitle = widget.args.title ?? '';
  // Fresh per-episode rating/year once known — null means "nothing fresher
  // than widget.args yet", read with a `?? widget.args.rating`/`.year`
  // fallback at every continue-watching write site. Without this, every CW
  // write past the first episode of a session would keep reporting the
  // *first* episode's rating/year forever — _currentEpisodePoster()/
  // _currentSeasonNumber()/_currentEpisodeNumber() below already got this
  // right by reading _nav fresh each time, rating/year just got missed.
  double? _curRating;
  int? _curYear;
  late final EpisodeNavState _nav = EpisodeNavState.fromArgs(widget.args);
  // Engine-agnostic and shared verbatim with mobile/desktop/TV — see
  // episode_prefetch.dart.
  late final _prefetcher = EpisodePrefetcher(
      repo: getIt<MediaRepository>(), pluginId: widget.pluginId);
  // Reassigned to a fresh (targetSec: 0) instance on every episode switch,
  // same as mobile/desktop/TV — see ResumeSeekController.
  late ResumeSeekController _resumeSeek;
  bool _resolvingEpisode = false;
  // True from the moment _openEpisode starts switching to a new episode
  // until _onReady confirms the new stream has actually attached. Guards
  // _saveProgress (heartbeat/dispose/backgrounding) against firing in that
  // window: without it, a 15s tick or a dispose-on-exit landing while the
  // old <video> was still mid-teardown wrote the *new* episode's identity
  // with the *old* episode's stale position (audit finding).
  bool _transitioningEpisode = false;
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

  // The native <video> element's own 'error' event fires on the very first
  // failure with no internal retry of its own — unlike hls.js's `fatal`
  // flag (see the listener below), which only ever fires *after* hls.js
  // already exhausted its own internal recovery attempts, so that path is
  // deliberately left immediate. TV/mobile/desktop all hold a plain engine
  // error behind a several-second grace window before surfacing it, since
  // "many are transient — one failed segment/manifest fetch that then
  // retries successfully" (see e.g. mobile_playback_screen.dart's
  // _onEngineError) — web's native-<video> path had no such grace at all:
  // the one platform of the four that would flash the blocking error
  // overlay on a blip the others silently shrug off.
  String? _pendingFatalError;
  Timer? _errorGrace;
  // Non-null shows _TakeoverOverlay instead of every other overlay —
  // contract "One device playing per profile", either the pre-play ABORTED
  // prompt (PlaybackPlayingElsewhere, "Guarda qui") or a mid-playback
  // take-over (_onPlaybackTakenOver, "Riprendi qui"). Never auto-dismissed
  // or retried — only the user's own tap on either button clears it.
  _TakeoverPrompt? _takeoverPrompt;

  LiveStallWatchdog? _liveWatchdog;
  // Set from the <video> element's own 'waiting'/'playing' events (wired in
  // _onVideoElementCreated) — the DOM's own signal for "stalled, fetching
  // more data" vs. actually rendering frames, mirroring PlayerEngine.
  // buffering on the other backends. Used only by the live watchdog: a live
  // stream stuck buffering forever used to never be recovered at all (see
  // LiveStallWatchdog's doc).
  bool _buffering = false;

  @override
  void initState() {
    super.initState();
    _resumeSeek = ResumeSeekController(
        targetSec: widget.args.seekTo, isLive: widget.args.isLive);
    // isLive skips this on purpose even for the single-device-lease
    // heartbeat's sake — see PlaybackProgress's class doc
    // ("Why every screen's 15s heartbeat still skips live streams").
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
        isBuffering: () => _buffering,
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
  /// titles you played in one session, the more piled up, never released.
  /// `fromTagName` creates the element the normal way
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
        if (!_opened || !mounted || _fatalError != null) return;
        // Held behind a grace window instead of surfacing immediately — see
        // _pendingFatalError's doc for why (this native-<video> path, unlike
        // hls.js's own `fatal` errors below, used to have none at all). Every
        // new 'error' here re-arms the window, same as the other three
        // platforms' engine-error handling: as long as failures keep
        // happening, keep waiting instead of showing a message from an
        // earlier failure once its own window happens to elapse.
        //
        // A native (non-hls.js) source doesn't expose an HTTP status to
        // MediaError, only a generic code — see profile_lease_conflict.dart.
        // A browser that happens to fold the status into `message` (some do
        // for network errors) still gets the friendly text. Unlike a plain
        // decode/network error, a lease conflict never self-recovers (the
        // lease stays elsewhere until someone explicitly takes it back), so
        // it skips the grace window entirely and goes straight to the
        // take-over prompt — no "Riprova", ever, for this one.
        if (looksLikeProfileLeaseConflict(err?.message ?? '')) {
          _onPlaybackTakenOver('');
          return;
        }
        _pendingFatalError = 'Riproduzione interrotta (errore ${err?.code ?? '?'}).';
        _errorGrace?.cancel();
        _errorGrace = Timer(kErrorGraceDuration, () {
          if (!mounted || _fatalError != null) return;
          if (!_video.paused) {
            // Recovered on its own within the window.
            _pendingFatalError = null;
            return;
          }
          setState(() => _fatalError = _pendingFatalError);
        });
      }).toJS,
    );
    // Mirrors PlayerEngine.buffering on the other backends — see _buffering's
    // doc. 'canplay'/'playing' both signal "no longer starved for data"
    // (some browsers fire one but not the other depending on why playback
    // paused), so either clears it.
    _video.addEventListener(
      'waiting',
      ((web.Event _) => _buffering = true).toJS,
    );
    _video.addEventListener(
      'playing',
      ((web.Event _) => _buffering = false).toJS,
    );
    _video.addEventListener(
      'canplay',
      ((web.Event _) => _buffering = false).toJS,
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
    _errorGrace?.cancel();
    _resumeCoverSafetyTimer?.cancel();
    _liveWatchdog?.disarm();
    if (!widget.args.isLive) _saveProgress();
    // Best-effort, never blocks teardown — see ReleasePlaybackRequest's own
    // doc (contract "One device playing per profile"): frees this device's
    // hold on the lease at once instead of leaving it to lapse by itself
    // ~90s later, so switching to another device never has to wait. Not
    // called on an episode switch (playback stays on this same device).
    getIt<MediaRepository>().releasePlayback();
    _hls?.destroy();
    _hls = null;
    _video
      ..pause()
      ..removeAttribute('src')
      ..load();
    super.dispose();
  }

  // Backstop for _onTimeUpdate's own resume-confirmation gate on
  // _videoStarted: if the resume seek/confirmation never lands (dropped
  // seek, no more 'timeupdate' events), don't leave the black cover up
  // forever. Cancelled early in _onTimeUpdate the moment _videoStarted
  // actually flips on its own.
  void _armResumeCoverSafetyTimer() {
    _resumeCoverSafetyTimer?.cancel();
    _resumeCoverSafetyTimer = Timer(kResumeCoverSafetyTimeout, () {
      if (mounted && !_videoStarted) setState(() => _videoStarted = true);
    });
  }

  void _onReady(PlaybackReady s) {
    if (_opened) return;
    _opened = true;
    // The new stream is confirmed resolved and about to attach — the
    // transition started by _openEpisode is over, heartbeat/dispose saves
    // are safe again (against the new episode's own state, from here on).
    _transitioningEpisode = false;
    // Fires for both the very first stream and every subsequent episode
    // (see _openEpisode, which dispatches InitializeVideoEvent and resets
    // _opened) — so skip markers refresh per-episode for free.
    setState(() {
      _skipIntervals = parseSkipTimes(s.extra['skip_times']);
      _activeSkip = null;
      _skipDismissed = false;
    });
    _armResumeCoverSafetyTimer();
    _attachSource(s.resolvedUrl,
        startPosition: _resumeSeek.pendingStartPosition);
    if (!widget.args.isLive) _markOpened();
    // The resume-seek retry loop (_onTimeUpdate) handles the launch-time
    // resume position itself — _resumeSeek is only ever constructed with a
    // non-zero targetSec for the very first episode opened (see initState/
    // _openEpisode), so a later episode/season naturally starts at 0.
    _video.play().toDart.catchError((_) => null);
  }

  void _retryFatal() {
    _errorGrace?.cancel();
    _pendingFatalError = null;
    setState(() {
      _fatalError = null;
      _opened = false;
    });
    // Same "only applies to the title the screen was opened with" guard as
    // mobile/desktop/TV's retry — see PlaybackArgs.directUrl's doc.
    final sameTitle = _curMediaId == widget.mediaId;
    final directUrl = sameTitle ? widget.args.directUrl : null;
    if (directUrl != null && directUrl.isNotEmpty) {
      context.read<PlaybackBloc>().add(UseDirectUrlEvent(
          url: directUrl, httpHeaders: widget.args.directUrlHeaders));
      return;
    }
    context.read<PlaybackBloc>().add(InitializeVideoEvent(
          pluginId: widget.pluginId,
          mediaId: _curMediaId,
          preferredLabel: _curSourceLabel,
          startPositionSec: sameTitle
              ? resolveStartPositionSec(
                  isLive: widget.args.isLive, seekTo: widget.args.seekTo)
              : 0,
        ));
  }

  void _onTimeUpdate() {
    if (!mounted) return;
    _liveWatchdog?.recordProgress();
    if (widget.args.isLive) {
      // No resume concept for live (ResumeSeekController.isDone is trivially
      // true) — the cover only ever waits on the first real frame here.
      if (!_videoStarted && _video.currentTime > 0) {
        _resumeCoverSafetyTimer?.cancel();
        setState(() => _videoStarted = true);
      }
      return;
    }
    // Belt-and-suspenders alongside the _video.pause() in _openEpisode: a
    // 'timeupdate' already queued before pause() takes effect must not run
    // _maybeClearProgress against the outgoing episode's position while
    // _curMediaId/_nav already point at the incoming one.
    if (_transitioningEpisode) return;

    final posSeconds = _video.currentTime;
    final durSeconds = _video.duration;
    if (posSeconds.isNaN || !durSeconds.isFinite || durSeconds <= 0) return;
    final pos = Duration(milliseconds: (posSeconds * 1000).round());
    final dur = Duration(milliseconds: (durSeconds * 1000).round());

    // Resume-seek retry loop — see ResumeSeekController (shared with mobile/
    // desktop/TV). Needed on web too: a seek issued right after open() on
    // an HLS stream is sometimes dropped (first segments/playlist not
    // ready yet), so without a confirm-and-retry loop it would just accept
    // whatever position that landed on instead.
    _resumeSeek.onPosition(
        pos, (target) => _video.currentTime = target.inSeconds.toDouble());

    // Primo frame — gated on the resume seek being done (confirmed landed,
    // or never applicable), same reasoning as TV/mobile/desktop's own
    // equivalent: without this, the very first tick after attaching the
    // source (often still ~0 while the resume seek above is in flight)
    // would flip this immediately, flashing frame 0 before the seek jumps
    // forward. _resumeCoverSafetyTimer is the backstop if the resume seek
    // itself never lands.
    if (!_videoStarted && pos > Duration.zero && _resumeSeek.isDone) {
      _resumeCoverSafetyTimer?.cancel();
      setState(() => _videoStarted = true);
    }

    final active = activeSkipInterval(_skipIntervals, pos);
    if (active != _activeSkip) {
      setState(() {
        _activeSkip = active;
        if (active != null) _skipDismissed = false;
      });
    }

    _maybeClearProgress(posSeconds, durSeconds);

    if (durSeconds <= kMinDurationForEndOfEpisodeLogicSec) return;

    // Warm the next episode once we're most of the way through this one —
    // same-season only, same kPrefetchThreshold as the other 3 platforms
    // (episode_prefetch.dart).
    _prefetcher.maybeStart(
      position: pos,
      duration: dur,
      nextEpisodeId: _nav.episodeIndex + 1 < _nav.episodeList.length
          ? _nav.episodeList[_nav.episodeIndex + 1]
          : null,
      currentSourceLabel: _curSourceLabel,
      nextEpisodeFallbackTitle:
          _nav.episodeIndex + 1 < _nav.episodeTitles.length
              ? _nav.episodeTitles[_nav.episodeIndex + 1]
              : null,
    );

    if (!_nav.hasNext) return;
    final remaining = durSeconds - posSeconds;
    if (remaining > 0 &&
        remaining <= kNextEpisodeBannerWindowSec &&
        !_nextEpisodeDismissed) {
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

  /// Same kCwRollForwardThreshold/kCwDropThreshold as PlaybackProgress.
  /// maybeClear (shared/player/playback_progress.dart) — a same-season next
  /// episode rolls the CW entry forward to it, otherwise (movie or last
  /// episode of a season) it's dropped instead of lingering at ~100% forever.
  void _maybeClearProgress(double pos, double dur) {
    if (_progressCleared) return;
    final frac = pos / dur;
    final a = widget.args;
    final repo = getIt<MediaRepository>();
    final hasSameSeasonNext = _nav.episodeIndex >= 0 &&
        _nav.episodeIndex + 1 < _nav.episodeList.length;
    if (hasSameSeasonNext && frac >= kCwRollForwardThreshold) {
      _progressCleared = true;
      final nextId = _nav.episodeList[_nav.episodeIndex + 1];
      final nextTitle = _nav.episodeIndex + 1 < _nav.episodeTitles.length
          ? _nav.episodeTitles[_nav.episodeIndex + 1]
          : '';
      repo.updateProgress(
        pluginId: a.epPluginId,
        mediaId: nextId,
        // See _saveProgress's comment — the stable series id, not
        // _nav.parentId (which EpisodeNavState may already have rewritten to
        // a season-folder id if resolving this next episode crossed one).
        parentId: a.parentId,
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
        rating: _curRating ?? a.rating,
        genres: a.genres,
        // Always the series' own synopsis, never an episode's — see
        // PlaybackArgs.copyWith's doc comment.
        plot: a.plot,
        year: _curYear ?? a.year,
        seasonNumber:
            numberForEpisode(_nav.seasonNumbers, _nav.episodeIndex + 1),
        episodeNumber:
            numberForEpisode(_nav.episodeNumbers, _nav.episodeIndex + 1),
      );
      repo.deleteProgress(providerID: a.epPluginId, playableID: _curMediaId);
    } else if (!hasSameSeasonNext && frac >= kCwDropThreshold) {
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

  /// Warm path: if [EpisodePrefetcher] already resolved this exact episode in
  /// the background (see _onTimeUpdate), skip PlaybackBloc/InitializeVideoEvent
  /// entirely and attach the cached URL directly — same shortcut mobile/
  /// desktop/TV take. Otherwise falls through to the cold path (dispatch
  /// InitializeVideoEvent, same as the initial load); [_onReady] handles the
  /// actual `_attachSource` once PlaybackReady arrives for that path.
  void _openEpisode(EpisodeNavTarget target) {
    if (!mounted) return;
    // Final save for the episode being left, using _curMediaId/the video's
    // current position exactly as they still are — must run before anything
    // below changes them. _saveProgress no-ops on its own if there's nothing
    // meaningful to save (isLive/_progressCleared), so this is always safe
    // to call unconditionally here.
    _saveProgress();
    // From here until the new stream attaches, suppress the heartbeat/
    // dispose save entirely (see _transitioningEpisode's doc). Pausing the
    // outgoing <video> too — previously it kept playing the old stream until
    // the new src/hls.js got attached, which is what let a 'timeupdate' fire
    // against stale content after _curMediaId had already flipped.
    _transitioningEpisode = true;
    _video.pause();
    _hls?.destroy();
    _hls = null;

    final prefetched = _prefetcher.cached;
    if (prefetched != null && prefetched.mediaId == target.mediaId) {
      _prefetcher.clear();
      setState(() {
        _curMediaId = target.mediaId;
        _curTitle = prefetched.title?.isNotEmpty == true
            ? prefetched.title!
            : (target.title.isNotEmpty ? target.title : _curTitle);
        _curSourceLabel = prefetched.sourceLabel;
        _curRating = prefetched.rating;
        _curYear = prefetched.year;
        _skipIntervals = parseSkipTimes(prefetched.skipTimesJson);
        _activeSkip = null;
        _skipDismissed = false;
        _opened = true;
        _videoStarted = false;
        _resolvingEpisode = false;
        _autoAdvanced = false;
        _nextEpisodeDismissed = false;
        _progressCleared = false;
        _fatalError = null;
      });
      _resumeSeek =
          ResumeSeekController(targetSec: 0, isLive: widget.args.isLive);
      _armResumeCoverSafetyTimer();
      _attachSource(prefetched.resolvedUrl,
          startPosition: _resumeSeek.pendingStartPosition);
      _markOpened();
      _transitioningEpisode = false;
      _video.play().toDart.catchError((_) => null);
      return;
    }
    _prefetcher.clear();

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
    _resumeSeek =
        ResumeSeekController(targetSec: 0, isLive: widget.args.isLive);
    // Best-effort per-episode rating/year refresh, fired off in the
    // background rather than awaited — must not delay the stream resolve
    // dispatched right below.
    _refreshEpisodeMeta(target.mediaId);
    context.read<PlaybackBloc>().add(InitializeVideoEvent(
          pluginId: widget.pluginId,
          mediaId: target.mediaId,
          preferredLabel: _curSourceLabel,
        ));
  }

  /// Cold-path counterpart to the warm path's `prefetched.rating`/`.year` —
  /// mobile/desktop/TV all get this from the same getDetails() call that
  /// resolves the stream itself; web's cold path goes through PlaybackBloc
  /// instead (which never fetches episode details), so this is a separate
  /// fire-and-forget fetch. Guarded against a stale result landing after the
  /// user has already moved on to yet another episode.
  Future<void> _refreshEpisodeMeta(String mediaId) async {
    try {
      final details = await getIt<MediaRepository>()
          .getDetails(widget.pluginId, mediaId)
          .timeout(kPrefetchGetDetailsTimeout);
      if (!mounted || _curMediaId != mediaId) return;
      final ep = details.hasEpisode() ? details.episode : null;
      setState(() {
        _curRating = (ep != null && ep.vote > 0) ? ep.vote : null;
        _curYear = details.item.year > 0 ? details.item.year : null;
      });
    } catch (_) {
      // Best-effort only — _saveProgress/_markOpened/_maybeClearProgress all
      // fall back to widget.args.rating/.year when this hasn't landed yet.
    }
  }

  /// Picks how to feed the URL to the element:
  ///  * progressive (mp4/webm/…) or HLS the browser plays natively → `src`;
  ///  * HLS in a browser without native support → hls.js (if bundled).
  ///
  /// [startPosition]: open already at this position (mycelium contract
  /// "Resume from Continue Watching") instead of decoding frame 0 and
  /// jumping on the first 'timeupdate' — see PlayerEngine.open's own doc,
  /// which this mirrors for the one platform with no PlayerEngine to carry
  /// it. hls.js gets it as a constructor option (its own supported hook,
  /// applied before it loads a single segment); the native/`src` path has no
  /// such hook, so this sets `<video>.currentTime` itself once metadata is
  /// available — one-shot ({once: true}), so it can never fire again for a
  /// later source. _resumeSeek remains the safety net either way if this
  /// doesn't land (dropped by hls.js, or the metadata event races the seek).
  void _attachSource(String url, {Duration? startPosition}) {
    final looksHls = url.toLowerCase().contains('.m3u8');
    // canPlayType returns "" (no), "maybe", or "probably" per spec — only
    // Safari genuinely plays HLS natively and returns "probably" for it.
    // Chromium (so Brave/Chrome/Edge too) has no native HLS decoder at all
    // but, because "application/vnd.apple.mpegurl" is a generic-enough MIME
    // string, sometimes hedges with "maybe" rather than committing to "" —
    // checking .isNotEmpty treated that hedge as "yes, native", skipped
    // hls.js entirely, and left the browser to fail outright on its own
    // (confirmed on Brave: `<video> element error: code=4`
    // MEDIA_ERR_SRC_NOT_SUPPORTED — the exact playlist played back fine in
    // VLC seconds later, so this was never a server-side/playlist problem).
    final nativeHls =
        _video.canPlayType('application/vnd.apple.mpegurl') == 'probably';
    // The actual branch decision — without this there's no way to tell
    // "hls.js never got a chance to run" (wrong looksHls, or nativeHls true
    // so the browser's own HLS support was trusted instead) apart from the
    // absence of every hls.js log line, which is exactly the ambiguity a
    // stream that silently never plays on web produces: PlaybackReady
    // fires, nothing after it, no hls.js event ever prints — this line is
    // what settles it immediately.
    _dlog('[web player] attachSource: looksHls=$looksHls '
        'nativeHls=$nativeHls hlsUsable=$_hlsUsable url=$url');
    if (looksHls && !nativeHls && _hlsUsable) {
      try {
        _hls?.destroy();
        final h = _Hls((startPosition != null && startPosition > Duration.zero)
            ? _HlsConfig(startPosition: startPosition.inSeconds.toDouble())
            : null);
        // Registered before loadSource/attachMedia so an error on the very
        // first manifest fetch can't fire before this is wired up. hls.js
        // otherwise fails a lot of this silently from Dart's side — no
        // exception crosses the JS/Dart boundary, so without this listener
        // a manifest parse failure, a blocked/rejected request, or a fatal
        // media error all look identical to "nothing happens": the <video>
        // just sits on its own idle grey chrome forever. This is what's
        // needed to actually see it.
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
                  _fatalError == null &&
                  _takeoverPrompt == null) {
                // hls.js exposes the real HTTP status on network errors
                // (unlike the plain <video> 'error' listener above) — an
                // exact 409 check, not the substring heuristic
                // profile_lease_conflict.dart falls back to elsewhere. Straight
                // to the take-over prompt, no grace window, no auto-retry —
                // this never self-recovers on its own.
                if (resp?.code == 409) {
                  _onPlaybackTakenOver('');
                  return;
                }
                setState(() => _fatalError = 'Riproduzione interrotta '
                    '(${data.details ?? data.type ?? 'errore hls.js'}).');
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
    if (startPosition != null && startPosition > Duration.zero) {
      _video.addEventListener(
        'loadedmetadata',
        ((web.Event _) =>
            _video.currentTime = startPosition.inSeconds.toDouble()).toJS,
        web.AddEventListenerOptions(once: true),
      );
    }
  }

  Future<void> _saveProgress() async {
    // _progressCleared: once _maybeClearProgress has closed/rolled the entry
    // forward (≥95%/≥90%), the 15s heartbeat must not silently recreate it —
    // same guard PlaybackProgress.save uses on desktop/mobile.
    // _transitioningEpisode: mid episode-switch, _curMediaId may already
    // point at the new episode while _video's position is still the old
    // one's (or vice versa, right as the new source attaches) — nothing
    // reliable to save until _onReady clears this. The one call that must
    // go through regardless (the final save for the outgoing episode, fired
    // from _openEpisode) runs before this flag is set, so it's unaffected.
    if (widget.args.isLive || _progressCleared || _transitioningEpisode) {
      return;
    }
    final pos = _video.currentTime;
    final dur = _video.duration;
    if (pos.isNaN || pos <= 0) return;
    final a = widget.args;
    final resp = await getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: _curMediaId,
      // The series' own stable id, never the season-folder id EpisodeNavState
      // rewrites into _nav.parentId while browsing across a season boundary
      // (see EpisodeNavState._resolveAt) — using that here left a stale
      // sibling Continue Watching card behind on a season crossing, since
      // mycelium's per-series cleanup in UpsertProgress is keyed on parent_id.
      parentId: a.parentId,
      position: Duration(seconds: pos.toInt()),
      totalDuration:
          dur.isFinite ? Duration(seconds: dur.toInt()) : Duration.zero,
      title: _curTitle.isNotEmpty ? _curTitle : a.showTitle,
      showTitle: a.showTitle,
      poster: _currentEpisodePoster(),
      // _curRating/_curYear: per-episode metadata refreshed by
      // _refreshEpisodeMeta on every episode switch (warm or cold) — a.rating/
      // a.year are just the launch-time episode's, immutable for the whole
      // widget lifetime. Falls back to them only until the refresh lands.
      rating: _curRating ?? a.rating,
      genres: a.genres,
      plot: a.plot,
      year: _curYear ?? a.year,
      seasonNumber: _currentSeasonNumber(),
      episodeNumber: _currentEpisodeNumber(),
    );
    _checkElsewhere(resp);
  }

  /// Writes a continue-watching row the instant the stream opens, even at
  /// position 0 — mycelium no longer gates Continue Watching on a minimum
  /// position, so a title should appear there as soon as it's opened rather
  /// than waiting for the first 15s heartbeat. Runs again for every episode
  /// change (see _onReady), each time with the now-current _curMediaId.
  Future<void> _markOpened() async {
    final a = widget.args;
    final resp = await getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: _curMediaId,
      // See _saveProgress's comment — the stable series id, not _nav.parentId.
      parentId: a.parentId,
      position: Duration.zero,
      totalDuration: Duration.zero,
      title: _curTitle.isNotEmpty ? _curTitle : a.showTitle,
      showTitle: a.showTitle,
      poster: _currentEpisodePoster(),
      rating: _curRating ?? a.rating,
      genres: a.genres,
      plot: a.plot,
      year: _curYear ?? a.year,
      seasonNumber: _currentSeasonNumber(),
      episodeNumber: _currentEpisodeNumber(),
    );
    _checkElsewhere(resp);
  }

  // Once per instance — see PlaybackProgress._elsewhereReported's identical
  // reasoning on mobile/desktop. Re-armed in _onPlaybackTakenOver's own
  // "Riprendi qui" action, same as those two platforms' resetForRetry.
  bool _elsewhereReported = false;

  void _checkElsewhere(ProgressResponse? resp) {
    if (_elsewhereReported || resp == null || !resp.playbackElsewhere) return;
    _elsewhereReported = true;
    _onPlaybackTakenOver(resp.playingOn);
  }

  // Contract "One device playing per profile": another device took over.
  // Learned either via an HTTP 409 (the native <video> 'error' listener or
  // hls.js's own error event, both in _onVideoElementCreated/_attachSource)
  // or via playback_elsewhere on this device's own next UpdateProgress
  // (_checkElsewhere, every 15s heartbeat). No automatic retry/watchdog/
  // take-back, ever — only the user's own explicit "Riprendi qui" gets
  // playback back on this device.
  void _onPlaybackTakenOver(String playingOn) {
    if (!mounted || _takeoverPrompt != null) return;
    _errorGrace?.cancel();
    _pendingFatalError = null;
    _liveWatchdog?.disarm();
    final resumePos = _video.currentTime.toInt();
    _video.pause();
    // Best-effort — records exactly where this device stopped (mainly
    // matters for the 409 path, which never got to save anything; the
    // playback_elsewhere path already saved this same position as part of
    // the very heartbeat that revealed it).
    _saveProgress();
    setState(() {
      _fatalError = null;
      _takeoverPrompt = _TakeoverPrompt(
        message: playingOn.isNotEmpty
            ? 'Riproduzione spostata su «$playingOn».'
            : 'Questo profilo è ora in riproduzione su un altro dispositivo.',
        actionLabel: 'Riprendi qui',
        backLabel: 'Esci',
        onAction: () {
          _elsewhereReported = false; // a fresh attempt can trip it again
          // Re-armed to resume-seek at resumePos instead of wherever
          // _resumeSeek's own target already landed/confirmed long ago —
          // same reasoning as an episode switch's own rebuild, just with
          // this position instead of 0.
          _resumeSeek = ResumeSeekController(
              targetSec: resumePos, isLive: widget.args.isLive);
          setState(() {
            _takeoverPrompt = null;
            _opened = false;
            _videoStarted = false;
          });
          _armResumeCoverSafetyTimer();
          context.read<PlaybackBloc>().add(InitializeVideoEvent(
                pluginId: widget.args.epPluginId,
                mediaId: _curMediaId,
                preferredLabel: _curSourceLabel,
                startPositionSec: resolveStartPositionSec(
                    isLive: widget.args.isLive, seekTo: resumePos),
                takeOver: true,
              ));
        },
      );
    });
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
          if (s is PlaybackPlayingElsewhere) {
            _transitioningEpisode = false;
            setState(() {
              _takeoverPrompt = _TakeoverPrompt(
                message: s.message,
                actionLabel: 'Guarda qui',
                backLabel: 'Annulla',
                onAction: () {
                  setState(() => _takeoverPrompt = null);
                  context.read<PlaybackBloc>().add(SelectStreamEvent(
                        pluginId: s.pluginId,
                        streamId: s.streamId,
                        startPositionSec: s.startPositionSec,
                        takeOver: true,
                      ));
                },
              );
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            HtmlElementView.fromTagName(
              tagName: 'video',
              onElementCreated: _onVideoElementCreated,
            ),
            // Cover nera fino al primo frame — mirrors TV's own version
            // (playback_screen/view.dart), the one thing web never had: the
            // bare <video> element shows whatever it's decoding the instant
            // a src/hls.js attaches, so without this the pre-resume frame
            // (or a decoder's own black flash) was directly visible. Kept up
            // until _videoStarted (see _onTimeUpdate's own gate), not just
            // "a source is attached" — see kResumeCoverSafetyTimeout's doc
            // for the backstop if the resume seek itself never lands.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _videoStarted ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: const ColoredBox(color: Colors.black),
              ),
            ),
            BlocBuilder<PlaybackBloc, PlaybackState>(
              builder: (context, s) {
                if (_takeoverPrompt != null) {
                  return _TakeoverOverlay(
                      prompt: _takeoverPrompt!, onBack: _exit);
                }
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

// ── Playback taken over by another device (contract "One device playing
// per profile") ──────────────────────────────────────────────────────────
// Pre-play ABORTED ("Guarda qui"/"Annulla") and mid-playback take-over
// ("Riprendi qui"/"Esci") share this one overlay, only the message/labels
// differ — see _onPlaybackTakenOver and the PlaybackPlayingElsewhere
// BlocListener branch above.

class _TakeoverPrompt {
  final String message;
  final String actionLabel;
  final String backLabel;
  final VoidCallback onAction;
  const _TakeoverPrompt({
    required this.message,
    required this.actionLabel,
    required this.backLabel,
    required this.onAction,
  });
}

class _TakeoverOverlay extends StatelessWidget {
  final _TakeoverPrompt prompt;
  final VoidCallback onBack;
  const _TakeoverOverlay({required this.prompt, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.devices_rounded,
                      color: Colors.white70, size: 48),
                  const SizedBox(height: 16),
                  Text(prompt.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: onBack,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                        child: Text(prompt.backLabel),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: prompt.onAction,
                        icon: const Icon(Icons.login_rounded),
                        label: Text(prompt.actionLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
