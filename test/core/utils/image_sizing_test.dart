import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/db/models/device_session.dart';
import 'package:pileus/core/di/injection.dart';
import 'package:pileus/core/utils/image_sizing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const jf = 'https://jf.example/Items/ed65eb435fc537f16f5a2c263856d25b';

  group('Jellyfin image width', () {
    test('poster gets the smallest ladder width covering the target', () {
      expect(posterSrc('$jf/Images/Primary?api_key=k', 300),
          '$jf/Images/Primary?api_key=k&maxWidth=360');
      expect(posterSrc('$jf/Images/Primary', 5000),
          '$jf/Images/Primary?maxWidth=960');
    });

    test('backdrop uses the backdrop ladder', () {
      expect(backdropSrc('$jf/Images/Backdrop?api_key=k', 1600),
          '$jf/Images/Backdrop?api_key=k&maxWidth=1920');
    });

    test('an explicit width from the plugin is kept', () {
      const url = '$jf/Images/Primary?fillWidth=200&api_key=k';
      expect(posterSrc(url, 300), url);
    });

    test('logos and other hosts are untouched', () {
      expect(posterSrc('$jf/Images/Logo?api_key=k', 300),
          '$jf/Images/Logo?api_key=k');
      expect(posterSrc('https://cdn.example/poster.jpg', 300),
          'https://cdn.example/poster.jpg');
    });
  });

  test('TMDB backdrops stop at w1280, never original', () {
    expect(backdropSrc('https://image.tmdb.org/t/p/original/a.jpg', 1920),
        'https://image.tmdb.org/t/p/w1280/a.jpg');
    expect(backdropSrc('https://image.tmdb.org/t/p/original/a.jpg', 700),
        'https://image.tmdb.org/t/p/w780/a.jpg');
  });

  group('/img proxy', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await DeviceSession.writeTo(
          prefs, DeviceSession()..grpcHost = '10.0.0.5');
      if (getIt.isRegistered<SharedPreferences>()) {
        getIt.unregister<SharedPreferences>();
      }
      getIt.registerSingleton<SharedPreferences>(prefs);
    });
    tearDown(() => getIt.unregister<SharedPreferences>());

    test('a plugin image goes through the proxy', () {
      expect(posterSrc('https://cdn.example/img/p.jpg', 300, proxy: true),
          startsWith('http://10.0.0.5:8000/img?u='));
    });

    test('a mycelium image under another base is not wrapped again', () {
      const versus = 'https://media.example/img/versus?h=aA&a=bB';
      expect(posterSrc(versus, 300, proxy: true), versus);
      const img = 'http://other:8000/img?u=aHR0cA';
      expect(backdropSrc(img, 1280, proxy: true), img);
    });
  });
}
