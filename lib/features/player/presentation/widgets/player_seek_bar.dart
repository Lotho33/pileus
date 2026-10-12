import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/duration_format.dart';
import '../../models/skip_interval.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom seek bar with colored skip-interval segments and a drag tooltip.
// Also D-pad focusable: left/right arrow scrubs in steps (held down, it
// accelerates — see _holdTickInterval/_stepForTick below); select/enter does
// nothing (no "activate" action on a slider) — navigation only, with the
// upward exit toward play/pause delegated to the caller.
//
// Doesn't use the shared TvFocusable: needs to distinguish KeyDownEvent from
// KeyUpEvent for hold-to-accelerate, which TvFocusable deliberately ignores
// by design (see its own file) for every other call site that doesn't need
// it.
// ─────────────────────────────────────────────────────────────────────────────

// Single tap / first press of a hold = 5s — a fine nudge, Netflix-style;
// held longer it ramps up fast (see _stepForTick).
const _seekStepSec = 5.0;
// Timer-driven, non affidato al key-repeat nativo del sistema/telecomando
// (rate incoerente tra Android TV, browser, desktop — alcuni remote non
// ripetono affatto).
const _holdTickInterval = Duration(milliseconds: 350);
// D-pad scrubbing only ever moves the *preview*; the one real seek happens
// this long after the last key release. Presses landing inside the window
// keep adding to the same preview — so a burst of taps (or an HDMI-CEC
// remote that turns a hold into a stream of separate press/release pairs)
// is still a single seek, not one per press.
const _commitDelay = Duration(milliseconds: 700);
// Safety net: se una piattaforma non manda mai un KeyUp affidabile, il hold
// si ferma comunque dopo un tetto massimo invece di continuare a scorrere
// all'infinito. Abbondante rispetto ai ~19 tick che servono a raggiungere il
// gradino massimo qui sotto — in pratica non scatta mai in uso normale.
const _maxHoldTicks = 60; // ~21s a 350ms/tick

class PlayerSeekBar extends StatefulWidget {
  final double posSec;
  final double durSec;
  final List<SkipInterval> skipIntervals;
  final ValueChanged<double> onSeek;
  // Fired when the user starts an active scrub (D-pad hold or touch drag) and
  // when it ends. The player screen pauses playback for the duration —
  // standard behaviour: hold still while scrubbing, seek once, then resume —
  // instead of the video playing on underneath a preview that isn't where it
  // is. A single tap/step does NOT trigger these (it's a nudge, not a scrub).
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;
  final FocusNode focusNode;
  final VoidCallback? onNavigateUp;
  // When set, Down off the seek bar moves focus onto the Skip-intro button
  // (it floats just above the seek bar, right side) — otherwise there is no
  // D-pad path to it once the overlay controls have focus.
  final VoidCallback? onNavigateDown;
  // Called on every key this bar handles — lets the caller keep the overlay
  // (this bar included) from auto-hiding while it's actively being used.
  // The screen-level key handler that normally does this never sees these
  // key presses at all: this bar returns KeyEventResult.handled for them,
  // so they never bubble up to it.
  final VoidCallback? onActivity;
  // True while the player is loading/buffering — starting or committing a
  // seek in that state just piles more buffering on top of what's already
  // happening, so all interaction here (tap, drag, D-pad step-and-hold) is
  // suspended until it clears.
  final bool disabled;

  const PlayerSeekBar({
    super.key,
    required this.posSec,
    required this.durSec,
    required this.skipIntervals,
    required this.onSeek,
    required this.focusNode,
    this.onScrubStart,
    this.onScrubEnd,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onActivity,
    this.disabled = false,
  });

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _dragPos;

  // widget.posSec only catches up with the engine's real position on the
  // next position-stream tick, well after a seek() call returns — so two
  // fast arrow presses both read the same stale widget.posSec and collapse
  // into a single step instead of two. Reusing _dragPos as an "optimistic
  // target" (already used for touch-drag) after a keyboard step fixes both
  // interactions the same way; the timer lets a stale target fall back to
  // the real widget.posSec if a seek is ever silently dropped.
  Timer? _optimisticClearTimer;

  // Visual-only move — no real seek() call. Every D-pad step (tap or hold
  // tick) only moves this preview; the real seek happens once, in
  // _commitPending. Seeking on the first press used to start an ExoPlayer
  // rebuffer right away, which flipped [PlayerSeekBar.disabled] on — and
  // the disabled check then swallowed the KeyUp, so the hold never stopped:
  // it kept ramping (up to 10 min/tick) for ~20s and committed a huge jump.
  void _previewStepBy(double deltaSec, double dur) {
    final base = (_dragPos ?? widget.posSec).clamp(0.0, dur);
    _setDragPos((base + deltaSec).clamp(0.0, dur));
  }

  void _setDragPos(double target) {
    setState(() => _dragPos = target);
    _optimisticClearTimer?.cancel();
    // Only once nothing is pending — while a commit is still due the
    // preview must stay where the user put it.
    if (_commitTimer != null || _holdTimer != null) return;
    _optimisticClearTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _dragPos = null);
    });
  }

  // ── Hold-to-accelerate + deferred commit ────────────────────────────────
  Timer? _holdTimer;
  Timer? _commitTimer;
  int _holdTicks = 0;
  LogicalKeyboardKey? _holdingKey;

  // True between an onScrubStart and its matching onScrubEnd — guards against
  // firing the pair more than once (a hold and a drag can't overlap in
  // practice, but focus-loss / dispose can race the release).
  bool _scrubbing = false;

  void _beginScrub() {
    if (_scrubbing) return;
    _scrubbing = true;
    // Keep the overlay awake for the whole scrub — a touch drag otherwise
    // doesn't touch onActivity and the overlay could auto-hide (and
    // IgnorePointer) out from under the drag.
    widget.onActivity?.call();
    widget.onScrubStart?.call();
  }

  void _endScrub({required bool resume}) {
    if (!_scrubbing) return;
    _scrubbing = false;
    if (resume) widget.onScrubEnd?.call();
  }

  // Gradual ramp — starts at the same 5s a single tap already does, and
  // only reaches a large per-tick jump after being held for a few real
  // seconds, capping at 10 minutes/tick so a long hold can cross a full
  // movie without needing an implausibly long press.
  double _stepForTick(int tick) {
    if (tick < 3) return 5; // 5s/tick — 0.35–1.05s held
    if (tick < 6) return 10; // 10s/tick — ~2.1s held
    if (tick < 9) return 30; // 30s/tick — ~3.15s held
    if (tick < 12) return 60; // 1 min/tick — ~4.2s held
    if (tick < 15) return 120; // 2 min/tick — ~5.25s held
    if (tick < 19) return 300; // 5 min/tick — ~6.65s held
    return 600; // 10 min/tick — max, past ~6.65s held
  }

  // Key down: first step right away (preview only), then the hold ticks.
  void _press(LogicalKeyboardKey key, double sign, double dur) {
    _commitTimer?.cancel();
    _commitTimer = null;
    _beginScrub();
    _holdingKey = key;
    _holdTicks = 0;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(_holdTickInterval, (_) {
      _holdTicks++;
      widget.onActivity?.call();
      _previewStepBy(sign * _stepForTick(_holdTicks), dur);
      if (_holdTicks >= _maxHoldTicks) _release(key);
    });
    _previewStepBy(sign * _seekStepSec, dur);
  }

  // Key up (or the safety cap): stop ticking, commit after _commitDelay
  // unless another press continues the scrub first.
  void _release(LogicalKeyboardKey key) {
    if (_holdingKey != key) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdingKey = null;
    _holdTicks = 0;
    _commitTimer?.cancel();
    _commitTimer = Timer(_commitDelay, _commitPending);
  }

  // The single real seek of a D-pad scrub, then resume (if it was playing).
  void _commitPending() {
    _commitTimer?.cancel();
    _commitTimer = null;
    if (!_scrubbing) return;
    final target = _dragPos;
    if (target != null) widget.onSeek(target);
    _endScrub(resume: true);
    if (target != null) _setDragPos(target); // re-arms the clear timer
  }

  // Stop everything now. commit: true seeks to wherever the preview is and
  // resumes (focus moved away, another key pressed); false (dispose) skips
  // calling back out.
  void _cancelHold({bool commit = false}) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdingKey = null;
    _holdTicks = 0;
    if (commit) {
      _commitPending();
    } else {
      _commitTimer?.cancel();
      _commitTimer = null;
      _endScrub(resume: false);
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event, double dur) {
    final key = event.logicalKey;
    // Any other key pressed while a scrub is in progress (held or waiting
    // to commit) commits it now — "rilasciando dovrebbe fermarsi, o anche
    // solo premendo un altro tasto". Deliberately not swallowed: only the
    // scrub is cut short, not that key's own action (e.g. OK toggling
    // play/pause, Up moving focus).
    final isArrowLR = key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    if (!isArrowLR &&
        event is KeyDownEvent &&
        (_holdingKey != null || _commitTimer != null)) {
      _cancelHold(commit: true);
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (widget.onNavigateUp == null) return KeyEventResult.ignored;
      widget.onActivity?.call();
      widget.onNavigateUp!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (widget.onNavigateDown == null) return KeyEventResult.ignored;
      widget.onActivity?.call();
      widget.onNavigateDown!();
      return KeyEventResult.handled;
    }
    if (!isArrowLR) return KeyEventResult.ignored;
    final sign = key == LogicalKeyboardKey.arrowLeft ? -1.0 : 1.0;
    // Release is always honoured — even while disabled (buffering). Ending
    // a scrub must never depend on the player's state.
    if (event is KeyUpEvent) {
      widget.onActivity?.call();
      _release(key);
      return KeyEventResult.handled;
    }
    // Platform auto-repeat: our own timer drives the hold. Swallowed so it
    // doesn't bubble to the screen-level ±10s handler either.
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    // Swallowed rather than left ignored: bubbling up while disabled would
    // hand this to the screen-level handler, which (before this widget
    // existed) used arrow keys for its own ±10s seek — exactly the action
    // this state is meant to suspend. A scrub already in progress may go on.
    if (widget.disabled && !_scrubbing) return KeyEventResult.handled;
    if (event is KeyDownEvent) {
      widget.onActivity?.call();
      // Switching direction mid-hold: the other key's release may never
      // come (some remotes), so close that hold first.
      if (_holdingKey != null && _holdingKey != key) _release(_holdingKey!);
      if (_holdingKey != key) _press(key, sign, dur);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _optimisticClearTimer?.cancel();
    _cancelHold();
    super.dispose();
  }

  static Color _colorForType(SkipType t) => switch (t) {
        SkipType.op => const Color(0xFFF5A623),
        SkipType.ed => const Color(0xFF7B61FF),
        SkipType.recap => const Color(0xFF43A047),
      };

  String _fmt(double sec) =>
      formatPlaybackDuration(Duration(milliseconds: (sec * 1000).toInt()));

  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final dur = widget.durSec.clamp(1.0, double.infinity);
    final pos = (_dragPos ?? widget.posSec).clamp(0.0, dur);
    final focused = _focused;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) {
        setState(() => _focused = v);
        // Losing focus (e.g. arrowUp moving away) without a matching KeyUp
        // — some platforms only deliver KeyUp to whichever node currently
        // has focus — must still stop an in-progress hold (and commit
        // wherever it had scrubbed to, or that seek is silently lost) rather
        // than leaving it ticking against a seek bar the user has left.
        if (!v) _cancelHold(commit: true);
      },
      onKeyEvent: (node, event) => _onKeyEvent(node, event, dur),
      child: Builder(
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final thumbFrac = pos / dur;

            return AnimatedOpacity(
              opacity: widget.disabled ? 0.45 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 48,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart:
                          widget.disabled ? null : (_) => _beginScrub(),
                      onHorizontalDragUpdate: widget.disabled
                          ? null
                          : (d) {
                              final frac = (d.localPosition.dx / barWidth)
                                  .clamp(0.0, 1.0);
                              setState(() => _dragPos = frac * dur);
                            },
                      onHorizontalDragEnd: widget.disabled
                          ? null
                          : (_) {
                              if (_dragPos != null) widget.onSeek(_dragPos!);
                              setState(() => _dragPos = null);
                              _endScrub(resume: true);
                            },
                      onTapUp: widget.disabled
                          ? null
                          : (d) {
                              final frac = (d.localPosition.dx / barWidth)
                                  .clamp(0.0, 1.0);
                              widget.onSeek(frac * dur);
                            },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: focused && !widget.disabled
                              ? AppScale.focusGlow(AppTheme.primary)
                              : null,
                        ),
                        child: CustomPaint(
                          size: Size(barWidth, 8),
                          painter: _SeekBarPainter(
                            posFrac: thumbFrac,
                            skipIntervals: widget.skipIntervals,
                            durSec: dur,
                            colorForType: _colorForType,
                            focused: focused,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Elapsed / remaining — tracks _dragPos (the same optimistic
                  // target the thumb itself follows) while scrubbing, not just
                  // the raw engine position, so this keeps moving smoothly
                  // during a hold even though the real seek() only commits
                  // once, on release (see _previewStepBy above). A separate
                  // floating tooltip above the thumb used to duplicate this
                  // same number — redundant once it's shown right here.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        Text('-${_fmt(dur - pos)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  final double posFrac;
  final List<SkipInterval> skipIntervals;
  final double durSec;
  final Color Function(SkipType) colorForType;
  final bool focused;

  const _SeekBarPainter({
    required this.posFrac,
    required this.skipIntervals,
    required this.durSec,
    required this.colorForType,
    required this.focused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final r = Radius.circular(h / 2);
    final w = size.width;

    // Track
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, w, h, r),
      Paint()..color = Colors.white24,
    );

    // Segmenti skip — sfondo colorato semitrasparente
    for (final seg in skipIntervals) {
      final x0 = (seg.start / durSec).clamp(0.0, 1.0) * w;
      final x1 = (seg.end / durSec).clamp(0.0, 1.0) * w;
      if (x1 <= x0) continue;
      canvas.drawRRect(
        RRect.fromLTRBR(x0, 0, x1, h, r),
        Paint()..color = colorForType(seg.type).withValues(alpha: 0.55),
      );
    }

    // Progress bar
    final progW = (posFrac * w).clamp(0.0, w);
    if (progW > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(0, 0, progW, h, r),
        Paint()..color = Colors.white,
      );
    }

    // Segmenti skip — bordo colorato sopra la progress (sempre visibile)
    for (final seg in skipIntervals) {
      final x0 = (seg.start / durSec).clamp(0.0, 1.0) * w;
      final x1 = (seg.end / durSec).clamp(0.0, 1.0) * w;
      if (x1 <= x0) continue;
      canvas.drawRRect(
        RRect.fromLTRBR(x0, 0, x1, h, r),
        Paint()
          ..color = colorForType(seg.type)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Thumb — enlarged while D-pad-focused, with a purple halo matching the
    // app's focus colour (the container glow behind it is the same purple).
    final thumbX = (posFrac * w).clamp(0.0, w);
    if (focused) {
      canvas.drawCircle(
        Offset(thumbX, h / 2),
        20,
        Paint()..color = AppTheme.primary.withValues(alpha: 0.4),
      );
    }
    canvas.drawCircle(
      Offset(thumbX, h / 2),
      focused ? 15 : 14,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SeekBarPainter old) =>
      old.posFrac != posFrac ||
      old.skipIntervals != skipIntervals ||
      old.durSec != durSec ||
      old.focused != focused;
}
