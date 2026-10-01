/// Formats a playback [Duration] as `h:mm:ss`, or `mm:ss` under an hour —
/// shared by the seek bar and the overlay's time labels (was duplicated
/// character-for-character in both).
String formatPlaybackDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
