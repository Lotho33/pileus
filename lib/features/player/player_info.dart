import '../../core/grpc/clients/media_client.dart' show DetailsResponse;
import '../media/data/media_repository.dart';
import 'models/playback_args.dart';
import 'episode_poster.dart' show numberForEpisode;

/// What the player's info panel (the (i) button / remote Info key) shows
/// about the title playing: the answer to "what year is this from?" without
/// leaving the player. Built at once from what the player already knows
/// ([playerInfoBase]) and completed from the plugin's details
/// ([loadPlayerInfo]): cast, directors, the episode's own plot…
class PlayerInfo {
  /// Big line: the film, the episode's title, or the live event.
  final String title;

  /// Above the title: the series' name for an episode, the competition for
  /// a live event. Empty otherwise.
  final String overline;

  /// "S2 · E5" for an episode, "In diretta" for a live. Empty otherwise.
  final String badge;

  /// Year, duration, rating, age rating… in display order.
  final List<String> facts;
  final List<String> genres;
  final String plot;

  /// Label → value ("Regia", "Cast", "Canale"…), only those known.
  final List<(String, String)> rows;

  const PlayerInfo({
    required this.title,
    this.overline = '',
    this.badge = '',
    this.facts = const [],
    this.genres = const [],
    this.plot = '',
    this.rows = const [],
  });

  PlayerInfo copyWith({
    String? title,
    String? overline,
    String? badge,
    List<String>? facts,
    List<String>? genres,
    String? plot,
    List<(String, String)>? rows,
  }) =>
      PlayerInfo(
        title: title ?? this.title,
        overline: overline ?? this.overline,
        badge: badge ?? this.badge,
        facts: facts ?? this.facts,
        genres: genres ?? this.genres,
        plot: plot ?? this.plot,
        rows: rows ?? this.rows,
      );
}

/// "1 h 52 min" / "24 min".
String formatRuntime(int minutes) {
  if (minutes <= 0) return '';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "★ 7.8".
String formatRating(double r) => r > 0 ? '★ ${r.toStringAsFixed(1)}' : '';

/// The panel from what the player knows already — no network.
PlayerInfo playerInfoBase({
  required String title,
  String showTitle = '',
  int seasonNumber = 0,
  int episodeNumber = 0,
  int year = 0,
  double rating = 0,
  int durationSeconds = 0,
  List<String> genres = const [],
  String plot = '',
  bool isLive = false,
}) {
  final isEpisode = showTitle.isNotEmpty && showTitle != title;
  final badge = isLive
      ? 'In diretta'
      : episodeNumber > 0
          ? (seasonNumber > 0
              ? 'S$seasonNumber · E$episodeNumber'
              : 'Episodio $episodeNumber')
          : '';
  return PlayerInfo(
    title: title.isNotEmpty ? title : showTitle,
    overline: isEpisode ? showTitle : '',
    badge: badge,
    facts: [
      if (year > 0) '$year',
      if (!isLive && durationSeconds >= 60)
        formatRuntime((durationSeconds / 60).round()),
      if (rating > 0) formatRating(rating),
    ],
    genres: genres,
    plot: plot.trim(),
  );
}

/// [playerInfoBase] from a player's current launch arguments (mobile and
/// desktop keep them current across episodes).
PlayerInfo playerInfoFromArgs(PlaybackArgs a) => playerInfoBase(
      title: a.title ?? '',
      showTitle: a.showTitle,
      seasonNumber: numberForEpisode(a.seasonNumbers, a.episodeIndex),
      episodeNumber: numberForEpisode(a.episodeNumbers, a.episodeIndex),
      year: a.year,
      rating: a.rating,
      durationSeconds: a.durationSeconds,
      genres: a.genres,
      plot: a.plot,
      isLive: a.isLive,
    );

/// [base] completed from the plugin's details of [itemId] (the film, the
/// episode or the live event) and, for an episode, of its series
/// [seriesId]. Whatever fails to load is simply left out.
Future<PlayerInfo> loadPlayerInfo(
  MediaRepository repo,
  PlayerInfo base, {
  required String pluginId,
  required String itemId,
  String seriesId = '',
}) async {
  DetailsResponse? item;
  DetailsResponse? series;
  try {
    if (itemId.isNotEmpty) item = await repo.getDetails(pluginId, itemId);
  } catch (_) {}
  try {
    if (seriesId.isNotEmpty && seriesId != itemId) {
      series = await repo.getDetails(pluginId, seriesId);
    }
  } catch (_) {}
  return mergePlayerInfo(base, item: item, series: series);
}

/// Pure: [base] with what [item] / [series] add (for tests).
PlayerInfo mergePlayerInfo(PlayerInfo base,
    {DetailsResponse? item, DetailsResponse? series}) {
  final facts = [...base.facts];
  var genres = base.genres;
  var plot = base.plot;
  var title = base.title;
  var overline = base.overline;
  final rows = <(String, String)>[...base.rows];

  void fact(String f) {
    if (f.isNotEmpty && !facts.contains(f)) facts.add(f);
  }

  void row(String label, String value) {
    if (value.trim().isNotEmpty) rows.add((label, value.trim()));
  }

  String list(List<String> v, [int max = 8]) =>
      v.where((e) => e.trim().isNotEmpty).take(max).join(', ');

  bool hasYear() => facts.any((f) => RegExp(r'^\d{4}$').hasMatch(f));

  if (item != null && item.hasMovie()) {
    final m = item.movie;
    if (!hasYear() && m.year > 0) facts.insert(0, '${m.year}');
    if (!facts.any((f) => f.contains('min') || f.endsWith(' h'))) {
      fact(m.runtime);
    }
    fact(m.contentRating);
    if (genres.isEmpty) genres = m.genres;
    if (m.plot.trim().isNotEmpty) plot = m.plot.trim();
    if (m.tagline.trim().isNotEmpty) row('Slogan', m.tagline);
    row('Regia', list(m.directors, 4));
    row('Cast', list(m.cast));
    row('Uscita', _date(m.released));
  }
  if (item != null && item.hasEpisode()) {
    final e = item.episode;
    // The episode's own plot beats the series' one the player carries.
    if (e.plot.trim().isNotEmpty) plot = e.plot.trim();
    if (!facts.any((f) => f.contains('min') || f.endsWith(' h'))) {
      fact(formatRuntime(e.duration));
    }
    if (e.vote > 0 && !facts.any((f) => f.startsWith('★'))) {
      fact(formatRating(e.vote));
    }
    row('Regia', list(e.directors, 4));
    row('Ospiti', list(e.guestStars));
    row('In onda', _date(e.airDate));
  }
  if (item != null && item.hasLive()) {
    final l = item.live;
    if (l.competition.isNotEmpty) overline = l.competition;
    if (l.teams.length >= 2 && title.isEmpty) title = l.teams.join(' – ');
    row('Squadre', list(l.teams, 4));
    row('Canale', l.channelName);
    row('Inizio', _dateTime(l.streamStart));
    row('Fine', _dateTime(l.streamEnd));
    if (l.isReplay) fact('Replica');
  }
  if (series != null && series.hasSeries()) {
    final s = series.series;
    if (!hasYear() && s.year > 0) facts.insert(0, '${s.year}');
    fact(s.contentRating);
    if (genres.isEmpty) genres = s.genres;
    if (plot.isEmpty && s.plot.trim().isNotEmpty) plot = s.plot.trim();
    row('Ideata da', list(s.creators, 4));
    row('Cast', list(s.cast));
    row('Rete', s.network);
    row('Stato', _status(s.status));
  }
  // One row per label: the first (most specific) wins.
  final seen = <String>{};
  return base.copyWith(
    title: title,
    overline: overline,
    facts: facts,
    genres: genres,
    plot: plot,
    rows: [
      for (final r in rows)
        if (seen.add(r.$1)) r
    ],
  );
}

const _months = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', //
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

/// ISO date → "12 marzo 2021"; as is when it doesn't parse.
String _date(String iso) {
  final d = DateTime.tryParse(iso.trim());
  if (d == null) return iso.trim();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// ISO datetime → "12 marzo 2021, 20:45" in local time.
String _dateTime(String iso) {
  final d = DateTime.tryParse(iso.trim())?.toLocal();
  if (d == null) return iso.trim();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $hh:$mm';
}

String _status(String s) => switch (s.toLowerCase()) {
      'ended' || 'finished' => 'Conclusa',
      'continuing' || 'releasing' || 'returning series' => 'In corso',
      'canceled' || 'cancelled' => 'Cancellata',
      _ => s,
    };
