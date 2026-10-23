import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClient implements MediaGrpcClient {
  // WarmStream answer, or the error it throws.
  Object warmAnswer = WarmStreamResponse(outcome: 'started');
  final List<String> warmCalls = [];
  List<StreamSource> sources = [StreamSource(id: 's:it', label: 'Italiano')];
  int streamsCalls = 0;
  int browseCalls = 0;

  @override
  Future<WarmStreamResponse> warmStream(WarmStreamRequest request) async {
    warmCalls.add('${request.pluginId}/${request.streamId}');
    final a = warmAnswer;
    if (a is WarmStreamResponse) return a;
    throw a;
  }

  @override
  Future<StreamsResponse> getStreams(StreamsRequest request) async {
    streamsCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return StreamsResponse(sources: sources);
  }

  @override
  Future<BrowseResponse> browse(BrowseRequest request) async {
    browseCalls++;
    return BrowseResponse(episodes: [EpisodeInfo(id: 'e1')]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClient client;
  late AuthInterceptor interceptor;
  late MediaRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = _FakeClient();
    getIt.registerSingleton<MediaGrpcClient>(client);
    interceptor = AuthInterceptor();
    repo = MediaRepository(await SharedPreferences.getInstance(), interceptor);
  });

  tearDown(() async => getIt.reset());

  // warmStream is fire-and-forget: let its future settle.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  group('warmStream', () {
    test('sends plugin and stream id as given', () async {
      repo.warmStream('movies', '603:it');
      await settle();
      expect(client.warmCalls, ['movies/603:it']);
      expect(repo.canWarm('movies'), isTrue);
    });

    test('UNIMPLEMENTED (old server) turns warming off for the session',
        () async {
      client.warmAnswer = const GrpcError.unimplemented();
      repo.warmStream('movies', 'a');
      await settle();
      expect(repo.canWarm('movies'), isFalse);
      expect(repo.canWarm('anime'), isFalse);
      repo.warmStream('anime', 'b');
      await settle();
      expect(client.warmCalls, ['movies/a']);
    });

    test('skipped(disabled) turns off that plugin only', () async {
      client.warmAnswer =
          WarmStreamResponse(outcome: 'skipped', reason: 'disabled');
      repo.warmStream('sport', 'a');
      await settle();
      expect(repo.canWarm('sport'), isFalse);
      expect(repo.canWarm('movies'), isTrue);
      repo.warmStream('sport', 'b');
      await settle();
      expect(client.warmCalls, ['sport/a']);
    });

    test('other skips and errors change nothing', () async {
      client.warmAnswer =
          WarmStreamResponse(outcome: 'skipped', reason: 'busy');
      repo.warmStream('movies', 'a');
      await settle();
      client.warmAnswer = const GrpcError.unavailable();
      repo.warmStream('movies', 'b');
      await settle();
      expect(repo.canWarm('movies'), isTrue);
      expect(client.warmCalls, hasLength(2));
    });

    test('empty ids are never sent', () async {
      repo.warmStream('', 'a');
      repo.warmStream('p', '');
      await settle();
      expect(client.warmCalls, isEmpty);
    });
  });

  group('getStreams cache', () {
    test('concurrent and repeated calls share one RPC', () async {
      await Future.wait([
        repo.getStreams('p', 'm'),
        repo.getStreams('p', 'm'),
      ]);
      await repo.getStreams('p', 'm');
      expect(client.streamsCalls, 1);
    });

    test('per profile: a plugin may order sources by the profile', () async {
      interceptor.setCredentials('jwt', 'anna');
      await repo.getStreams('p', 'm');
      interceptor.setCredentials('jwt', 'luca');
      await repo.getStreams('p', 'm');
      expect(client.streamsCalls, 2);
    });

    test('an empty list is not cached', () async {
      client.sources = [];
      await repo.getStreams('p', 'm');
      await repo.getStreams('p', 'm');
      expect(client.streamsCalls, 2);
    });
  });

  test('browse is cached only when asked (live directories stay fresh)',
      () async {
    await repo.browse('p', 'season', '');
    await repo.browse('p', 'season', '');
    expect(client.browseCalls, 2);
    await repo.browse('p', 'season', '', cache: true);
    await repo.browse('p', 'season', '', cache: true);
    expect(client.browseCalls, 3);
  });
}
