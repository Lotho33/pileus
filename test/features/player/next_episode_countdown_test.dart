import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/models/skip_interval.dart';
import 'package:pileus/features/player/next_episode_countdown.dart';

void main() {
  const dur = Duration(minutes: 24);
  const ed = SkipInterval(type: SkipType.ed, start: 1300, end: 1390);
  const op = SkipInterval(type: SkipType.op, start: 60, end: 150);

  NextEpisodeTick at(double secs,
          {List<SkipInterval> skips = const [ed, op],
          bool dismissed = false}) =>
      nextEpisodeTick(
        position: Duration(milliseconds: (secs * 1000).round()),
        duration: dur,
        skips: skips,
        dismissed: dismissed,
      );

  test('hidden mid-episode and during the opening', () {
    expect(at(600).bannerSecs, isNull);
    expect(at(100).bannerSecs, isNull);
    expect(at(100).advance, isFalse);
  });

  test('ending counts down 20 s of playback, then advances', () {
    expect(at(1300).bannerSecs, 20);
    expect(at(1305.5).bannerSecs, 15);
    expect(at(1319.2).bannerSecs, 1);
    expect(at(1319.2).advance, isFalse);
    expect(at(1320).advance, isTrue);
  });

  test('closing the banner keeps the ending playing', () {
    expect(at(1310, dismissed: true).bannerSecs, isNull);
    expect(at(1330, dismissed: true).advance, isFalse);
  });

  test('ending shorter than the countdown: plays on after it', () {
    const short = SkipInterval(type: SkipType.ed, start: 1300, end: 1310);
    expect(at(1305, skips: [short]).bannerSecs, 15);
    expect(at(1312, skips: [short]).bannerSecs, isNull);
    expect(at(1312, skips: [short]).advance, isFalse);
  });

  test('last 30 s of the file without markers', () {
    expect(at(1409, skips: []).bannerSecs, isNull);
    expect(at(1410, skips: []).bannerSecs, 30);
    expect(at(1439, skips: []).bannerSecs, 1);
    expect(at(1440, skips: []).advance, isTrue);
  });

  test('end of file advances even after closing the banner', () {
    expect(at(1430, skips: [], dismissed: true).bannerSecs, isNull);
    expect(at(1440, skips: [], dismissed: true).advance, isTrue);
  });

  test('ending near the end of the file: the shorter countdown wins', () {
    const late = SkipInterval(type: SkipType.ed, start: 1425, end: 1440);
    expect(at(1426, skips: [late]).bannerSecs, 14);
    const early = SkipInterval(type: SkipType.ed, start: 1415, end: 1440);
    expect(at(1416, skips: [early]).bannerSecs, 19);
  });
}
