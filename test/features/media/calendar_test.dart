import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    show CalendarEntry, CatalogItem;
import 'package:pileus/features/media/calendar.dart';

CalendarEntry entry(String at,
        {bool allDay = false,
        bool available = true,
        String seriesId = '',
        String title = 'T',
        Map<String, String> extra = const {},
        int season = 0,
        int episode = 0}) =>
    CalendarEntry(
      pluginId: 'p',
      releaseAt: at,
      allDay: allDay,
      available: available,
      seriesId: seriesId,
      item: CatalogItem(
          id: 'i',
          title: title,
          seasonNumber: season,
          episodeNumber: episode,
          extra: extra.entries),
    );

void main() {
  test('an all-day release keeps its own date, whatever the zone', () {
    final e = entry('2026-11-26T00:00:00+09:00', allDay: true);
    expect(calendarReleaseTime(e), DateTime(2026, 11, 26));
    expect(calendarTimeLabel(e), '');
  });

  test('a timed release is shown on the device clock', () {
    final e = entry('2026-11-26T20:30:00Z');
    final local = DateTime.utc(2026, 11, 26, 20, 30).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    expect(calendarTimeLabel(e), '${two(local.hour)}:${two(local.minute)}');
  });

  test('grouped by day in order, unreadable dates left out', () {
    final days = groupCalendar([
      entry('2026-11-27', allDay: true, title: 'b'),
      entry('2026-11-26', allDay: true, title: 'a'),
      entry('2026-11-27', allDay: true, title: 'c'),
      entry('', title: 'x'),
    ]);
    expect(days.map((d) => d.day),
        [DateTime(2026, 11, 26), DateTime(2026, 11, 27)]);
    expect(days[1].entries.map((e) => e.item.title), ['b', 'c']);
  });

  test('day labels', () {
    final now = DateTime(2026, 11, 24, 21);
    expect(calendarDayLabel(DateTime(2026, 11, 24), now), 'Oggi');
    expect(calendarDayLabel(DateTime(2026, 11, 25), now), 'Domani');
    expect(
        calendarDayLabel(DateTime(2026, 11, 27), now), 'venerdì 27 novembre');
  });

  test('titles: the series when the plugin names it', () {
    final named = entry('2026-11-26',
        allDay: true,
        title: 'Episodio 8',
        extra: {'series_title': 'Dark'},
        season: 2,
        episode: 8);
    expect(calendarTitle(named), 'Dark');
    expect(calendarSubtitle(named), 'S2 · E8 · Episodio 8');
    final bare = entry('2026-11-26',
        allDay: true, title: 'Episodio 8', season: 2, episode: 8);
    expect(calendarTitle(bare), 'Episodio 8');
    expect(calendarSubtitle(bare), 'S2 · E8');
  });

  test('a live event: its competition, a landscape cover, opens itself', () {
    final e = entry('2026-11-28T19:45:00Z',
        title: 'Inter - Milan', extra: {'competition': 'Serie A'});
    e.item.mediaType = 'live';
    expect(calendarTitle(e), 'Inter - Milan');
    expect(calendarSubtitle(e), 'Serie A');
    expect(calendarLandscapeThumb(e), isTrue);
    expect(calendarOpenTarget(e)!.mediaType, 'live');
  });

  test('a tap opens the series, "Previsto" ones too', () {
    expect(
        calendarOpenTarget(
                entry('2026-11-26', available: false, seriesId: 's1'))!
            .id,
        's1');
    final ep = calendarOpenTarget(entry('2026-11-26', seriesId: 's1'))!;
    expect(ep.id, 's1');
    expect(ep.mediaType, 'series');
    final film = calendarOpenTarget(entry('2026-11-26'))!;
    expect(film.id, 'i');
  });
}
