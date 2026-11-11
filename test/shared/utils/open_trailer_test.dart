import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/shared/utils/open_trailer.dart';

void main() {
  test('youtubeIdOf', () {
    const id = 'dQw4w9WgXcQ';
    for (final u in [
      id,
      'https://www.youtube.com/watch?v=$id',
      'https://youtu.be/$id',
      'https://www.youtube.com/embed/$id?autoplay=1',
      'https://m.youtube.com/shorts/$id',
    ]) {
      expect(youtubeIdOf(u), id, reason: u);
    }
    expect(youtubeIdOf('https://vimeo.com/123'), isNull);
    expect(youtubeIdOf(''), isNull);
  });
}
