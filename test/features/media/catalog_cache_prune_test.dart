import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    hide ContinueWatchingItem;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClient implements MediaGrpcClient {
  final List<int> pages = [];

  @override
  Future<CatalogResponse> getCatalog(CatalogRequest request) async {
    pages.add(request.page);
    return CatalogResponse(items: [
      CatalogItem(
        id: 'x',
        title: 'X',
        posterUrl: 'p',
        logoMeta: LogoMeta(width: 600, height: 200, halo: 'light'),
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The persisted catalog cache is maintained when the repository is built:
/// before, nothing ever removed a row (and the schema-version wipe was dead
/// code), so SharedPreferences only grew.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _FakeClient client;

  String row(String endpoint, int ageSeconds) => jsonEncode({
        'screenEndpoint': endpoint,
        'jsonLayoutStructure': jsonEncode({
          'items': [
            {'id': 'a', 'title': 'A', 'poster_url': 'p', 'media_type': 'clip'}
          ],
          'has_more': false,
        }),
        'cachedAtTimestamp':
            DateTime.now().millisecondsSinceEpoch ~/ 1000 - ageSeconds,
      });

  Future<MediaRepository> start(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    client = _FakeClient();
    getIt.registerSingleton<MediaGrpcClient>(client);
    return MediaRepository(prefs, AuthInterceptor()..setCredentials('j', 'p'));
  }

  tearDown(() async => getIt.reset());

  const day = 86400;

  test('drops rows past the stale window and pages after the first', () async {
    await start({
      'layoutcache:a/top/1': row('a/top/1', day),
      'layoutcache:a/old/1': row('a/old/1', 8 * day),
      'layoutcache:a/top/2': row('a/top/2', 60),
      'layoutcache:__plugin_order__:p': row('__plugin_order__:p', 30 * day),
      'layoutcache:__cw_snapshot__:p': row('__cw_snapshot__:p', 30 * day),
      'pluginicon:a': '<svg/>',
    });
    expect(
        prefs.getKeys(),
        unorderedEquals([
          'layoutcache:a/top/1',
          'layoutcache:__plugin_order__:p',
          'layoutcache:__cw_snapshot__:p',
          'layoutcache:__cache_version__',
          'pluginicon:a',
        ]));
  });

  test('a schema bump wipes catalog rows only', () async {
    await start({
      'layoutcache:__cache_version__': jsonEncode({
        'screenEndpoint': '__cache_version__',
        'jsonLayoutStructure': '1',
        'cachedAtTimestamp': 0,
      }),
      'layoutcache:a/top/1': row('a/top/1', 60),
      'layoutcache:__plugin_prefs__:p': row('__plugin_prefs__:p', 60),
    });
    expect(prefs.getKeys(), isNot(contains('layoutcache:a/top/1')));
    expect(prefs.getKeys(), contains('layoutcache:__plugin_prefs__:p'));
  });

  test('logo_meta survives the disk cache', () async {
    final repo = await start({});
    await repo.getCatalog('a', 'top');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final cached = await repo.getCatalog('a', 'top');
    expect(cached.fromCache, isTrue);
    expect(cached.catalog.items.single.logoMeta.halo, 'light');
    expect(cached.catalog.items.single.logoMeta.width, 600);
  });

  test('later pages are fetched but not persisted', () async {
    final repo = await start({});
    await repo.getCatalog('a', 'top', page: 2);
    await repo.getCatalog('a', 'top');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(client.pages, [2, 1]);
    expect(prefs.getKeys(), contains('layoutcache:a/top/1'));
    expect(prefs.getKeys(), isNot(contains('layoutcache:a/top/2')));
  });
}
