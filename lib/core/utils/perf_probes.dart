import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'perf_log.dart';

/// Field-diagnostics probes (only with kPerfDiagnostics): navigation timing
/// and a periodic memory summary, both into `pileus/perf`. Profiling the TV
/// build on weak boxes (1 GB Mi TV Stick) without a debug build.

/// Logs every route change and how long the new screen took to its first
/// rendered frame; keeps [perfScreen] current for the jank lines.
class PerfNavigatorObserver extends NavigatorObserver {
  static String _name(Route<dynamic>? r) {
    final n = r?.settings.name;
    if (n != null && n.isNotEmpty) return n;
    return r == null ? '-' : r.runtimeType.toString();
  }

  void _changed(String what, Route<dynamic>? shown, Route<dynamic>? from) {
    final to = _name(shown);
    // Always — the smoothness metric (Metrics.fluidity) files every frame
    // under the current screen. The logging below is diagnostics-only.
    perfScreen = to;
    if (!kPerfDiagnostics) return;
    final sw = Stopwatch()..start();
    perf('nav: $what $to (from ${_name(from)})');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // The frame that built the new screen has been laid out and
      // submitted; its raster cost shows up in the jank line if slow.
      perf('nav: $to first frame ${sw.elapsedMilliseconds}ms');
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed('push', route, previousRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed('pop →', previousRoute, route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _changed('replace', newRoute, oldRoute);
}

Timer? _memTimer;

/// Every [every]: process RSS and the decoded-image cache (bytes, entries,
/// live images) — the two numbers that matter on a 1 GB box.
void installMemoryProbe({Duration every = const Duration(seconds: 30)}) {
  if (!kPerfDiagnostics || kIsWeb) return;
  _memTimer?.cancel();
  void sample() {
    final cache = PaintingBinding.instance.imageCache;
    int? rssMb;
    try {
      rssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    } catch (_) {}
    perf('mem: rss=${rssMb ?? '?'}MB '
        'images=${cache.currentSizeBytes ~/ (1024 * 1024)}/'
        '${cache.maximumSizeBytes ~/ (1024 * 1024)}MB '
        'entries=${cache.currentSize}/${cache.maximumSize} '
        'live=${cache.liveImageCount} @$perfScreen');
  }

  sample();
  _memTimer = Timer.periodic(every, (_) => sample());
}
