/// User-selectable playback speeds — the same steps on every player (TV,
/// mobile, desktop, web). On-demand only: on a live stream the live-sync
/// owns the rate (see live_sync.dart) and the choice is hidden.
///
/// Per player session, like the big streaming apps: it carries across the
/// episodes of one session but a new Play starts at normal speed again.
const kPlaybackSpeeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// "Normale" for 1×, otherwise e.g. "1,25×".
String playbackSpeedLabel(double speed) {
  if ((speed - 1.0).abs() < 0.001) return 'Normale';
  var s = speed.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '${s.replaceAll('.', ',')}×';
}
