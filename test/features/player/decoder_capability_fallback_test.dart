import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/engine/decoder_capability_fallback.dart';

void main() {
  // Verbatim from the Mi TV Stick report (PlatformException wrapper included).
  const stickError = 'PlatformException(VideoError, Video player had error '
      'androidx.media3.exoplayer.ExoPlaybackException: MediaCodecVideoRenderer '
      'error, index=0, format=Format(null, null, video/mp2t, video/avc, '
      'avc1640028, 4500000, null, [1920, 1440, -1.0, null], [-1, -1]), '
      'format_supported=NO_EXCEEDS_CAPABILITIES, , null)';

  group('parseDecoderCapabilityError', () {
    test('parses size and bitrate from the Mi TV Stick error', () {
      final f = parseDecoderCapabilityError(stickError)!;
      expect(f.width, 1920);
      expect(f.height, 1440);
      expect(f.bitrate, 4500000);
      expect(f.sizeLabel, '1920×1440');
    });

    test('unknown (-1) fields become null', () {
      final f = parseDecoderCapabilityError(
          'MediaCodecVideoRenderer error, index=0, format=Format(1, null, '
          'null, video/avc, null, -1, null, [-1, -1, -1.0, null], [-1, -1]), '
          'format_supported=NO_EXCEEDS_CAPABILITIES')!;
      expect(f.width, isNull);
      expect(f.height, isNull);
      expect(f.bitrate, isNull);
      expect(f.sizeLabel, isNull);
    });

    test('bare renderer error counts only above 1088 lines', () {
      String err(int h) => 'MediaCodecVideoRenderer error, index=0, '
          'format=Format(null, null, video/mp2t, video/avc, avc1640028, '
          '4500000, null, [1920, $h, -1.0, null], [-1, -1]), '
          'format_supported=YES';
      expect(parseDecoderCapabilityError(err(1440)), isNotNull);
      expect(parseDecoderCapabilityError(err(1080)), isNull);
    });

    test('ignores unrelated errors', () {
      expect(
          parseDecoderCapabilityError(
              'Video player had error androidx.media3.exoplayer.'
              'ExoPlaybackException: Source error'),
          isNull);
    });
  });

  group('pickDecoderFallback', () {
    const failed1440 =
        FailedVideoFormat(width: 1920, height: 1440, bitrate: 4500000);

    test('prefers the highest variant at or under 1080', () {
      final variants = [
        (height: 1440, bitrate: 4500000),
        (height: 480, bitrate: 900000),
        (height: 1080, bitrate: 3000000),
        (height: 720, bitrate: 1800000),
      ];
      expect(pickDecoderFallback(variants, failed1440, {}), 2);
    });

    test('one attempt per quality, then the next one down', () {
      final variants = [
        (height: 1440, bitrate: 4500000),
        (height: 1080, bitrate: 3000000),
        (height: 720, bitrate: 1800000),
      ];
      expect(pickDecoderFallback(variants, failed1440, {1}), 2);
      expect(pickDecoderFallback(variants, failed1440, {1, 2}), isNull);
    });

    test('nothing lower than what failed → null', () {
      expect(
          pickDecoderFallback(
              [(height: 1440, bitrate: 4500000)], failed1440, {}),
          isNull);
    });

    test('skips the 0x0 auto placeholder', () {
      expect(
          pickDecoderFallback([
            (height: 0, bitrate: 0),
            (height: 1440, bitrate: 4500000),
          ], failed1440, {}),
          isNull);
    });

    test('without declared resolutions goes by bitrate', () {
      final variants = [
        (height: 0, bitrate: 4500000),
        (height: 0, bitrate: 1200000),
        (height: 0, bitrate: 2500000),
      ];
      expect(pickDecoderFallback(variants, failed1440, {}), 2);
    });

    test('when nothing fits 1080, takes the next one below the failure', () {
      const failed2160 = FailedVideoFormat(height: 2160, bitrate: 16000000);
      final variants = [
        (height: 2160, bitrate: 16000000),
        (height: 1440, bitrate: 8000000),
        (height: 1200, bitrate: 6000000),
      ];
      expect(pickDecoderFallback(variants, failed2160, {}), 1);
    });

    test('a variant that lies about its height is skipped by bitrate', () {
      // Declared "1080p" @4.5M is the stream that really is 1920x1440.
      const failed = FailedVideoFormat(height: 1440, bitrate: 4500000);
      final variants = [
        (height: 1080, bitrate: 4500000),
        (height: 720, bitrate: 2500000),
        (height: 480, bitrate: 1000000),
      ];
      expect(pickDecoderFallback(variants, failed, {}), 1);
    });
  });
}
