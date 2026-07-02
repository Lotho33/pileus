import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/duration_format.dart';
import '../../models/skip_interval.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom seek bar con segmenti AniSkip colorati e tooltip durante il drag.
// Anche D-pad focusable: freccia sinistra/destra scrubba a step (tenendo
// premuto, accelera — vedi _holdTickInterval/_stepForTick sotto), select/enter
// non fa nulla (nessuna azione da "attivare" su uno slider) — solo
// navigazione, delegata al chiamante per l'uscita in alto verso play/pause.
//
// Non usa il TvFocusable condiviso: serve distinguere KeyDownEvent da
// KeyUpEvent per il tieni-premuto-accelera, cosa che TvFocusable (per design,
// vedi il suo file) ignora deliberatamente per tutti gli altri ~106 call
// site che non ne hanno bisogno.
// ─────────────────────────────────────────────────────────────────────────────

// Single tap / first press of a hold = 5s — a fine nudge, Netflix-style;
// held longer it ramps up fast (see _stepForTick).
const _seekStepSec = 5.0;
// Timer-driven, non affidato al key-repeat nativo del sistema/telecomando
// (rate incoerente tra Android TV, browser, desktop — alcuni remote non
// ripetono affatto). Ogni tick avanza lo step; il primo passo (alla
// pressione) resta invariato — un tap rapido si ferma prima che il timer
// scatti la prima volta, quindi il comportamento di un singolo tap non
// cambia.
const _holdTickInterval = Duration(milliseconds: 350);
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

  // Real seek — used for a single tap/step, and to commit the final target
  // once a hold ends (see _commitHold below).
  void _stepBy(double deltaSec, double dur) {
    final base = (_dragPos ?? widget.posSec).clamp(0.0, dur);
    final target = (base + deltaSec).clamp(0.0, dur);
    widget.onSeek(target);
    _setDragPos(target);
  }

  // Visual-only move — no real seek() call. Repeatedly calling the real
  // seek() on every ~350ms hold tick (up to 3/s) was making mpv re-buffer
  // constantly while the user was just trying to scrub through the video —
  // the same "preview while held, commit on release" idea the touch-drag
  // handlers below already used, just not applied to the keyboard/D-pad path.
  void _previewStepBy(double deltaSec, double dur) {
    final base = (_dragPos ?? widget.posSec).clamp(0.0, dur);
    _setDragPos((base + deltaSec).clamp(0.0, dur));
  }

  void _setDragPos(double target) {
    setState(() => _dragPos = target);
    _optimisticClearTimer?.cancel();
    _optimisticClearTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _dragPos = null);
    });
  }

  // ── Hold-to-accelerate ──────────────────────────────────────────────────
  Timer? _holdTimer;
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

  // Gradual ramp — starts at the same 10s a single tap already does, and
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

  void _startHold(LogicalKeyboardKey key, double sign, double dur) {
    _beginScrub();
    _holdingKey = key;
    _holdTicks = 0;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(_holdTickInterval, (_) {
      _holdTicks++;
      widget.onActivity?.call();
      _previewStepBy(sign * _stepForTick(_holdTicks), dur);
      if (_holdTicks >= _maxHoldTicks) _stopHold(key);
    });
  }

  void _stopHold(LogicalKeyboardKey key) {
    if (_holdingKey != key) return;
    _cancelHold(commit: true);
  }

  // commit: true applies whatever _dragPos the hold left behind as a real
  // seek() — the hold only ever moved the preview, so without this the
  // final position the user actually stopped on would never reach the
  // player. false (dispose, widget going away) skips calling back out.
  void _cancelHold({bool commit = false}) {
    if (commit && _holdTimer != null && _dragPos != null) {
      widget.onSeek(_dragPos!);
    }
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdingKey = null;
    _holdTicks = 0;
    // Seek first (above), then resume — never resume a still-disposing widget.
    _endScrub(resume: commit);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event, double dur) {
    final key = event.logicalKey;
    // Any other key pressed while a hold is in progress stops it — "tenendo
    // premuto... rilasciando dovrebbe fermarsi, o anche solo premendo un
    // altro tasto". A real KeyUp on the held key already stops it below, and
    // losing focus already stops it via onFocusChange — this covers the
    // remaining case: a different key pressed *without* first releasing the
    // held one, and without that key moving focus away either (e.g.
    // select/enter toggling play/pause while the seek bar keeps focus).
    // Deliberately not swallowed here (falls through to whatever handling
    // below/beyond this widget that key normally gets) — only the hold
    // itself is cut short, not the key press.
    if (_holdingKey != null && key != _holdingKey && event is KeyDownEvent) {
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
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    // Swallowed rather than left ignored: bubbling up while disabled would
    // hand this to the screen-level handler, which (before this widget
    // existed) used arrow keys for its own ±10s seek — exactly the action
    // this state is meant to suspend.
    if (widget.disabled) return KeyEventResult.handled;
    final sign = key == LogicalKeyboardKey.arrowLeft ? -1.0 : 1.0;
    if (event is KeyDownEvent) {
      widget.onActivity?.call();
      // A platform that auto-repeats KeyDownEvents while held would
      // otherwise re-trigger this branch (and double-step) on every repeat —
      // only the first press of a given direction starts anything; our own
      // timer, not the platform's repeat rate, drives every step after that.
      if (_holdingKey != key) {
        _stepBy(sign * _seekStepSec, dur);
        _startHold(key, sign, dur);
      }
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      widget.onActivity?.call();
      _stopHold(key);
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
