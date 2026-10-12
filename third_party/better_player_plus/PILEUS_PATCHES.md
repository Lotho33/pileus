# better_player_plus 1.4.1 — Pileus fork

Vendored from pub.dev `better_player_plus` 1.4.1 (`example/` and `test/`
dropped) and wired in through `dependency_overrides` in the app's
`pubspec.yaml`. Every change is marked `PILEUS PATCH` in the source, except
the verbatim upstream backport (3):

1. `android/.../BetterPlayer.kt` — play/pause events sent to Dart come from
   `onPlayWhenReadyChanged` instead of `onIsPlayingChanged`. Since 1.3.5
   every rebuffer/seek (isPlaying → false while STATE_BUFFERING) was sent as
   "pause", and Dart's `VideoPlayerController` answers that by calling
   `pause()` natively: playback stayed paused once the buffer refilled.
   Still present upstream in 2.0.0 (checked 2026-10-12), not reported there.
2. `android/.../DataSourceUtils.kt` — HTTP read timeout 20s instead of
   Media3's 8s default (the mycelium proxy sends nothing until it has the
   whole segment from the CDN, which can take ~20s).

3. Upstream PR #138 (released in 2.0.0) backported: video rendered into a
   `SurfaceProducer` instead of a `SurfaceTexture` (no GL→Vulkan interop
   and fence wait per frame under Impeller; surface re-attached when the
   engine recreates it), plus `rotationCorrection`. New
   `android/.../VideoOutput.kt` keeps the old SurfaceTexture path
   selectable.
4. `BetterPlayerAndroidOptions` (Dart, sent with `create`; more in 7–8):
   `legacySurfaceTexture` (path above) and `preferSoftwareVideoDecoder`
   (custom MediaCodecSelector: software video decoders first, hardware as
   fallback).
5. Frozen-picture watchdog in `BetterPlayer.kt` (`checkVideoFrozen`):
   playing + position advancing + no new rendered frame for ~6s → re-attach
   the surface; still frozen 6s later → `videoFrozen` event to Dart
   (`BetterPlayerEventType.videoFrozen`, `VideoEventType.videoFrozen`).

6. `onPlayerError`: `ERROR_CODE_BEHIND_LIVE_WINDOW` (live stream fell behind
   the playlist window, typically after a network dip) → back to the live
   edge (`seekToDefaultPosition()` + `prepare()`) instead of a fatal error;
   at most 3 times a minute, then it is reported as usual.
7. `BetterPlayerAndroidOptions.maxVideoHeight`: height cap set on the track
   selector at creation and re-applied whenever the selection goes back to
   "auto" (`setTrackParameters(0, 0, 0)`).
8. `BetterPlayerAndroidOptions.statsIntervalMs`: periodic `videoStats` event
   (decoder rendered/dropped/skipped counters, current format, buffer).

Upgrading to 2.0.0+: patch 3 is upstream there; re-apply all the others.
Upgrading: re-copy the new upstream release here and re-apply both patches
(or drop the fork once upstream fixes 1.).
