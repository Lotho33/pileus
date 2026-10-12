import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/features/player/engine/buffer_policy.dart';
import 'package:pileus/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('exoBufferMs', () {
    test('default VOD reserve (60s)', () {
      final b = exoBufferMs(60);
      expect(b.minBuffer, 60000);
      expect(b.maxBuffer, 105000); // ×1.75
      expect(b.forPlayback, 2500);
      expect(b.afterRebuffer, 7500); // 60/8
    });

    test('max is capped at 300s, afterRebuffer at 10s', () {
      final b = exoBufferMs(180);
      expect(b.minBuffer, 180000);
      expect(b.maxBuffer, 300000);
      expect(b.afterRebuffer, 10000);
    });

    test('small live reserve keeps afterRebuffer at the 3s floor', () {
      final b = exoBufferMs(6);
      expect(b.minBuffer, 6000);
      expect(b.maxBuffer, 10500);
      expect(b.afterRebuffer, 3000);
      expect(b.forPlayback, 2500);
    });
  });

  test('mpv byte cap: reserve × 1 MB/s, never below 16 MiB', () {
    expect(mpvBufferCapBytes(60), 60 * 1000 * 1000);
    expect(mpvBufferCapBytes(6), 16 * 1024 * 1024);
  });

  test('hls.js buffer mirrors ExoPlayer min/max', () {
    final b = hlsJsBuffer(60);
    expect(b.maxBufferLength, 60);
    expect(b.maxMaxBufferLength, 105);
    expect(hlsJsBuffer(180).maxMaxBufferLength, 300);
  });

  test('hardware modesto caps the applied reserve, otherwise untouched', () {
    expect(appliedReserveSec(120, live: false, lowPower: false), 120);
    expect(appliedReserveSec(120, live: false, lowPower: true), 90);
    expect(appliedReserveSec(45, live: true, lowPower: true), 30);
    expect(appliedReserveSec(20, live: true, lowPower: true), 20);
  });

  group('SettingsRepository reserve + MiB migration', () {
    Future<(SettingsRepository, SharedPreferences)> repo(
        Map<String, Object> stored) async {
      SharedPreferences.setMockInitialValues(stored);
      final prefs = await SharedPreferences.getInstance();
      return (
        SettingsRepository(prefs, AuthInterceptor(), (_, __) async {}),
        prefs
      );
    }

    test('nothing stored → new defaults', () async {
      final (s, _) = await repo({});
      expect(s.getVodBufferSec(), 60);
      expect(s.getLiveBufferSec(), 20);
    });

    test('stored MiB is converted once and the old key dropped', () async {
      final (s, prefs) = await repo({
        'settings.playerBufferMiB': 96, // 96/32×20 = 60s
        'settings.liveBufferMiB': 32, // 32s
      });
      expect(s.getVodBufferSec(), 60);
      expect(s.getLiveBufferSec(), 32);
      expect(prefs.getInt('settings.vodBufferSec'), 60);
      expect(prefs.containsKey('settings.playerBufferMiB'), isFalse);
      expect(prefs.containsKey('settings.liveBufferMiB'), isFalse);
    });

    test('converted values are clamped to the new ranges', () async {
      final (s, _) = await repo({
        'settings.playerBufferMiB': 8, // 5s → 15s floor
        'settings.liveBufferMiB': 4, // 4s → 6s floor
      });
      expect(s.getVodBufferSec(), 15);
      expect(s.getLiveBufferSec(), 6);
      final (s2, _) = await repo({'settings.playerBufferMiB': 512});
      expect(s2.getVodBufferSec(), 180);
    });

    test('a new-key value wins over a leftover MiB one', () async {
      final (s, _) = await repo({
        'settings.vodBufferSec': 90,
        'settings.playerBufferMiB': 8,
      });
      expect(s.getVodBufferSec(), 90);
    });
  });
}
