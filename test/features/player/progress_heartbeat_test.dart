import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/progress_heartbeat.dart';

void main() {
  group('ProgressHeartbeat', () {
    testWidgets('saves every interval once started', (t) async {
      var saves = 0;
      final hb = ProgressHeartbeat(isLive: false, onSave: () => saves++)
        ..start();
      await t.pump(const Duration(seconds: 44));
      expect(saves, 2);
      hb.start(); // already running: no second timer
      await t.pump(const Duration(seconds: 10)); // t=54: tick at 45
      expect(saves, 3);
      hb.close();
    });

    testWidgets('live never saves', (t) async {
      var saves = 0;
      final hb = ProgressHeartbeat(isLive: true, onSave: () => saves++)
        ..start();
      await t.pump(const Duration(minutes: 1));
      hb.setBackgrounded(true);
      hb.close();
      expect(saves, 0);
      expect(hb.isRunning, isFalse);
    });

    testWidgets('background: stops with one save; foreground restarts',
        (t) async {
      var saves = 0;
      final hb = ProgressHeartbeat(isLive: false, onSave: () => saves++)
        ..start();
      hb.setBackgrounded(true);
      expect(saves, 1);
      hb.setBackgrounded(true); // already stopped: no extra save
      expect(saves, 1);
      await t.pump(const Duration(minutes: 1));
      expect(saves, 1);
      hb.setBackgrounded(false);
      await t.pump(const Duration(seconds: 15));
      expect(saves, 2);
      hb.close();
    });

    testWidgets('close stops and saves once; a throwing save is swallowed',
        (t) async {
      var saves = 0;
      final hb = ProgressHeartbeat(
          isLive: false,
          onSave: () {
            saves++;
            throw StateError('engine gone');
          })
        ..start();
      hb.close();
      expect(saves, 1);
      await t.pump(const Duration(minutes: 1));
      expect(saves, 1);
    });
  });

  group('ErrorGrace', () {
    testWidgets('fires after the window unless cancelled', (t) async {
      var fired = 0;
      final g = ErrorGrace(duration: const Duration(seconds: 6));
      g.arm(() => fired++);
      expect(g.isActive, isTrue);
      await t.pump(const Duration(seconds: 6));
      expect(fired, 1);
      expect(g.isActive, isFalse);

      g.arm(() => fired++);
      await t.pump(const Duration(seconds: 3));
      g.cancel();
      await t.pump(const Duration(seconds: 10));
      expect(fired, 1);
    });

    testWidgets('re-arming restarts the window', (t) async {
      final hits = <int>[];
      final g = ErrorGrace(duration: const Duration(seconds: 6));
      g.arm(() => hits.add(1));
      await t.pump(const Duration(seconds: 4));
      g.arm(() => hits.add(2));
      await t.pump(const Duration(seconds: 4));
      expect(hits, isEmpty);
      await t.pump(const Duration(seconds: 2));
      expect(hits, [2]);
    });
  });
}
