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

9. Video size: `onVideoSizeChanged` → `videoSizeChanged` event → Dart
   `VideoPlayerValue.size`, and `initialized` reports the *display* size
   (pixel aspect ratio applied, swapped for 90/270° rotation) and no longer
   overwrites a known size with 0x0. Upstream reported the size once, from
   the first STATE_READY: 0x0 when the video format wasn't known yet (laid
   out as a 1x1 square), stale after an ABR switch (upstream #112/#113).
10. `better_player_with_controls.dart` `_BetterPlayerVideoFitWidget`
    rebuilds when `controller.value.size` changes (it read it only at build).

11. `video_player.dart`: native play/pause events only sync the Dart state
    (`_syncPlayingFromNative`) instead of calling play()/pause(), which sent
    the command back to native — two opposite commands close together
    echoed into an endless pause/play flicker (TV D-pad seek). `seekTo`
    re-applies the play state as it is after the seek, not the one captured
    before it (a scrub resume was being undone).
12. `BetterPlayer.kt` `checkDecoderStall`: STATE_BUFFERING with ≥8s
    buffered and no new frame for ~8s → one `decoderStalled` event per
    source (`BetterPlayerEventType.decoderStalled`, width/height/bitrate):
    a decoder that silently can't take the video (no exception).

Upgrading to 2.0.0+: patch 3 is upstream there; re-apply all the others.
Upgrading: re-copy the new upstream release here and re-apply both patches
(or drop the fork once upstream fixes 1.).
