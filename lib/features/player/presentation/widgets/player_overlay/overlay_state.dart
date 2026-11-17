// Part of player_overlay.dart — split out for readability (plan 2e). The
// library file holds the shared imports and the PlayerOverlay widget;
// private identifiers are shared across all parts.
part of '../player_overlay.dart';

class PlayerOverlayState extends State<PlayerOverlay> {
  // Top row (left → right): back … settings.
  final _backFn = FocusNode();
  final _settingsFn = FocusNode();
  // Center row (left → right): prevEp?, skipBack, playPause, skipFwd, nextEp?
  FocusNode? _prevEpFn;
  final _skipBackFn = FocusNode();
  final _playPauseFn = FocusNode();
  final _skipFwdFn = FocusNode();
  FocusNode? _nextEpFn;
  // Bottom row: just the seek bar (arrow keys scrub it directly, see
  // PlayerSeekBar) — arrowUp/arrowDown connect it to the center row instead
  // of a _moveIn chain, since there's nothing to its left/right.
  final _seekBarFn = FocusNode();

  // player.state.position only reflects a seek() once the engine reports it
  // back on the position stream, a moment after the call returns — two fast
  // skip-button presses both read the same stale position and land on the
  // same target instead of accumulating ±10s each. Tracked here the same
  // way PlayerSeekBar tracks its own drag/step target.
  Duration? _optimisticSeekTarget;
  Timer? _optimisticClearTimer;

  // Playback is paused for the duration of an active seek-bar scrub (D-pad
  // hold or touch drag) and resumed after the single committed seek — but
  // only if it was actually playing when the scrub began.
  bool _wasPlayingBeforeScrub = false;

  void _onScrubStart() {
    _wasPlayingBeforeScrub = widget.engine.playing;
    if (_wasPlayingBeforeScrub) widget.engine.pause();
  }

  void _onScrubEnd() {
    if (_wasPlayingBeforeScrub) widget.engine.play();
    _wasPlayingBeforeScrub = false;
  }

  Duration _seekBy(Duration delta) {
    final base = _optimisticSeekTarget ?? widget.engine.position;
    var target = base + delta;
    if (target.isNegative) target = Duration.zero;
    widget.engine.seek(target);
    _optimisticSeekTarget = target;
    _optimisticClearTimer?.cancel();
    _optimisticClearTimer = Timer(const Duration(milliseconds: 1200), () {
      _optimisticSeekTarget = null;
    });
    return target;
  }

  @override
  void initState() {
    super.initState();
    _syncEpisodeNodes();
  }

  @override
  void didUpdateWidget(PlayerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEpisodeNodes();
  }

  void _syncEpisodeNodes() {
    final hasNav = widget.episodeCount > 1 && widget.episodeIndex >= 0;
    if (hasNav && _prevEpFn == null) {
      _prevEpFn = FocusNode();
      _nextEpFn = FocusNode();
    } else if (!hasNav && _prevEpFn != null) {
      // Disposing a FocusNode that currently holds focus doesn't transfer
      // focus anywhere else — the D-pad silently stops responding until
      // something else explicitly requests focus. This flips async (episode
      // metadata loading can flip hasNav false while the user is sitting on
      // prev/next-episode), so bail to a button that's always present.
      if (_prevEpFn!.hasFocus || _nextEpFn!.hasFocus) {
        _playPauseFn.requestFocus();
      }
      _prevEpFn!.dispose();
      _nextEpFn!.dispose();
      _prevEpFn = null;
      _nextEpFn = null;
    }
  }

  @override
  void dispose() {
    _optimisticClearTimer?.cancel();
    _backFn.dispose();
    _settingsFn.dispose();
    _prevEpFn?.dispose();
    _skipBackFn.dispose();
    _playPauseFn.dispose();
    _skipFwdFn.dispose();
    _nextEpFn?.dispose();
    _seekBarFn.dispose();
    super.dispose();
  }

  /// Called by PlaybackScreen right after it reveals this overlay via a
  /// D-pad press, so the press that revealed it also lands a focus target
  /// inside it — otherwise the screen-level Focus keeps every subsequent key
  /// (see playback_screen.dart's _onKey).
  void requestInitialFocus() => _playPauseFn.requestFocus();

  /// Called by PlaybackScreen to hand focus back to the overlay from the
  /// Skip-intro button (Up off that button).
  void focusSeekBar() => _seekBarFn.requestFocus();

  // Under the play/pause button while loading: the mpv cache-fill % once the
  // stream is resolved and buffering toward the first frame, otherwise the
  // plugin/backend's current resolve step + an icon for its outcome
  // (spinner / ✓ / ✗ / !). Empty box once playback is running.
  Widget _statusSlot(double fs) {
    final pct = widget.bufferingPercent;
    // The fill % lives in the centre play/pause ring now (see
    // _PlayPauseButton.bufferProgress) — here it's just the number.
    if (widget.buffering && pct >= 1 && pct < 100) {
      return Text('${pct.round()}%',
          style: TextStyle(
              color: Colors.white70,
              fontSize: fs,
              fontWeight: FontWeight.w600));
    }
    if (!widget.loading || widget.statusMessage == null) {
      return const SizedBox.shrink();
    }
    // Icon only for a finished step (✓ / ✗ / !) — a still-running step is
    // just text; the one spinner the user sees is the centre one.
    final (icon, color) = switch (widget.statusKind) {
      'success' => (Icons.check_circle_rounded, const Color(0xFF4CAF50)),
      'error' => (Icons.error_rounded, const Color(0xFFE53935)),
      'warning' => (Icons.warning_amber_rounded, const Color(0xFFFFB300)),
      _ => (null, Colors.white70),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fs * 1.2, color: color),
          SizedBox(width: fs * 0.5),
        ],
        Flexible(
          child: Text(
            widget.statusMessage!,
            style: TextStyle(color: Colors.white70, fontSize: fs),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // The bottom row, left to right: episode nav, ±10, play/pause, settings.
  List<FocusNode> get _rowChain => [
        if (_prevEpFn != null) _prevEpFn!,
        _skipBackFn,
        _playPauseFn,
        _skipFwdFn,
        if (_nextEpFn != null) _nextEpFn!,
        _settingsFn,
      ];

  void _moveIn(List<FocusNode> chain, FocusNode from, int dir) {
    var i = chain.indexOf(from);
    if (i == -1) return;
    // Skip disabled nodes (e.g. prev/next episode at a season boundary) —
    // canRequestFocus is false there, so a plain neighbor jump would strand
    // focus instead of continuing past them.
    do {
      i += dir;
    } while (i >= 0 && i < chain.length && !chain[i].canRequestFocus);
    if (i >= 0 && i < chain.length) chain[i].requestFocus();
  }

  // Layout of the Vega OS player (pileus-vega PlayerScreen), the controls
  // most TV players have: the title top left; at the bottom elapsed · bar ·
  // remaining on one line and under it a row of round buttons — episode
  // nav, −10, play/pause, +10 — with settings at the far right. Sizes in
  // 1080p pixels of the screen height, as there. The loading spinner and
  // the plugin's progress text sit in the middle while it loads.
  @override
  Widget build(BuildContext context) {
    final hasEpisodeNav = widget.episodeCount > 1 && widget.episodeIndex >= 0;
    final sh = MediaQuery.sizeOf(context).height;
    final u = sh / 1080;
    final hPad = 64 * u;

    Widget rowButton(FocusNode fn,
        {IconData? icon,
        String? label,
        required String semantic,
        VoidCallback? onPressed}) {
      return _ShakaButton(
        icon: icon,
        label: label,
        semanticLabel: semantic,
        onPressed: onPressed,
        focusNode: fn,
        onLeft: () => _moveIn(_rowChain, fn, -1),
        onRight: () => _moveIn(_rowChain, fn, 1),
        onUp: () => _seekBarFn.requestFocus(),
        onDown: widget.onNavigateToSkip,
      );
    }

    final captionFs = AppScale.caption(context);
    final bufferRing = (widget.buffering &&
            widget.bufferingPercent >= 1 &&
            widget.bufferingPercent < 100)
        ? widget.bufferingPercent / 100.0
        : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent, Color(0xDD000000)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // ── Top: title, episode ──────────────────────────────────────────
          Positioned(
            left: hPad,
            right: hPad,
            top: 48 * u,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: 40 * u,
                      fontWeight: FontWeight.w800,
                      shadows: const [Shadow(blurRadius: 8)],
                    ),
                  ),
                if (hasEpisodeNav)
                  Padding(
                    padding: EdgeInsets.only(top: 6 * u),
                    child: Text(
                      'Episodio ${widget.episodeIndex + 1} di ${widget.episodeCount}',
                      style:
                          TextStyle(color: AppTheme.textMid, fontSize: 24 * u),
                    ),
                  ),
              ],
            ),
          ),

          // ── Middle: loading ──────────────────────────────────────────────
          // The status slot keeps its height whether or not there's a
          // message, so the spinner never jumps when one comes or goes.
          if (widget.loading || bufferRing != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PileusSpinner(
                      size: 64 * u,
                      color: AppTheme.textHigh,
                      value: bufferRing),
                  SizedBox(height: AppScale.space(context, 16)),
                  SizedBox(
                    height: captionFs * 1.3 * 2,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: AppScale.space(context, 420)),
                      child: _statusSlot(captionFs),
                    ),
                  ),
                ],
              ),
            ),

          // ── Bottom: bar, buttons ─────────────────────────────────────────
          Positioned(
            left: hPad,
            right: hPad,
            bottom: 48 * u,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<Duration>(
                  // null stream while hidden → no subscription, no per-tick
                  // rebuild; initialData keeps the bar showing the right
                  // position the instant the overlay reappears.
                  stream: widget.active ? widget.engine.positionStream : null,
                  initialData: widget.engine.position,
                  builder: (_, posSnap) => StreamBuilder<Duration>(
                    stream: widget.active ? widget.engine.durationStream : null,
                    initialData: widget.engine.duration,
                    builder: (_, durSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final dur = durSnap.data ?? Duration.zero;
                      // mpv's duration can trail the real length while the
                      // backend is still generating the HLS playlist — never
                      // show a shorter total than what the catalog knows.
                      final durSec = math.max(
                        dur.inMilliseconds / 1000.0,
                        widget.knownDurationSeconds.toDouble(),
                      );
                      return PlayerSeekBar(
                        posSec: pos.inMilliseconds / 1000.0,
                        durSec: durSec,
                        skipIntervals: widget.skipIntervals,
                        inlineTimes: true,
                        onSeek: (sec) => widget.engine.seek(
                          Duration(milliseconds: (sec * 1000).toInt()),
                        ),
                        onScrubStart: _onScrubStart,
                        onScrubEnd: _onScrubEnd,
                        focusNode: _seekBarFn,
                        onNavigateDown: () => _playPauseFn.requestFocus(),
                        onActivity: widget.onActivity,
                        disabled: widget.loading,
                      );
                    },
                  ),
                ),
                SizedBox(height: 28 * u),
                StreamBuilder<bool>(
                  stream: widget.engine.playingStream,
                  initialData: widget.engine.playing,
                  builder: (_, snap) {
                    final playing = snap.data ?? false;
                    final gap = SizedBox(width: 16 * u);
                    return Row(
                      children: [
                        if (hasEpisodeNav) ...[
                          rowButton(_prevEpFn!,
                              icon: Icons.skip_previous_rounded,
                              semantic: 'Episodio precedente',
                              onPressed: widget.onPrevEpisode),
                          gap,
                        ],
                        rowButton(_skipBackFn,
                            label: '−10',
                            semantic: 'Indietro di 10 secondi',
                            onPressed: widget.loading
                                ? null
                                : () => _seekBy(const Duration(seconds: -10))),
                        gap,
                        // Focusable while loading too: it's where the
                        // controls put focus when they come up.
                        rowButton(_playPauseFn,
                            icon: playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            semantic: playing ? 'Pausa' : 'Riproduci',
                            onPressed: widget.loading
                                ? () {}
                                : widget.engine.playOrPause),
                        gap,
                        rowButton(_skipFwdFn,
                            label: '+10',
                            semantic: 'Avanti di 10 secondi',
                            onPressed: widget.loading
                                ? null
                                : () => _seekBy(const Duration(seconds: 10))),
                        if (hasEpisodeNav) ...[
                          gap,
                          rowButton(_nextEpFn!,
                              icon: Icons.skip_next_rounded,
                              semantic: 'Episodio successivo',
                              onPressed: widget.onNextEpisode),
                        ],
                        const Spacer(),
                        rowButton(_settingsFn,
                            icon: Icons.settings_rounded,
                            semantic: 'Impostazioni di riproduzione',
                            onPressed: widget.onOpenSettings),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
