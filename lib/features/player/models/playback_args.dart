class PlaybackArgs {
  final bool isAudio;
  final bool isLive;
  final String? directStreamId;
  final String? title;
  final List<String> episodeList;
  final List<String> episodeTitles;
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

  const PlaybackArgs({
    required this.isAudio,
    required this.isLive,
    required this.epPluginId,
    required this.livePluginId,
    required this.liveMediaId,
    this.directStreamId,
    this.title,
    this.episodeList = const [],
    this.episodeTitles = const [],
    this.episodeIndex = -1,
    this.sourceLabel = '',
    this.allSeasonIds = const [],
    this.allSeasonLabels = const [],
    this.seasonIndex = 0,
    this.liveSources = const [],
    this.liveSourceLabels = const [],
    this.poster = '',
    this.parentId = '',
    this.seekTo = 0,
    this.showTitle = '',
    this.plot = '',
    this.rating = 0.0,
    this.durationSeconds = 0,
    this.genres = const [],
    this.year = 0,
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
      title: extra?['title'] as String?,
      episodeList: (extra?['episodeList'] as List?)?.cast<String>() ?? const [],
      episodeTitles:
          (extra?['episodeTitles'] as List?)?.cast<String>() ?? const [],
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

  /// Used by in-player "next episode" navigation (mobile) to rebuild the
  /// args around a new current episode without losing the series-level
  /// metadata (poster, parentId, showTitle, …) the launch route carried.
  PlaybackArgs copyWith({
    String? title,
    List<String>? episodeList,
    List<String>? episodeTitles,
    int? episodeIndex,
    String? sourceLabel,
    int? seasonIndex,
    int? seekTo,
    String? poster,
    String? plot,
    double? rating,
    int? durationSeconds,
    int? year,
  }) {
    return PlaybackArgs(
      isAudio: isAudio,
      isLive: isLive,
      directStreamId: directStreamId,
      epPluginId: epPluginId,
      livePluginId: livePluginId,
      liveMediaId: liveMediaId,
      title: title ?? this.title,
      episodeList: episodeList ?? this.episodeList,
      episodeTitles: episodeTitles ?? this.episodeTitles,
      episodeIndex: episodeIndex ?? this.episodeIndex,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      allSeasonIds: allSeasonIds,
      allSeasonLabels: allSeasonLabels,
      seasonIndex: seasonIndex ?? this.seasonIndex,
      liveSources: liveSources,
      liveSourceLabels: liveSourceLabels,
      poster: (poster != null && poster.isNotEmpty) ? poster : this.poster,
      parentId: parentId,
      seekTo: seekTo ?? this.seekTo,
      showTitle: showTitle,
      plot: (plot != null && plot.isNotEmpty) ? plot : this.plot,
      rating: rating ?? this.rating,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      genres: genres,
      year: year ?? this.year,
    );
  }
}
