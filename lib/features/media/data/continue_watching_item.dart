class ContinueWatchingItem {
  final String providerID;
  final String playableID;
  final String parentID;
  final String title;
  final String poster;
  final double progressTime;
  final double totalTime;
  // rating/genres/plot/year: persisted server-side (watch_history columns,
  // see UpsertProgress) — come back from GetContinueWatching itself, not
  // re-fetched. durationSeconds has no server column and stays
  // local/in-session only, populated from GetDetails at play time.
  //
  // showTitle: the series name for an episode ("" for a movie). Rides in the
  // ProgressRequest.navigation_context field both ways — `title` is the thing
  // you're watching now ("Episodio 5"), showTitle is the show it belongs to,
  // rendered as a small overline on the card.
  final String showTitle;
  final String plot;
  final double rating;
  final List<String> genres;
  final int year;
  final int durationSeconds;
  // 0 for a movie/non-episodic item, or when the plugin never sent them —
  // persisted server-side same as rating/genres/plot/year (watch_history's
  // season_number/episode_number columns). The real "S{x}/E{y}" numbers,
  // never a list position.
  final int seasonNumber;
  final int episodeNumber;

  const ContinueWatchingItem({
    required this.providerID,
    required this.playableID,
    required this.parentID,
    required this.title,
    required this.poster,
    required this.progressTime,
    required this.totalTime,
    this.showTitle = '',
    this.plot = '',
    this.rating = 0.0,
    this.genres = const [],
    this.year = 0,
    this.durationSeconds = 0,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
  });

  double get progressFraction =>
      totalTime > 0 ? (progressTime / totalTime).clamp(0.0, 1.0) : 0.0;
}
