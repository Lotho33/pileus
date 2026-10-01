import 'player_tuning.dart';

/// What to send as ResolveRequest.start_position_sec / InitializeVideoEvent/
/// SelectStreamEvent.startPositionSec — the mycelium-core contract's own
/// threshold ("Resume from Continue Watching"): 0 (not sent — the field's
/// own zero value) for a live stream or a resume point too small to bother
/// warming server-side, otherwise the resume point itself. Same
/// [kResumeSeekMinTargetSec] threshold ResumeSeekController already gates
/// on, so the server only ever warms a point the client will actually try
/// to open at.
double resolveStartPositionSec({required bool isLive, required int seekTo}) =>
    (!isLive && seekTo > kResumeSeekMinTargetSec) ? seekTo.toDouble() : 0;

/// Same threshold as [resolveStartPositionSec], as a [Duration] for
/// [PlayerEngine.open]'s own startPosition parameter — null (not 0) when
/// there's nothing to open at, since callers use this straight as an
/// optional argument.
Duration? resumeStartPosition({required bool isLive, required int seekTo}) {
  final sec = resolveStartPositionSec(isLive: isLive, seekTo: seekTo);
  return sec > 0 ? Duration(seconds: sec.round()) : null;
}

/// "Resume playback at a remembered position" — confirm-and-retry, not a
/// single fire-and-forget seek: a seek issued right after a stream opens is
/// sometimes dropped (the HLS playlist/first segments aren't ready yet, or
/// the backend's own playlist is still being generated), which is why
/// "continue watching sometimes starts from the beginning" happened. Every
/// position tick after the first seek checks whether it actually landed and
/// re-seeks a few times if not, then gives up (the user can still seek by
/// hand).
///
/// Backend-agnostic on purpose — it only ever calls the `seek` callback the
/// caller passes in, never touches a [PlayerEngine]/`<video>` element/etc
/// itself — so every platform screen can share the exact same algorithm and
/// constants regardless of what's actually playing the stream. Extracted
/// from what was duplicated near-verbatim between
/// PlaybackProgress.maybeResumeSeek (mobile/desktop, PlayerEngine-based) and
/// the TV player's own private copy (presentation/playback_screen/view.dart)
/// — both already used the exact same constants, just copied by hand — and
/// missing entirely on web, which had no resume-retry loop at all.
class ResumeSeekController {
  final int targetSec;
  final bool isLive;
  // Overridable only for tests (retry timing is otherwise real wall-clock
  // DateTime.now(), same reasoning as LiveStallWatchdog's own configurable
  // Durations) — every real call site relies on the default.
  final Duration _retryGap;

  ResumeSeekController({
    required this.targetSec,
    required this.isLive,
    Duration retryGap = kResumeSeekRetryGap,
  }) : _retryGap = retryGap;

  bool _seekIssued = false;
  bool _confirmed = false;
  int _retries = 0;
  DateTime? _lastSeekAt;

  /// True once there's nothing left for [onPosition] to do — either there
  /// was never a resume target worth seeking to, or it's been confirmed
  /// landed. Callers typically use this to skip calling [onPosition] at all
  /// once it flips (not required for correctness, [onPosition] is a no-op
  /// either way, just avoids the position-tick busywork).
  bool get isDone => isLive || targetSec <= kResumeSeekMinTargetSec || _confirmed;

  /// What to pass as [PlayerEngine.open]'s own startPosition — null exactly
  /// when there's nothing worth opening at (mirrors [isDone] at the point
  /// it's checked here: always before the first [onPosition] call, so
  /// [_confirmed] is still false and this reduces to "live, or no real
  /// resume target"). A caller only ever needs this once, right before its
  /// open() call for whichever title this instance was constructed for.
  Duration? get pendingStartPosition =>
      isDone ? null : Duration(seconds: targetSec);

  /// Call on every position tick once a stream is open. On the very first
  /// call, checks whether the engine already opened at (or near) the target
  /// itself — see PlayerEngine.open's startPositionSec / the ExoPlayer/
  /// hls.js equivalents — and only falls back to issuing a seek here if it
  /// didn't; a blind seek at this point would otherwise be its own visible
  /// hiccup on top of a start-position that already worked. Every later
  /// call either confirms a still-pending seek landed or retries it, up to
  /// [kResumeSeekMaxRetries] times. This is the safety net now, not the
  /// primary mechanism — the normal case never issues a seek at all.
  void onPosition(Duration pos, void Function(Duration target) seek) {
    if (isDone) return;
    if (!_seekIssued) {
      _seekIssued = true;
      final p = pos.inSeconds;
      if (p >= targetSec - kResumeSeekLandedToleranceSec) {
        _confirmed = true; // the engine already opened at/near the target
        return;
      }
      _lastSeekAt = DateTime.now();
      seek(Duration(seconds: targetSec));
      return;
    }
    final p = pos.inSeconds;
    if (p >= targetSec - kResumeSeekLandedToleranceSec) {
      _confirmed = true; // landed at/past the target — done
      return;
    }
    // Still stuck well before the target a while after the last seek
    // attempt: it was dropped (common right after open on HLS). Retry, a
    // few times, then give up.
    final since = _lastSeekAt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_lastSeekAt!);
    if (_retries < kResumeSeekMaxRetries &&
        since > _retryGap &&
        p < targetSec - kResumeSeekGiveUpToleranceSec) {
      _retries++;
      _lastSeekAt = DateTime.now();
      seek(Duration(seconds: targetSec));
    }
  }
}
