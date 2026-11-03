import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/utils/image_sizing.dart';

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
}
