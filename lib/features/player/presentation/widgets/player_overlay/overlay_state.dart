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

  List<FocusNode> get _topChain => [_backFn, _settingsFn];

  List<FocusNode> get _centerChain => [
        if (_prevEpFn != null) _prevEpFn!,
        _skipBackFn,
        _playPauseFn,
        _skipFwdFn,
        if (_nextEpFn != null) _nextEpFn!,
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

  @override
  Widget build(BuildContext context) {
    final hasEpisodeNav = widget.episodeCount > 1 && widget.episodeIndex >= 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent, Color(0xDD000000)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Builder(builder: (context) {
            final h = MediaQuery.sizeOf(context).height;
            final iconSz = (h * 0.037).clamp(28.0, 48.0);
            final titleFs = (h * 0.024).clamp(18.0, 30.0);
            final epFs = (h * 0.017).clamp(13.0, 22.0);
            final hPad = AppScale.screenHPad(context);
            return Padding(
              padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
              child: Row(
                children: [
                  _FocusableIconButton(
                    icon: Icons.arrow_back_ios_new,
                    size: iconSz,
                    onPressed: widget.onBack,
                    focusNode: _backFn,
                    onLeft: () => _moveIn(_topChain, _backFn, -1),
                    onRight: () => _moveIn(_topChain, _backFn, 1),
                    onDown: () => _playPauseFn.requestFocus(),
                  ),
                  const SizedBox(width: 4),
                  if (widget.title != null)
                    Expanded(
                      child: Text(
                        widget.title!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFs,
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(blurRadius: 8)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  if (hasEpisodeNav)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'Ep. ${widget.episodeIndex + 1}/${widget.episodeCount}',
                        style: TextStyle(color: Colors.white54, fontSize: epFs),
                      ),
                    ),
                  _FocusableIconButton(
                    icon: Icons.settings_rounded,
                    size: iconSz,
                    onPressed: widget.onOpenSettings,
                    focusNode: _settingsFn,
                    onLeft: () => _moveIn(_topChain, _settingsFn, -1),
                    onRight: () => _moveIn(_topChain, _settingsFn, 1),
                    onDown: () => _playPauseFn.requestFocus(),
                  ),
                ],
              ),
            );
          }),

          // ── Centro: episodio-nav · skip-back · play/pause · skip-fwd · episodio-nav ──
          Expanded(
            child: Center(
              child: StreamBuilder<bool>(
                stream: widget.engine.playingStream,
                initialData: widget.engine.playing,
                builder: (_, snap) {
                  final playing = snap.data ?? false;
                  // FittedBox previene overflow su schermi stretti
                  final controlsRow = FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasEpisodeNav) ...[
                          _NavEpisodeButton(
                            icon: Icons.skip_previous_rounded,
                            onPressed: widget.onPrevEpisode,
                            focusNode: _prevEpFn!,
                            onLeft: () => _moveIn(_centerChain, _prevEpFn!, -1),
                            onRight: () => _moveIn(_centerChain, _prevEpFn!, 1),
                            onUp: () => _settingsFn.requestFocus(),
                            onDown: () => _seekBarFn.requestFocus(),
                          ),
                          const SizedBox(width: 24),
                        ],
                        _SkipButton(
                          icon: Icons.replay_10,
                          focusNode: _skipBackFn,
                          onLeft: () => _moveIn(_centerChain, _skipBackFn, -1),
                          onRight: () => _moveIn(_centerChain, _skipBackFn, 1),
                          onUp: () => _settingsFn.requestFocus(),
                          onDown: () => _seekBarFn.requestFocus(),
                          onPressed: widget.loading
                              ? null
                              : () => _seekBy(const Duration(seconds: -10)),
                        ),
                        const SizedBox(width: 36),
                        _PlayPauseButton(
                          playing: playing,
                          loading: widget.loading,
                          bufferProgress: (widget.buffering &&
                                  widget.bufferingPercent >= 1 &&
                                  widget.bufferingPercent < 100)
                              ? widget.bufferingPercent / 100.0
                              : null,
                          onPressed:
                              widget.loading ? null : widget.engine.playOrPause,
                          focusNode: _playPauseFn,
                          onLeft: () => _moveIn(_centerChain, _playPauseFn, -1),
                          onRight: () => _moveIn(_centerChain, _playPauseFn, 1),
                          onUp: () => _settingsFn.requestFocus(),
                          onDown: () => _seekBarFn.requestFocus(),
                        ),
                        const SizedBox(width: 36),
                        _SkipButton(
                          icon: Icons.forward_10,
                          focusNode: _skipFwdFn,
                          onLeft: () => _moveIn(_centerChain, _skipFwdFn, -1),
                          onRight: () => _moveIn(_centerChain, _skipFwdFn, 1),
                          onUp: () => _settingsFn.requestFocus(),
                          onDown: () => _seekBarFn.requestFocus(),
                          onPressed: widget.loading
                              ? null
                              : () => _seekBy(const Duration(seconds: 10)),
                        ),
                        if (hasEpisodeNav) ...[
                          const SizedBox(width: 24),
                          _NavEpisodeButton(
                            icon: Icons.skip_next_rounded,
                            onPressed: widget.onNextEpisode,
                            focusNode: _nextEpFn!,
                            onLeft: () => _moveIn(_centerChain, _nextEpFn!, -1),
                            onRight: () => _moveIn(_centerChain, _nextEpFn!, 1),
                            onUp: () => _settingsFn.requestFocus(),
                            onDown: () => _seekBarFn.requestFocus(),
                          ),
                        ],
                      ],
                    ),
                  );
                  // The button's own spinner (see _PlayPauseButton) is the
                  // app's one loading indicator — the only other thing that
                  // can appear is whatever free-form progress text the
                  // plugin/backend sent via ResolveStream (see
                  // PlayerOverlay.statusMessage's own doc), shown under the
                  // controls row.
                  //
                  // This status slot is ALWAYS present, at a fixed height,
                  // whether or not there's a message to show right now (or
                  // even whether we're loading at all) — the parent chain is
                  // Expanded(child: Center(...)), which repositions its
                  // child based on its *total* measured height. A
                  // conditionally-included/excluded text row here used to
                  // change that total height every time a message
                  // appeared/disappeared or loading toggled, which visibly
                  // shifted the play/pause button up and down. Reserving the
                  // same fixed-height box unconditionally means the block's
                  // total height — and therefore the button's position —
                  // never changes; only the text inside the slot toggles.
                  final captionFs = AppScale.caption(context);
                  final statusSlotH = captionFs * 1.3 * 2; // up to 2 lines
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      controlsRow,
                      SizedBox(height: AppScale.space(context, 16)),
                      SizedBox(
                        height: statusSlotH,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: AppScale.space(context, 420)),
                            child: _statusSlot(captionFs),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Bottom: seekbar + tempi ───────────────────────────────────────
          Builder(builder: (context) {
            final sz = MediaQuery.sizeOf(context);
            final hPad = (sz.width * 0.021).clamp(24.0, 56.0);
            final bPad = (sz.height * 0.037).clamp(24.0, 56.0);
            return Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, bPad),
              child: StreamBuilder<Duration>(
                // null stream while hidden → no subscription, no per-tick
                // rebuild; initialData keeps the bar showing the right
                // position the instant the overlay reappears.
                stream: widget.active ? widget.engine.positionStream : null,
                initialData: widget.engine.position,
                builder: (_, posSnap) {
                  return StreamBuilder<Duration>(
                    stream:
                        widget.active ? widget.engine.durationStream : null,
                    initialData: widget.engine.duration,
                    builder: (_, durSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final dur = durSnap.data ?? Duration.zero;
                      final posSec = pos.inMilliseconds / 1000.0;
                      // mpv's duration can trail the real length while the
                      // backend is still generating the HLS playlist — never
                      // show a shorter total than what the catalog already
                      // knows (see knownDurationSeconds doc above).
                      final durSec = math.max(
                        dur.inMilliseconds / 1000.0,
                        widget.knownDurationSeconds.toDouble(),
                      );
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerSeekBar(
                            posSec: posSec,
                            durSec: durSec,
                            skipIntervals: widget.skipIntervals,
                            onSeek: (sec) => widget.engine.seek(
                              Duration(milliseconds: (sec * 1000).toInt()),
                            ),
                            onScrubStart: _onScrubStart,
                            onScrubEnd: _onScrubEnd,
                            focusNode: _seekBarFn,
                            onNavigateUp: () => _playPauseFn.requestFocus(),
                            onNavigateDown: widget.onNavigateToSkip,
                            onActivity: widget.onActivity,
                            disabled: widget.loading,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

