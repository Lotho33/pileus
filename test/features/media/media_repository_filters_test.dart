import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// getSearchFilters answers after a short delay with [filters].
class _FakeClient implements MediaGrpcClient {
  _FakeClient(this.filters);
  final List<String> filters;
  int calls = 0;

  @override
  Future<SearchFiltersResponse> getSearchFilters(
      SearchFiltersRequest request) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return SearchFiltersResponse(
        filters: [for (final id in filters) SearchFilter(id: id)]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MediaRepository repo;

  Future<void> setUpWith(_FakeClient client) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<MediaGrpcClient>(client);
    repo = MediaRepository(prefs, AuthInterceptor());
  }

  tearDown(() async {
    await getIt.reset();
  });

  // Regression: the first request for a plugin's filters used to never
  // complete (its future waited on itself), leaving the Filtri spinner up.
  test('first request completes; concurrent ones share it', () async {
    final client = _FakeClient(['genre']);
    await setUpWith(client);
    const limit = Duration(seconds: 2);
    final results = await Future.wait([
      repo.getSearchFilters('p').timeout(limit),
      repo.getSearchFilters('p').timeout(limit),
    ]);
    expect(results.map((r) => r.filters.single.id), ['genre', 'genre']);
    expect(client.calls, 1);
    // Then served from the session cache.
    final again = await repo.getSearchFilters('p').timeout(limit);
    expect(again.filters.single.id, 'genre');
    expect(client.calls, 1);
  });

  test('empty answers are not cached and do not stall', () async {
    final client = _FakeClient([]);
    await setUpWith(client);
    const limit = Duration(seconds: 2);
    expect((await repo.getSearchFilters('p').timeout(limit)).filters, isEmpty);
    expect((await repo.getSearchFilters('p').timeout(limit)).filters, isEmpty);
    expect(client.calls, 2);
  });
}
