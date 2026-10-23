import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/utils/metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> _samples(Metric m) =>
    Metrics.summaries().where((s) => s.metric.id == m.id).firstOrNull?.samples ??
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
}
