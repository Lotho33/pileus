import 'dart:ui' show FrameTiming;

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/utils/perf_log.dart';
import 'package:pileus/core/utils/metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> _samples(Metric m) =>
    Metrics.summaries()
        .where((s) => s.metric.id == m.id)
        .firstOrNull
        ?.samples ??
    const [];

void main() {
  setUp(Metrics.resetForTest);

  test('keeps the last 20 samples and drops abandoned flows', () {
    for (var i = 1; i <= 25; i++) {
      Metrics.record(Metrics.details, i);
    }
    Metrics.record(Metrics.details, const Duration(minutes: 3).inMilliseconds);
    expect(_samples(Metrics.details), [for (var i = 6; i <= 25; i++) i]);
  });

  test('summary statistics', () {
    for (final v in [300, 100, 200]) {
      Metrics.record(Metrics.resolve, v);
    }
    final s = Metrics.summaries().single;
    expect(s.median, 200);
    expect(s.last, 200);
    expect(s.worst, 300);
  });

  test('play clock: one sample per Play, joined by the player', () {
    Metrics.playBegin(); // tap site
    Metrics.playBegin(join: true); // player bloc a moment later
    Metrics.playReady();
    Metrics.playFirstFrame();
    Metrics.playFirstFrame(); // episode switch in the same player
    expect(_samples(Metrics.play), hasLength(1));
    expect(_samples(Metrics.firstFrame), hasLength(1));
  });

  test('abandoned Play records nothing', () {
    Metrics.playBegin();
    Metrics.playAbandon();
    Metrics.playFirstFrame();
    expect(Metrics.summaries(), isEmpty);
  });

  test('startup only counts when going straight to the home', () {
    Metrics.markAppStart();
    Metrics.startupPath(direct: false);
    Metrics.startupPath(direct: true); // a later AppStarted can't flip it
    Metrics.homeShown();
    expect(_samples(Metrics.startup), isEmpty);

    Metrics.resetForTest();
    Metrics.startupPath(direct: true);
    Metrics.homeShown();
    Metrics.homeShown();
    expect(_samples(Metrics.startup), hasLength(1));
  });

  test('wake: first successful RPC after a wake, once', () {
    Metrics.rpcOk();
    expect(Metrics.summaries(), isEmpty);
    Metrics.wakeBegin();
    Metrics.rpcOk();
    Metrics.rpcOk();
    expect(_samples(Metrics.wake), hasLength(1));
  });

  test('persisted samples load on attach, ahead of this session', () async {
    SharedPreferences.setMockInitialValues({
      'metrics.samples.v1': '{"dettagli":[10,20]}',
    });
    Metrics.record(Metrics.details, 30);
    Metrics.attach(await SharedPreferences.getInstance());
    expect(_samples(Metrics.details), [10, 20, 30]);
  });

  test('a corrupt blob is ignored', () async {
    SharedPreferences.setMockInitialValues({'metrics.samples.v1': '{oops'});
    Metrics.attach(await SharedPreferences.getInstance());
    expect(Metrics.summaries(), isEmpty);
  });

  group('fluidity', () {
    FrameTiming frame(int ms) => FrameTiming(
          vsyncStart: 0,
          buildStart: 0,
          buildFinish: ms * 1000,
          rasterStart: ms * 1000,
          rasterFinish: ms * 1000,
          rasterFinishWallTime: ms * 1000,
        );

    test('screen of a route', () {
      expect(Metrics.screenOf('/details/p/1'), 'details');
      expect(Metrics.screenOf('/home'), 'home');
      expect(Metrics.screenOf('/player/p/x'), 'player');
      expect(Metrics.screenOf('/unknown'), 'altro');
      expect(Metrics.screenOf('MaterialPageRoute<void>'), 'altro');
    });

    test('share of slow frames, per screen', () {
      perfScreen = '/home';
      Metrics.recordFrames([frame(8), frame(8), frame(8), frame(40)]);
      perfScreen = '/details/p/1';
      Metrics.recordFrames([frame(10)]);
      final f = Metrics.fluidity();
      expect(f.first.label, 'Home');
      expect(f.first.frames, 4);
      expect(f.first.slowPct, 25);
      expect(f.last.label, 'Scheda titolo');
      expect(f.last.slowPct, 0);
    });
  });

  group('seek and rebuffering', () {
    const s = Duration(seconds: 1);

    test('nothing before the first frame', () {
      Metrics.playBegin();
      Metrics.seekBegin(s * 60);
      Metrics.playbackTick(s * 60, playing: true, buffering: false);
      expect(_samples(Metrics.seek), isEmpty);
    });

    test('a seek counts once playback moves at its target', () {
      Metrics.playBegin();
      Metrics.playFirstFrame();
      Metrics.seekBegin(s * 60);
      // Stale tick from before the seek landed, then buffering: neither ends it.
      Metrics.playbackTick(s * 10, playing: true, buffering: false);
      Metrics.playbackTick(s * 10, playing: true, buffering: true);
      expect(_samples(Metrics.seek), isEmpty);
      Metrics.playbackTick(s * 61, playing: true, buffering: false);
      expect(_samples(Metrics.seek), hasLength(1));
      // The buffering after the seek was the seek's, not an interruption.
      expect(_samples(Metrics.rebuffer), isEmpty);
    });

    test('a stall counts; a short blip or a pause does not', () async {
      Metrics.playBegin();
      Metrics.playFirstFrame();
      Metrics.playbackTick(s * 5, playing: true, buffering: true);
      Metrics.playbackTick(s * 5, playing: true, buffering: false);
      expect(_samples(Metrics.rebuffer), isEmpty); // < 300 ms

      Metrics.playbackTick(s * 6, playing: true, buffering: true);
      Metrics.playbackTick(s * 6, playing: false, buffering: false); // paused
      await Future<void>.delayed(const Duration(milliseconds: 350));
      Metrics.playbackTick(s * 6, playing: true, buffering: false);
      expect(_samples(Metrics.rebuffer), isEmpty);

      Metrics.playbackTick(s * 7, playing: true, buffering: true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      Metrics.playbackTick(s * 7, playing: true, buffering: false);
      expect(_samples(Metrics.rebuffer), hasLength(1));
    });

    test('a new Play stops watching', () {
      Metrics.playBegin();
      Metrics.playFirstFrame();
      Metrics.playBegin();
      Metrics.seekBegin(s * 60);
      Metrics.playbackTick(s * 60, playing: true, buffering: false);
      expect(_samples(Metrics.seek), isEmpty);
    });
  });
}
