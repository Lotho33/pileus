import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/clients/media_client.dart';
import 'package:pileus/features/media/episode_kind.dart';

String plain(TextSpan s) => s.toPlainText();

void main() {
  test('labels from extra.filler', () {
    expect(episodeKindLabel('filler'), 'Filler');
    expect(episodeKindLabel(' Recap '), 'Riassunto');
    expect(episodeKindLabel(''), '');
    expect(episodeKindLabel(null), '');
    expect(episodeKindLabel('canon'), '');
  });

  test('meta line places the kind and skips empty parts', () {
    expect(plain(episodeMetaSpan(['24 min', 'Trama'], kind: 'Filler')),
        '24 min  ·  Filler  ·  Trama');
    expect(plain(episodeMetaSpan(['', 'Trama'], kind: 'Filler', kindAt: 0)),
        'Filler  ·  Trama');
    expect(plain(episodeMetaSpan(['Ep. 3'], kind: 'Riassunto', kindAt: 9)),
        'Ep. 3  ·  Riassunto');
    expect(plain(episodeMetaSpan(['24 min'])), '24 min');
    final kindSpan = (episodeMetaSpan(['24 min'], kind: 'Filler').children!)
        .whereType<TextSpan>()
        .firstWhere((s) => s.text == 'Filler');
    expect(kindSpan.style?.color, kEpisodeKindColor);
  });

  test('browse answers feed the player lookup, per plugin', () {
    rememberEpisodeKinds(
        'au',
        BrowseResponse(episodes: [
          EpisodeInfo(id: 'ep:1', extra: {'filler': 'filler'}.entries),
          EpisodeInfo(id: 'ep:2'),
          EpisodeInfo(id: 'ep:3', extra: {'filler': 'recap'}.entries),
        ]));
    expect(episodeKindOf('au', 'ep:1'), 'Filler');
    expect(episodeKindOf('au', 'ep:2'), '');
    expect(episodeKindOf('au', 'ep:3'), 'Riassunto');
    expect(episodeKindOf('other', 'ep:1'), '');

    // A later answer that no longer flags it wins.
    rememberEpisodeKinds(
        'au', BrowseResponse(episodes: [EpisodeInfo(id: 'ep:1')]));
    expect(episodeKindOf('au', 'ep:1'), '');
  });
}
