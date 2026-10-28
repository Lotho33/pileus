import 'dart:math' as math;

import 'models/skip_interval.dart';
import 'player_tuning.dart';

/// What the "prossimo episodio" countdown should do at one position tick.
class NextEpisodeTick {
  /// Seconds shown on the banner, or null to hide it.
  final int? bannerSecs;

  /// Time to move on to the next episode.
  final bool advance;

  const NextEpisodeTick({this.bannerSecs, this.advance = false});
}

/// The next-episode countdown, shared by the four playback screens. Two
/// things start it:
///  - the ending (an `ed` skip marker): a [kOutroCountdownSec] countdown from
///    the moment the credits begin, measured in playback time so pausing
///    pauses it too. It only runs inside the marker — an ending shorter than
///    the countdown just plays on (a post-credits scene stays watchable);
///  - the last [kNextEpisodeBannerWindowSec] of the file, as before.
/// When both apply, the shorter one is shown.
///
/// [dismissed]: the user closed the banner for this episode — it stays
/// hidden and the ending no longer advances, but the end of the file still
/// does (the screen has nothing else left to play).
///
/// The caller checks there IS a next episode and that the duration is long
/// enough (kMinDurationForEndOfEpisodeLogicSec) before asking.
NextEpisodeTick nextEpisodeTick({
  required Duration position,
  required Duration duration,
  required List<SkipInterval> skips,
  bool dismissed = false,
}) {
  final remaining = duration.inSeconds - position.inSeconds;
  if (remaining <= 0) return const NextEpisodeTick(advance: true);

  int? outroLeft;
  final active = activeSkipInterval(skips, position);
  if (active != null && active.type == SkipType.ed) {
    final elapsed = position.inMilliseconds / 1000.0 - active.start;
    outroLeft = math.max(0, (kOutroCountdownSec - elapsed).ceil());
  }
  if (outroLeft == 0 && !dismissed) {
    return const NextEpisodeTick(advance: true);
  }
  if (dismissed) return const NextEpisodeTick();

  final candidates = [
    if (remaining <= kNextEpisodeBannerWindowSec) remaining,
    if (outroLeft != null) outroLeft,
  ];
  return NextEpisodeTick(
      bannerSecs: candidates.isEmpty ? null : candidates.reduce(math.min));
}
