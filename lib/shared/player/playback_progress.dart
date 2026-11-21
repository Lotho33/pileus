import '../../features/media/data/media_repository.dart';
import '../../features/player/audio_lang_pref.dart';
import '../../features/player/content_view_mode.dart';
import '../../features/player/cw_progress.dart';
import '../../features/player/engine/player_engine.dart';
import '../../features/player/episode_prefetch.dart';
import '../../features/player/models/playback_args.dart';
import '../../features/player/resume_seek.dart';

/// Watch-progress bookkeeping for the touch (mobile) and desktop players —
/// both drive a [PlayerEngine] and take their continue-watching metadata
/// straight from [PlaybackArgs]. The Continue Watching logic itself is
/// [ContinueWatchingTracker] (cw_progress.dart, engine-agnostic, shared by
/// all four players); this class feeds it [PlaybackArgs] and [PlayerEngine]
/// position/duration, and also owns the [ResumeSeekController] and the
/// remembered-audio-language logic.
///
/// ── Why every screen's 15s heartbeat still skips live streams
///
/// mycelium-core now gives each profile a 90s single-device playback lease
/// that /proxy traffic and this RPC both renew; a live stream's own segment
/// polling already renews it continuously on its own, so the heartbeat isn't
/// needed for the lease. It was considered for the case that traffic alone
/// doesn't cover (a live player paused/backgrounded long enough to starve
/// /proxy without the lease moving elsewhere), but mycelium's `UpdateProgress`
/// RPC unconditionally calls `DBManager.UpsertProgress` server-side — which
/// creates/upserts a continue-watching row — with no separate
/// position-only path for a live call the way `UpdateProgressPosition` (used
/// internally by mycelium's own RecordFetch, not exposed over this RPC) does.
/// Calling it from a live player would put a ghost "continue watching" entry
/// on the live channel/EPG entry every 15s, so every screen keeps the
/// existing `if (isLive) return` here instead. Revisit only if mycelium-core
/// grows a live-safe lease-only heartbeat RPC.
class PlaybackProgress {
  PlaybackProgress({
    required this.args,
    required this.mediaId,
    void Function(String playingOn)? onPlaybackElsewhere,
    PlaybackProgress? replacing,
    MediaRepository? repo,
  }) : _resumeSeek =
            ResumeSeekController(targetSec: args.seekTo, isLive: args.isLive) {
    _cw = ContinueWatchingTracker(
      snapshot: _snapshot,
      isLive: args.isLive,
      onPlaybackElsewhere: onPlaybackElsewhere,
      onWrite: _trackViewMode,
      repo: repo,
    );
    // Applies this title's remembered "Formato" (content_view_mode.dart)
    // before the player's first frame. [replacing]: the instance this one
    // takes over from in the same screen (retry, source/language or episode
    // switch) — the title goes on in the mode it was in.
    if (!args.isLive) {
      _viewModeToken = contentViewModes.open(
        pluginId: args.epPluginId,
        parentId: args.parentId,
        ids: [mediaId, args.directStreamId ?? ''],
        continuing: replacing?._viewModeToken,
      );
    }
  }

  Object? _viewModeToken;
  late final ContinueWatchingTracker _cw;

  /// Not final: refreshed in place when the screen learns more mid-session
  /// without starting a new stream — e.g. the episode list backfilled after
  /// a Continue Watching launch (without it, [maybeClear] never saw a "next
  /// episode" and dropped the whole series from Continue Watching instead of
  /// rolling it forward). Replacing it never touches the resume seek, which
  /// is fixed at construction.
  PlaybackArgs args;

  /// The Continue Watching playable id — the stream id once known (see
  /// PlaybackReady.streamId / source_continuity.dart), the bare media id
  /// otherwise. Not final for the same reason as [args]: the stream id often
  /// only becomes known once the resolve lands.
  String mediaId;

  final ResumeSeekController _resumeSeek;

  late final AudioLangPref _audioPref =
      AudioLangPref(() => (pluginId: args.epPluginId, seriesId: args.parentId));

  CwSnapshot _snapshot() {
    final a = args;
    return CwSnapshot(
      pluginId: a.epPluginId,
      cwId: mediaId,
      parentId: a.parentId,
      title: a.title ?? '',
      showTitle: a.showTitle,
      poster: a.poster,
      rating: a.rating,
      genres: a.genres,
      plot: a.plot,
      year: a.year,
      episodeList: a.episodeList,
      episodeIndex: a.episodeIndex,
      episodeTitles: a.episodeTitles,
      episodeThumbs: a.episodeThumbs,
      seasonNumbers: a.seasonNumbers,
      episodeNumbers: a.episodeNumbers,
      knownSeasonIds: a.allSeasonIds,
      sourceLabel: a.sourceLabel,
      seriesPoster: a.seriesPoster,
      seriesCoverUrl: a.seriesCoverUrl,
      fallbackPoster: a.poster,
    );
  }

  /// A fresh stream URL was opened — re-arm the one-shot audio-pref apply.
  void onStreamOpened() {
    _audioPref.reset();
  }

  /// Retrying the same media (bloc re-dispatch): allow the CW entry to be
  /// rewritten and the audio pref to re-apply. Also re-arms
  /// onPlaybackElsewhere — covers "Riprendi qui" reusing this same
  /// instance (see each screen's own take-over handling): this device can
  /// legitimately lose the lease again later in the same session.
  void resetForRetry() {
    _audioPref.reset();
    _cw.resetForRetry();
  }

  /// The user explicitly picked an audio track — remember it for a later
  /// resume / next episode and stop auto-applying the stored preference this
  /// session.
  void rememberAudioTrack(String label) => _audioPref.remember(label);

  /// Writes the continue-watching row the instant the stream opens (see
  /// [ContinueWatchingTracker.markStarted]) — at the resume *target*, not
  /// `engine.position`, which still reads ~0 while the resume seek is in
  /// flight.
  Future<void> markStarted(PlayerEngine engine) {
    final target = Duration(seconds: _resumeSeek.targetSec);
    return _cw.markStarted(
      position: engine.position > target ? engine.position : target,
      duration: engine.duration,
    );
  }

  Future<void> save(PlayerEngine engine) =>
      _cw.save(position: engine.position, duration: engine.duration);

  /// The ids Continue Watching is about to store (the stream id once known,
  /// the series id once backfilled) — so the remembered "Formato" still
  /// recognises this title when it's reopened from Continue Watching.
  void _trackViewMode() {
    final t = _viewModeToken;
    if (t != null) {
      contentViewModes.track(t, parentId: args.parentId, ids: [mediaId]);
    }
  }

  /// The player screen is going away (call after its final [save]): later
  /// format changes no longer belong to this title. No-op on an instance a
  /// newer one already replaced.
  void close() {
    final t = _viewModeToken;
    if (t != null) contentViewModes.close(t);
  }

  /// End-of-title continue-watching handling — see
  /// [ContinueWatchingTracker.maybeClear].
  void maybeClear(PlayerEngine engine, {PrefetchedEpisode? prefetched}) {
    _cw.maybeClear(
      position: engine.position,
      duration: engine.duration,
      prefetched: prefetched,
    );
  }

  /// What to pass as this title's own [PlayerEngine.open] call — see
  /// [ResumeSeekController.pendingStartPosition]. A fresh [PlaybackProgress]
  /// (and so a fresh [ResumeSeekController]) is constructed per episode/
  /// retry by both mobile and desktop, so this is already correctly scoped:
  /// null for an episode switch (`args.seekTo` is 0 there), the resume target
  /// only for the title this instance was actually built for.
  Duration? get pendingStartPosition => _resumeSeek.pendingStartPosition;

  /// Whether the resume-until-confirmed cover (see each screen's own
  /// "resuming…" overlay) can be lifted — mirrors [ResumeSeekController.
  /// isDone]. Read this only after [maybeResumeSeek] has run for the current
  /// tick, so a landed/confirmed seek is reflected the same tick it happens.
  bool get isResumeDone => _resumeSeek.isDone;

  void maybeResumeSeek(PlayerEngine engine) {
    if (_resumeSeek.isDone) return;
    if (engine.duration <= Duration.zero) return;
    _resumeSeek.onPosition(engine.position, engine.seek);
  }

  /// See [AudioLangPref.pick] (shared with the TV player).
  void maybeApplyAudioPref(PlayerEngine engine) {
    final t = _audioPref.pick(engine.audioTracks, engine.activeAudioTrack);
    if (t != null) engine.selectAudioTrack(t);
  }
}
