import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    hide ContinueWatchingItem;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/player_languages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClient implements MediaGrpcClient {
  int calls = 0;
  bool fail = false;

  @override
  Future<StreamsResponse> getStreams(StreamsRequest request) async {
    calls++;
    if (fail) throw const GrpcError.unavailable();
    return StreamsResponse(
        sources: [StreamSource(id: '${request.mediaId}-ita', label: 'Italiano')]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    client = _FakeClient();
    getIt.registerSingleton<MediaGrpcClient>(client);
    getIt.registerSingleton<MediaRepository>(
        MediaRepository(prefs, AuthInterceptor()));
  });

  tearDown(() async => getIt.reset());

  test('loads once per title, again when the title changes', () async {
    final l = PlayerLanguages();
    expect(await l.load('p', 'a'), isTrue);
    expect(l.sources.single.id, 'a-ita');
    expect(await l.load('p', 'a'), isFalse);
    expect(client.calls, 1);
    expect(await l.load('p', 'b'), isTrue);
    expect(l.loadedFor, 'b');
  });

  test('a failure keeps the menu and is retried', () async {
    final l = PlayerLanguages();
    await l.load('p', 'a');
    client.fail = true;
    expect(await l.load('p', 'b'), isFalse);
    expect(l.loadedFor, 'a');
    client.fail = false;
    expect(await l.load('p', 'b'), isTrue);
  });
}
