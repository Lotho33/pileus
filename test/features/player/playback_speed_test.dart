import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/engine/playback_speed.dart';

void main() {
  test('labels', () {
    expect(kPlaybackSpeeds.map(playbackSpeedLabel),
        ['0,5×', '0,75×', 'Normale', '1,25×', '1,5×', '2×']);
  });
}
