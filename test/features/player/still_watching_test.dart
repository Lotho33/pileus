import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/still_watching.dart';

void main() {
  var now = DateTime(2026, 11, 24, 21);
  StillWatchingGuard guard() => StillWatchingGuard(now: () => now);

  setUp(() => now = DateTime(2026, 11, 24, 21));

  test('asks before the 4th episode in a row with no input', () {
    final g = guard();
    expect(g.shouldAsk, isFalse); // end of the 1st
    g.noteAutoAdvance();
    expect(g.shouldAsk, isFalse); // end of the 2nd
    g.noteAutoAdvance();
    expect(g.shouldAsk, isTrue); // end of the 3rd
  });

  test('any input starts the count again', () {
    final g = guard()
      ..noteAutoAdvance()
      ..noteAutoAdvance();
    g.noteInput();
    expect(g.shouldAsk, isFalse);
    g
      ..noteAutoAdvance()
      ..noteAutoAdvance();
    expect(g.shouldAsk, isTrue);
  });

  test('asks after 90 minutes without input, even within 3 episodes', () {
    final g = guard();
    now = now.add(const Duration(minutes: 89));
    expect(g.shouldAsk, isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(g.shouldAsk, isTrue);
    g.noteInput();
    expect(g.shouldAsk, isFalse);
  });

  test('message names the series when known', () {
    expect(stillWatchingMessage(''), 'Stai ancora guardando?');
    expect(stillWatchingMessage(' Naruto '), 'Stai ancora guardando «Naruto»?');
  });
}
