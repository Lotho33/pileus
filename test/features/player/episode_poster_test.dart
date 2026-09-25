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

    test('falls back to the series poster when the episode thumb is empty', () {
      final poster = posterForEpisode(
        episodeThumbs: ['ep0.jpg', '', 'ep2.jpg'],
        index: 1,
        seriesPoster: 'series.jpg',
        fallback: 'launch.jpg',
      );
      expect(poster, 'series.jpg');
    });

    test('falls back to the series poster when the index is out of range', () {
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

    test(
        'falls back to the series cover_url (horizontal) before the series '
        'poster (vertical) when the episode thumb is empty', () {
      final poster = posterForEpisode(
        episodeThumbs: ['ep0.jpg', ''],
        index: 1,
        seriesCoverUrl: 'series_cover.jpg',
        seriesPoster: 'series.jpg',
        fallback: 'launch.jpg',
      );
      expect(poster, 'series_cover.jpg');
    });

    test(
        'skips an empty series cover_url and falls back to the series '
        'poster', () {
      final poster = posterForEpisode(
        episodeThumbs: const [],
        index: 0,
        seriesCoverUrl: '',
        seriesPoster: 'series.jpg',
        fallback: 'launch.jpg',
      );
      expect(poster, 'series.jpg');
    });
  });

  group('posterForMovie', () {
    test('prefers extra[cover_url] over fanart and poster', () {
      final poster = posterForMovie(
        coverUrl: 'cover.jpg',
        fanartUrl: 'fanart.jpg',
        posterUrl: 'poster.jpg',
      );
      expect(poster, 'cover.jpg');
    });

    test('falls back to fanart when cover_url is absent', () {
      final poster = posterForMovie(
        coverUrl: '',
        fanartUrl: 'fanart.jpg',
        posterUrl: 'poster.jpg',
      );
      expect(poster, 'fanart.jpg');
    });

    test('falls back to the vertical poster when both are empty', () {
      final poster = posterForMovie(
        coverUrl: '',
        fanartUrl: '',
        posterUrl: 'poster.jpg',
      );
      expect(poster, 'poster.jpg');
    });

    test('never picks the vertical poster over an available cover_url', () {
      // Regression test for the bug this helper exists to fix: the CW
      // poster for a movie used to always be the backdrop/fanart (cropped,
      // identical to the details page hero) instead of the horizontal
      // "title card" plugins expose specifically for this.
      final poster = posterForMovie(
        coverUrl: 'cover.jpg',
        fanartUrl: '',
        posterUrl: 'poster.jpg',
      );
      expect(poster, 'cover.jpg');
    });
  });

  group('numberForEpisode', () {
    test('returns the number at index', () {
      expect(numberForEpisode([1, 2, 3], 1), 2);
    });

    test('returns 0 for a negative index', () {
      expect(numberForEpisode([1, 2, 3], -1), 0);
    });

    test('returns 0 for an out-of-range index', () {
      expect(numberForEpisode([1, 2, 3], 5), 0);
    });

    test('returns 0 for an empty list', () {
      expect(numberForEpisode(const [], 0), 0);
    });
  });

  group('episodeBadge', () {
    test('formats "S{x} · E{y}" when both are known', () {
      expect(episodeBadge(2, 5), 'S2 · E5');
    });

    test('falls back to just "E{y}" when the season is unknown', () {
      expect(episodeBadge(0, 5), 'E5');
    });

    test('is empty when the episode number is 0 (a movie)', () {
      expect(episodeBadge(2, 0), '');
    });

    test('is empty when both are 0', () {
      expect(episodeBadge(0, 0), '');
    });
  });
}
