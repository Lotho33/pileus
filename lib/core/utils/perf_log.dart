import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Master switch for all release-visible diagnostics: the `perf()` /
/// `perfReset()` wall-clock trace and the [installJankLogger] frame sampler.
///
/// Defaults to [kDebugMode] so a normal release build ships silent. `main()`
/// raises it at startup when `SettingsRepository.getDiagnostics()` is on —
/// a hidden Preferenze toggle used to pull field logs off a specific TV box
/// (the Tanix W2 tuning work) without a debug build. Not `const`: it's set
/// once, after settings load, before `runApp`.
bool kPerfDiagnostics = kDebugMode;

/// Lightweight wall-clock tracing for the playback start pipeline.
///
/// Everything here goes through `debugPrint`, which — unlike `assert` /
/// `kDebugMode` blocks — is NOT stripped from a release build, so these
/// lines show up in `adb logcat` on the Obtainium build on the TV boxes.
/// Grep the log for `pileus/perf`.
///
/// The point is to see where the wall-clock goes between "user pressed play"
/// and "first frame on screen", and — for the full-freeze bug — the last
/// line before the device locks up.
final Stopwatch _perfClock = Stopwatch()..start();

/// Log [event] with the ms elapsed since the last [perfReset]. No-op unless
/// [kPerfDiagnostics] (debug build, or the field-diagnostics toggle).
void perf(String event) {
  if (!kPerfDiagnostics) return;
  debugPrint('[pileus/perf] t=${_perfClock.elapsedMilliseconds}ms  $event');
}

/// Restart the wall-clock — call the instant a new playback session begins
/// (the player route is pushed), so every following [perf] line is relative
/// to "user pressed play".
void perfReset(String reason) {
  _perfClock
    ..reset()
    ..start();
  if (!kPerfDiagnostics) return;
  debugPrint('[pileus/perf] ===================== $reason');
}

/// The screen the user is on, kept current by [PerfNavigatorObserver] —
/// stamped on every `pileus/jank` line so a slow frame can be pinned to the
/// screen that produced it.
String perfScreen = '?';

/// Sample frame timings and log the slow ones to `adb logcat`
/// (`pileus/jank`). One line per second at most, so it can't flood the log
/// or become the jank itself — but that line summarises the whole second:
/// how many frames were slow out of how many, the worst one, and the
/// screen. Call once from `main()` after
/// `WidgetsFlutterBinding.ensureInitialized()`.
void installJankLogger({
  Duration threshold = const Duration(milliseconds: 32),
}) {
  if (!kPerfDiagnostics) return;
  var windowStartMs = 0;
  var frames = 0;
  var slow = 0;
  FrameTiming? worst;
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      frames++;
      if (t.totalSpan >= threshold) {
        slow++;
        if (worst == null || t.totalSpan > worst!.totalSpan) worst = t;
      }
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - windowStartMs < 1000) return;
    final w = worst;
    if (w != null) {
      debugPrint('[pileus/jank] @$perfScreen  slow $slow/$frames'
          '  worst ${w.totalSpan.inMilliseconds}ms'
          ' (build ${w.buildDuration.inMilliseconds}ms'
          ' raster ${w.rasterDuration.inMilliseconds}ms)'
          '  #${w.frameNumber}');
    }
    windowStartMs = nowMs;
    frames = 0;
    slow = 0;
    worst = null;
  });
}
