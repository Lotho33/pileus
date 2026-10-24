import 'package:flutter/foundation.dart';

/// One selectable playback track (audio language, subtitle language, video
/// quality). Backend-agnostic: [raw] holds the native handle the concrete
/// engine needs to actually switch to it.
@immutable
class MediaTrack {
  final String id;
  final String label;

  /// The "no subtitles" pseudo-track. Only ever set on subtitle entries.
  final bool isOff;
  final Object? raw;

  const MediaTrack({
    required this.id,
    required this.label,
    this.isOff = false,
    this.raw,
  });

  @override
  bool operator ==(Object other) =>
      other is MediaTrack && other.id == id && other.isOff == isOff;

  @override
  int get hashCode => Object.hash(id, isOff);
}
