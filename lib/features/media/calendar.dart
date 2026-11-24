import '../../core/grpc/generated/media.pb.dart'
    show CalendarEntry, CatalogItem;
import '../player/episode_poster.dart' show episodeBadge;

/// The release calendar (mycelium's GetCalendar): what comes out in the next
/// days, from every plugin that has one, in one list — like La mia lista,
/// not per plugin; the screen filters by plugin on what came back.

/// How many days the screen asks for (today included; the server allows 31).
const kCalendarDays = 14;

/// One day of the calendar, in the device's time zone.
class CalendarDay {
  final DateTime day; // local midnight
  final List<CalendarEntry> entries;
  const CalendarDay(this.day, this.entries);
}

/// When [e] comes out, on the device's clock. An all-day release keeps its
/// own date (converting its midnight could move it to the day before).
DateTime? calendarReleaseTime(CalendarEntry e) {
  final raw = e.releaseAt.trim();
  if (raw.isEmpty) return null;
  if (e.allDay) {
    final d = DateTime.tryParse(raw.length >= 10 ? raw.substring(0, 10) : raw);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }
  return DateTime.tryParse(raw)?.toLocal();
}

/// [entries] by local day, in the server's order (by release time) within
/// each; entries without a readable date are left out.
List<CalendarDay> groupCalendar(Iterable<CalendarEntry> entries) {
  final days = <DateTime, List<CalendarEntry>>{};
  for (final e in entries) {
    final t = calendarReleaseTime(e);
    if (t == null) continue;
    days.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(e);
  }
  final keys = days.keys.toList()..sort();
  return [for (final k in keys) CalendarDay(k, days[k]!)];
}

const _weekdays = [
  'lunedì',
  'martedì',
  'mercoledì',
  'giovedì',
  'venerdì',
  'sabato',
  'domenica',
];
const _months = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

/// "Oggi", "Domani", else "giovedì 27 novembre".
String calendarDayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Oggi';
  if (diff == 1) return 'Domani';
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// "21:00", or '' when only the date is known.
String calendarTimeLabel(CalendarEntry e) {
  if (e.allDay) return '';
  final t = calendarReleaseTime(e);
  if (t == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

/// The series' name for an episode, when the plugin sends it
/// (`extra.series_title`); '' otherwise.
String calendarSeriesTitle(CalendarEntry e) =>
    (e.item.extra['series_title'] ?? '').trim();

/// The big line of a row: the series for an episode when known, else the
/// title itself.
String calendarTitle(CalendarEntry e) {
  final series = calendarSeriesTitle(e);
  return series.isNotEmpty ? series : e.item.title;
}

/// The small line: "S2 · E8 · Episodio 8" (the episode's own title only
/// when the big line is the series').
String calendarSubtitle(CalendarEntry e) {
  final i = e.item;
  final badge = episodeBadge(i.seasonNumber, i.episodeNumber);
  final ownTitle = calendarSeriesTitle(e).isNotEmpty ? i.title.trim() : '';
  return [badge, ownTitle].where((s) => s.isNotEmpty).join(' · ');
}

bool calendarIsEpisode(CalendarEntry e) =>
    e.item.mediaType == 'episode' || e.seriesId.isNotEmpty;

/// What a tap opens: the series of an episode, or the title itself — only
/// once it's available ("Previsto" opens nothing: a date is a plan).
CatalogItem? calendarOpenTarget(CalendarEntry e) {
  if (!e.available) return null;
  if (e.seriesId.isNotEmpty) {
    return CatalogItem(
      id: e.seriesId,
      title: calendarTitle(e),
      posterUrl: e.item.posterUrl,
      mediaType: 'series',
    );
  }
  return e.item;
}
