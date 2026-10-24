import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/features/media/data/recent_searches.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _p = 'plugin.a';

void main() {
  late AuthInterceptor interceptor;

  Future<void> setUpWith(Map<String, Object> prefs, {String? profile}) async {
    SharedPreferences.setMockInitialValues(prefs);
    interceptor = AuthInterceptor();
    if (profile != null) interceptor.setCredentials('jwt', profile);
    getIt.registerSingleton<SharedPreferences>(
        await SharedPreferences.getInstance());
    getIt.registerSingleton<AuthInterceptor>(interceptor);
  }

  tearDown(() async => getIt.reset());

  group('with a profile', () {
    setUp(() => setUpWith({}, profile: 'anna'));

    test('newest first, no duplicates, prefixes absorbed, at most 8',
        () async {
      await RecentSearches.add(_p, 'brea');
      await RecentSearches.add(_p, 'Dune');
      await RecentSearches.add(_p, 'breaking bad');
      await RecentSearches.add(_p, 'dune'); // same, other case → to front
      expect(RecentSearches.list(_p), ['dune', 'breaking bad']);
      for (var i = 0; i < 10; i++) {
        await RecentSearches.add(_p, 'titolo $i');
      }
      expect(RecentSearches.list(_p), hasLength(RecentSearches.max));
      expect(RecentSearches.list(_p).first, 'titolo 9');
    });

    test('too short is ignored; remove and clear', () async {
      await RecentSearches.add(_p, ' x ');
      expect(RecentSearches.list(_p), isEmpty);
      await RecentSearches.add(_p, 'alien');
      await RecentSearches.add(_p, 'heat');
      await RecentSearches.remove(_p, 'alien');
      expect(RecentSearches.list(_p), ['heat']);
      await RecentSearches.clear(_p);
      expect(RecentSearches.list(_p), isEmpty);
    });

    test('per profile', () async {
      await RecentSearches.add(_p, 'heat');
      interceptor.setCredentials('jwt', 'luca');
      expect(RecentSearches.list(_p), isEmpty);
      interceptor.setCredentials('jwt', 'anna');
      expect(RecentSearches.list(_p), ['heat']);
    });

    test('per plugin', () async {
      await RecentSearches.add(_p, 'heat');
      await RecentSearches.add('plugin.b', 'naruto');
      expect(RecentSearches.list(_p), ['heat']);
      expect(RecentSearches.list('plugin.b'), ['naruto']);
      await RecentSearches.clear(_p);
      expect(RecentSearches.list('plugin.b'), ['naruto']);
    });

    testWidgets('recorder keeps only a query that settles on results',
        (t) async {
      final r = RecentSearchRecorder();
      r.settled(_p, 'brea', hasResults: true);
      await t.pump(const Duration(seconds: 1));
      r.typing(); // still typing: dropped
      r.settled(_p, 'breaking', hasResults: false); // no results: dropped
      r.settled(_p, 'breaking bad', hasResults: true);
      await t.pump(RecentSearches.settleAfter);
      expect(RecentSearches.list(_p), ['breaking bad']);
      r.submit(_p, 'heat');
      expect(RecentSearches.list(_p).first, 'heat');
      r.dispose();
    });
  });

  test('no profile: nothing kept, nothing shown', () async {
    await setUpWith({});
    await RecentSearches.add(_p, 'heat');
    expect(RecentSearches.list(_p), isEmpty);
  });

  test('the old lists (all plugins mixed) are dropped', () async {
    await setUpWith({
      'recent_searches:anna': ['heat'],
      'recent_searches:': ['dune'],
    }, profile: 'anna');
    expect(RecentSearches.list(_p), isEmpty);
    final prefs = getIt<SharedPreferences>();
    expect(prefs.getKeys().where((k) => k.startsWith('recent_searches:')),
        isEmpty);
  });
}
