import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/watch_next.dart';
import 'package:pileus/features/media/data/continue_watching_item.dart';

void main() {
  const episode = ContinueWatchingItem(
    providerID: 'p',
    playableID: 'ep 1/it',
    parentID: 'show',
    title: 'Pilota',
    showTitle: 'La serie',
    poster: 'https://img/x.jpg',
    progressTime: 754,
    totalTime: 2700,
    seasonNumber: 2,
    episodeNumber: 5,
  );
  const movie = ContinueWatchingItem(
    providerID: 'p',
    playableID: 'm1',
    parentID: '',
    title: 'Film',
    poster: '',
    progressTime: 60,
    totalTime: 0,
  );

  test('card payload: series first for an episode, ms positions', () {
    final [e, m] = WatchNext.payload([episode, movie]);
    expect(e['episode'], isTrue);
    expect(e['title'], 'La serie');
    expect(e['episodeTitle'], 'Pilota');
    expect(e['season'], 2);
    expect(e['positionMs'], 754000);
    expect(e['durationMs'], 2700000);
    expect(e['key'], 'p|ep 1/it');
    expect(m['episode'], isFalse);
    expect(m['title'], 'Film');
  });

  test('at most 10 cards', () {
    expect(WatchNext.payload(List.filled(15, movie)), hasLength(10));
  });

  test('deep link round trip, ids with odd characters included', () {
    final parsed = WatchNext.parseLaunch(WatchNext.uriFor(episode));
    expect(parsed?.pluginId, 'p');
    expect(parsed?.playableId, 'ep 1/it');
  });

  test('anything else is ignored', () {
    expect(WatchNext.parseLaunch(null), isNull);
    expect(WatchNext.parseLaunch('https://x/resume?plugin=p&id=1'), isNull);
    expect(WatchNext.parseLaunch('pileus://other?plugin=p&id=1'), isNull);
    expect(WatchNext.parseLaunch('pileus://resume?plugin=p'), isNull);
  });
}
