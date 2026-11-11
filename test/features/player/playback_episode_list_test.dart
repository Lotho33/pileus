import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    hide ContinueWatchingItem;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/episode_nav.dart';
import 'package:pileus/features/player/models/playback_args.dart';
import 'package:pileus/features/player/playback_episode_cache.dart';
import 'package:pileus/features/player/playback_episode_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClient implements MediaGrpcClient {
  final Map<String, BrowseResponse> byParent;
  final List<String> asked = [];
  _FakeClient(this.byParent);

  @override
  Future<BrowseResponse> browse(BrowseRequest request) async {
    asked.add(request.parentId);
    return byParent[request.parentId] ?? BrowseResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EpisodeInfo _ep(String id, String title, int n) =>
    EpisodeInfo(id: id, title: title, episodeNumber: n, seasonNumber: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClient client;
  late MediaRepository repo;

  Future<void> start(Map<String, BrowseResponse> byParent) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    client = _FakeClient(byParent);
    getIt.registerSingleton<MediaGrpcClient>(client);
    repo = MediaRepository(prefs, AuthInterceptor());
  }

  tearDown(() async {
    clearPlaybackEpisodeCache();
    await getIt.reset();
  });

  test('flat parent: episodes straight off it, then from the cache', () async {
    await start({
      'show': BrowseResponse(episodes: [
        _ep('show-e1', 'Pilot', 1),
        _ep('show-e2', 'Second', 2),
      ]),
    });
    final eps = await resolvePlaybackEpisodes(repo,
        pluginId: 'p', parentId: 'show', target: episodeMatchKey('Second'));
    expect(eps!.map((e) => e.id), ['show-e1', 'show-e2']);
    await resolvePlaybackEpisodes(repo,
        pluginId: 'p', parentId: 'show', target: '');
    expect(client.asked, ['show']);
  });

  test('season directories: walks to the one holding the playing title',
      () async {
    await start({
      'show': BrowseResponse(items: [
        CatalogItem(id: 's1', isDir: true),
        CatalogItem(id: 's2', isDir: true),
      ]),
      's1': BrowseResponse(episodes: [_ep('a', 'One', 1), _ep('b', 'Two', 2)]),
      's2': BrowseResponse(
          episodes: [_ep('c', 'Three', 1), _ep('d', ' Four ', 2)]),
    });
    final eps = await resolvePlaybackEpisodes(repo,
        pluginId: 'p', parentId: 'show', target: episodeMatchKey('four'));
    expect(eps!.map((e) => e.id), ['c', 'd']);
  });

  test('cancelled or too short: null', () async {
    await start({
      'show': BrowseResponse(episodes: [_ep('only', 'Only', 1)]),
    });
    expect(
        await resolvePlaybackEpisodes(repo,
            pluginId: 'p', parentId: 'show', target: ''),
        isNull);
    expect(
        await resolvePlaybackEpisodes(repo,
            pluginId: 'p', parentId: 'x', target: '', cancelled: () => true),
        isNull);
  });

  group('matchPlaybackEpisode', () {
    const eps = <PlaybackEpisode>[
      (id: '1', title: 'Uno', thumb: '', episodeNumber: 1, seasonNumber: 1),
      (
        id: 'episode-two',
        title: 'Due',
        thumb: '',
        episodeNumber: 2,
        seasonNumber: 1
      ),
    ];
    test('id, then title, then a long-enough id inside a stream id', () {
      expect(matchPlaybackEpisode(eps, currentId: '1', target: ''), 0);
      expect(matchPlaybackEpisode(eps, currentId: 'zz', target: 'due'), 1);
      expect(
          matchPlaybackEpisode(eps,
              currentId: 'https://x/episode-two/ita.m3u8', target: ''),
          1);
      // A bare "1" inside a URL must not match episode 1.
      expect(
          matchPlaybackEpisode(eps, currentId: 'https://x/1/a', target: ''),
          -1);
    });
  });

  test('EpisodeNavState.adoptResolved fills an empty nav only', () {
    final nav = EpisodeNavState.fromArgs(
        PlaybackArgs.fromExtra(null, pluginId: 'p', mediaId: 'b'));
    const eps = <PlaybackEpisode>[
      (id: 'a', title: 'A', thumb: 'ta', episodeNumber: 1, seasonNumber: 2),
      (id: 'b', title: 'B', thumb: 'tb', episodeNumber: 2, seasonNumber: 2),
    ];
    expect(nav.hasNext, isFalse);
    expect(nav.adoptResolved(eps, currentId: 'b', target: ''), isTrue);
    expect(nav.episodeIndex, 1);
    expect(nav.hasPrevious, isTrue);
    expect(nav.currentEpisodeNumber, 2);
    expect(nav.adoptResolved(eps, currentId: 'a', target: ''), isFalse);
  });
}
