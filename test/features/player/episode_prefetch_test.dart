import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/episode_prefetch.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records which episode the prefetch asked streams for; returns none, so
/// the prefetch stops right there.
class _Repo extends MediaRepository {
  _Repo(SharedPreferences prefs) : super(prefs, AuthInterceptor());

  final List<String> asked = [];

  @override
  Future<StreamsResponse> getStreams(String pluginId, String mediaId) async {
    asked.add(mediaId);
    return StreamsResponse();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;
  late EpisodePrefetcher prefetcher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo(await SharedPreferences.getInstance());
    prefetcher = EpisodePrefetcher(repo: repo, pluginId: 'p');
  });

  void tick(int pos, {int index = 0, int dur = 1000}) =>
      prefetcher.maybeStartInSeason(
        position: Duration(seconds: pos),
        duration: Duration(seconds: dur),
        episodeList: const ['e0', 'e1', 'e2'],
        episodeTitles: const ['Ep 0', 'Ep 1'],
        episodeIndex: index,
        currentSourceLabel: 'ITA',
      );

  test('warms the next episode of the season past the threshold', () async {
    tick(799);
    await pumpEventQueue();
    expect(repo.asked, isEmpty);
    tick(800);
    await pumpEventQueue();
    expect(repo.asked, ['e1']);
  });

  test('last episode of the season: nothing to warm', () async {
    tick(900, index: 2);
    await pumpEventQueue();
    expect(repo.asked, isEmpty);
  });

  test('too short to bother', () async {
    tick(59, dur: 60);
    await pumpEventQueue();
    expect(repo.asked, isEmpty);
  });
}
