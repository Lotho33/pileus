import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/episode_poster.dart';

void main() {
  group('posterForEpisode', () {
    test('uses the episode\'s own thumbnail when present', () {
      final poster = posterForEpisode(
        episodeThumbs: ['ep0.jpg', 'ep1.jpg', 'ep2.jpg'],
        index: 1,
        seriesPoster: 'series.jpg',
        fallback: 'launch.jpg',
      );
      expect(poster, 'ep1.jpg');
    });

    test('falls back to the series poster when the episode thumb is empty',
        () {
      final poster = posterForEpisode(
        episodeThumbs: ['ep0.jpg', '', 'ep2.jpg'],
        index: 1,
        seriesPoster: 'series.jpg',
        fallback: 'launch.jpg',
      );
      expect(poster, 'series.jpg');
    });

    test('falls back to the series poster when the index is out of range',
        () {
      final poster = posterForEpisode(
        episodeThumbs: ['ep0.jpg'],
        index: 5,
        seriesPoster: 'series.jpg',
        fallback: 'launch.jpg',
      );
      expect(poster, 'series.jpg');
    });

    test('falls back to the series poster for a negative index', () {
      final poster = posterForEpisode(
        episodeThumbs: ['ep0.jpg'],
        index: -1,
        seriesPoster: 'series.jpg',
        fallback: 'launch.jpg',
      );
      expect(poster, 'series.jpg');
    });

    test('falls back to the caller-supplied fallback when neither is usable',
        () {
      final poster = posterForEpisode(
        episodeThumbs: const [],
        index: 0,
        seriesPoster: '',
        fallback: 'launch.jpg',
      );
      expect(poster, 'launch.jpg');
    });

    test('never gets stuck on the entry-point episode across a binge', () {
      // Regression test for the bug this helper exists to fix: the cover
      // used to stay frozen on episode 0's thumbnail for the whole session.
      const thumbs = ['ep0.jpg', 'ep1.jpg', 'ep2.jpg'];
      for (var i = 0; i < thumbs.length; i++) {
        final poster = posterForEpisode(
          episodeThumbs: thumbs,
          index: i,
          seriesPoster: 'series.jpg',
          fallback: 'ep0.jpg', // the frozen launch-time poster
        );
        expect(poster, thumbs[i]);
      }
    });
  });
}
