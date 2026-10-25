import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/shared/sdui/sport_theme.dart';

void main() {
  final now = DateTime(2026, 10, 25, 10, 0); // a Sunday

  group('liveStartAt', () {
    test('a start key wins over the plot', () {
      final at = liveStartAt({
        'start_unix':
            '${DateTime.utc(2026, 10, 25, 18).millisecondsSinceEpoch ~/ 1000}',
        'plot': 'Inizio: 26/10 12:00',
      }, now: now);
      expect(at, DateTime.utc(2026, 10, 25, 18).toLocal());
    });

    test('from the plot line, local time', () {
      expect(
          liveStartAt({'plot': 'Inizio: 25/10 12:00\nLBA · Giornata 5'},
              now: now),
          DateTime(2026, 10, 25, 12, 0));
    });

    test('from the plot line in UTC', () {
      expect(liveStartAt({'plot': 'Inizio: 25/10 18:30 UTC'}, now: now),
          DateTime.utc(2026, 10, 25, 18, 30).toLocal());
    });

    test('a date across new year lands in the right year', () {
      final dec30 = DateTime(2026, 12, 30);
      expect(
          liveStartAt({'plot': 'Inizio: 02/01 15:00'}, now: dec30)!.year, 2027);
    });

    test('nothing to read', () {
      expect(liveStartAt({'plot': 'IN DIRETTA'}, now: now), isNull);
      expect(liveStartAt({}, now: now), isNull);
    });
  });

  test('liveWhenLabel', () {
    expect(
        liveWhenLabel(DateTime(2026, 10, 25, 10, 25), now: now), 'Tra 25 min');
    expect(liveWhenLabel(DateTime(2026, 10, 25, 20, 45), now: now),
        'Oggi alle 20:45');
    expect(liveWhenLabel(DateTime(2026, 10, 26, 15, 0), now: now),
        'Domani alle 15:00');
    expect(liveWhenLabel(DateTime(2026, 10, 31, 18, 0), now: now),
        'Sabato alle 18:00');
    expect(liveWhenLabel(DateTime(2026, 11, 2, 21, 0), now: now),
        '02/11 alle 21:00');
    expect(liveWhenLabel(DateTime(2026, 10, 25, 9, 0), now: now),
        'Doveva iniziare alle 09:00');
  });

  test('liveWhenShort', () {
    expect(
        liveWhenShort(DateTime(2026, 10, 25, 20, 45), now: now), 'Oggi 20:45');
    expect(
        liveWhenShort(DateTime(2026, 10, 26, 15, 0), now: now), 'Domani 15:00');
    expect(liveWhenShort(DateTime(2026, 10, 31, 18, 0), now: now), 'Sab 18:00');
    expect(liveWhenShort(DateTime(2026, 10, 25, 9, 0), now: now), 'In attesa');
  });

  test('livePlotWithoutStatus keeps what the status line does not say', () {
    expect(
        livePlotWithoutStatus('Inizio: 25/10 12:00\nLBA · Giornata 5',
            startShown: true),
        'LBA · Giornata 5');
    expect(livePlotWithoutStatus('Inizio: 25/10 12:00\nLBA', startShown: false),
        'Inizio: 25/10 12:00\nLBA');
    expect(livePlotWithoutStatus('IN DIRETTA\nSerie A', startShown: false),
        'Serie A');
    expect(livePlotWithoutStatus("IN DIRETTA · 63'  (1-0)", startShown: false),
        "IN DIRETTA · 63'  (1-0)");
  });
}
