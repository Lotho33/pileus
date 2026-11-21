import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    hide ContinueWatchingItem;
import 'package:pileus/core/grpc/generated/media.pb.dart' as pb
    show ContinueWatchingItem;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Continue Watching with no server (a download on a train): written to the
/// offline queue, shown from disk, sent once the server answers — as a
/// replay, which doesn't take the profile's playback lease.
class _FakeClient implements MediaGrpcClient {
  bool offline = false;
  final List<({String media, int pos, bool replay})> updates = [];
  final List<String> deleted = [];
  ContinueWatchingResponse cw = ContinueWatchingResponse(items: [
    pb.ContinueWatchingItem(
        pluginId: 'p', mediaId: 'e1', parentId: 'show', title: 'Ep 1',
        progressTime: 100),
  ]);

  void _net() {
    if (offline) throw const GrpcError.unavailable('offline');
  }

  @override
  Future<ProgressResponse> updateProgress(ProgressRequest request,
      {bool replay = false}) async {
    _net();
    updates.add((
      media: request.mediaId,
      pos: request.currentPosition.toInt(),
      replay: replay,
    ));
    return ProgressResponse(ok: true);
  }

  @override
  Future<DeleteProgressResponse> deleteProgress(
      DeleteProgressRequest request) async {
    _net();
    deleted.add(request.mediaId);
    return DeleteProgressResponse();
  }

  @override
  Future<ContinueWatchingResponse> getContinueWatching(
      ContinueWatchingRequest request) async {
    _net();
    return cw;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  Future<void> save(String media, int pos) => repo.updateProgress(
        pluginId: 'p',
        mediaId: media,
        parentId: 'show',
        position: Duration(seconds: pos),
        title: 'T $media',
      );

  test('offline writes are queued, shown, then replayed in order', () async {
    // Online once: the row on disk.
    await repo.fetchContinueWatching();
    client.offline = true;
    await save('e1', 1200);
    await save('e2', 60);
    await save('e2', 300); // heartbeat: only the latest is kept
    expect(client.updates, isEmpty);

    // Drawn from disk with the offline progress over it: e2 replaces the
    // series' older row.
    final shown = repo.cachedContinueWatching()!;
    expect(shown.map((i) => i.playableID), ['e2']);
    expect(shown.single.progressTime, 300);

    // Back online: the next fetch sends the queue first, as replays.
    client.offline = false;
    await repo.fetchContinueWatching();
    expect(client.updates.map((u) => (u.media, u.pos)), [('e1', 1200), ('e2', 300)]);
    expect(client.updates.every((u) => u.replay), isTrue);

    // Sent once only.
    await repo.fetchContinueWatching();
    expect(client.updates, hasLength(2));
  });

  test('a live write after reconnecting wins over the queued one', () async {
    client.offline = true;
    await save('e1', 500);
    client.offline = false;
    await save('e1', 900); // the player's next heartbeat, online
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(client.updates.map((u) => (u.media, u.pos, u.replay)),
        [('e1', 900, false)]);
  });

  test('an automatic removal offline is queued too', () async {
    client.offline = true;
    final ok = await repo.deleteProgress(providerID: 'p', playableID: 'm1');
    expect(ok, isFalse);
    client.offline = false;
    await repo.fetchContinueWatching();
    expect(client.deleted, ['m1']);
  });
}
