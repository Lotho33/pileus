///Supported event types
enum BetterPlayerEventType {
  initialized,
  play,
  pause,
  seekTo,
  openFullscreen,
  hideFullscreen,
  setVolume,
  progress,
  finished,
  exception,
  controlsVisible,
  controlsHiddenStart,
  controlsHiddenEnd,
  setSpeed,
  changedSubtitles,
  changedTrack,
  changedPlayerVisibility,
  changedResolution,
  pipStart,
  pipStop,
  setupDataSource,
  bufferingStart,
  bufferingUpdate,
  bufferingEnd,
  changedPlaylistItem,

  /// PILEUS PATCH (Android): the picture stopped updating while playback
  /// (audio, position) keeps going, and re-attaching the surface natively
  /// did not bring it back. Parameters: position (Duration), rendered and
  /// dropped (decoder frame counters).
  videoFrozen,

  /// PILEUS PATCH (Android): periodic decoder counters, only when
  /// BetterPlayerAndroidOptions.statsIntervalMs > 0. Parameters: position
  /// (Duration), rendered, dropped, skipped (cumulative frame counts),
  /// width, height, bitrate (current video format), bufferedMs, playing.
  videoStats,
}
