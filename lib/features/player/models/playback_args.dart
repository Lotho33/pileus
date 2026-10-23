import '../engine/stream_format.dart';

class PlaybackArgs {
  final bool isAudio;
  final bool isLive;
  final String? directStreamId;
  // Offline-downloads playback (mycelium-contract "Offline downloads"): when
  // set, the player opens this URL directly and skips GetStreams/
  // ResolveStream entirely — see PlaybackBloc's UseDirectUrlEvent. epPluginId/
  // the launch mediaId still carry the ORIGINAL plugin/media ids (not a
  // synthetic download id), so UpdateProgress/Continue Watching work exactly
  // as for a live stream, unchanged (contract: "l'avanzamento... funziona
  // come per le stream, con plugin_id/media_id del download"). Always paired
  // with isLive=false (a download is never live) and directStreamId=null
  // (mutually exclusive resolve shortcuts).
  final String? directUrl;
  final Map<String, String> directUrlHeaders;
  // DownloadInfo.container of the file behind [directUrl] ("mkv"…), empty
  // when unknown. Tells the player it is a progressive file instead of
  // guessing from the URL — see [directUrlFormat].
  final String directUrlContainer;

  /// How to open [directUrl] — explicit from the download's container, not
  /// inferred from the URL (a download link with no extension used to be
  /// opened as HLS and fail).
  StreamFormat get directUrlFormat =>
      StreamFormat.fromContainer(directUrlContainer);
  final String? title;
  final List<String> episodeList;
  final List<String> episodeTitles;
  // Parallel to episodeList/episodeTitles, one entry per episode (empty
  // string where the plugin doesn't have one) — the per-episode thumbnail,
  // read from Browse's EpisodeInfo.thumbnailUrl. Lets the player show the
  // *current* episode's own cover in Continue Watching instead of whichever
  // episode's thumbnail the session happened to launch with (see `poster`
  // below and episode_poster.dart's posterForEpisode()).
  final List<String> episodeThumbs;
  // Parallel to episodeList — the real "S{x} · E{y}" numbers (not the list
  // *index*, which is just position and can differ from a plugin's own
  // numbering, e.g. specials). 0 means "unknown". Read from Browse's
  // EpisodeInfo.episodeNumber/seasonNumber, same source as episodeThumbs —
  // lets Continue Watching show the season/episode without a client-side
  // re-fetch (see MediaRepository.updateProgress).
  final List<int> episodeNumbers;
  final List<int> seasonNumbers;
  final int episodeIndex;
  final String epPluginId;
  final String sourceLabel;
  final List<String> allSeasonIds;
  final List<String> allSeasonLabels;
  final int seasonIndex;
  final List<String> liveSources;
  final List<String> liveSourceLabels;
  final String livePluginId;
  final String liveMediaId;
  final String poster;
  // The series' own poster (not a specific episode's thumbnail) — the last
  // resort in posterForEpisode() when neither a fresh per-episode thumbnail
  // nor the entry-point `poster` above is available. Immutable for the whole
  // session, same as showTitle/plot below.
  final String seriesPoster;
  // The series' own horizontal `extra['cover_url']` (a plugin-provided
  // field) — tried in posterForEpisode() *before* seriesPoster (vertical)
  // when an episode has no thumbnail of its own. Same immutability as
  // seriesPoster.
  final String seriesCoverUrl;
  final String parentId;
  final int seekTo;
  // Threaded through to MediaRepository.postProgress so continue-watching
  // entries carry richer metadata than just title/poster — see
  // episode_detail_screen.dart's _play() for where these are populated.
  final String showTitle;
  final String plot;
  final double rating;
  final int durationSeconds;
  final List<String> genres;
  final int year;
  // "Disponibile solo in inglese" — set by resolveAndPlay when the source it
  // picked isn't the profile's preferred language (source_preference.dart);
  // shown while the player loads.
  final String languageNotice;

  const PlaybackArgs({
    required this.isAudio,
    required this.isLive,
    required this.epPluginId,
    required this.livePluginId,
    required this.liveMediaId,
    this.directStreamId,
    this.directUrl,
    this.directUrlHeaders = const {},
    this.directUrlContainer = '',
    this.title,
    this.episodeList = const [],
    this.episodeTitles = const [],
    this.episodeThumbs = const [],
    this.episodeNumbers = const [],
    this.seasonNumbers = const [],
    this.episodeIndex = -1,
    this.sourceLabel = '',
    this.allSeasonIds = const [],
    this.allSeasonLabels = const [],
    this.seasonIndex = 0,
    this.liveSources = const [],
    this.liveSourceLabels = const [],
    this.poster = '',
    this.seriesPoster = '',
    this.seriesCoverUrl = '',
    this.parentId = '',
    this.seekTo = 0,
    this.showTitle = '',
    this.plot = '',
    this.rating = 0.0,
    this.durationSeconds = 0,
    this.genres = const [],
    this.year = 0,
    this.languageNotice = '',
  });

  factory PlaybackArgs.fromExtra(
    Map<String, dynamic>? extra, {
    required String pluginId,
    required String mediaId,
  }) {
    return PlaybackArgs(
      isAudio: extra?['mediaType'] == 'music',
      isLive: extra?['isLive'] as bool? ?? false,
      directStreamId: extra?['streamId'] as String?,
      directUrl: extra?['directUrl'] as String?,
      directUrlHeaders:
          (extra?['directUrlHeaders'] as Map?)?.cast<String, String>() ??
              const {},
      directUrlContainer: extra?['directUrlContainer'] as String? ?? '',
      title: extra?['title'] as String?,
      languageNotice: extra?['languageNotice'] as String? ?? '',
      episodeList: (extra?['episodeList'] as List?)?.cast<String>() ?? const [],
      episodeTitles:
          (extra?['episodeTitles'] as List?)?.cast<String>() ?? const [],
      episodeThumbs:
          (extra?['episodeThumbs'] as List?)?.cast<String>() ?? const [],
      episodeNumbers:
          (extra?['episodeNumbers'] as List?)?.cast<int>() ?? const [],
      seasonNumbers:
          (extra?['seasonNumbers'] as List?)?.cast<int>() ?? const [],
      episodeIndex: extra?['episodeIndex'] as int? ?? -1,
      epPluginId: extra?['pluginId'] as String? ?? pluginId,
      sourceLabel: extra?['sourceLabel'] as String? ?? '',
      allSeasonIds:
          (extra?['allSeasonIds'] as List?)?.cast<String>() ?? const [],
      allSeasonLabels:
          (extra?['allSeasonLabels'] as List?)?.cast<String>() ?? const [],
      seasonIndex: extra?['seasonIndex'] as int? ?? 0,
      liveSources: (extra?['liveSources'] as List?)?.cast<String>() ?? const [],
      liveSourceLabels:
          (extra?['liveSourceLabels'] as List?)?.cast<String>() ?? const [],
      livePluginId: extra?['livePluginId'] as String? ?? pluginId,
      liveMediaId: extra?['liveMediaId'] as String? ?? mediaId,
      poster: extra?['poster'] as String? ?? '',
      seriesPoster: extra?['seriesPoster'] as String? ?? '',
      seriesCoverUrl: extra?['seriesCoverUrl'] as String? ?? '',
      parentId: extra?['parentId'] as String? ?? '',
      seekTo: (extra?['seekTo'] as num?)?.toInt() ?? 0,
      showTitle: extra?['showTitle'] as String? ?? '',
      plot: extra?['plot'] as String? ?? '',
      rating: (extra?['rating'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (extra?['durationSeconds'] as num?)?.toInt() ?? 0,
      genres: (extra?['genres'] as List?)?.cast<String>() ?? const [],
      year: (extra?['year'] as num?)?.toInt() ?? 0,
    );
  }

  /// Used by in-player "next episode" navigation (mobile/desktop/web) to
  /// rebuild the args around a new current episode without losing the
  /// series-level metadata (seriesPoster, parentId, showTitle, plot, …) the
  /// launch route carried.
  ///
  /// [plot] is deliberately NOT a parameter here: Continue Watching always
  /// shows the *series'* synopsis, never a specific episode's — see
  /// episode_poster.dart's doc comment for the poster equivalent
  /// (posterForEpisode) of the same "one clear source, no fallback chain"
  /// call. A caller that used to pass a per-episode plot through here was
  /// the bug, not a feature to preserve.
  /// Series-level metadata backfilled by the player when the launch route
  /// didn't carry it (search/direct-play of an episode, an older Continue
  /// Watching row) — same lookup the TV player does in
  /// _resolveSeriesMetaIfMissing. [plot] here is the *series'* synopsis (see
  /// [copyWith]'s doc on why a per-episode plot never goes through args).
  /// Empty/zero values keep the current one.
  PlaybackArgs withSeriesMeta({
    String parentId = '',
    String showTitle = '',
    String plot = '',
    List<String> genres = const [],
    double rating = 0,
    int year = 0,
  }) {
    final base = copyWith(
      rating: this.rating > 0 || rating <= 0 ? null : rating,
      year: this.year > 0 || year <= 0 ? null : year,
    );
    return PlaybackArgs(
      isAudio: base.isAudio,
      isLive: base.isLive,
      directStreamId: base.directStreamId,
      directUrl: base.directUrl,
      directUrlHeaders: base.directUrlHeaders,
      directUrlContainer: base.directUrlContainer,
      epPluginId: base.epPluginId,
      livePluginId: base.livePluginId,
      liveMediaId: base.liveMediaId,
      title: base.title,
      episodeList: base.episodeList,
      episodeTitles: base.episodeTitles,
      episodeThumbs: base.episodeThumbs,
      episodeNumbers: base.episodeNumbers,
      seasonNumbers: base.seasonNumbers,
      episodeIndex: base.episodeIndex,
      sourceLabel: base.sourceLabel,
      allSeasonIds: base.allSeasonIds,
      allSeasonLabels: base.allSeasonLabels,
      seasonIndex: base.seasonIndex,
      liveSources: base.liveSources,
      liveSourceLabels: base.liveSourceLabels,
      poster: base.poster,
      seriesPoster: base.seriesPoster,
      seriesCoverUrl: base.seriesCoverUrl,
      parentId: base.parentId.isNotEmpty ? base.parentId : parentId,
      seekTo: base.seekTo,
      showTitle: base.showTitle.isNotEmpty ? base.showTitle : showTitle,
      plot: base.plot.isNotEmpty ? base.plot : plot,
      rating: base.rating,
      durationSeconds: base.durationSeconds,
      genres: base.genres.isNotEmpty ? base.genres : genres,
      year: base.year,
      languageNotice: base.languageNotice,
    );
  }

  PlaybackArgs copyWith({
    String? title,
    List<String>? episodeList,
    List<String>? episodeTitles,
    List<String>? episodeThumbs,
    List<int>? episodeNumbers,
    List<int>? seasonNumbers,
    int? episodeIndex,
    String? sourceLabel,
    int? seasonIndex,
    int? seekTo,
    String? poster,
    double? rating,
    int? durationSeconds,
    int? year,
  }) {
    return PlaybackArgs(
      isAudio: isAudio,
      isLive: isLive,
      directStreamId: directStreamId,
      directUrl: directUrl,
      directUrlHeaders: directUrlHeaders,
      directUrlContainer: directUrlContainer,
      epPluginId: epPluginId,
      livePluginId: livePluginId,
      liveMediaId: liveMediaId,
      title: title ?? this.title,
      episodeList: episodeList ?? this.episodeList,
      episodeTitles: episodeTitles ?? this.episodeTitles,
      episodeThumbs: episodeThumbs ?? this.episodeThumbs,
      episodeNumbers: episodeNumbers ?? this.episodeNumbers,
      seasonNumbers: seasonNumbers ?? this.seasonNumbers,
      episodeIndex: episodeIndex ?? this.episodeIndex,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      allSeasonIds: allSeasonIds,
      allSeasonLabels: allSeasonLabels,
      seasonIndex: seasonIndex ?? this.seasonIndex,
      liveSources: liveSources,
      liveSourceLabels: liveSourceLabels,
      poster: (poster != null && poster.isNotEmpty) ? poster : this.poster,
      seriesPoster: seriesPoster,
      seriesCoverUrl: seriesCoverUrl,
      parentId: parentId,
      seekTo: seekTo ?? this.seekTo,
      showTitle: showTitle,
      plot: plot,
      rating: rating ?? this.rating,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      genres: genres,
      year: year ?? this.year,
      languageNotice: languageNotice,
    );
  }
}
