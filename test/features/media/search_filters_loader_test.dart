import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:pileus/core/grpc/generated/media.pb.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/media/data/search_filters_loader.dart';

/// Scripted getSearchFilters: each call takes the next answer (a list of
/// filter ids, or an Exception to throw). Everything else is unused.
class _FakeRepo implements MediaRepository {
  _FakeRepo(this.answers);
  final List<Object> answers;
  int calls = 0;

  @override
  Future<SearchFiltersResponse> getSearchFilters(String pluginId) async {
    final a = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    if (a is Exception) throw a;
    return SearchFiltersResponse(
        filters: [for (final id in a as List<String>) SearchFilter(id: id)]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final unavailable = GrpcError.unavailable('warming up');

  testWidgets('UNAVAILABLE is retried with backoff until filters arrive',
      (tester) async {
    final repo = _FakeRepo([unavailable, unavailable, ['genre']]);
    final l = SearchFiltersLoader(repo)..setPlugin('p');
    await tester.pump();
    expect(l.status, FiltersStatus.error);
    expect(repo.calls, 1);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(repo.calls, 2);
    expect(l.status, FiltersStatus.error);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(repo.calls, 3);
    expect(l.status, FiltersStatus.ready);
    expect(l.filters.single.id, 'genre');
    l.dispose();
  });

  testWidgets('errors keep retrying every 30s after the backoff',
      (tester) async {
    final repo = _FakeRepo([unavailable]);
    final l = SearchFiltersLoader(repo)..setPlugin('p');
    await tester.pump();
    for (final d in [1500, 4000, 10000, 30000, 30000]) {
      await tester.pump(Duration(milliseconds: d));
      await tester.pump();
    }
    expect(repo.calls, 6);
    l.dispose();
  });

  testWidgets('empty answers stop after the backoff (plugin has none)',
      (tester) async {
    final repo = _FakeRepo([<String>[]]);
    final l = SearchFiltersLoader(repo)..setPlugin('p');
    await tester.pump();
    for (final d in [1500, 4000, 10000, 30000, 30000]) {
      await tester.pump(Duration(milliseconds: d));
      await tester.pump();
    }
    expect(repo.calls, 4);
    expect(l.status, FiltersStatus.none);
    l.dispose();
  });

  testWidgets('hidden: no retries; visible again: retries at once',
      (tester) async {
    final repo = _FakeRepo([unavailable, unavailable, ['genre']]);
    final l = SearchFiltersLoader(repo)
      ..setVisible(false)
      ..setPlugin('p');
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(repo.calls, 1, reason: 'no background retries while hidden');
    l.setVisible(true);
    await tester.pump();
    expect(repo.calls, 2);
    l.dispose();
  });

  testWidgets('retryNow tries immediately and joins an in-flight request',
      (tester) async {
    final repo = _FakeRepo([unavailable, ['genre']]);
    final l = SearchFiltersLoader(repo)..setPlugin('p');
    await tester.pump();
    expect(l.status, FiltersStatus.error);
    await l.retryNow();
    expect(repo.calls, 2);
    expect(l.hasFilters, isTrue);
    l.dispose();
  });

  testWidgets('a later failure never wipes filters already obtained',
      (tester) async {
    final repo = _FakeRepo([['genre'], unavailable]);
    final l = SearchFiltersLoader(repo)..setPlugin('p');
    await tester.pump();
    expect(l.hasFilters, isTrue);
    await l.retryNow();
    expect(l.status, FiltersStatus.ready);
    expect(l.filters.single.id, 'genre');
    l.dispose();
  });

  testWidgets('switching plugin drops the old filters and loads the new',
      (tester) async {
    final repo = _FakeRepo([['genre'], ['year']]);
    final l = SearchFiltersLoader(repo)..setPlugin('a');
    await tester.pump();
    expect(l.filters.single.id, 'genre');
    l.setPlugin('b');
    expect(l.filters, isEmpty);
    await tester.pump();
    expect(l.filters.single.id, 'year');
    l.dispose();
  });
}
