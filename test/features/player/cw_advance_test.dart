import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/cw_advance.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Moving a finished episode's Continue Watching row across seasons.
class _Repo extends MediaRepository {
  _Repo(SharedPreferences prefs) : super(prefs, AuthInterceptor());

  DetailsResponse details = DetailsResponse();
  Object? detailsError;
  final Map<String, BrowseResponse> folders = {};
  final List<String> browsed = [];
  final List<ProgressRequest> updates = [];
  final List<String> deletes = [];
  final List<CwAdvanceRequest> queued = [];
  bool updateFails = false;

  @override
  Future<DetailsResponse> getDetails(String pluginId, String mediaId,
      {bool urgent = false, bool fresh = false}) async {
    if (detailsError != null) throw detailsError!;
    return details;
  }

  @override
  Future<BrowseResponse> browse(
      String pluginId, String parentId, String childId,
      {bool cache = false}) async {
    browsed.add(parentId);
    return folders[parentId] ?? BrowseResponse();
  }

  @override
  Future<StreamsResponse> getStreams(String pluginId, String mediaId) async =>
      StreamsResponse();

  @override
  Future<ProgressResponse?> updateProgress({
    required String pluginId,
    required String mediaId,
    required Duration position,
    Duration totalDuration = Duration.zero,
    String parentId = '',
    String title = '',
    String showTitle = '',
    String poster = '',
    double rating = 0.0,
    List<String> genres = const [],
    String plot = '',
    int year = 0,
    int seasonNumber = 0,
    int episodeNumber = 0,
    bool queueOffline = true,
    bool replay = false,
  }) async {
    if (updateFails) return null;
    updates.add(ProgressRequest(
      pluginId: pluginId,
      mediaId: mediaId,
      parentId: parentId,
      title: title,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    ));
    return ProgressResponse();
  }

  @override
  Future<bool> deleteProgress({
    required String providerID,
    required String playableID,
    bool queueOffline = true,
  }) async {
    deletes.add(playableID);
    return true;
  }

  @override
  Future<void> queueCwAdvance(CwAdvanceRequest r) async => queued.add(r);
}

EpisodeInfo _ep(String id, int s, int n) =>
    EpisodeInfo(id: id, title: 'S$s E$n', seasonNumber: s, episodeNumber: n);

DetailsResponse _series(List<String> seasonDirs) => DetailsResponse(
      series: SeriesDetails(seasons: [
        for (var i = 0; i < seasonDirs.length; i++)
          SeasonInfo(number: i + 1, directoryId: seasonDirs[i]),
      ]),
    );

CwAdvanceRequest _req(String current,
        {int season = 0, int episode = 0, String title = ''}) =>
    CwAdvanceRequest(
      pluginId: 'p',
      seriesId: 'show',
      currentCwId: current,
      currentTitle: title,
      seasonNumber: season,
      episodeNumber: episode,
      showTitle: 'Serie',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo(await SharedPreferences.getInstance());
    repo.details = _series(['s1', 's2']);
    repo.folders['s1'] =
        BrowseResponse(episodes: [_ep('e11', 1, 1), _ep('e12', 1, 2)]);
    repo.folders['s2'] =
        BrowseResponse(episodes: [_ep('e21', 2, 1), _ep('e22', 2, 2)]);
  });

  test('last episode of a season → first episode of the next one', () async {
    final done = await tryAdvanceContinueWatching(repo, _req('e12', season: 1));
    expect(done, isTrue);
    expect(repo.updates.single.mediaId, 'e21');
    // Grouped under the series, not the season folder.
    expect(repo.updates.single.parentId, 'show');
    expect(repo.updates.single.seasonNumber, 2);
    expect(repo.updates.single.episodeNumber, 1);
    expect(repo.deletes, ['e12']);
  });

  test('season unknown (a download): found by walking the seasons', () async {
    final done = await tryAdvanceContinueWatching(repo, _req('e12'));
    expect(done, isTrue);
    expect(repo.updates.single.mediaId, 'e21');
  });

  test('a download in the middle of a season → the next episode', () async {
    await tryAdvanceContinueWatching(repo, _req('e21'));
    expect(repo.updates.single.mediaId, 'e22');
  });

  test('matched by number when the id is a stream id', () async {
    await tryAdvanceContinueWatching(
        repo, _req('stream-xyz', season: 1, episode: 2));
    expect(repo.updates.single.mediaId, 'e21');
  });

  test('last episode of the last season → the row goes', () async {
    final done = await tryAdvanceContinueWatching(repo, _req('e22', season: 2));
    expect(done, isTrue);
    expect(repo.updates, isEmpty);
    expect(repo.deletes, ['e22']);
  });

  test('a movie launched with a parent id → the row goes', () async {
    repo.details = DetailsResponse(movie: MovieDetails());
    await tryAdvanceContinueWatching(repo, _req('m1'));
    expect(repo.updates, isEmpty);
    expect(repo.deletes, ['m1']);
  });

  test('single-level series (no season folders)', () async {
    repo.details = DetailsResponse(series: SeriesDetails());
    repo.folders['show'] =
        BrowseResponse(episodes: [_ep('a', 1, 1), _ep('b', 1, 2)]);
    await tryAdvanceContinueWatching(repo, _req('a'));
    expect(repo.updates.single.mediaId, 'b');
  });

  test('episode not found anywhere: the row is left alone', () async {
    final done = await tryAdvanceContinueWatching(repo, _req('zzz'));
    expect(done, isTrue);
    expect(repo.updates, isEmpty);
    expect(repo.deletes, isEmpty);
  });

  test('server unreachable → queued for later', () async {
    repo.detailsError = const GrpcError.unavailable('offline');
    await advanceContinueWatching(repo, _req('e12', season: 1));
    expect(repo.queued.single.currentCwId, 'e12');
    expect(repo.updates, isEmpty);
  });

  test('the write failing → queued for later', () async {
    repo.updateFails = true;
    await advanceContinueWatching(repo, _req('e12', season: 1));
    expect(repo.queued, hasLength(1));
  });

  test('a plugin error is not queued (retrying would not help)', () async {
    repo.detailsError = const GrpcError.internal('boom');
    await advanceContinueWatching(repo, _req('e12', season: 1));
    expect(repo.queued, isEmpty);
  });

  test('request survives JSON (the offline queue stores it)', () {
    final r = CwAdvanceRequest.fromJson(
        _req('e12', season: 1, episode: 2, title: 'S1 E2').toJson());
    expect(r.currentCwId, 'e12');
    expect(r.seasonNumber, 1);
    expect(r.episodeNumber, 2);
    expect(r.currentTitle, 'S1 E2');
    expect(r.seriesId, 'show');
  });

  test('isEpisodeOfSeries', () {
    expect(isEpisodeOfSeries('show', 'e1'), isTrue);
    expect(isEpisodeOfSeries('', 'm1'), isFalse);
    expect(isEpisodeOfSeries('m1', 'm1'), isFalse);
  });
}
