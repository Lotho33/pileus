import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/stream_warmer.dart';

void main() {
  const delay = Duration(milliseconds: 40);
  // Comfortably past [delay] plus the async target.
  Future<void> settle() => Future<void>.delayed(delay * 3);

  late List<String> warmed;
  late Set<String> blocked;
  late StreamWarmer warmer;

  setUp(() {
    warmed = [];
    blocked = {};
    warmer = StreamWarmer(
      warm: (p, s) => warmed.add('$p/$s'),
      canWarm: (p) => !blocked.contains(p),
      delay: delay,
    );
  });

  test('warms only once the dwell delay has passed', () async {
    warmer.schedule('movies', () async => '1:it');
    await Future<void>.delayed(delay ~/ 2);
    expect(warmed, isEmpty);
    await settle();
    expect(warmed, ['movies/1:it']);
  });

  test('leaving before the delay sends nothing — and never runs the target',
      () async {
    var targetRuns = 0;
    final t = warmer.schedule('movies', () async {
      targetRuns++;
      return '1:it';
    });
    await Future<void>.delayed(delay ~/ 2);
    t.cancel();
    await settle();
    expect(warmed, isEmpty);
    expect(targetRuns, 0);
  });

  test('leaving while the target is still being worked out sends nothing',
      () async {
    final lookup = Completer<String?>();
    final t = warmer.schedule('series', () => lookup.future);
    await settle(); // delay passed, target awaiting
    t.cancel();
    lookup.complete('9_1_1:it');
    await settle();
    expect(warmed, isEmpty);
  });

  test('one warm per plugin + stream id per session', () async {
    warmer.schedule('movies', () async => '1:it');
    warmer.schedule('movies', () async => '1:it');
    await settle();
    warmer.schedule('movies', () async => '1:it'); // reopened later
    warmer.schedule('movies', () async => '1:en'); // other language
    warmer.schedule('anime', () async => '1:it'); // other plugin
    await settle();
    expect(warmed, ['movies/1:it', 'movies/1:en', 'anime/1:it']);
  });

  test('a cancelled schedule does not use up the stream id', () async {
    warmer.schedule('movies', () async => '1:it').cancel();
    await settle();
    warmer.schedule('movies', () async => '1:it');
    await settle();
    expect(warmed, ['movies/1:it']);
  });

  test('a plugin the server will not warm is skipped up front', () async {
    blocked.add('sport');
    var targetRuns = 0;
    warmer.schedule('sport', () async {
      targetRuns++;
      return 'x';
    });
    await settle();
    expect(warmed, isEmpty);
    expect(targetRuns, 0);
  });

  test('server turning a plugin off during the delay still stops it', () async {
    warmer.schedule('movies', () async => '1:it');
    blocked.add('movies');
    await settle();
    expect(warmed, isEmpty);
  });

  test('no stream id, an empty one or a failing lookup: nothing', () async {
    warmer.schedule('a', () async => null);
    warmer.schedule('b', () async => '');
    warmer.schedule('c', () async => throw StateError('GetStreams failed'));
    await settle();
    expect(warmed, isEmpty);
  });
}
