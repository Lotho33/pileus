/// Picks the right Continue Watching cover for episode [index] of a
/// session, used identically by TV, mobile, desktop and web instead of each
/// carrying its own copy: that episode's own thumbnail if we have one (from
/// [episodeThumbs], parallel to the episode list — see
/// `PlaybackArgs.episodeThumbs`), the series' own poster otherwise, and
/// [fallback] (whatever the caller was already showing) only as a last
/// resort — so a plugin with no per-episode thumbnails still shows the
/// series poster instead of a blank card, and a plugin with neither still
/// keeps whatever the entry point originally had rather than going blank.
///
/// This replaces the previous behaviour of reusing the *entry point's*
/// poster (`PlaybackArgs.poster`, frozen at whichever episode the session
/// started on) for every later episode — the bug this exists to fix: the
/// Continue Watching cover used to stay stuck on the first episode's
/// thumbnail through an entire binge / auto-advance session.
String posterForEpisode({
  required List<String> episodeThumbs,
  required int index,
  required String seriesPoster,
  required String fallback,
}) {
  if (index >= 0 &&
      index < episodeThumbs.length &&
      episodeThumbs[index].isNotEmpty) {
    return episodeThumbs[index];
  }
  if (seriesPoster.isNotEmpty) return seriesPoster;
  return fallback;
}
