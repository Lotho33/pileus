import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/generated/media.pb.dart';

/// Guards the hand-edited protobuf Dart for EpisodeInfo.extra (media.proto
/// field 12, `map<string, string>`) — protoc-gen-dart isn't re-run for it
/// (see lib/core/grpc/generated/README.md), so a wrong tag or map index
/// would silently drop what the server sends.
void main() {
  // What the server writes for extra {"lang": "jap"}: field 12, wire type 2
  // (0x62), then one map entry {1: "lang", 2: "jap"}.
  final wire = <int>[
    0x62, 11, //
    0x0a, 4, ...utf8.encode('lang'),
    0x12, 3, ...utf8.encode('jap'),
  ];

  test('reads extra from the server bytes', () {
    final ep = EpisodeInfo.fromBuffer(wire);
    expect(ep.extra, {'lang': 'jap'});
    expect(ep.id, isEmpty);
  });

  test('writes the same bytes and survives a round-trip', () {
    final ep = EpisodeInfo(extra: {'lang': 'jap'}.entries);
    expect(ep.writeToBuffer(), wire);

    final full = EpisodeInfo(
        id: 'e1',
        episodeNumber: 3,
        parentId: 'p',
        extra: {'lang': 'ita'}.entries);
    final back = EpisodeInfo.fromBuffer(full.writeToBuffer());
    expect(back.id, 'e1');
    expect(back.episodeNumber, 3);
    expect(back.parentId, 'p');
    expect(back.extra['lang'], 'ita');
  });

  test('an older server (no field 12) reads back empty', () {
    final ep = EpisodeInfo.fromBuffer(EpisodeInfo(id: 'e1').writeToBuffer());
    expect(ep.extra, isEmpty);
  });
}
