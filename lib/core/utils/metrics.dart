import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_log.dart';

/// User-facing response times — the few waits that decide whether the app
/// feels fast: cold start, opening a title, Play → first frame, coming back
/// from standby. Unlike `perf()` (a raw trace, only with the diagnostics
/// toggle) these are always collected: a handful of samples per action, the
/// last [_keep] of each persisted, so they survive restarts and can be read
/// in Preferenze → "Tempi di risposta" without adb. Each sample is also
/// logged as `pileus/metric` when diagnostics are on.
///
/// Every clock here is best-effort and starts where Dart can see it: the
/// startup one at `main()` (the engine's own boot before that is not
/// counted), the standby one when the wake is noticed (up to one 5 s tick
/// after the actual wake).
class Metric {
  final String id;
  final String label;
  final String hint;
  const Metric(this.id, this.label, this.hint);
}

class MetricSummary {
  final Metric metric;
  final List<int> samples; // oldest first
  const MetricSummary(this.metric, this.samples);

  int get last => samples.last;
  int get median {
    final s = [...samples]..sort();
    return s[s.length ~/ 2];
  }

  int get worst => samples.reduce((a, b) => a > b ? a : b);
}

class Metrics {
  Metrics._();

  static const startup = Metric('avvio', 'Avvio → home',
      'Da quando l\'app parte alla home pronta (solo con profilo ricordato).');
  static const details = Metric('dettagli', 'Apertura dettaglio',
      'Caricamento della scheda di un titolo.');
  static const play = Metric('play', 'Play → primo frame',
      'Dal tocco su Play al primo fotogramma sullo schermo.');
  static const sources = Metric(
      'sorgenti', 'Ricerca sorgenti', 'Elenco delle sorgenti (GetStreams).');
  static const resolve = Metric('resolve', 'Preparazione stream',
      'Preparazione del video sul server, fino ai primi segmenti.');
  static const firstFrame = Metric('apertura', 'Apertura video',
      'Dallo stream pronto al primo fotogramma (player del dispositivo).');
  static const wake = Metric('ripresa', 'Ripresa dopo standby',
      'Dal risveglio alla prima risposta del server.');
  static const seek = Metric('seek', 'Spostamento nel video',
      'Da un salto (barra, avanti/indietro, salta intro) alla ripresa.');
  static const rebuffer = Metric('interruzioni', 'Interruzioni',
      'Pause per caricamento durante la visione (salti esclusi).');

  static const all = [
    startup,
    details,
    play,
    sources,
    resolve,
    firstFrame,
    wake,
    seek,
    rebuffer,
  ];

  static const _prefsKey = 'metrics.samples.v1';
  static const _keep = 20;
  // Anything longer is an abandoned flow (screen left open, app in the
  // background), not a wait — it would wreck the median.
  static const _maxSample = Duration(minutes: 2);

  static final Map<String, List<int>> _samples = {};
  static SharedPreferences? _prefs;
  static Timer? _saveTimer;

  /// Call first thing in every `main()`.
  static final Stopwatch _sinceStart = Stopwatch();
  static void markAppStart() {
    if (!_sinceStart.isRunning) _sinceStart.start();
  }

  /// Loads the persisted samples. Call once dependencies are up.
  static void attach(SharedPreferences prefs) {
    _prefs = prefs;
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in decoded.entries) {
        final list = (e.value as List).whereType<int>().toList();
        // Samples taken this session before attach() win.
        _samples[e.key] = [...list, ...?_samples[e.key]];
        _trim(e.key);
      }
    } catch (_) {
      // A corrupt blob only costs the history.
    }
  }

  static void record(Metric m, int ms, {String detail = ''}) {
    if (ms < 0 || ms > _maxSample.inMilliseconds) return;
    (_samples[m.id] ??= []).add(ms);
    _trim(m.id);
    if (kPerfDiagnostics) {
      debugPrint('[pileus/metric] ${m.id}=${ms}ms'
          '${detail.isEmpty ? '' : '  $detail'}');
    }
    _scheduleSave();
  }

  static List<MetricSummary> summaries() => [
        for (final m in all)
          if ((_samples[m.id] ?? const []).isNotEmpty)
            MetricSummary(m, List.unmodifiable(_samples[m.id]!)),
      ];

  static Future<void> clear() async {
    _samples.clear();
    _fluidity.clear();
    _saveTimer?.cancel();
    await _prefs?.remove(_prefsKey);
    await _prefs?.remove(_fluidityKey);
  }

  static void _trim(String id) {
    final l = _samples[id]!;
    if (l.length > _keep) l.removeRange(0, l.length - _keep);
  }

  static void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_prefs?.setString(_prefsKey, jsonEncode(_samples)));
      unawaited(_prefs?.setString(_fluidityKey, jsonEncode(_fluidity)));
    });
  }

  // ── Startup ────────────────────────────────────────────────────────────────

  static bool? _startupDirect;
  static bool _startupDone = false;

  /// AuthBloc decides at boot whether the app goes straight to the home
  /// (remembered profile) or stops on a screen that waits for the user
  /// (discovery, pairing, profile picker) — only the first is a wait worth
  /// timing.
  static void startupPath({required bool direct}) => _startupDirect ??= direct;

  /// First frame of a home shell. Only the first one per process counts.
  static void homeShown() {
    if (_startupDone) return;
    _startupDone = true;
    if (_startupDirect == true) {
      record(startup, _sinceStart.elapsedMilliseconds);
    }
  }

  // ── Play → first frame ─────────────────────────────────────────────────────

  static Stopwatch? _play;
  static Stopwatch? _sinceReady;
  static const _playJoinWindow = Duration(seconds: 15);

  /// The user asked to play something. Tap sites that fetch sources before
  /// pushing the player call this plainly; the player itself calls it with
  /// [join] so it keeps a clock a tap site started moments ago instead of
  /// restarting it.
  static void playBegin({bool join = false}) {
    final p = _play;
    if (join && p != null && p.elapsed < _playJoinWindow) return;
    _play = Stopwatch()..start();
    _sinceReady = null;
    _stopWatching();
  }

  /// The stream is resolved and handed to the engine.
  static void playReady() {
    if (_play != null) _sinceReady = Stopwatch()..start();
  }

  /// The first frame is on screen. Ends the clock: later "started" flips in
  /// the same player (episode switches, reopen after an error) don't count.
  static void playFirstFrame() {
    _watching = true;
    final p = _play;
    if (p == null) return;
    final r = _sinceReady;
    _play = null;
    _sinceReady = null;
    record(play, p.elapsedMilliseconds);
    if (r != null) record(firstFrame, r.elapsedMilliseconds);
  }

  /// The player went away without a first frame (error, backed out).
  static void playAbandon() {
    _play = null;
    _sinceReady = null;
    _stopWatching();
  }

  // ── Seek and rebuffering ──────────────────────────────────────────────────
  //
  // Only between the first frame and the next Play: the opening wait is the
  // Play clock's. Fed by the players: [seekBegin] on every seek, and
  // [playbackTick] whenever position/playing/buffering change.

  static bool _watching = false;
  static Stopwatch? _seek;
  static Duration _seekTarget = Duration.zero;
  static Stopwatch? _stall;
  // Shorter stalls are a blip nobody notices, not an interruption.
  static const _minStallMs = 300;
  // A seek whose landing is never seen (out of range, player closed).
  static const _seekGiveUp = Duration(seconds: 30);

  static void _stopWatching() {
    _watching = false;
    _seek = null;
    _stall = null;
  }

  static void seekBegin(Duration to) {
    if (!_watching) return;
    _seek = Stopwatch()..start();
    _seekTarget = to;
    _stall = null;
  }

  static void playbackTick(Duration position,
      {required bool playing, required bool buffering}) {
    if (!_watching) return;
    if (!playing && !buffering) {
      // Paused: time spent here is the user's, not a wait.
      _seek = null;
      _stall = null;
      return;
    }
    if (buffering) {
      if (_seek == null) _stall ??= Stopwatch()..start();
      return;
    }
    final s = _seek;
    if (s != null) {
      // Moving again at the target — not a stale tick from before the seek
      // landed.
      final d = position - _seekTarget;
      if (d >= const Duration(seconds: -1) && d <= const Duration(seconds: 5)) {
        _seek = null;
        record(seek, s.elapsedMilliseconds);
      } else if (s.elapsed > _seekGiveUp) {
        _seek = null;
      }
    }
    final st = _stall;
    if (st != null) {
      _stall = null;
      if (st.elapsedMilliseconds >= _minStallMs) {
        record(rebuffer, st.elapsedMilliseconds);
      }
    }
  }

  // ── Standby ────────────────────────────────────────────────────────────────

  static Stopwatch? _wake;

  static void wakeBegin() => _wake = Stopwatch()..start();

  /// Any content RPC answered successfully.
  static void rpcOk() {
    final w = _wake;
    if (w == null) return;
    _wake = null;
    record(wake, w.elapsedMilliseconds);
  }

  // ── Smoothness ─────────────────────────────────────────────────────────────
  //
  // Share of slow frames per screen, always on: the engine already hands
  // frame timings over in batches, counting them is nearly free. "Slow" is
  // past 1.5 frames at 60 Hz — a hitch you can see, not a missed vsync.
  // Counts are halved past [_fluidityWindow] frames so the number follows
  // the current build/settings, not the whole install's history.

  static const _fluidityKey = 'metrics.fluidity.v1';
  static const _slowFrame = Duration(milliseconds: 25);
  static const _fluidityWindow = 20000;
  static final Map<String, List<int>> _fluidity = {}; // screen → [frames, slow]
  static bool _fluidityInstalled = false;

  static const screenLabels = {
    'home': 'Home',
    'details': 'Scheda titolo',
    'episode': 'Scheda episodio',
    'browse': 'Sfoglia',
    'search': 'Ricerca',
    'player': 'Player',
    'settings': 'Impostazioni',
  };

  /// "/details/p/123" → "details"; anything unnamed → "altro".
  static String screenOf(String route) {
    if (!route.startsWith('/')) return 'altro';
    final first = route.split('/').where((s) => s.isNotEmpty).firstOrNull;
    return screenLabels.containsKey(first) ? first! : 'altro';
  }

  /// Call once from main(), after [attach].
  static void installFluidity() {
    if (_fluidityInstalled) return;
    _fluidityInstalled = true;
    try {
      final raw = _prefs?.getString(_fluidityKey);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in m.entries) {
          final v = (e.value as List).whereType<int>().toList();
          if (v.length == 2) _fluidity[e.key] = v;
        }
      }
    } catch (_) {}
    SchedulerBinding.instance.addTimingsCallback(recordFrames);
  }

  @visibleForTesting
  static void recordFrames(List<FrameTiming> timings) {
    final c = _fluidity[screenOf(perfScreen)] ??= [0, 0];
    for (final t in timings) {
      c[0]++;
      if (t.totalSpan > _slowFrame) c[1]++;
    }
    if (c[0] > _fluidityWindow) {
      c[0] ~/= 2;
      c[1] ~/= 2;
    }
    _scheduleSave();
  }

  /// (label, slow frames %, frames) per screen seen, busiest first.
  static List<({String label, double slowPct, int frames})> fluidity() {
    final out = [
      for (final e in _fluidity.entries)
        if (e.value[0] > 0)
          (
            label: screenLabels[e.key] ?? 'Altro',
            slowPct: e.value[1] * 100 / e.value[0],
            frames: e.value[0],
          ),
    ]..sort((a, b) => b.frames.compareTo(a.frames));
    return out;
  }

  @visibleForTesting
  static void resetForTest() {
    _fluidity.clear();
    _samples.clear();
    _prefs = null;
    _saveTimer?.cancel();
    _startupDirect = null;
    _startupDone = false;
    _play = null;
    _sinceReady = null;
    _wake = null;
    _stopWatching();
  }
}
