/// Picks the right Continue Watching cover for episode [index] of a
/// session, used identically by TV, mobile, desktop and web instead of each
/// carrying its own copy: that episode's own thumbnail if we have one (from
/// [episodeThumbs], parallel to the episode list — see
/// `PlaybackArgs.episodeThumbs`); otherwise the series' own horizontal
/// `extra['cover_url']` [seriesCoverUrl] (vix.series/animeunity already
/// backfill a missing episode thumbnail with one of these themselves, but
/// other plugins might not); otherwise the series' vertical poster
/// [seriesPoster]; and [fallback] (whatever the caller was already showing)
/// only as a last resort — so a plugin with no per-episode thumbnails still
/// shows a horizontal-ish cover instead of a cropped vertical poster or a
/// blank card, and a plugin with none of the above still keeps whatever the
/// entry point originally had rather than going blank.
///
/// This replaces the previous behaviour of reusing the *entry point's*
/// poster (`PlaybackArgs.poster`, frozen at whichever episode the session
/// started on) for every later episode — the bug this exists to fix: the
/// Continue Watching cover used to stay stuck on the first episode's
/// thumbnail through an entire binge / auto-advance session.
String posterForEpisode({
  required List<String> episodeThumbs,
  required int index,
  String seriesCoverUrl = '',
  required String seriesPoster,
  required String fallback,
}) {
  if (index >= 0 &&
      index < episodeThumbs.length &&
      episodeThumbs[index].isNotEmpty) {
    return episodeThumbs[index];
  }
  if (seriesCoverUrl.isNotEmpty) return seriesCoverUrl;
  if (seriesPoster.isNotEmpty) return seriesPoster;
  return fallback;
}

/// Continue Watching cover for a MOVIE (or anime movie) — never the plain
/// backdrop/fanart alone. mycelium's vix.movie/vix.series plugins (1.0.3+)
/// expose `extra['cover_url']`: a horizontal TMDB image built for exactly
/// this (a title card, or a backdrop distinct from the details page's own),
/// while [fanartUrl] is the *ambient background* shown behind that details
/// page hero — reusing it for the small Continue Watching card crops into a
/// near-duplicate of that hero and rarely reads well. [posterUrl] (vertical)
/// is the last resort, for a plugin that exposes neither.
String posterForMovie({
  required String coverUrl,
  required String fanartUrl,
  required String posterUrl,
}) {
  if (coverUrl.isNotEmpty) return coverUrl;
  if (fanartUrl.isNotEmpty) return fanartUrl;
  return posterUrl;
}

/// This episode's real "S{x}"/"E{y}" number (from [numbers], parallel to the
/// episode list — see `PlaybackArgs.episodeNumbers`/`seasonNumbers`), or 0 if
/// unknown/out of range. Never the list *index* itself: that's just the
/// episode's position, which can legitimately differ from a plugin's own
/// numbering (specials, a season that doesn't start at episode 1, …).
int numberForEpisode(List<int> numbers, int index) =>
    index >= 0 && index < numbers.length ? numbers[index] : 0;

/// "S{x} · E{y}" (or just "E{y}" when the season is unknown) for a Continue
/// Watching card — empty when [episodeNumber] is 0 (a movie, or a plugin
/// that never tagged the episode), so callers can just skip rendering
/// anything rather than showing "E0". Used identically by TV, mobile and
/// desktop's CW card instead of each formatting it inline.
String episodeBadge(int seasonNumber, int episodeNumber) {
  if (episodeNumber <= 0) return '';
  return seasonNumber > 0
      ? 'S$seasonNumber · E$episodeNumber'
      : 'E$episodeNumber';
}
