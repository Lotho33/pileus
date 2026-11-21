import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/cw_advance.dart';
import 'package:pileus/features/player/cw_progress.dart';
import 'package:pileus/features/player/episode_prefetch.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Continue Watching bookkeeping shared by the four players.
class _Repo extends MediaRepository {
  _Repo(SharedPreferences prefs) : super(prefs, AuthInterceptor());

  final List<({String mediaId, Duration position, ProgressRequest req})>
      updates = [];
  final List<String> deletes = [];
  final List<CwAdvanceRequest> queued = [];
  final Map<String, List<StreamSource>> streams = {};
  bool elsewhere = false;
  bool offline = false;

  @override
  Future<StreamsResponse> getStreams(String pluginId, String mediaId) async =>
      StreamsResponse(sources: streams[mediaId] ?? const []);

  @override
  Future<DetailsResponse> getDetails(String pluginId, String mediaId,
      {bool urgent = false, bool fresh = false}) async {
    if (offline) throw const GrpcError.unavailable();
    return DetailsResponse(movie: MovieDetails());
  }

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
    updates.add((
      mediaId: mediaId,
      position: position,
      req: ProgressRequest(
        pluginId: pluginId,
        mediaId: mediaId,
        parentId: parentId,
        title: title,
        poster: poster,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      ),
    ));
    return ProgressResponse(playbackElsewhere: elsewhere, playingOn: 'Salotto');
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

CwSnapshot _episode(int index, {String cwId = ''}) => CwSnapshot(
      pluginId: 'p',
      cwId: cwId.isNotEmpty ? cwId : 'e$index',
      parentId: 'show',
      title: 'Ep $index',
      showTitle: 'Serie',
      poster: 'thumb$index',
      episodeList: const ['e0', 'e1', 'e2'],
      episodeIndex: index,
      episodeTitles: const ['Ep 0', 'Ep 1', 'Ep 2'],
      episodeThumbs: const ['thumb0', 'thumb1', 'thumb2'],
      seasonNumbers: const [1, 1, 1],
      episodeNumbers: const [1, 2, 3],
      sourceLabel: 'ITA',
    );

const _movie = CwSnapshot(
  pluginId: 'p',
  cwId: 'film',
  parentId: '',
  title: 'Film',
  poster: 'cover',
);

const _min = Duration(minutes: 1);
Duration _at(int seconds) => Duration(seconds: seconds);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo(await SharedPreferences.getInstance());
  });

  ContinueWatchingTracker tracker(CwSnapshot Function() snap,
          {bool isLive = false, void Function(String)? elsewhere}) =>
      ContinueWatchingTracker(
        snapshot: snap,
        isLive: isLive,
        onPlaybackElsewhere: elsewhere,
        repo: repo,
      );

  group('writes', () {
    test('markStarted writes even at 0, with the current episode metadata',
        () async {
      await tracker(() => _episode(1))
          .markStarted(position: Duration.zero, duration: _min);
      final u = repo.updates.single;
      expect(u.position, Duration.zero);
      expect(u.req.mediaId, 'e1');
      expect(u.req.parentId, 'show');
      expect(u.req.title, 'Ep 1');
      expect(u.req.poster, 'thumb1');
      expect(u.req.seasonNumber, 1);
      expect(u.req.episodeNumber, 2);
    });

    test('save skips a 0 position', () async {
      final t = tracker(() => _episode(1));
      await t.save(position: Duration.zero, duration: _min);
      await t.save(position: const Duration(milliseconds: 900), duration: _min);
      expect(repo.updates, isEmpty);
      await t.save(position: _at(5), duration: _min);
      expect(repo.updates.single.position, _at(5));
    });

    test('empty title falls back to the show title', () async {
      await tracker(() => const CwSnapshot(
          pluginId: 'p',
          cwId: 'x',
          parentId: '',
          showTitle: 'Serie')).save(position: _at(3));
      expect(repo.updates.single.req.title, 'Serie');
    });

    test('live never writes nor clears', () async {
      final t = tracker(() => _episode(1), isLive: true);
      await t.markStarted(position: Duration.zero);
      await t.save(position: _at(30), duration: _min);
      expect(t.maybeClear(position: _min, duration: _min), isNull);
      expect(repo.updates, isEmpty);
      expect(repo.deletes, isEmpty);
    });

    test('snapshot is read at each write (episode switch)', () async {
      var snap = _episode(0);
      final t = tracker(() => snap);
      await t.save(position: _at(10));
      snap = _episode(1);
      await t.save(position: _at(10));
      expect(repo.updates.map((u) => u.mediaId), ['e0', 'e1']);
    });

    test('onWrite runs before each write', () async {
      var calls = 0;
      final t = ContinueWatchingTracker(
        snapshot: () => _episode(1),
        isLive: false,
        onWrite: () => calls++,
        repo: repo,
      );
      await t.markStarted(position: Duration.zero);
      await t.save(position: _at(4));
      await t.save(position: Duration.zero);
      expect(calls, 2);
    });
  });

  group('playback elsewhere', () {
    test('reported once until re-armed', () async {
      final seen = <String>[];
      final t = tracker(() => _episode(1), elsewhere: seen.add);
      repo.elsewhere = true;
      await t.save(position: _at(10));
      await t.save(position: _at(20));
      expect(seen, ['Salotto']);
      t.rearmElsewhere();
      await t.save(position: _at(30));
      expect(seen, ['Salotto', 'Salotto']);
    });
  });

  group('end of title', () {
    test('below the thresholds nothing happens', () {
      final t = tracker(() => _episode(0));
      expect(t.maybeClear(position: _at(89), duration: _at(100)), isNull);
      expect(t.cleared, isFalse);
      expect(t.maybeClear(position: _at(50), duration: Duration.zero), isNull);
    });

    test('same-season next at 90%: rolls forward to its stream id', () async {
      repo.streams['e1'] = [
        StreamSource(id: 'e1-eng', label: 'ENG'),
        StreamSource(id: 'e1-ita', label: 'ITA'),
      ];
      final t = tracker(() => _episode(0));
      await t.maybeClear(position: _at(90), duration: _at(100));
      final u = repo.updates.single;
      expect(u.mediaId, 'e1-ita');
      expect(u.position, _at(31));
      expect(u.req.parentId, 'show');
      expect(u.req.title, 'Ep 1');
      expect(u.req.poster, 'thumb1');
      expect(u.req.episodeNumber, 2);
      expect(repo.deletes, ['e0']);
      expect(t.cleared, isTrue);
    });

    test('roll forward reuses a matching prefetch', () async {
      final t = tracker(() => _episode(0, cwId: 'e0-ita'));
      await t.maybeClear(
        position: _at(95),
        duration: _at(100),
        prefetched: const PrefetchedEpisode(
          mediaId: 'e1',
          streamId: 'e1-pre',
          resolvedUrl: '',
          httpHeaders: {},
          sourceLabel: 'ITA',
        ),
      );
      expect(repo.updates.single.mediaId, 'e1-pre');
      expect(repo.deletes, ['e0-ita']);
    });

    test('once cleared, saves and further clears are no-ops', () async {
      final t = tracker(() => _episode(0));
      await t.maybeClear(position: _at(90), duration: _at(100));
      repo.updates.clear();
      await t.save(position: _at(95));
      expect(t.maybeClear(position: _at(99), duration: _at(100)), isNull);
      expect(repo.updates, isEmpty);
      t.resetCleared();
      await t.save(position: _at(95));
      expect(repo.updates, hasLength(1));
    });

    test('last episode of the season waits for 95%', () async {
      final t = tracker(() => _episode(2));
      expect(t.maybeClear(position: _at(94), duration: _at(100)), isNull);
      expect(t.cleared, isFalse);
    });

    test('last episode at 95%: hands over to cw_advance', () async {
      repo.offline = true; // the advance can't look up: queued as-is
      final t = tracker(() => _episode(2));
      await t.maybeClear(position: _at(95), duration: _at(100));
      final q = repo.queued.single;
      expect(q.seriesId, 'show');
      expect(q.currentCwId, 'e2');
      expect(q.currentTitle, 'Ep 2');
      expect(q.seasonNumber, 1);
      expect(q.episodeNumber, 3);
      expect(q.sourceLabel, 'ITA');
      expect(t.cleared, isTrue);
    });

    test('movie at 95% is dropped', () async {
      final t = tracker(() => _movie);
      await t.maybeClear(position: _at(95), duration: _at(100));
      expect(repo.deletes, ['film']);
      expect(repo.updates, isEmpty);
    });
  });
}
