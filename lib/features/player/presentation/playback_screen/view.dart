// Part of playback_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports and the PlaybackScreen entry point
// (resolves PlaybackArgs from the GoRouter extra); private identifiers are
// shared across all parts. _PlaybackViewState is still one large class —
// candidate for a real refactor (D-pad / resume / skip mixins) later.
part of '../playback_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// View
// ─────────────────────────────────────────────────────────────────────────────

class _PlaybackView extends StatefulWidget {
  final String pluginId;
  final String mediaId;
  final PlaybackArgs args;

  const _PlaybackView({
    required this.pluginId,
    required this.mediaId,
    required this.args,
  });

  @override
  State<_PlaybackView> createState() => _PlaybackViewState();
}

class _PlaybackViewState extends State<_PlaybackView> {
  // Not `final`: _restartPlayerInPlace() disposes and rebuilds this from
  // scratch (new BetterPlayerController → new native player → new Surface)
  // as a last-resort recovery for a frozen live picture that a mere re-open
  // can't fix (see _restartPlayerInPlace).
  late PlayerEngine _engine;
  late final PlayerUiCubit _uiCubit;
  // Read once from settings in initState, reused verbatim by
  // _restartPlayerInPlace so a manual restart doesn't have to re-read
  // SettingsRepository or duplicate the lowPowerUi clamp.
  late final int _bufferMiB;

  // Lets _onKey hand D-pad focus into whichever overlay is on screen the
  // moment it's revealed — otherwise the screen-level Focus below keeps
  // every subsequent key press (see _onKey).
  final _overlayKey = GlobalKey<PlayerOverlayState>();
  final _liveOverlayKey = GlobalKey<PlayerLiveOverlayState>();
  final _settingsPanelKey = GlobalKey<PlayerSettingsPanelState>();
  final _skipIntroKey = GlobalKey<SkipIntroButtonState>();
  final _nextEpisodeKey = GlobalKey<_NextEpisodeBannerState>();
  final _errorOverlayKey = GlobalKey<_InPlayerErrorOverlayState>();

  // ── Volume ─────────────────────────────────────────────────────────────────
  double _volume = 100.0;

  // ── Subtitle config — initial values come from SettingsRepository in
  // initState (fallback defaults below only apply before that runs) ────────
  late final SettingsRepository _settings;
  double _subtitleFontSize = 32.0;
  Color _subtitleColor = Colors.white;
  bool _subtitleBgEnabled = true;
  double _subtitleBottomPadding = 80.0;

  // ── Playback lifecycle ─────────────────────────────────────────────────────
  bool _playbackReady = false;
  bool _videoStarted = false;
  // Resume-from-timestamp. A seek issued right after open() on an HLS stream
  // is sometimes dropped (the playlist/first segments aren't ready yet),
  // which is why "continue watching sometimes starts from the beginning" —
  // so we don't fire it once and hope: seek on open, then _onPosition
  // checks the position actually landed and re-seeks a few times if not.
  int _resumeTargetSec = 0;
  bool _resumeConfirmed = false;
  int _resumeRetries = 0;
  DateTime? _resumeSeekAt;
  Timer? _heartbeatTimer;
  Timer? _errorGraceTimer;
  // Live-only: catches the case a plain error/buffering event never covers —
  // ExoPlayer (or mpv) reporting playing=true with no error at all while the
  // position has genuinely stopped advancing (e.g. an HLS live edge blip
  // that lands ExoPlayer in STATE_IDLE without ever surfacing an exception —
  // see the 2026-09-13 stall/freeze audit). See _armLiveStallWatchdog.
  Timer? _liveStallWatchdog;
  int _liveStallStrikes = 0;
  // Last resolved stream (url/headers), kept only so _restartPlayerInPlace
  // can reopen the same source after rebuilding the engine — nothing else
  // reads these.
  String? _lastStreamUrl;
  Map<String, String> _lastStreamHeaders = const {};
  // Same reasoning as PlayerOverlayState._optimisticSeekTarget: the reported
  // position lags a seek() call, so two fast arrow presses on the raw D-pad
  // handler (as opposed to the seek bar / skip buttons, which track this
  // themselves) would otherwise both read the same stale position and
  // collapse into a single 10s step.
  Duration? _optimisticSeekTarget;
  Timer? _optimisticSeekClearTimer;
  // Diff state for _onEngineChanged (the engine notifies on every value
  // change; we only act on the transitions the screen cares about).
  Duration _lastEnginePos = Duration.zero;
  bool _lastEnginePlaying = false;
  bool _lastBuffering = false;
  double _lastBufferPct = 0;

  // ── In-player error ────────────────────────────────────────────────────────
  String? _playbackError;
  // Wall-clock of the last position tick. An error while the stream is in
  // fact still advancing (segment fetch that retried and succeeded, an
  // end-file for a discarded variant, …) must not blank the screen — the
  // error page "flashes then the video starts". Every error now goes
  // through a grace timer that checks this before showing anything.
  DateTime? _lastProgressAt;
  String? _pendingErrorText;

  // ── AniSkip ────────────────────────────────────────────────────────────────
  List<SkipInterval> _skipIntervals = [];
  SkipInterval? _activeSkip;
  bool _skipDismissed = false;

  // ── Episode navigation (mutabile durante la sessione) ─────────────────────
  late int _currentEpisodeIndex;
  late int _currentSeasonIndex;
  late String _currentMediaId;
  late String _currentSourceLabel;
  late String? _currentTitle;
  late List<String> _currentEpisodeList;
  late List<String> _currentEpisodeTitles;
  // Series name for the continue-watching card's overline. Prefer the value
  // the caller passed (args.showTitle); when it's missing — e.g. resuming
  // from a continue-watching entry that predates this, or the /episode/
  // detail path — fall back to a one-shot GetDetails(parentId) lookup so the
  // card still gets a series name instead of just the episode title.
  String _showTitle = '';
  // Series id + series synopsis for the continue-watching card/hero. Like
  // _showTitle, prefer what the caller passed; when a launch path omitted
  // them (details/direct-play, an /episode/ deep link) a one-shot lookup
  // fills them in so the stored CW entry is complete.
  String _parentId = '';
  String _plot = '';
  // Also part of the continue-watching card/hero metadata. Same rule as
  // _plot/_showTitle: seeded from args, backfilled by the one-shot
  // GetDetails(parentId) when a launch path (browse list, a CW resume, an
  // /episode/ link) didn't carry them — so _saveProgress always writes a
  // complete row and the hero doesn't lose its rating/genres/year chips
  // after the in-session detail cache is gone.
  double _rating = 0;
  List<String> _genres = const [];
  int _year = 0;
  bool _resolvingEpisode = false;
  bool _autoAdvanced = false;
  // Guards the continue-watching cleanup below against firing more than
  // once per media — reset whenever `_currentMediaId` changes.
  bool _progressCleared = false;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    perf('screen: initState (live=${args.isLive}, lowPower=$lowPowerUi)');

    // Silence the home's 30s plugin-status poll for the whole playback
    // session — see PluginBloc.pausePolling.
    getIt<PluginBloc>().pausePolling();

    _settings = getIt<SettingsRepository>();
    _subtitleFontSize = _settings.getSubtitleFontSize();
    _subtitleColor = _settings.getSubtitleColor();
    _subtitleBgEnabled = _settings.getSubtitleBgEnabled();
    _subtitleBottomPadding = _settings.getSubtitleBottomPadding();

    _uiCubit = PlayerUiCubit();
    // `episodeIndex` defaults to -1 ("unknown"). With a populated episode
    // list that sentinel makes `_hasNextEpisode` read true and
    // `_goToEpisode(idx + 1)` jump to index 0 — i.e. "next episode" replays
    // the current one. Clamp into the list when we have one; keep -1 (inert:
    // `-1 < -1` is false) when the list is empty and the resolver will fill
    // both together later.
    _currentEpisodeIndex = args.episodeList.isEmpty
        ? args.episodeIndex
        : args.episodeIndex.clamp(0, args.episodeList.length - 1);
    _currentSeasonIndex = args.seasonIndex;
    _currentMediaId = widget.mediaId;
    _currentSourceLabel = args.sourceLabel;
    _currentTitle = args.title;
    _currentEpisodeList = args.episodeList;
    _currentEpisodeTitles = args.episodeTitles;
    _showTitle = args.showTitle;
    _parentId = args.parentId;
    _plot = args.plot;
    _rating = args.rating;
    _genres = args.genres;
    _year = args.year;
    _resumeTargetSec = args.seekTo;

    // Two separate knobs in Preferenze: a bigger cushion for VOD, a smaller
    // one for live so it isn't stuck buffering a long pre-roll before the
    // picture appears. Under "hardware modesto" cap both harder — these
    // boxes have ~1 GB shared with the OS and the lowmemorykiller is active
    // during playback.
    var bufMiB = args.isLive
        ? _settings.getLiveBufferMiB()
        : _settings.getPlayerBufferMiB();
    if (lowPowerUi) bufMiB = bufMiB.clamp(4, args.isLive ? 10 : 16);
    _bufferMiB = bufMiB;

    _engine = PlayerEngine.create();
    _engine.onError = _onEngineError;
    _engine.addListener(_onEngineChanged);
    _engine.initialize(
      PlayerSubtitleStyle(
        fontSize: _subtitleFontSize,
        color: _subtitleColor,
        backgroundEnabled: _subtitleBgEnabled,
        bottomPadding: _subtitleBottomPadding,
      ),
      isLive: args.isLive,
      bufferMiB: _bufferMiB,
    );
    perf('screen: engine built (${_engine.runtimeType})');

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || widget.args.isLive) return;
      _saveProgress();
    });
    if (args.isLive) _armLiveStallWatchdog();

    _resolveSeriesMetaIfMissing().whenComplete(() {
      if (mounted) _resolveEpisodeListIfMissing();
    });
  }

  // ── Engine event fan-out ───────────────────────────────────────────────────

  void _onEngineChanged() {
    if (!mounted) return;
    final pos = _engine.position;
    if (pos != _lastEnginePos) {
      _lastEnginePos = pos;
      _onPosition(pos);
    }
    final playing = _engine.playing;
    if (playing != _lastEnginePlaying) {
      _lastEnginePlaying = playing;
      _onPlayingChanged(playing);
    }
    if (!_uiCubit.isClosed) {
      final b = _engine.buffering;
      if (b != _lastBuffering) {
        _lastBuffering = b;
        _uiCubit.setBuffering(b);
      }
      final bp = _engine.bufferedPercent;
      if ((bp - _lastBufferPct).abs() >= 1) {
        _lastBufferPct = bp;
        _uiCubit.setBufferingPercent(bp);
      }
    }
    final v = _engine.volume;
    if ((v - _volume).abs() > 0.5) setState(() => _volume = v);
  }

  void _onPlayingChanged(bool playing) {
    // A transient error (common on live streams: manifest/segment fetch
    // failing once before the connection stabilizes) can recover on its own
    // a moment later — "playing" reporting true again is the strongest
    // signal that happened. Without clearing it here, _InPlayerErrorOverlay
    // stays up forever blocking a stream that works underneath it.
    if (playing && (_playbackError != null || _pendingErrorText != null)) {
      _errorGraceTimer?.cancel();
      _pendingErrorText = null;
      if (_playbackError != null) setState(() => _playbackError = null);
    }
    // Explicit for every mode, not just audio. Video used to lean on
    // BetterPlayerConfiguration's own `allowedScreenSleep: false` alone —
    // that only holds a wake lock, which doesn't stop an Android TV
    // launcher's own idle screensaver/dim policy the way `WakelockPlus`'s
    // FLAG_KEEP_SCREEN_ON does; the mpv desktop backend had nothing at all.
    if (playing) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    if (playing || widget.args.isLive) return;
    _saveProgress();
  }

  void _onEngineError(String err) {
    if (kDebugMode) debugPrint('[player] error: $err');
    if (!mounted) return;
    // Never blank the screen synchronously. An error is very often one
    // failed segment/manifest fetch the player then retries successfully.
    // Hold the message and let the grace timer decide: it only surfaces if,
    // after the window, playback is still stopped AND no position tick has
    // landed since. The playing / _onPosition paths cancel it the instant
    // the stream proves it's alive.
    setState(() => _pendingErrorText = 'Errore riproduzione: $err');
    final firedAt = DateTime.now();
    _errorGraceTimer?.cancel();
    _errorGraceTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      final progressed =
          _lastProgressAt != null && _lastProgressAt!.isAfter(firedAt);
      if (_engine.playing || progressed) {
        setState(() => _pendingErrorText = null);
        return;
      }
      setState(() => _playbackError = _pendingErrorText);
      // Root Focus(autofocus:true) at Scaffold level already holds real
      // focus in this scope by now, same as the skip-intro/next-episode
      // banners above — the Riprova button's own autofocus is a no-op
      // without this (TV: the error was there but D-pad couldn't reach it).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _errorOverlayKey.currentState?.requestInitialFocus();
      });
    });
  }

  // ── Live stall watchdog ─────────────────────────────────────────────────
  //
  // Neither better_player_plus (ExoPlayer) nor libmpv is guaranteed to tell
  // us when a live stream dies: a brief network blip at an HLS live edge can
  // land ExoPlayer in STATE_IDLE without ever emitting bufferingStart or a
  // catchable exception (BehindLiveWindowException goes unhandled upstream —
  // see the 2026-09-13 stall/freeze audit). `playing` then keeps reading
  // true and `position` simply stops advancing — nothing above this ever
  // notices on its own, which is exactly the "no buffering shown, video just
  // freezes" symptom reported for live sport. Wall-clock time since the last
  // real position tick (_onPosition, only ever called when the position
  // actually changed) is the one signal that can't be silently skipped.
  //
  // Two escalating tiers, both already-existing recovery paths (nothing new
  // to get subtly wrong): a cheap pause/play nudge first — fixes a renderer
  // merely stuck on a stale internal state — then, if that didn't bring
  // progress back, the same fresh-URL reopen the "Riprova" button triggers
  // by hand. This does *not* cover a frozen picture with audio/position
  // still advancing (the Amlogic-style dead-Surface freeze) — there is no
  // engine-agnostic signal here to detect that case; see
  // _restartPlayerInPlace for the manual fallback.
  void _armLiveStallWatchdog() {
    _liveStallWatchdog?.cancel();
    _liveStallWatchdog = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_videoStarted) return;
      if (_playbackError != null || _pendingErrorText != null) return;
      if (!_engine.playing || _engine.buffering) return;
      final last = _lastProgressAt;
      if (last == null) return;
      final stalledFor = DateTime.now().difference(last);
      if (stalledFor < const Duration(seconds: 9)) return;

      _liveStallStrikes++;
      perf('screen: live stall watchdog — playing=true, no progress in '
          '${stalledFor.inSeconds}s (strike #$_liveStallStrikes)');
      if (_liveStallStrikes <= 1) {
        _engine.pause();
        _engine.play();
      } else {
        _liveStallStrikes = 0;
        context.read<PlaybackBloc>().add(InitializeVideoEvent(
              pluginId: widget.args.epPluginId,
              mediaId: _currentMediaId,
              preferredLabel: _currentSourceLabel,
            ));
      }
      // Give the recovery attempt a full interval to show progress instead
      // of re-firing (and escalating) again 4s later while it's still
      // settling.
      _lastProgressAt = DateTime.now();
    });
  }

  // ── Manual "restart in place" (TV freeze fallback) ──────────────────────
  //
  // The stall watchdog above only ever sees a genuinely stuck *position* —
  // it can't detect the other freeze reported on some Android TV boxes
  // (Amlogic in particular): the decoder gets wedged against a dead render
  // Surface after a mid-stream reconfigure (an ABR switch or an HLS
  // discontinuity — either can be triggered by the same kind of network
  // blip), while audio and the position clock keep advancing normally — see
  // the 2026-09-13 stall/freeze audit. better_player_plus creates that
  // Surface once per native player instance and never reattaches it, so even
  // a full `_engine.open()` reopen (same instance) can't recover it — only
  // tearing the whole PlayerEngine down and building a fresh one does (which
  // is what exiting and re-entering the screen already did by accident).
  // This exposes the same recovery from the live overlay's restart button,
  // without losing the screen/overlay state.
  //
  // No automatic trigger: unlike the position stall above, there is no
  // Dart-observable signal that the picture is frozen while everything else
  // (audio, position, playing) reports healthy — the underlying frame-render
  // count isn't exposed past the plugin's Dart API. Manual only.
  Future<void> _restartPlayerInPlace() async {
    final url = _lastStreamUrl;
    if (url == null) return; // nothing resolved yet — nothing to reopen
    perf('screen: manual player restart in place');
    _liveStallStrikes = 0;
    _errorGraceTimer?.cancel();
    setState(() {
      _playbackError = null;
      _pendingErrorText = null;
      _videoStarted = false;
    });

    // Detach the old engine's callbacks before it's torn down, but don't
    // dispose it yet — `_engine` must keep pointing at a live, still-usable
    // instance (buildView() et al.) for as long as `await` below can yield
    // to a rebuild.
    final old = _engine;
    old.onError = null;
    old.removeListener(_onEngineChanged);

    final fresh = PlayerEngine.create();
    fresh.onError = _onEngineError;
    fresh.addListener(_onEngineChanged);
    await fresh.initialize(
      PlayerSubtitleStyle(
        fontSize: _subtitleFontSize,
        color: _subtitleColor,
        backgroundEnabled: _subtitleBgEnabled,
        bottomPadding: _subtitleBottomPadding,
      ),
      isLive: widget.args.isLive,
      bufferMiB: _bufferMiB,
    );
    if (!mounted) {
      // The screen itself got torn down while we were awaiting — its own
      // dispose() already released `old` (still `_engine` at that point);
      // `fresh` was never wired in, so it's the only thing left to clean up.
      fresh.dispose();
      return;
    }
    setState(() => _engine = fresh);
    old.dispose();
    _engine.open(url, headers: _lastStreamHeaders);
  }

  // One-shot: backfill the series name / synopsis / parent id when a launch
  // path didn't pass them, so _saveProgress stores a complete
  // continue-watching entry (overline + hero logo/plot lookup later).
  Future<void> _resolveSeriesMetaIfMissing() async {
    if (widget.args.isLive) return;
    if (_showTitle.isNotEmpty &&
        _plot.isNotEmpty &&
        _parentId.isNotEmpty &&
        _genres.isNotEmpty) {
      return;
    }
    try {
      final repo = getIt<MediaRepository>();
      // No parent id in the args → read it off the current media's own
      // details (episodes carry show_id). A standalone movie has no parent;
      // its own plot is the one to keep.
      if (_parentId.isEmpty) {
        final self =
            await repo.getDetails(widget.args.epPluginId, _currentMediaId);
        if (!mounted) return;
        _parentId = self.item.showId;
        if (self.hasMovie()) {
          final m = self.movie;
          if (_plot.isEmpty) _plot = m.plot;
          if (_genres.isEmpty) _genres = m.genres;
          if (_year == 0 && m.year > 0) _year = m.year;
        }
        if (_rating == 0 && self.item.rating > 0) _rating = self.item.rating;
        if (_year == 0 && self.item.year > 0) _year = self.item.year;
      }
      if (_parentId.isEmpty) return;
      final res = await repo.getDetails(widget.args.epPluginId, _parentId);
      if (!mounted) return;
      if (_showTitle.isEmpty && res.item.title.isNotEmpty) {
        _showTitle = res.item.title;
      }
      if (_rating == 0 && res.item.rating > 0) _rating = res.item.rating;
      if (_year == 0 && res.item.year > 0) _year = res.item.year;
      if (res.hasSeries()) {
        final s = res.series;
        if (_plot.isEmpty && s.plot.isNotEmpty) _plot = s.plot;
        if (_genres.isEmpty && s.genres.isNotEmpty) _genres = s.genres;
        if (_year == 0 && s.year > 0) _year = s.year;
      }
    } catch (_) {
      // ignore — card falls back to the episode title / no plot
    }
  }

  // One-shot: rebuild the prev/next-episode list when a launch path didn't
  // pass one (continue-watching taps carry only the single episode). Runs in
  // the background after playback has already started — the buttons just
  // appear a beat later. `_currentMediaId` here is the resolved stream id,
  // not a bare episode id, so matches fall back to the episode title.
  Future<void> _resolveEpisodeListIfMissing() async {
    if (widget.args.isLive ||
        _currentEpisodeList.isNotEmpty ||
        _parentId.isEmpty) {
      return;
    }
    final target = (_currentTitle ?? '').trim().toLowerCase();
    final cacheKey = '${widget.args.epPluginId} $_parentId';
    final cached = playbackEpisodeCache[cacheKey];
    if (cached != null && cached.length >= 2) {
      _applyResolvedEpisodes(cached, target);
      return;
    }
    try {
      final repo = getIt<MediaRepository>();
      final res = await repo.browse(widget.args.epPluginId, _parentId, '');
      if (!mounted) return;

      // Flat list straight off the parent?
      var eps = <({String id, String title})>[];
      if (res.episodes.isNotEmpty) {
        eps = [for (final e in res.episodes) (id: e.id, title: e.title)];
      } else {
        eps = [
          for (final e in res.items)
            if (!e.isDir) (id: e.id, title: e.title),
        ];
      }

      // Otherwise the parent is a list of season directories — walk them
      // until one holds an episode whose title matches what's playing. Cap
      // the walk: 25 sequential browses on a deep series (One Piece &co.)
      // is a long stall right after playback starts, and prev/next is a
      // convenience, not load-bearing. 8 covers virtually every real show.
      if (eps.length < 2) {
        final seasonDirs = res.items.where((i) => i.isDir).toList();
        for (final s in seasonDirs.take(8)) {
          if (!mounted) return;
          final sr = await repo.browse(widget.args.epPluginId, s.id, '');
          final se = sr.episodes.isNotEmpty
              ? [for (final e in sr.episodes) (id: e.id, title: e.title)]
              : [
                  for (final e in sr.items)
                    if (!e.isDir) (id: e.id, title: e.title),
                ];
          if (se.length > 1 &&
              (target.isEmpty ||
                  se.any((e) => e.title.trim().toLowerCase() == target))) {
            eps = se;
            break;
          }
        }
      }

      if (!mounted || eps.length < 2) return;
      playbackEpisodeCache[cacheKey] = eps;
      _applyResolvedEpisodes(eps, target);
    } catch (_) {
      // ignore — no prev/next this session
    }
  }

  void _applyResolvedEpisodes(
      List<({String id, String title})> eps, String target) {
    if (!mounted) return;
    var idx = eps.indexWhere((e) => e.id == _currentMediaId);
    if (idx < 0 && target.isNotEmpty) {
      idx = eps.indexWhere((e) => e.title.trim().toLowerCase() == target);
    }
    if (idx < 0) {
      // Loose containment, last resort — only for ids long enough to be a
      // real unique token. A bare "1"/"2" episode number is a substring of
      // almost every resolved stream URL, so the old unguarded check
      // matched episode 1 for nearly every continue-watching tap.
      idx = eps.indexWhere(
          (e) => e.id.length >= 8 && _currentMediaId.contains(e.id));
    }
    if (idx < 0) return;
    setState(() {
      _currentEpisodeList = [for (final e in eps) e.id];
      _currentEpisodeTitles = [for (final e in eps) e.title];
      _currentEpisodeIndex = idx;
    });
  }

  @override
  void dispose() {
    perf('screen: dispose (videoStarted=$_videoStarted)');
    _heartbeatTimer?.cancel();
    _errorGraceTimer?.cancel();
    _liveStallWatchdog?.cancel();
    _optimisticSeekClearTimer?.cancel();
    _engine.removeListener(_onEngineChanged);
    _uiCubit.close(); // cancella internamente il suo _hideTimer
    if (!widget.args.isLive) _saveProgress();
    WakelockPlus.disable();
    _engine.dispose();
    getIt<PluginBloc>().resumePolling();
    super.dispose();
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  void _saveProgress() {
    // Once _onPosition has already deleted the continue-watching entry
    // (≥95% watched, marked as finished), every remaining caller of this
    // method — the stream.playing listener firing on natural EOF, the 15s
    // heartbeat, and the unconditional dispose() save — would otherwise
    // silently recreate the entry it just cleared.
    if (_progressCleared) return;
    final pos = _engine.position;
    final dur = _engine.duration;
    if (pos.inSeconds <= 0) return;
    getIt<MediaRepository>().updateProgress(
      pluginId: widget.args.epPluginId,
      mediaId: _currentMediaId,
      parentId: _parentId,
      position: pos,
      totalDuration: dur,
      // Card main line = what you're watching now ("Episodio 5" for an
      // episode, the film title for a movie); the series name rides in
      // showTitle and the card shows it as a small overline above it.
      title: (_currentTitle?.isNotEmpty ?? false) ? _currentTitle! : _showTitle,
      showTitle: _showTitle,
      poster: widget.args.poster,
      rating: _rating,
      genres: _genres,
      plot: _plot,
      year: _year,
    );
  }

  // ── Resume-from-timestamp ─────────────────────────────────────────────────

  // Issue the resume seek once a stream is opened. A seek issued right after
  // open() on an HLS stream is sometimes dropped (playlist/first segments
  // not ready, or the backend playlist still being generated) —
  // _maybeResumeSeek then confirms it took and retries a few times.
  void _issueResumeSeek() {
    if (widget.args.isLive || _resumeTargetSec <= 2 || _resumeConfirmed) {
      return;
    }
    _resumeSeekAt = DateTime.now();
    _engine.seek(Duration(seconds: _resumeTargetSec));
  }

  void _maybeResumeSeek(Duration pos) {
    if (widget.args.isLive || _resumeTargetSec <= 2 || _resumeConfirmed) {
      return;
    }
    final p = pos.inSeconds;
    if (p >= _resumeTargetSec - 8) {
      _resumeConfirmed = true; // landed at/past the target — done
      return;
    }
    // Still stuck well before the target a few seconds after the last seek
    // attempt: it was dropped (common right after open on HLS). Retry, a few
    // times, then give up (the user can seek manually).
    final since = _resumeSeekAt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_resumeSeekAt!);
    if (_resumeRetries < 4 &&
        since > const Duration(milliseconds: 2500) &&
        p < _resumeTargetSec - 15) {
      _resumeRetries++;
      _resumeSeekAt = DateTime.now();
      _engine.seek(Duration(seconds: _resumeTargetSec));
    }
  }

  // ── Position listener ──────────────────────────────────────────────────────

  void _onPosition(Duration pos) {
    _lastProgressAt = DateTime.now();
    // Real forward progress — whatever the stall watchdog was escalating
    // toward, drop it back to the first (gentlest) tier.
    _liveStallStrikes = 0;
    // Position updates only arrive while the player is actively decoding — a
    // stream that's still advancing has recovered from whatever transient
    // error triggered _playbackError, even mid-playback (not just on the
    // very first frame; see _onPlayingChanged for the same reasoning).
    if (mounted && (_playbackError != null || _pendingErrorText != null)) {
      _errorGraceTimer?.cancel();
      _pendingErrorText = null;
      if (_playbackError != null) setState(() => _playbackError = null);
    }
    // Primo frame
    if (mounted && _playbackReady && !_videoStarted && pos.inMilliseconds > 0) {
      perf('screen: ***** FIRST FRAME VISIBLE ***** (videoStarted)');
      setState(() => _videoStarted = true);
      _uiCubit.onVideoStarted();
      // The overlay is visible from the start (PlayerUiState.overlayVisible
      // defaults true), but nothing had ever given its play/pause button
      // real Flutter focus — the *only* other place that does
      // (_onKey's arrow-key handler) only fires on a hidden→shown
      // transition, which never happens on this very first frame. Without
      // this, arrow keys at playback start are consumed by the screen-level
      // Focus as raw seek shortcuts instead of visibly moving focus onto
      // any control.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.args.isLive) {
          _liveOverlayKey.currentState?.requestInitialFocus();
        } else {
          _overlayKey.currentState?.requestInitialFocus();
        }
      });
    }
    if (!mounted) return;

    _maybeResumeSeek(pos);

    // AniSkip: calcola intervallo attivo
    final posF = pos.inMilliseconds / 1000.0;
    SkipInterval? active;
    for (final interval in _skipIntervals) {
      if (posF >= interval.start && posF < interval.end - 1) {
        active = interval;
        break;
      }
    }
    if (active != _activeSkip) {
      final wasNull = _activeSkip == null;
      setState(() {
        _activeSkip = active;
        if (active != null) _skipDismissed = false;
      });
      if (active != null && wasNull) {
        // Same reasoning as _openSettings(): the overlay controls may
        // already hold real focus in this scope, making the button's own
        // autofocus a no-op — push focus explicitly once it's mounted.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _skipIntroKey.currentState?.requestInitialFocus();
        });
      }
    }

    // Next episode countdown: attivo negli ultimi 30 secondi
    if (!widget.args.isLive && _videoStarted) {
      final dur = _engine.duration;
      final hasNext = _hasNextEpisode;
      if (hasNext && dur.inSeconds > 60) {
        final remaining = dur.inSeconds - pos.inSeconds;
        if (remaining > 0 && remaining <= 30) {
          final wasShown = _uiCubit.state.nextEpisodeSecs != null;
          _uiCubit.setNextEpisodeSecs(remaining);
          if (!wasShown) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _nextEpisodeKey.currentState?.requestInitialFocus();
            });
          }
        } else {
          _uiCubit.setNextEpisodeSecs(null);
        }
        if (remaining <= 0 && !_autoAdvanced) {
          _autoAdvanced = true;
          _goToEpisode(_currentEpisodeIndex + 1);
        }
      }
      // End-of-title continue-watching handling. Three cases:
      //
      //  - Episode with a NEXT episode in this same season, ~90% in: roll
      //    the CW entry forward to that next episode (barely-started, so it
      //    shows as "up next" with an empty progress bar) and drop the
      //    current one. Without this, finishing an episode and leaving
      //    before the last-30s auto-advance wiped the whole series out of
      //    Continue Watching — you'd have to go dig the series back up and
      //    find your place.
      //  - Last episode of a non-last season (a season boundary): leave the
      //    entry as-is so the series stays in CW; resuming replays the tail
      //    and the auto-advance carries on into the next season.
      //  - Movie, or the genuinely last episode, ~95% in: it really is
      //    finished — drop it so it doesn't linger at ~100% forever.
      if (!_progressCleared && dur.inSeconds > 0) {
        final frac = pos.inSeconds / dur.inSeconds;
        final hasSameSeasonNext = _currentEpisodeIndex >= 0 &&
            _currentEpisodeIndex + 1 < _currentEpisodeList.length;
        if (hasSameSeasonNext && frac >= 0.90) {
          _progressCleared = true;
          final nextId = _currentEpisodeList[_currentEpisodeIndex + 1];
          final nextTitle =
              _currentEpisodeIndex + 1 < _currentEpisodeTitles.length
                  ? _currentEpisodeTitles[_currentEpisodeIndex + 1]
                  : '';
          final repo = getIt<MediaRepository>();
          repo.updateProgress(
            pluginId: widget.args.epPluginId,
            mediaId: nextId,
            parentId: _parentId,
            // 31 s, and totalDuration left at 0 on purpose: mycelium's
            // GetContinueWatching filter drops any row with
            // `progress_time < 30`, and only applies its 3-95% "watched
            // fraction" window when `total_time > 0`. So this is the
            // smallest position that still surfaces as an "up next" row.
            // The card's bar reads 0% (progressFraction needs total_time).
            // Trade-off: resuming this row starts ~30 s in — past the
            // recap/logo stings on most episodes.
            position: const Duration(seconds: 31),
            title: nextTitle.isNotEmpty ? nextTitle : _showTitle,
            showTitle: _showTitle,
            poster: widget.args.poster,
            rating: _rating,
            genres: _genres,
            plot: _plot,
            year: _year,
          );
          repo.deleteProgress(
            providerID: widget.args.epPluginId,
            playableID: _currentMediaId,
          );
        } else if (!_hasNextEpisode && frac >= 0.95) {
          _progressCleared = true;
          getIt<MediaRepository>().deleteProgress(
            providerID: widget.args.epPluginId,
            playableID: _currentMediaId,
          );
        }
      }
    }
  }

  // ── Playback start ─────────────────────────────────────────────────────────

  void _startPlayback(
      String url, Map<String, String> headers, Map<String, String> extra) {
    List<SkipInterval> intervals = const [];
    final skipJson = extra['skip_times'];
    if (skipJson != null && skipJson.isNotEmpty) {
      try {
        final list = jsonDecode(skipJson) as List;
        intervals = list
            .map((r) {
              final interval = r['interval'] as Map<String, dynamic>;
              final typeStr = (r['skipType'] as String?) ?? '';
              final type = switch (typeStr) {
                'op' => SkipType.op,
                'ed' => SkipType.ed,
                'recap' => SkipType.recap,
                _ => null,
              };
              if (type == null) return null;
              return SkipInterval(
                type: type,
                start: (interval['startTime'] as num).toDouble(),
                end: (interval['endTime'] as num).toDouble(),
              );
            })
            .whereType<SkipInterval>()
            .toList();
      } catch (e) {
        if (kDebugMode) debugPrint('[AniSkip] parse error: $e');
      }
    }
    // A grace timer armed by a previous stream's transient buffering error
    // can still be pending here — without cancelling it, it fires 8s later
    // against *this* new stream and shows the old error message over one
    // that's actually loading fine.
    _errorGraceTimer?.cancel();
    _lastStreamUrl = url;
    _lastStreamHeaders = headers;
    setState(() {
      _playbackReady = true;
      _videoStarted = false;
      _skipIntervals = intervals;
      _activeSkip = null;
      _skipDismissed = false;
      _autoAdvanced = false;
      _playbackError = null;
    });
    perf('screen: engine.open()  host=${Uri.tryParse(url)?.host ?? '?'}'
        '  headers=${headers.length}');
    _engine.open(url, headers: headers);
    _issueResumeSeek();
  }

  // ── Episode navigation ─────────────────────────────────────────────────────

  bool get _hasNextEpisode =>
      _currentEpisodeIndex < _currentEpisodeList.length - 1 ||
      (_currentSeasonIndex < widget.args.allSeasonIds.length - 1 &&
          widget.args.allSeasonIds.isNotEmpty);

  Future<void> _goToEpisode(int newIndex) async {
    if (_resolvingEpisode) return;
    setState(() => _resolvingEpisode = true);
    try {
      await _resolveEpisodeAt(newIndex, _currentEpisodeList,
          _currentEpisodeTitles, _currentSeasonIndex);
    } catch (e) {
      if (kDebugMode) debugPrint('[player] _goToEpisode error: $e');
      if (mounted) {
        setState(() {
          _resolvingEpisode = false;
          _playbackError = 'Impossibile cambiare episodio: $e';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _errorOverlayKey.currentState?.requestInitialFocus();
        });
      }
    }
  }

  Future<void> _resolveEpisodeAt(
    int newIndex,
    List<String> episodeList,
    List<String> episodeTitles,
    int seasonIndex,
  ) async {
    final repo = getIt<MediaRepository>();

    if (newIndex < 0 || newIndex >= episodeList.length) {
      final allSeasonIds = widget.args.allSeasonIds;
      if (allSeasonIds.isEmpty) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      final newSeasonIndex = newIndex < 0 ? seasonIndex - 1 : seasonIndex + 1;
      if (newSeasonIndex < 0 || newSeasonIndex >= allSeasonIds.length) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      final browseRes = await repo.browse(
          widget.args.epPluginId, allSeasonIds[newSeasonIndex], '');
      final newEpisodes = browseRes.items;
      if (newEpisodes.isEmpty) {
        if (mounted) setState(() => _resolvingEpisode = false);
        return;
      }
      final targetIndex = newIndex < 0 ? newEpisodes.length - 1 : 0;
      final newIds = newEpisodes.map((e) => e.id).toList();
      final newTitles = newEpisodes.map((e) => e.title).toList();
      if (mounted) {
        setState(() {
          _currentEpisodeList = newIds;
          _currentEpisodeTitles = newTitles;
          _currentSeasonIndex = newSeasonIndex;
        });
      }
      await _resolveEpisodeAt(targetIndex, newIds, newTitles, newSeasonIndex);
      return;
    }

    final newMediaId = episodeList[newIndex];
    final newTitle =
        newIndex < episodeTitles.length ? episodeTitles[newIndex] : null;
    final streamsRes =
        await repo.getStreams(widget.args.epPluginId, newMediaId);
    final sources = streamsRes.sources;

    // Prefer the same source label the user is already watching; if it's
    // unknown (e.g. launched from continue-watching, which carries no
    // label) or this episode doesn't offer it, fall back to the first
    // source and just play — don't bounce to the episode picker mid-binge.
    final match = (_currentSourceLabel.isEmpty
            ? null
            : sources
                .where((s) =>
                    s.label.toLowerCase() == _currentSourceLabel.toLowerCase())
                .firstOrNull) ??
        (sources.isNotEmpty ? sources.first : null);

    if (!mounted) return;

    if (match != null) {
      _errorGraceTimer?.cancel();
      _engine.stop();
      _uiCubit.setNextEpisodeSecs(null);
      setState(() {
        _currentEpisodeIndex = newIndex;
        _currentMediaId = newMediaId;
        _currentSourceLabel = match.label;
        _currentTitle = newTitle ?? _currentTitle;
        _playbackReady = false;
        _resolvingEpisode = false;
        _autoAdvanced = false;
        _progressCleared = false;
      });
      // A new episode starts from 0 — don't carry the resume target.
      _resumeTargetSec = 0;
      _resumeConfirmed = false;
      context.read<PlaybackBloc>().add(
            SelectStreamEvent(
                pluginId: widget.args.epPluginId, streamId: match.id),
          );
    } else {
      setState(() => _resolvingEpisode = false);
      _engine.stop();
      context.pushReplacement(
        '/episode/${widget.args.epPluginId}/${Uri.encodeComponent(newMediaId)}',
        extra: {
          'episodeList': episodeList,
          'episodeTitles': episodeTitles,
          'episodeIndex': newIndex,
          'allSeasonIds': widget.args.allSeasonIds,
          'allSeasonLabels': widget.args.allSeasonLabels,
          'seasonIndex': _currentSeasonIndex,
          'sourceLabel': _currentSourceLabel,
          'showTitle': _showTitle,
          'parentId': _parentId,
        },
      );
    }
  }

  // ── Input ──────────────────────────────────────────────────────────────────

  void _seekBy(Duration delta) {
    final base = _optimisticSeekTarget ?? _engine.position;
    var target = base + delta;
    if (target.isNegative) target = Duration.zero;
    _engine.seek(target);
    _optimisticSeekTarget = target;
    _optimisticSeekClearTimer?.cancel();
    _optimisticSeekClearTimer = Timer(const Duration(milliseconds: 1200), () {
      _optimisticSeekTarget = null;
    });
  }

  // Same idiom as the overlay-reveal path above: openSettings() alone isn't
  // enough because whatever button was pressed to get here still holds
  // focus in the frame the panel mounts, so the panel's own autofocus is a
  // no-op — explicit requestInitialFocus() after the frame is the fix.
  void _openSettings() {
    _uiCubit.openSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _settingsPanelKey.currentState?.requestInitialFocus();
    });
  }

  // Mirrors _openSettings(): closing the panel leaves nothing with real
  // Flutter focus (the panel itself unmounts, taking its focused node with
  // it) — without this, the next arrow key after closing settings was
  // handled as a raw seek/play-pause shortcut by the screen-level Focus
  // instead of visibly landing back on play/pause.
  void _closeSettings() {
    _uiCubit.closeSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.args.isLive) {
        _liveOverlayKey.currentState?.requestInitialFocus();
      } else {
        _overlayKey.currentState?.requestInitialFocus();
      }
    });
  }

  // Single source of truth shared with the central spinner and the overlay
  // controls — "loading" covers both the initial resolve/first-frame wait
  // and any later re-buffering, both cases where play/pause and seek would
  // race the engine's own state instead of doing anything useful.
  bool _isLoadingFor(PlaybackState state, PlayerUiState uiState) {
    final initialLoading = _resolvingEpisode ||
        state is FetchingStreams ||
        state is ResolvingMediaStream ||
        state is PlaybackResolveProgress ||
        (state is PlaybackReady && !_videoStarted) ||
        // Error grace window: a stream.error fired and the grace timer
        // hasn't decided yet. Show the spinner instead of a frozen frame
        // for the ~8s before the error page (if it) appears.
        (_pendingErrorText != null && !_engine.playing);
    return initialLoading || uiState.buffering;
  }

  // Leave the player. A deep link straight to /player has nothing to pop
  // back to — context.pop() there just leaves a black screen — so fall back
  // to /home.
  void _exitPlayer() {
    _engine.stop();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      if (!consumeBackEvent()) return KeyEventResult.handled;
      if (_uiCubit.state.settingsOpen) {
        _closeSettings();
        return KeyEventResult.handled;
      }
      _exitPlayer();
      return KeyEventResult.handled;
    }

    if (_uiCubit.state.settingsOpen) return KeyEventResult.ignored;

    final wasHidden = !_uiCubit.state.overlayVisible;
    _uiCubit.showOverlay();
    if (wasHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.args.isLive) {
          _liveOverlayKey.currentState?.requestInitialFocus();
        } else {
          _overlayKey.currentState?.requestInitialFocus();
        }
      });
      // The press that wakes a hidden overlay is just that — "show me the
      // controls" — not also an implicit seek/play-pause. Without this, an
      // arrow key pressed only to reveal a hidden overlay also jumped the
      // video ±10s in the same press.
      return KeyEventResult.handled;
    }

    final loading = !widget.args.isLive &&
        _isLoadingFor(context.read<PlaybackBloc>().state, _uiCubit.state);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.mediaPlayPause:
        if (!widget.args.isLive && !loading) _engine.playOrPause();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (!widget.args.isLive && !loading) {
          _seekBy(const Duration(seconds: 10));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        if (!widget.args.isLive && !loading) {
          _seekBy(const Duration(seconds: -10));
        }
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.sizeOf(context);

    return BlocProvider<PlayerUiCubit>.value(
      value: _uiCubit,
      child: BlocListener<PlaybackBloc, PlaybackState>(
        listener: (context, state) {
          if (state is PlaybackReady) {
            perf('screen: got PlaybackReady → _startPlayback');
            _startPlayback(state.resolvedUrl, state.httpHeaders, state.extra);
          }
          if (state is PlaybackRetrying) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(
                content: Text('Tentativo ${state.attempt} di ${state.of}…'),
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 4),
              ));
          }
          if (state is PlaybackFailed) {
            setState(() => _playbackError = state.errorMessage);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _errorOverlayKey.currentState?.requestInitialFocus();
            });
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Focus(
            autofocus: true,
            onKeyEvent: _onKey,
            child: GestureDetector(
              onTap: () {
                if (_uiCubit.state.settingsOpen) {
                  _closeSettings();
                } else {
                  _uiCubit.showOverlay();
                }
              },
              child: Stack(
                children: [
                  // ── Video / Audio artwork ─────────────────────────────
                  // Always painted (never Offstage) even before the first
                  // frame arrives — the opaque black cover below hides it
                  // visually instead. Keeping the video view genuinely
                  // painted at all times avoids the platform surface being
                  // reclaimed before the first frame lands (seen on live
                  // streams, which reach a first frame later than VOD).
                  // RepaintBoundary: isolate the video/artwork layer from the
                  // overlay, subtitle view and fade cover stacked on top —
                  // their repaints (spinner, seek bar, opacity tweens) then
                  // don't force the compositor to re-touch this layer.
                  RepaintBoundary(
                    child: widget.args.isAudio
                        ? PlayerAudioArtwork(
                            poster: widget.args.poster,
                            title: _currentTitle,
                          )
                        : _engine.buildView(),
                  ),

                  // ── Cover nera fino al primo frame ────────────────────
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _videoStarted ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      child: Container(color: Colors.black),
                    ),
                  ),

                  // ── Player overlay (VOD o Live) ───────────────────────
                  // RepaintBoundary so the overlay's own animations (fade,
                  // seek bar, spinner) repaint only this layer, not the whole
                  // player Stack.
                  RepaintBoundary(
                    child: BlocBuilder<PlaybackBloc, PlaybackState>(
                      builder: (context, blocState) {
                        return BlocBuilder<PlayerUiCubit, PlayerUiState>(
                          buildWhen: (p, c) =>
                              p.overlayVisible != c.overlayVisible ||
                              p.settingsOpen != c.settingsOpen ||
                              p.buffering != c.buffering ||
                              p.bufferingPercent != c.bufferingPercent,
                          builder: (context, uiState) {
                            // Play/pause, ±10s skip and the seek bar all get
                            // disabled while this is true — starting/committing a
                            // seek during buffering just piles more buffering on
                            // top, and toggling play/pause mid-resolve/mid-rebuffer
                            // races the engine's own state transitions.
                            final loading = _isLoadingFor(blocState, uiState);
                            final ready =
                                _videoStarted && blocState is PlaybackReady;
                            // While loading, the overlay must stay on screen
                            // unconditionally (not gated by overlayVisible/
                            // auto-hide) — its center button is the app's one
                            // loading spinner now (see PlayerOverlay's
                            // statusMessage/loading), so hiding the overlay
                            // during resolve/buffering hid the spinner too.
                            // Once the video actually starts, normal
                            // show/hide-on-activity behavior takes back over.
                            final visible = loading ||
                                (ready &&
                                    uiState.overlayVisible &&
                                    !uiState.settingsOpen);

                            final overlay = widget.args.isLive
                                ? PlayerLiveOverlay(
                                    key: _liveOverlayKey,
                                    title: _currentTitle,
                                    liveSources: widget.args.liveSources,
                                    liveSourceLabels:
                                        widget.args.liveSourceLabels,
                                    livePluginId: widget.args.livePluginId,
                                    liveMediaId: widget.args.liveMediaId,
                                    onBack: _exitPlayer,
                                    onSwitchSource: (srcId, srcLabel) {
                                      _errorGraceTimer?.cancel();
                                      setState(() {
                                        _playbackReady = false;
                                        _videoStarted = false;
                                      });
                                      context
                                          .read<PlaybackBloc>()
                                          .add(SelectStreamEvent(
                                            pluginId: widget.args.livePluginId
                                                    .isNotEmpty
                                                ? widget.args.livePluginId
                                                : widget.pluginId,
                                            streamId: srcId,
                                          ));
                                    },
                                    onOpenSettings: _openSettings,
                                    onRestart: _restartPlayerInPlace,
                                    // Initial load AND any mid-stream
                                    // rebuffer — the live overlay has no
                                    // other loading cue.
                                    loading: loading,
                                    statusMessage:
                                        blocState is PlaybackResolveProgress
                                            ? blocState.message
                                            : null,
                                    statusKind:
                                        blocState is PlaybackResolveProgress
                                            ? blocState.status
                                            : null,
                                    buffering: uiState.buffering,
                                    bufferingPercent: uiState.bufferingPercent,
                                  )
                                : PlayerOverlay(
                                    key: _overlayKey,
                                    engine: _engine,
                                    title: _currentTitle,
                                    episodeIndex: _currentEpisodeIndex,
                                    episodeCount: _currentEpisodeList.length,
                                    onBack: _exitPlayer,
                                    onOpenSettings: _openSettings,
                                    onActivity: () => _uiCubit.showOverlay(),
                                    onNavigateToSkip: (_activeSkip != null &&
                                            !_skipDismissed &&
                                            _videoStarted)
                                        ? () => _skipIntroKey.currentState
                                            ?.requestInitialFocus()
                                        : null,
                                    onPrevEpisode: !_resolvingEpisode &&
                                            (_currentEpisodeIndex > 0 ||
                                                (_currentSeasonIndex > 0 &&
                                                    widget.args.allSeasonIds
                                                        .isNotEmpty))
                                        ? () => _goToEpisode(
                                            _currentEpisodeIndex - 1)
                                        : null,
                                    onNextEpisode: !_resolvingEpisode &&
                                            (_currentEpisodeIndex <
                                                    _currentEpisodeList.length -
                                                        1 ||
                                                (_currentSeasonIndex <
                                                        widget.args.allSeasonIds
                                                                .length -
                                                            1 &&
                                                    widget.args.allSeasonIds
                                                        .isNotEmpty))
                                        ? () => _goToEpisode(
                                            _currentEpisodeIndex + 1)
                                        : null,
                                    skipIntervals: _skipIntervals,
                                    knownDurationSeconds:
                                        widget.args.durationSeconds,
                                    loading: loading,
                                    active: visible,
                                    statusMessage:
                                        blocState is PlaybackResolveProgress
                                            ? blocState.message
                                            : null,
                                    statusKind:
                                        blocState is PlaybackResolveProgress
                                            ? blocState.status
                                            : null,
                                    buffering: uiState.buffering,
                                    bufferingPercent: uiState.bufferingPercent,
                                  );

                            return ExcludeFocus(
                              excluding: !visible,
                              child: IgnorePointer(
                                ignoring: !visible,
                                child: AnimatedOpacity(
                                  opacity: visible ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: overlay,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // ── AniSkip button ────────────────────────────────────
                  if (_activeSkip != null && !_skipDismissed && _videoStarted)
                    Builder(builder: (_) {
                      // On the ending/outro, if there's a next episode, this
                      // becomes "jump to next episode" instead of "skip to
                      // the end of this one" — matches how binge-watching
                      // apps behave once the credits roll.
                      final outroToNext = _activeSkip!.type == SkipType.ed &&
                          _hasNextEpisode &&
                          !_resolvingEpisode;
                      return Positioned(
                        right: sz.width * 0.025,
                        bottom: sz.height * 0.11,
                        child: SkipIntroButton(
                          key: _skipIntroKey,
                          label: outroToNext
                              ? 'Prossimo episodio'
                              : _activeSkip!.label,
                          icon: outroToNext
                              ? Icons.skip_next_rounded
                              : Icons.fast_forward_rounded,
                          onSkip: () {
                            if (outroToNext) {
                              setState(() => _skipDismissed = true);
                              _goToEpisode(_currentEpisodeIndex + 1);
                            } else {
                              _engine.seek(Duration(
                                  milliseconds:
                                      (_activeSkip!.end * 1000).toInt()));
                              setState(() => _skipDismissed = true);
                            }
                          },
                          onDismiss: () =>
                              setState(() => _skipDismissed = true),
                          // Reveal the overlay first — the seek bar is inside
                          // ExcludeFocus while it's hidden, so a bare
                          // requestFocus would land nowhere.
                          onExitUp: () {
                            _uiCubit.showOverlay();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _overlayKey.currentState?.focusSeekBar();
                              }
                            });
                          },
                        ),
                      );
                    }),

                  // ── Next episode countdown banner ─────────────────────
                  BlocBuilder<PlayerUiCubit, PlayerUiState>(
                    buildWhen: (p, c) => p.nextEpisodeSecs != c.nextEpisodeSecs,
                    builder: (context, uiState) {
                      if (uiState.nextEpisodeSecs == null || !_videoStarted) {
                        return const SizedBox.shrink();
                      }
                      final nextTitle = _currentEpisodeIndex + 1 <
                              _currentEpisodeTitles.length
                          ? _currentEpisodeTitles[_currentEpisodeIndex + 1]
                          : null;
                      return Positioned(
                        right: sz.width * 0.025,
                        bottom: sz.height * 0.20,
                        child: _NextEpisodeBanner(
                          key: _nextEpisodeKey,
                          secsRemaining: uiState.nextEpisodeSecs!,
                          nextTitle: nextTitle,
                          onPlay: () {
                            _uiCubit.setNextEpisodeSecs(null);
                            _goToEpisode(_currentEpisodeIndex + 1);
                          },
                          onDismiss: () => _uiCubit.setNextEpisodeSecs(null),
                        ),
                      );
                    },
                  ),

                  // ── Settings panel ────────────────────────────────────
                  BlocBuilder<PlayerUiCubit, PlayerUiState>(
                    buildWhen: (p, c) => p.settingsOpen != c.settingsOpen,
                    builder: (context, uiState) {
                      if (!uiState.settingsOpen) return const SizedBox.shrink();
                      return PlayerSettingsPanel(
                        key: _settingsPanelKey,
                        engine: _engine,
                        volume: _volume,
                        onClose: _closeSettings,
                        onVolumeChanged: (v) {
                          setState(() => _volume = v);
                          _engine.setVolume(v);
                        },
                      );
                    },
                  ),

                  // ── In-player error overlay ───────────────────────────
                  if (_playbackError != null)
                    _InPlayerErrorOverlay(
                      key: _errorOverlayKey,
                      error: _playbackError!,
                      onRetry: () {
                        setState(() => _playbackError = null);
                        context.read<PlaybackBloc>().add(InitializeVideoEvent(
                              pluginId: widget.args.epPluginId,
                              mediaId: _currentMediaId,
                              preferredLabel: _currentSourceLabel,
                            ));
                      },
                      onExit: _exitPlayer,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

