import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/generated/media.pb.dart';
import 'package:pileus/features/player/player_info.dart';

void main() {
  test('a film: year, runtime, rating at once; cast and direction from details',
      () {
    final base = playerInfoBase(
        title: 'Inception',
        year: 2010,
        rating: 8.4,
        durationSeconds: 148 * 60,
        genres: ['Fantascienza']);
    expect(base.facts, ['2010', '2 h 28 min', '★ 8.4']);
    expect(base.overline, '');
    final full = mergePlayerInfo(base,
        item: DetailsResponse(
            movie: MovieDetails(
                plot: 'Un ladro di sogni…',
                runtime: '148 min',
                contentRating: 'PG-13',
                directors: ['Christopher Nolan'],
                cast: ['Leonardo DiCaprio', 'Elliot Page'],
                released: '2010-07-16')));
    expect(full.facts, ['2010', '2 h 28 min', '★ 8.4', 'PG-13']);
    expect(full.plot, 'Un ladro di sogni…');
    expect(full.rows, [
      ('Regia', 'Christopher Nolan'),
      ('Cast', 'Leonardo DiCaprio, Elliot Page'),
      ('Uscita', '16 luglio 2010'),
    ]);
  });

  test("an episode: series above, S·E badge, the episode's own plot", () {
    final base = playerInfoBase(
        title: 'Il pilota',
        showTitle: 'Breaking Bad',
        seasonNumber: 1,
        episodeNumber: 1,
        plot: 'La serie racconta…');
    expect(base.overline, 'Breaking Bad');
    expect(base.badge, 'S1 · E1');
    final full = mergePlayerInfo(base,
        item: DetailsResponse(
            episode: EpisodeDetails(
                plot: 'Walter White scopre…',
                duration: 58,
                guestStars: ['Ospite A'])),
        series: DetailsResponse(
            series: SeriesDetails(
                year: 2008,
                genres: ['Drama'],
                network: 'AMC',
                status: 'Ended',
                creators: ['Vince Gilligan'])));
    expect(full.plot, 'Walter White scopre…');
    expect(full.facts, ['2008', '58 min']);
    expect(full.genres, ['Drama']);
    expect(full.rows, [
      ('Ospiti', 'Ospite A'),
      ('Ideata da', 'Vince Gilligan'),
      ('Rete', 'AMC'),
      ('Stato', 'Conclusa'),
    ]);
  });

  test('a live: competition above, teams, channel', () {
    final base = playerInfoBase(title: 'Inter – Milan', isLive: true);
    expect(base.badge, 'In diretta');
    final full = mergePlayerInfo(base,
        item: DetailsResponse(
            live: LiveDetails(
                competition: 'Serie A',
                teams: ['Inter', 'Milan'],
                channelName: 'Canale 1')));
    expect(full.overline, 'Serie A');
    expect(full.rows.first, ('Squadre', 'Inter, Milan'));
    expect(full.rows[1], ('Canale', 'Canale 1'));
  });

  test('nothing from the plugin: the base as it was', () {
    final base = playerInfoBase(title: 'X', year: 1999);
    final same = mergePlayerInfo(base);
    expect(same.facts, ['1999']);
    expect(same.rows, isEmpty);
  });
}
