import 'package:equatable/equatable.dart';

abstract class PlaybackEvent extends Equatable {
  const PlaybackEvent();
  @override
  List<Object?> get props => [];
}

class InitializeVideoEvent extends PlaybackEvent {
  final String pluginId;
  final String mediaId;
  final String preferredLabel;
  // Continue Watching resume point (seconds), 0 = from the start — carried
  // through to the SelectStreamEvent this internally dispatches once
  // GetStreams answers. See SelectStreamEvent.startPositionSec's own doc.
  final double startPositionSec;
  // See SelectStreamEvent.takeOver's own doc — carried through the same way
  // as startPositionSec, so "Riprendi qui" (mid-playback take-over, which
  // doesn't know the already-resolved stream_id the way "Guarda qui" does)
  // can just re-dispatch this like any other from-scratch retry.
  final bool takeOver;
  const InitializeVideoEvent({
    required this.pluginId,
    required this.mediaId,
    this.preferredLabel = '',
    this.startPositionSec = 0,
    this.takeOver = false,
  });
  @override
  List<Object?> get props =>
      [pluginId, mediaId, preferredLabel, startPositionSec, takeOver];
}

class SelectStreamEvent extends PlaybackEvent {
  final String pluginId;
  final String streamId;
  // ResolveRequest.start_position_sec (mycelium-core contract, "Resume from
  // Continue Watching") — 0 = from the start / not applicable (live, or no
  // resume point). Lets the server pre-warm the segments around this point
  // instead of the first ones, so the player's own start-at-position (see
  // PlayerEngine.open's startPositionSec) is served from cache instead of
  // decoding segment 0 first. Purely a server-side hint: the client still
  // has to open the player at this position itself (see resolveStartPositionSec).
  final double startPositionSec;
  // ResolveRequest.take_over (contract, "One device playing per profile") —
  // true only for the explicit "Guarda qui"/"Riprendi qui" retry after an
  // ABORTED/playback_elsewhere signal (see PlaybackPlayingElsewhere and each
  // screen's own takeover overlay): moves the profile's single-device
  // playback lease to this device instead of failing again. Never set by
  // the normal resolve path.
  final bool takeOver;
  const SelectStreamEvent({
    required this.pluginId,
    required this.streamId,
    this.startPositionSec = 0,
    this.takeOver = false,
  });
  @override
  List<Object?> get props =>
      [pluginId, streamId, startPositionSec, takeOver];
}

/// Offline-downloads playback (see PlaybackArgs.directUrl's doc) — no
/// GetStreams/ResolveStream at all, just the already-known URL for a file
/// the server prepared. Goes straight to PlaybackReady, so every screen's
/// existing BlocConsumer listener (resume-seek, skip_times parsing off
/// `extra`, engine open, …) handles it identically to a real resolve.
class UseDirectUrlEvent extends PlaybackEvent {
  final String url;
  final Map<String, String> httpHeaders;
  const UseDirectUrlEvent({required this.url, this.httpHeaders = const {}});
  @override
  List<Object?> get props => [url, httpHeaders];
}
