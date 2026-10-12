import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/perf_profile.dart';
import '../../core/theme/app_scale.dart';
import '../../core/theme/app_theme.dart';

/// The app's one loading-spinner look — same ring/color/proportions as the
/// splash screen's own (see splash_screen.dart), just reusable everywhere
/// else a `CircularProgressIndicator` used to be dropped in ad hoc with
/// whatever size/strokeWidth/color a given screen happened to pick.
///
/// Fades in on its own (no flash-of-spinner on a fetch that resolves in a
/// couple frames) — pair with [PileusLoadingSwitcher] where the *disappearing*
/// half also needs a soft transition instead of an instant pop.
class PileusSpinner extends StatelessWidget {
  final double size;
  final Color color;
  // Optional determinate progress (0..1, or a percent 0..100 — same as
  // CircularProgressIndicator's own `value`); null keeps the usual
  // indeterminate spin. Threaded through as-is for callers like the
  // playback buffering indicator that show a real percentage.
  final double? value;
  // No default: a fixed px size is exactly what let this drift small on a
  // real 4K/FHD panel while looking fine on the QHD dev monitor — every
  // call site must pass one of AppScale.spinnerS/spinnerL (or its own
  // AppScale-derived value) so the spinner actually scales with the rest
  // of the screen it's on (2026-09 audit: ~20 of ~25 call sites were
  // relying on this default instead).
  const PileusSpinner({
    super.key,
    required this.size,
    this.color = AppTheme.primary,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: SizedBox(
        width: size,
        height: size,
        child: lowPowerUi && value == null
            ? _SteppedSpinner(color: color, strokeWidth: size * (2.5 / 30))
            : CircularProgressIndicator(
                color: color,
                value: value,
                strokeWidth: size * (2.5 / 30),
              ),
      ),
    );
  }
}

/// "Hardware modesto" spinner: a fixed arc that turns in steps ~12 times a
/// second instead of CircularProgressIndicator's 60 fps animation.
///
/// A spinning indicator is what keeps the whole screen re-rendering and
/// re-compositing every vsync (an idle Flutter screen renders nothing), so
/// on a weak TV box it is the single biggest sustained GPU load in the
/// UI — and the moment the Tanix W2's driver used to hang: "it always
/// freezes while a spinner is spinning". Each step still repaints the full
/// frame, but 5× fewer of them.
class _SteppedSpinner extends StatefulWidget {
  final Color color;
  final double strokeWidth;

  const _SteppedSpinner({required this.color, required this.strokeWidth});

  @override
  State<_SteppedSpinner> createState() => _SteppedSpinnerState();
}

class _SteppedSpinnerState extends State<_SteppedSpinner> {
  static const _interval = Duration(milliseconds: 83);
  static const _steps = 12; // one turn per second
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) {
      if (mounted) setState(() => _step = (_step + 1) % _steps);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _ArcPainter(
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            startAngle: _step * 2 * math.pi / _steps,
          ),
        ),
      );
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double startAngle;

  const _ArcPainter({
    required this.color,
    required this.strokeWidth,
    required this.startAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    canvas.drawArc(
      rect,
      startAngle,
      math.pi * 1.5,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.startAngle != startAngle ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Cross-fades between [PileusSpinner] and [child] on [isLoading], instead
/// of the spinner popping off the instant loading flips false — a beat too
/// abrupt to read as "done" rather than "glitched". [minVisible] additionally
/// floors how long the spinner stays up once shown, so a fetch that resolves
/// in a handful of milliseconds doesn't still flash it for one frame.
class PileusLoadingSwitcher extends StatefulWidget {
  final bool isLoading;
  final Widget child;
  final double spinnerSize;
  final Duration minVisible;
  const PileusLoadingSwitcher({
    super.key,
    required this.isLoading,
    required this.child,
    required this.spinnerSize,
    this.minVisible = const Duration(milliseconds: 260),
  });

  @override
  State<PileusLoadingSwitcher> createState() => _PileusLoadingSwitcherState();
}

class _PileusLoadingSwitcherState extends State<PileusLoadingSwitcher> {
  DateTime? _shownAt;
  bool _effectiveLoading = true;

  @override
  void initState() {
    super.initState();
    _effectiveLoading = widget.isLoading;
    if (_effectiveLoading) _shownAt = DateTime.now();
  }

  @override
  void didUpdateWidget(PileusLoadingSwitcher old) {
    super.didUpdateWidget(old);
    if (widget.isLoading == old.isLoading) return;
    if (widget.isLoading) {
      _shownAt = DateTime.now();
      setState(() => _effectiveLoading = true);
      return;
    }
    final shownAt = _shownAt;
    final elapsed = shownAt == null
        ? widget.minVisible
        : DateTime.now().difference(shownAt);
    final remaining = widget.minVisible - elapsed;
    if (remaining <= Duration.zero) {
      setState(() => _effectiveLoading = false);
    } else {
      Future.delayed(remaining, () {
        if (mounted && !widget.isLoading) {
          setState(() => _effectiveLoading = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: AppScale.fadeCurve,
      switchOutCurve: AppScale.fadeCurve,
      child: _effectiveLoading
          ? Center(
              key: const ValueKey('spinner'),
              child: PileusSpinner(size: widget.spinnerSize),
            )
          : KeyedSubtree(key: const ValueKey('content'), child: widget.child),
    );
  }
}
