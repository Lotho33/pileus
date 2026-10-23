import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/features/media/data/recent_searches.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthInterceptor interceptor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    interceptor = AuthInterceptor()..setCredentials('jwt', 'anna');
    getIt.registerSingleton<SharedPreferences>(
        await SharedPreferences.getInstance());
    getIt.registerSingleton<AuthInterceptor>(interceptor);
  });
  tearDown(() async => getIt.reset());

  test('newest first, no duplicates, prefixes absorbed, at most 8', () async {
    await RecentSearches.add('brea');
    await RecentSearches.add('Dune');
    await RecentSearches.add('breaking bad');
    await RecentSearches.add('dune'); // same, other case → moves to front
    expect(RecentSearches.list(), ['dune', 'breaking bad']);
    for (var i = 0; i < 10; i++) {
      await RecentSearches.add('titolo $i');
    }
    expect(RecentSearches.list(), hasLength(RecentSearches.max));
    expect(RecentSearches.list().first, 'titolo 9');
  });

  test('too short is ignored; remove and clear', () async {
    await RecentSearches.add(' x ');
    expect(RecentSearches.list(), isEmpty);
    await RecentSearches.add('alien');
    await RecentSearches.add('heat');
    await RecentSearches.remove('alien');
    expect(RecentSearches.list(), ['heat']);
    await RecentSearches.clear();
    expect(RecentSearches.list(), isEmpty);
  });

  test('per profile', () async {
    await RecentSearches.add('heat');
    interceptor.setCredentials('jwt', 'luca');
    expect(RecentSearches.list(), isEmpty);
  });

  testWidgets('recorder keeps only a query that settles on results',
      (t) async {
    final r = RecentSearchRecorder();
    r.settled('brea', hasResults: true);
    await t.pump(const Duration(seconds: 1));
    r.typing(); // still typing: dropped
    r.settled('breaking', hasResults: false); // no results: dropped
    r.settled('breaking bad', hasResults: true);
    await t.pump(RecentSearches.settleAfter);
    expect(RecentSearches.list(), ['breaking bad']);
    r.submit('heat');
    expect(RecentSearches.list().first, 'heat');
    r.dispose();
  });
}
