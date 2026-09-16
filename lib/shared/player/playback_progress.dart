import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/injection.dart';
import '../../features/media/data/media_repository.dart';
import '../../features/player/engine/player_engine.dart';
import '../../features/player/models/playback_args.dart';

/// Watch-progress bookkeeping shared by the touch (mobile) and desktop
/// players — both drive a [PlayerEngine] and take their continue-watching
/// metadata straight from [PlaybackArgs], so the three near-identical
/// helpers they each carried (`_saveProgress`, `_maybeClearProgress`,
/// `_maybeResumeSeek`) plus the remembered-audio-language logic live here
/// once.
///
/// The TV player (`features/player/presentation/playback_screen.dart`) keeps
/// its own copies: it mutates episode/season state mid-session (auto-advance)
/// and folds the end-of-title handling into `_onPosition` alongside AniSkip
/// and the next-episode countdown, so it reads from live fields rather than
/// `widget.args`. The web player uses an `HTMLVideoElement`, not a
/// [PlayerEngine], and has no resume-retry loop.
class PlaybackProgress {
  PlaybackProgress({required this.args, required this.mediaId});

  final PlaybackArgs args;
  final String mediaId;

  static const _audioLangKey = 'player.preferredAudioLang';

  // Resume seek is confirm-and-retry: a seek issued right after open() on an
  // HLS stream is often dropped (first segments / playlist not ready yet).
  bool _resumeSeekDone = false;
  bool _resumeConfirmed = false;
  int _resumeRetries = 0;
  DateTime? _resumeSeekAt;

  bool _audioPrefApplied = false;

  // Once [maybeClear] has cleared the continue-watching entry (≥95% watched,
  // or rolled forward to the next episode), every later [save] caller (15s
  // heartbeat, dispose save) must not silently recreate it.
  bool _progressCleared = false;

  /// A fresh stream URL was opened — re-arm the one-shot audio-pref apply.
  void onStreamOpened() {
    _audioPrefApplied = false;
  }

  /// Retrying the same media (bloc re-dispatch): allow the CW entry to be
  /// rewritten and the audio pref to re-apply.
  void resetForRetry() {
    _audioPrefApplied = false;
    _progressCleared = false;
  }

  /// The user explicitly picked an audio track — remember it for a later
  /// resume / next episode and stop auto-applying the stored preference this
  /// session.
  void rememberAudioTrack(String label) {
    _audioPrefApplied = true;
    getIt<SharedPreferences>().setString(_audioLangKey, label);
  }

  /// Writes a continue-watching row the instant the stream opens, even at
  /// position 0 — mycelium no longer gates Continue Watching on a minimum
  /// position, so a title should appear there as soon as it's opened rather
  /// than waiting for the first 15s heartbeat (or dispose, if the user backs
  /// out before that).
  void markStarted(PlayerEngine engine) {
    if (_progressCleared || args.isLive) return;
    final a = args;
    getIt<MediaRepository>().updateProgress(
      pluginId: a.epPluginId,
      mediaId: mediaId,
      parentId: a.parentId,
      position: engine.position,
      totalDuration: engine.duration,
      title: (a.title?.isNotEmpty ?? false) ? a.title! : a.showTitle,
      showTitle: a.showTitle,
      poster: a.poster,
      rating: a.rating,
      genres: a.genres,
      plot: a.plot,
      year: a.year,
    );
  }

  void save(PlayerEngine engine) {
    if (_progressCleared || args.isLive) return;
    final pos = engine.position;
    if (pos.inSeconds <= 0) return;
    final a = args;
    getIt<MediaRepository>().updateProgress(
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
    );
  }

  /// End-of-title continue-watching handling, mirroring the TV player: an
  /// episode ~90% in with a known next episode rolls the CW entry forward to
  /// it; a movie or last episode ~95% in is dropped so it doesn't linger at
  /// ~100% forever. With no episode list (the common mobile launch) only the
  /// 95% drop applies.
  void maybeClear(PlayerEngine engine) {
    if (_progressCleared || args.isLive) return;
    final dur = engine.duration;
    if (dur.inSeconds <= 0) return;
    final frac = engine.position.inSeconds / dur.inSeconds;
    final a = args;
    final hasSameSeasonNext =
        a.episodeIndex >= 0 && a.episodeIndex + 1 < a.episodeList.length;
    final repo = getIt<MediaRepository>();
    if (hasSameSeasonNext && frac >= 0.90) {
      _progressCleared = true;
      final nextId = a.episodeList[a.episodeIndex + 1];
      final nextTitle = a.episodeIndex + 1 < a.episodeTitles.length
          ? a.episodeTitles[a.episodeIndex + 1]
          : '';
      repo.updateProgress(
        pluginId: a.epPluginId,
        mediaId: nextId,
        parentId: a.parentId,
        position: const Duration(seconds: 31),
        title: nextTitle.isNotEmpty ? nextTitle : a.showTitle,
        showTitle: a.showTitle,
        poster: a.poster,
        rating: a.rating,
        genres: a.genres,
        plot: a.plot,
        year: a.year,
      );
      repo.deleteProgress(providerID: a.epPluginId, playableID: mediaId);
    } else if (!hasSameSeasonNext && frac >= 0.95) {
      _progressCleared = true;
      repo.deleteProgress(providerID: a.epPluginId, playableID: mediaId);
    }
  }

  void maybeResumeSeek(PlayerEngine engine) {
    final target = args.seekTo;
    if (args.isLive || target <= 2 || _resumeConfirmed) return;
    if (engine.duration <= Duration.zero) return;
    final p = engine.position.inSeconds;
    if (!_resumeSeekDone) {
      _resumeSeekDone = true;
      _resumeSeekAt = DateTime.now();
      engine.seek(Duration(seconds: target));
      return;
    }
    if (p >= target - 8) {
      _resumeConfirmed = true; // landed at/past the target
      return;
    }
    final since = _resumeSeekAt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_resumeSeekAt!);
    if (_resumeRetries < 4 &&
        since > const Duration(milliseconds: 2500) &&
        p < target - 15) {
      _resumeRetries++;
      _resumeSeekAt = DateTime.now();
      engine.seek(Duration(seconds: target));
    }
  }

  /// Once tracks are known, if the user has a remembered audio language and
  /// the auto-picked track isn't it, switch. Fixes "started in Japanese on
  /// the TV, resumed in Italian on the phone" — the engine otherwise picks
  /// audio by the device locale.
  void maybeApplyAudioPref(PlayerEngine engine) {
    if (_audioPrefApplied) return;
    final tracks = engine.audioTracks;
    if (tracks.length < 2) return;
    _audioPrefApplied = true;
    final prefs = getIt<SharedPreferences>();
    final want = prefs.getString(_audioLangKey);
    if (want == null || want.isEmpty) {
      // No sticky preference yet — anchor on whatever the engine auto-picked
      // for this first stream, so every later episode/movie keeps the same
      // language instead of drifting with each file's own track order (the
      // "anime audio language keeps flipping between episodes" report —
      // without this, only an *explicit* pick via rememberAudioTrack stuck,
      // so a run of episodes nobody ever manually touched the tracks sheet
      // on just followed each file's own default).
      final active = engine.activeAudioTrack;
      if (active != null) prefs.setString(_audioLangKey, active.label);
      return;
    }
    final w = want.toLowerCase().trim();
    // Exact label match only — the pref is a stored `t.label`, so on the
    // same stream it matches exactly. A loose `contains` picked "Slovenian"
    // for a stored "en", etc.
    MediaTrack? match;
    for (final t in tracks) {
      if (t.label.toLowerCase().trim() == w) {
        match = t;
        break;
      }
    }
    if (match != null && match.id != engine.activeAudioTrack?.id) {
      engine.selectAudioTrack(match);
    }
  }
}
