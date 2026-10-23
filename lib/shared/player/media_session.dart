import 'media_session_io.dart'
    if (dart.library.js_interop) 'media_session_web.dart' as impl;

/// What's playing, for the system's own media controls — the Media Session
/// API on web, Tizen and webOS (browser/OS media keys, the TV remote's
/// media buttons, the lock-screen/notification controls of a phone's
/// browser). A no-op on native builds, where the players' own engines own
/// that integration.
///
/// One per player screen: [update] when the title changes, [setPlaying] on
/// play/pause, [clear] on dispose. Handlers left null are not offered.
class PlayerMediaSession {
  void update({
    required String title,
    String subtitle = '',
    String artworkUrl = '',
    void Function()? onPlay,
    void Function()? onPause,
    void Function(int seconds)? onSeekBy,
    void Function()? onNext,
    void Function()? onPrevious,
  }) =>
      impl.update(
        title: title,
        subtitle: subtitle,
        artworkUrl: artworkUrl,
        onPlay: onPlay,
        onPause: onPause,
        onSeekBy: onSeekBy,
        onNext: onNext,
        onPrevious: onPrevious,
      );

  void setPlaying(bool playing) => impl.setPlaying(playing);

  void clear() => impl.clear();
}
