import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    hide ContinueWatchingItem;
import 'package:pileus/features/media/bloc/details_bloc.dart';
import 'package:pileus/features/media/bloc/details_event.dart';
import 'package:pileus/features/media/bloc/details_state.dart';
import 'package:pileus/features/media/bloc/discovery_bloc.dart';
import 'package:pileus/features/media/bloc/discovery_event.dart';
import 'package:pileus/features/media/bloc/discovery_state.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogItem _item({LogoMeta? meta, String logo = 'https://x/logo.png'}) =>
    CatalogItem(
        id: 'x',
        title: 'X',
        posterUrl: 'p',
        mediaType: 'series',
        logoUrl: logo,
        logoMeta: meta);

class _FakeClient implements MediaGrpcClient {
  final List<CatalogItem> answers;
  int calls = 0;
  _FakeClient(this.answers);

  @override
  Future<CatalogResponse> getCatalog(CatalogRequest request) async {
    final i = calls < answers.length ? calls : answers.length - 1;
    calls++;
    return CatalogResponse(items: [answers[i]]);
  }

  final List<DetailsResponse> details = [];
  int detailCalls = 0;

  @override
  Future<DetailsResponse> getDetails(DetailsRequest request,
      {bool urgent = false}) async {
    final i = detailCalls < details.length ? detailCalls : details.length - 1;
    detailCalls++;
    return details[i];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final measured = LogoMeta(width: 600, height: 200, halo: 'light');

  late _FakeClient client;
  late MediaRepository repo;

  Future<void> start(List<CatalogItem> answers,
      {Map<String, Object> stored = const {}}) async {
    SharedPreferences.setMockInitialValues(stored);
    client = _FakeClient(answers);
    getIt.registerSingleton<MediaGrpcClient>(client);
    repo = MediaRepository(
        await SharedPreferences.getInstance(), AuthInterceptor());
  }

  tearDown(() async => getIt.reset());

  test('pending: unmeasured logos, except SVGs the server never measures', () {
    expect(logoMetaPending(_item()), isTrue);
    expect(logoMetaPending(_item(meta: measured)), isFalse);
    expect(logoMetaPending(_item(logo: '')), isFalse);
    expect(logoMetaPending(_item(logo: 'https://x/a.svg')), isFalse);
    expect(logoMetaPending(_item(logo: 'https://image.tmdb.org/t/p/w500/a.svg')),
        isTrue);
  });

  test('a logo the server never measures stops being pending', () {
    final item = _item(logo: 'https://x/never-measured.png');
    expect(logoMetaPending(item), isTrue);
    final saved = logoPendingWindow;
    addTearDown(() => logoPendingWindow = saved);
    // Past the window (first seen above): no more revalidation / short TTL.
    logoPendingWindow = Duration.zero;
    expect(logoMetaPending(item), isFalse);
  });

  test('a fresh cached row with an unmeasured logo is revalidated', () async {
    final row = jsonEncode({
      'screenEndpoint': 'a/top/1',
      'jsonLayoutStructure': jsonEncode({
        'items': [
          {
            'id': 'x',
            'title': 'X',
            'poster_url': 'p',
            'media_type': 'series',
            'logo_url': 'https://x/logo.png',
          }
        ],
        'has_more': false,
      }),
      'cachedAtTimestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60,
    });
    await start([_item(meta: measured)], stored: {'layoutcache:a/top/1': row});
    final r = await repo.getCatalog('a', 'top');
    expect(r.fromCache, isTrue);
    expect(r.stale, isTrue);
  });

  test('the row is re-read once and picks up the measured logo', () async {
    DiscoveryBloc.logoMetaRetryDelay = const Duration(milliseconds: 5);
    addTearDown(
        () => DiscoveryBloc.logoMetaRetryDelay = const Duration(seconds: 6));
    await start([_item(), _item(meta: measured)]);
    final bloc = DiscoveryBloc(repo)
      ..add(const LoadCatalogEvent(
          pluginId: 'a', catalogId: 'top', cacheTtlSeconds: -1));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final s = bloc.state as DiscoveryLoaded;
    expect(s.items.single.logoMeta.halo, 'light');
    expect(client.calls, 2);
    await bloc.close();
  });

  test('details: the first answer without logo_meta is re-read once', () async {
    DetailsBloc.logoMetaRetryDelay = const Duration(milliseconds: 5);
    addTearDown(
        () => DetailsBloc.logoMetaRetryDelay = const Duration(seconds: 6));
    await start([_item()]);
    client.details.addAll([
      DetailsResponse(
          item: _item(), series: SeriesDetails(logoUrl: 'https://x/logo.png')),
      DetailsResponse(
          item: _item(meta: measured),
          series: SeriesDetails(
              logoUrl: 'https://x/logo.png', logoMeta: measured)),
    ]);
    // Past the short life of an unmeasured answer in the session cache.
    final bloc = DetailsBloc(repo, refreshLogoMeta: true)
      ..add(const LoadDetailsEvent(pluginId: 'a', mediaId: 'x'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(client.detailCalls, 2);
    final s = bloc.state as DetailsLoaded;
    expect(s.response.series.logoMeta.halo, 'light');
    await bloc.close();
  });
}
