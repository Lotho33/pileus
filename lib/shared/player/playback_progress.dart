import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' show ProgressResponse;
import '../../features/media/data/media_repository.dart';
import '../../features/player/audio_lang_pref.dart';
import '../../features/player/engine/player_engine.dart';
import '../../features/player/episode_poster.dart';
import '../../features/player/episode_prefetch.dart';
import '../../features/player/models/playback_args.dart';
import '../../features/player/player_tuning.dart';
import '../../features/player/resume_seek.dart';
import '../../features/player/source_continuity.dart';

/// Watch-progress bookkeeping shared by the touch (mobile) and desktop
/// players — both drive a [PlayerEngine] and take their continue-watching
/// metadata straight from [PlaybackArgs], so the near-identical helpers they
/// each carried (`_saveProgress`, `_maybeClearProgress`) plus the
/// remembered-audio-language logic live here once. The resume-seek retry
/// loop itself is [ResumeSeekController] (engine-agnostic, shared by all
/// four platform screens); this class just owns one and feeds it
/// [PlayerEngine] position/seek calls.
///
/// The TV player (`features/player/presentation/playback_screen.dart`) and
/// the web player (an `HTMLVideoElement`, not a [PlayerEngine]) keep their
/// own copies of the save/clear logic: TV mutates episode/season state mid-
/// session (auto-advance) and folds the end-of-title handling into
/// `_onPosition` alongside skip markers and the next-episode countdown, so it
/// reads from live fields rather than `widget.args`; web has no
/// [PlayerEngine] to hand this class at all. Both use the same
/// [kCwRollForwardThreshold]/[kCwDropThreshold] constants this class does,
/// and the same [ResumeSeekController].
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
    this.onPlaybackElsewhere,
  }) : _resumeSeek =
            ResumeSeekController(targetSec: args.seekTo, isLive: args.isLive);

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

  /// Fired (at most once per instance) the moment a [save]/[markStarted]
  /// call's own UpdateProgress reveals this device no longer holds the
  /// profile's single-device playback lease (contract "One device playing
  /// per profile") — [playingOn] is the other device's display name, empty
  /// if the server didn't have one. The screen must pause/stop the engine
  /// and show the "moved elsewhere" prompt (take-over on demand only, never
  /// retried automatically here).
  final void Function(String playingOn)? onPlaybackElsewhere;

  final ResumeSeekController _resumeSeek;

  final AudioLangPref _audioPref = AudioLangPref();
  bool _elsewhereReported = false;

  // Once [maybeClear] has cleared the continue-watching entry (≥95% watched,
  // or rolled forward to the next episode), every later [save] caller (15s
  // heartbeat, dispose save) must not silently recreate it.
  bool _progressCleared = false;

  /// A fresh stream URL was opened — re-arm the one-shot audio-pref apply.
  void onStreamOpened() {
    _audioPref.reset();
  }

  /// Retrying the same media (bloc re-dispatch): allow the CW entry to be
  /// rewritten and the audio pref to re-apply. Also re-arms
  /// [onPlaybackElsewhere] — covers "Riprendi qui" reusing this same
  /// instance (see each screen's own take-over handling): this device can
  /// legitimately lose the lease again later in the same session.
  void resetForRetry() {
    _audioPref.reset();
    _progressCleared = false;
    _elsewhereReported = false;
  }

  /// The user explicitly picked an audio track — remember it for a later
  /// resume / next episode and stop auto-applying the stored preference this
  /// session.
  void rememberAudioTrack(String label) => _audioPref.remember(label);

  /// Writes a continue-watching row the instant the stream opens, even at
  /// position 0 — mycelium no longer gates Continue Watching on a minimum
  /// position, so a title should appear there as soon as it's opened rather
  /// than waiting for the first 15s heartbeat (or dispose, if the user backs
  /// out before that).
  ///
  /// Reports the resume *target*, not `engine.position`: this runs right
  /// after open(), while the engine still reads ~0 and the resume seek is in
  /// flight — sending that 0 zeroed the Continue Watching entry whenever the
  /// user backed out before the first heartbeat (the dispose save skips a 0
  /// position). Same fix the TV player's _markOpened already carries.
  Future<void> markStarted(PlayerEngine engine) async {
    if (_progressCleared || args.isLive) return;
    final a = args;
    final target = Duration(seconds: _resumeSeek.targetSec);
    final resp = await getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: mediaId,
      parentId: a.parentId,
      position: engine.position > target ? engine.position : target,
      totalDuration: engine.duration,
      title: (a.title?.isNotEmpty ?? false) ? a.title! : a.showTitle,
      showTitle: a.showTitle,
      poster: a.poster,
      rating: a.rating,
      genres: a.genres,
      plot: a.plot,
      year: a.year,
      seasonNumber: numberForEpisode(a.seasonNumbers, a.episodeIndex),
      episodeNumber: numberForEpisode(a.episodeNumbers, a.episodeIndex),
    );
    _checkElsewhere(resp);
  }

  Future<void> save(PlayerEngine engine) async {
    if (_progressCleared || args.isLive) return;
    final pos = engine.position;
    if (pos.inSeconds <= 0) return;
    final a = args;
    final resp = await getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: mediaId,
      parentId: a.parentId,
      position: pos,
      totalDuration: engine.duration,
      title: (a.title?.isNotEmpty ?? false) ? a.title! : a.showTitle,
      showTitle: a.showTitle,
      poster: a.poster,
      rating: a.rating,
      genres: a.genres,
      plot: a.plot,
      year: a.year,
      seasonNumber: numberForEpisode(a.seasonNumbers, a.episodeIndex),
      episodeNumber: numberForEpisode(a.episodeNumbers, a.episodeIndex),
    );
    _checkElsewhere(resp);
  }

  void _checkElsewhere(ProgressResponse? resp) {
    if (_elsewhereReported || resp == null) return;
    if (resp.playbackElsewhere) {
      _elsewhereReported = true;
      onPlaybackElsewhere?.call(resp.playingOn);
    }
  }

  /// End-of-title continue-watching handling, mirroring the TV player: an
  /// episode ~90% in with a known next episode rolls the CW entry forward to
  /// it; a movie or last episode ~95% in is dropped so it doesn't linger at
  /// ~100% forever. With no episode list (yet) only the 95% drop applies.
  ///
  /// The roll-forward row stores the next episode's *stream id* for the
  /// source playing now ([prefetched] when it already covers it) — see
  /// source_continuity.dart: a bare episode id would resume in the plugin's
  /// default language.
  void maybeClear(PlayerEngine engine, {PrefetchedEpisode? prefetched}) {
    if (_progressCleared || args.isLive) return;
    final dur = engine.duration;
    if (dur.inSeconds <= 0) return;
    final frac = engine.position.inSeconds / dur.inSeconds;
    final a = args;
    final hasSameSeasonNext =
        a.episodeIndex >= 0 && a.episodeIndex + 1 < a.episodeList.length;
    final repo = getIt<MediaRepository>();
    if (hasSameSeasonNext && frac >= kCwRollForwardThreshold) {
      _progressCleared = true;
      final nextId = a.episodeList[a.episodeIndex + 1];
      final nextTitle = a.episodeIndex + 1 < a.episodeTitles.length
          ? a.episodeTitles[a.episodeIndex + 1]
          : '';
      final currentId = mediaId;
      _rollForward(repo, a, nextId, nextTitle, currentId, prefetched);
    } else if (!hasSameSeasonNext && frac >= kCwDropThreshold) {
      _progressCleared = true;
      repo.deleteProgress(providerID: a.epPluginId, playableID: mediaId);
    }
  }

  Future<void> _rollForward(
    MediaRepository repo,
    PlaybackArgs a,
    String nextId,
    String nextTitle,
    String currentId,
    PrefetchedEpisode? prefetched,
  ) async {
    final nextStreamId = await streamIdForNextEpisode(
      repo,
      pluginId: a.epPluginId,
      nextEpisodeId: nextId,
      sourceLabel: a.sourceLabel,
      prefetched: prefetched,
    );
    try {
      await repo.updateProgress(
        pluginId: a.epPluginId,
        mediaId: nextStreamId,
        parentId: a.parentId,
        position: const Duration(seconds: 31),
        title: nextTitle.isNotEmpty ? nextTitle : a.showTitle,
        showTitle: a.showTitle,
        // The *next* episode's own thumbnail, not the one currently
        // playing's — see episode_poster.dart's doc comment for the bug
        // this replaces (the cover used to stay stuck on whichever episode
        // the session started on).
        poster: posterForEpisode(
          episodeThumbs: a.episodeThumbs,
          index: a.episodeIndex + 1,
          seriesCoverUrl: a.seriesCoverUrl,
          seriesPoster: a.seriesPoster,
          fallback: a.poster,
        ),
        rating: a.rating,
        genres: a.genres,
        // Always the series' own synopsis, never an episode's — see
        // PlaybackArgs.copyWith's doc comment on why `plot` has no
        // per-episode override at all.
        plot: a.plot,
        year: a.year,
        seasonNumber: numberForEpisode(a.seasonNumbers, a.episodeIndex + 1),
        episodeNumber: numberForEpisode(a.episodeNumbers, a.episodeIndex + 1),
      );
    } catch (_) {}
    repo.deleteProgress(providerID: a.epPluginId, playableID: currentId);
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

  /// See [AudioLangPref.maybeApply] (shared with the TV player).
  void maybeApplyAudioPref(PlayerEngine engine) => _audioPref.maybeApply(engine);
}
