import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    hide ContinueWatchingItem;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/media/new_episodes.dart';
import 'package:pileus/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClient implements MediaGrpcClient {
  int calls = 0;
  bool unimplemented = false;

  @override
  Future<NewEpisodesResponse> getNewEpisodes() async {
    calls++;
    if (unimplemented) throw const GrpcError.unimplemented('old server');
    return NewEpisodesResponse(items: [
      NewEpisode(
          pluginId: 'vix',
          seriesId: 's1',
          title: 'Serie 1',
          posterUrl: 'p1',
          seasonNumber: 2,
          episodeNumber: 5),
      NewEpisode(pluginId: 'anime', seriesId: 'a1', title: 'Anime 1'),
      NewEpisode(pluginId: 'vix', seriesId: 's2', title: 'Serie 2'),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the row goes second, only where there are on-demand catalogs', () {
    final out = withNewEpisodesRow([
      PluginInfo(pluginId: 'vix', catalogs: [
        CatalogDef(id: 'popular'),
        CatalogDef(id: 'new'),
      ]),
      PluginInfo(
          pluginId: 'sport', catalogs: [CatalogDef(id: 'l', type: 'live')]),
      PluginInfo(pluginId: 'one', catalogs: [CatalogDef(id: 'only')]),
      PluginInfo(pluginId: 'none'),
    ]);
    expect(out[0].catalogs.map((c) => c.id),
        ['popular', kNewEpisodesCatalogId, 'new']);
    expect(out[1].catalogs.map((c) => c.id), ['l']);
    expect(out[2].catalogs.map((c) => c.id), ['only', kNewEpisodesCatalogId]);
    expect(out[3].catalogs, isEmpty);
    // Applying it twice adds nothing.
    expect(withNewEpisodesRow(out)[0].catalogs, hasLength(3));
  });

  test('the card is the server one when it sent it, else title and poster', () {
    final full = newEpisodeCard(NewEpisode(
        pluginId: 'anime',
        seriesId: 'a1',
        title: 'Anime 1',
        posterUrl: 'old',
        item: CatalogItem(
            id: 'a1',
            title: 'Anime 1',
            posterUrl: 'tmdb',
            isDir: true,
            logoUrl: 'logo',
            extra: {'fanart_url': 'bg', 'plot': 'Trama'}.entries)));
    expect(full.posterUrl, 'tmdb');
    expect(full.extra['fanart_url'], 'bg');
    expect(full.extra['plot'], 'Trama');
    expect(full.logoUrl, 'logo');
    expect(full.badge, 'new_episode');
    final bare = newEpisodeCard(
        NewEpisode(seriesId: 's2', title: 'Serie 2', posterUrl: 'p2'));
    expect(bare.posterUrl, 'p2');
    expect(bare.extra, isEmpty);
    expect(bare.badge, 'new_episode');
  });

  group('repository', () {
    late _FakeClient client;
    late MediaRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      client = _FakeClient();
      final interceptor = AuthInterceptor()..setCredentials('jwt', 'anna');
      getIt.registerSingleton<MediaGrpcClient>(client);
      getIt.registerSingleton<SettingsRepository>(
          SettingsRepository(prefs, interceptor, (_, __) async {}));
      repo = MediaRepository(prefs, interceptor);
    });
    tearDown(() async => getIt.reset());

    test("each plugin's row lists its own series, one call for all", () async {
      final vix = await repo.getCatalog('vix', kNewEpisodesCatalogId);
      final anime = await repo.getCatalog('anime', kNewEpisodesCatalogId);
      expect(vix.catalog.items.map((i) => i.id), ['s1', 's2']);
      expect(vix.catalog.items.first.mediaType, 'series');
      expect(vix.catalog.items.first.badge, 'new_episode');
      expect(vix.catalog.hasMore, isFalse);
      expect(anime.catalog.items.map((i) => i.title), ['Anime 1']);
      expect(client.calls, 1);
      expect(
          (await repo.getCatalog('vix', kNewEpisodesCatalogId, page: 2))
              .catalog
              .items,
          isEmpty);
    });

    test('an older server: an empty row, not asked again', () async {
      client.unimplemented = true;
      final r = await repo.getCatalog('vix', kNewEpisodesCatalogId);
      expect(r.catalog.items, isEmpty);
      await repo.getCatalog('vix', kNewEpisodesCatalogId, forceRefresh: true);
      expect(client.calls, 1);
    });
  });
}
