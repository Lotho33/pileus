/// Single source of truth for the timing/threshold constants shared by all
/// four playback screens (TV, mobile, desktop, web).
///
/// Extracted after these had quietly drifted
/// per-platform — each screen kept its own hand-copied literal, and nothing
/// enforced they stayed equal:
///   - the error-grace window was 8s on TV, 6s everywhere else, and web had
///     none at all (a plain playback error showed the blocking "Riprova"
///     overlay immediately instead of tolerating a transient blip);
///   - the next-episode prefetch threshold/timeouts were duplicated
///     verbatim between mobile and desktop, with TV and web missing the
///     feature entirely;
///   - the continue-watching roll-forward/drop fractions (0.90/0.95) and the
///     30s "prossimo episodio" banner window were each copied by hand into
///     every screen that reimplements PlaybackProgress's logic locally (TV,
///     web) instead of coming from one place.
///
/// Retuning any of these again should only ever mean editing this file —
/// never chasing four copies to keep them in sync by hand.
library;

// ignore_for_file: constant_identifier_names

/// How far through the current episode (position/duration) to start warming
/// the next one's stream in the background — see EpisodePrefetcher.
const kPrefetchThreshold = 0.80;

/// Below this remaining episode length, prefetch/CW-close/next-episode-
/// banner logic all stay off — too short for any of it to be worth doing
/// (a post-credits stinger, an OP/ED-only "episode", etc).
const kMinDurationForEndOfEpisodeLogicSec = 60;

const kPrefetchGetStreamsTimeout = Duration(seconds: 20);
const kPrefetchResolveTimeout = Duration(seconds: 25);
const kPrefetchGetDetailsTimeout = Duration(seconds: 8);

/// Fraction of the way into an episode (position/duration) that rolls the
/// continue-watching entry forward to the next one, when there IS a same-
/// season next episode.
const kCwRollForwardThreshold = 0.90;

/// Fraction of the way into a movie/last-episode-of-a-season that drops its
/// continue-watching entry instead of leaving it stuck at ~100% forever.
const kCwDropThreshold = 0.95;

/// How many seconds before an episode's end the "prossimo episodio"
/// countdown/banner appears (and, once it hits zero, auto-advances).
const kNextEpisodeBannerWindowSec = 30;

/// Once a plain playback error fires, how long to hold it before actually
/// surfacing the blocking "Riprova" overlay. Many are transient (one failed
/// segment/manifest fetch that then retries successfully) — something that
/// recovers inside this window (the engine starts playing again, or the
/// position genuinely advances) never shows anything to the user at all.
const kErrorGraceDuration = Duration(seconds: 6);

/// Below this remembered resume position, don't bother seeking at all —
/// starting from ~0 anyway.
const kResumeSeekMinTargetSec = 2;

/// Give up resuming automatically after this many retries (the user can
/// still seek by hand) — see ResumeSeekController.
const kResumeSeekMaxRetries = 4;

/// Minimum gap between resume-seek retries.
const kResumeSeekRetryGap = Duration(milliseconds: 2500);

/// Landed at/past target minus this many seconds counts as "confirmed" —
/// backends don't always land exactly on the requested second.
const kResumeSeekLandedToleranceSec = 8;

/// Still more than this many seconds short of the target counts as "the
/// seek was dropped" and is worth retrying (between this and the landed
/// tolerance above, it's close enough that retrying isn't worth the risk of
/// visibly jumping the position around).
const kResumeSeekGiveUpToleranceSec = 15;

/// How long the "resuming…" cover (poster/black + spinner, kept up so the
/// pre-resume frame is never visible — see ResumeSeekController) stays on
/// screen waiting for the resume seek to land before giving up and revealing
/// the video anyway. Deliberately shorter than the full resume-seek give-up
/// window (kResumeSeekMaxRetries × kResumeSeekRetryGap, ~10s) — this is only
/// about not leaving the user staring at a frozen cover; the retry loop
/// keeps trying underneath even after it elapses.
const kResumeCoverSafetyTimeout = Duration(seconds: 5);

/// TV only (contract "One device playing per profile"): how long the app
/// has to stay backgrounded before this device gives up its single-device
/// playback lease (MediaRepository.releasePlayback) — see
/// _PlaybackViewState._onAppLifecycle. Shorter than the lease's own passive
/// ~90s lapse (so switching devices on purpose doesn't wait that long), but
/// long enough that a brief trip to the launcher/input switch doesn't give
/// up a lease the user still wants this device to hold.
const kBackgroundReleaseTimeout = Duration(seconds: 60);
