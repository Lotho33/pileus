/// PILEUS PATCH: per-device Android rendering/decoding options, read when a
/// native player is created (the `create` call), so a change applies to the
/// next player, not one already playing. Ignored on iOS.
class BetterPlayerAndroidOptions {
  BetterPlayerAndroidOptions._();

  /// Software video decoders first; the hardware ones stay as fallback.
  static bool preferSoftwareVideoDecoder = false;

  /// Render into a GL SurfaceTexture (better_player_plus ≤1.4.1) instead of
  /// a SurfaceProducer (upstream 2.0.0).
  static bool legacySurfaceTexture = false;

  /// Highest video height ABR may pick (0 = no cap). Kept when the track
  /// selection goes back to "auto"; an explicitly chosen track still wins.
  static int maxVideoHeight = 0;

  /// Period of the `videoStats` event (decoder counters), 0 = off.
  static int statsIntervalMs = 0;

  static Map<String, dynamic> toMap() => <String, dynamic>{
    'preferSoftwareVideoDecoder': preferSoftwareVideoDecoder,
    'legacySurfaceTexture': legacySurfaceTexture,
    'maxVideoHeight': maxVideoHeight,
    'statsIntervalMs': statsIntervalMs,
  };
}
