import 'package:flutter/widgets.dart';

/// How the picture fills the screen — the player settings' "Formato video".
enum VideoViewMode {
  /// Whole picture visible, black bars where the proportions differ.
  fit('Adatta'),

  /// Fills the screen keeping proportions, cropping what overflows.
  zoom('Riempi (zoom)'),

  /// Fills the screen, distorting the proportions.
  stretch('Allunga'),

  /// Shown as 16:9 / 4:3 whatever the stream says (wrongly flagged or
  /// anamorphic sources), fitted inside the screen.
  ratio16x9('16:9'),
  ratio4x3('4:3');

  final String label;
  const VideoViewMode(this.label);

  /// Forced display aspect ratio, null when the video's own one is used.
  double? get forcedAspect => switch (this) {
        VideoViewMode.ratio16x9 => 16 / 9,
        VideoViewMode.ratio4x3 => 4 / 3,
        _ => null,
      };

  static VideoViewMode fromName(String? name) => VideoViewMode.values
      .firstWhere((m) => m.name == name, orElse: () => VideoViewMode.fit);
}

/// The current mode, shared by every player screen and engine — so it
/// survives episode changes and player rebuilds. Persisted per device by
/// [bindVideoViewModeSetting].
final videoViewMode = ValueNotifier<VideoViewMode>(VideoViewMode.fit);

/// Loads the stored mode and saves every later change.
void bindVideoViewModeSetting({
  required String? stored,
  required void Function(String name) save,
}) {
  videoViewMode.value = VideoViewMode.fromName(stored);
  videoViewMode.addListener(() => save(videoViewMode.value.name));
}

/// The largest box with [aspect] that fits inside [area], centred by the
/// caller — used for the forced-ratio modes.
Size containAspect(Size area, double aspect) {
  if (area.width <= 0 || area.height <= 0 || aspect <= 0) return area;
  final areaAspect = area.width / area.height;
  return aspect > areaAspect
      ? Size(area.width, area.width / aspect)
      : Size(area.height * aspect, area.height);
}
