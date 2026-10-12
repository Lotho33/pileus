import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/engine/stream_format.dart';
import 'package:pileus/features/player/models/playback_args.dart';

void main() {
  group('StreamFormat.fromContainer', () {
    test('a download container means progressive', () {
      expect(StreamFormat.fromContainer('mkv'), StreamFormat.progressive);
      expect(StreamFormat.fromContainer(' MP4 '), StreamFormat.progressive);
    });

    test('hls / m3u8 stay HLS', () {
      expect(StreamFormat.fromContainer('m3u8'), StreamFormat.hls);
      expect(StreamFormat.fromContainer('HLS'), StreamFormat.hls);
    });

    test('unknown (older server) falls back to guessing from the URL', () {
      expect(StreamFormat.fromContainer(''), StreamFormat.auto);
      expect(StreamFormat.fromContainer(null), StreamFormat.auto);
    });
  });

  group('PlaybackArgs.directUrlFormat', () {
    PlaybackArgs args(Map<String, dynamic> extra) =>
        PlaybackArgs.fromExtra(extra, pluginId: 'p', mediaId: 'm');

    test('download extra → progressive, even with an extension-less URL', () {
      final a = args({
        'directUrl': 'https://srv/downloads/file?sig=x',
        'directUrlContainer': 'mkv',
      });
      expect(a.directUrlFormat, StreamFormat.progressive);
    });

    test('survives copyWith (episode/retry paths rebuild the args)', () {
      final a = args({
        'directUrl': 'https://srv/downloads/file.mkv?sig=x',
        'directUrlContainer': 'mkv',
      }).copyWith(seekTo: 120);
      expect(a.directUrlFormat, StreamFormat.progressive);
      expect(a.seekTo, 120);
    });

    test('no container → auto', () {
      expect(args({'directUrl': 'https://srv/x'}).directUrlFormat,
          StreamFormat.auto);
    });
  });
}
