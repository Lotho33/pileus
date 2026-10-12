import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/engine/video_view_mode.dart';

void main() {
  test('containAspect fits a forced ratio inside the screen', () {
    // 20:9 phone, 16:9 forced → full height, pillarboxed.
    final phone = containAspect(const Size(2400, 1080), 16 / 9);
    expect(phone.height, 1080);
    expect(phone.width, closeTo(1920, 0.5));
    // 16:9 TV, 4:3 forced → full height.
    final tv = containAspect(const Size(1920, 1080), 4 / 3);
    expect(tv.height, 1080);
    expect(tv.width, closeTo(1440, 0.5));
    // Portrait area, 16:9 → full width, letterboxed.
    final portrait = containAspect(const Size(1080, 2400), 16 / 9);
    expect(portrait.width, 1080);
    expect(portrait.height, closeTo(607.5, 0.5));
  });

  test('fromName falls back to fit on anything unknown', () {
    expect(VideoViewMode.fromName('zoom'), VideoViewMode.zoom);
    expect(VideoViewMode.fromName(null), VideoViewMode.fit);
    expect(VideoViewMode.fromName('nope'), VideoViewMode.fit);
  });

  test('only the ratio modes force an aspect', () {
    expect(VideoViewMode.ratio16x9.forcedAspect, 16 / 9);
    expect(VideoViewMode.ratio4x3.forcedAspect, 4 / 3);
    expect(VideoViewMode.fit.forcedAspect, isNull);
    expect(VideoViewMode.zoom.forcedAspect, isNull);
    expect(VideoViewMode.stretch.forcedAspect, isNull);
  });
}
