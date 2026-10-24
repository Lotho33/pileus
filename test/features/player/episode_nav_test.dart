import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    show BrowseResponse, CatalogItem, EpisodeInfo;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/episode_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crossing a season boundary — one loader shared by every player.
class _Repo extends MediaRepository {
  _Repo(SharedPreferences prefs) : super(prefs, AuthInterceptor());

  final Map<String, BrowseResponse> seasons = {};
  bool hang = false;

  @override
  Future<BrowseResponse> browse(
      String pluginId, String parentId, String childId,
      {bool cache = false}) {
    if (hang) return Future.any([]); // never completes
    return Future.value(seasons[parentId] ?? BrowseResponse());
  }
}

EpisodeInfo _ep(String id, int n) =>
    EpisodeInfo(id: id, title: 'Ep $n', episodeNumber: n, seasonNumber: 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo(await SharedPreferences.getInstance());
  });

  test('episodes first, items (files only) as fallback, empty is null',
      () async {
    repo.seasons['s2'] = BrowseResponse(episodes: [_ep('a', 1), _ep('b', 2)]);
    repo.seasons['s3'] = BrowseResponse(items: [
      CatalogItem(id: 'dir', isDir: true),
      CatalogItem(id: 'f1', title: 'Uno', episodeNumber: 1),
    ]);
    final s2 = await loadSeasonEpisodes(repo, 'p', 's2');
    expect(s2!.ids, ['a', 'b']);
    expect(s2.titles, ['Ep 1', 'Ep 2']);
    expect(s2.episodeNumbers, [1, 2]);
    expect(s2.seasonNumbers, [2, 2]);
    expect((await loadSeasonEpisodes(repo, 'p', 's3'))!.ids, ['f1']);
    expect(await loadSeasonEpisodes(repo, 'p', 'none'), isNull);
  });

  testWidgets('a hung browse times out instead of spinning forever', (t) async {
    repo.hang = true;
    Object? error;
    loadSeasonEpisodes(repo, 'p', 's2').catchError((Object e) {
      error = e;
      return null;
    });
    await t.pump(seasonBrowseTimeout + const Duration(seconds: 1));
    expect(error, isA<Exception>());
  });

  test('next after the last episode opens the next season', () async {
    repo.seasons['s2'] = BrowseResponse(episodes: [_ep('a', 1), _ep('b', 2)]);
    final nav = EpisodeNavState(
      pluginId: 'p',
      episodeIndex: 0,
      seasonIndex: 0,
      episodeList: ['x'],
      episodeTitles: ['X'],
      episodeThumbs: [''],
      allSeasonIds: ['s1', 's2'],
      allSeasonLabels: ['1', '2'],
      parentId: 's1',
      seriesPoster: '',
    );
    expect(nav.hasNext, isTrue);
    final t = await nav.resolveNext(repo);
    expect(t!.mediaId, 'a');
    expect(t.seasonIndex, 1);
    expect(nav.parentId, 's2');
    expect(nav.hasPrevious, isTrue);
    expect(nav.hasNext, isTrue);
    expect((await nav.resolveNext(repo))!.mediaId, 'b');
    expect(nav.hasNext, isFalse);
  });
}
