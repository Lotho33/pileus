import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    hide ContinueWatchingItem;
import 'package:pileus/core/grpc/generated/media.pb.dart' as pb
    show ContinueWatchingItem;
import 'package:pileus/features/media/bloc/continue_watching_bloc.dart';
import 'package:pileus/features/media/bloc/continue_watching_event.dart';
import 'package:pileus/features/media/bloc/continue_watching_state.dart';
import 'package:pileus/features/media/bloc/discovery_bloc.dart';
import 'package:pileus/features/media/bloc/discovery_event.dart';
import 'package:pileus/features/media/bloc/discovery_state.dart';
import 'package:pileus/features/media/bloc/plugin_bloc.dart';
import 'package:pileus/features/media/bloc/plugin_event.dart';
import 'package:pileus/features/media/bloc/plugin_state.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fase 1 of the premium audit: the home is drawn from disk at a cold start
/// and the network only replaces it.
class _FakeClient implements MediaGrpcClient {
  Object plugins = PluginListResponse(plugins: [
    PluginInfo(pluginId: 'b', name: 'B'),
    PluginInfo(pluginId: 'a', name: 'A'),
  ]);
  Object cw = ContinueWatchingResponse(items: [
    pb.ContinueWatchingItem(pluginId: 'a', mediaId: 'm1', title: 'Uno'),
    pb.ContinueWatchingItem(pluginId: 'a', mediaId: 'm2', title: 'Due'),
  ]);
  Object catalog = CatalogResponse(items: [
    CatalogItem(id: 'x', title: 'X', posterUrl: 'p'),
  ]);
  int catalogCalls = 0;

  T _answer<T>(Object a) {
    if (a is T) return a as T;
    throw a;
  }

  @override
  Future<PluginListResponse> listPlugins() async => _answer(plugins);

  @override
  Future<ContinueWatchingResponse> getContinueWatching(
          ContinueWatchingRequest request) async =>
      _answer(cw);

  Object delete = DeleteProgressResponse();
  final List<String> deleted = [];

  @override
  Future<DeleteProgressResponse> deleteProgress(
      DeleteProgressRequest request) async {
    final r = _answer<DeleteProgressResponse>(delete);
    deleted.add(request.mediaId);
    return r;
  }

  @override
  Future<ProgressResponse> updateProgress(ProgressRequest request) async =>
      ProgressResponse();

  @override
  Future<CatalogResponse> getCatalog(CatalogRequest request) async {
    catalogCalls++;
    return _answer(catalog);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClient client;
  late AuthInterceptor interceptor;
  late SharedPreferences prefs;
  late MediaRepository repo;

  Future<void> start({Map<String, Object> stored = const {}}) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    client = _FakeClient();
    interceptor = AuthInterceptor()..setCredentials('jwt', 'anna');
    getIt.registerSingleton<MediaGrpcClient>(client);
    getIt.registerSingleton<SettingsRepository>(
        SettingsRepository(prefs, interceptor, (_, __) async {}));
    repo = MediaRepository(prefs, interceptor);
  }

  tearDown(() async => getIt.reset());

  // Fire-and-forget disk writes.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  group('plugin list snapshot', () {
    test('saved per profile after a live list, read back with no network',
        () async {
      await start();
      expect(repo.hasStartupSnapshot('anna'), isFalse);
      await repo.listPlugins();
      await settle();
      expect(repo.hasStartupSnapshot('anna'), isTrue);
      expect(repo.hasStartupSnapshot('luca'), isFalse);

      client.plugins = const GrpcError.unavailable();
      final cached = await repo.cachedPlugins();
      // Same stable order as the live list (by id with no custom order).
      expect(cached!.map((p) => p.pluginId), ['a', 'b']);

      interceptor.setCredentials('jwt', 'luca');
      expect(await repo.cachedPlugins(), isNull);
    });

    test('PluginBloc: home from disk at once, live list replaces it', () async {
      await start();
      await repo.listPlugins();
      await settle();
      client.plugins = PluginListResponse(plugins: [
        PluginInfo(pluginId: 'a', name: 'A', statusLabel: 'pronto'),
      ]);
      final bloc = PluginBloc(repo);
      final states = <PluginState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LoadPluginsEvent());
      await settle();
      expect(states.first, isA<PluginsLoaded>());
      expect((states.first as PluginsLoaded).plugins, hasLength(2));
      expect(states.whereType<PluginLoading>(), isEmpty);
      expect(
          (bloc.state as PluginsLoaded).plugins.single.statusLabel, 'pronto');
      await sub.cancel();
      await bloc.close();
    });

    test('PluginBloc: server down keeps the home from disk, no error',
        () async {
      await start();
      await repo.listPlugins();
      await settle();
      client.plugins = const GrpcError.unavailable();
      final bloc = PluginBloc(repo);
      bloc.add(const LoadPluginsEvent());
      await settle();
      expect(bloc.state, isA<PluginsLoaded>());
      await bloc.close();
    });

    test('PluginBloc: a changed certificate still shows its error', () async {
      await start();
      await repo.listPlugins();
      await settle();
      client.plugins =
          StateError('HandshakeException: CERTIFICATE_VERIFY_FAILED');
      final bloc = PluginBloc(repo);
      bloc.add(const LoadPluginsEvent());
      await settle();
      expect(bloc.state, isA<PluginError>());
      expect((bloc.state as PluginError).certMismatch, isTrue);
      await bloc.close();
    });

    test('PluginBloc: no snapshot → PluginLoading then error, as before',
        () async {
      await start();
      client.plugins = const GrpcError.unavailable();
      final bloc = PluginBloc(repo);
      final states = <PluginState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LoadPluginsEvent());
      await settle();
      expect(states, [isA<PluginLoading>(), isA<PluginError>()]);
      await sub.cancel();
      await bloc.close();
    });
  });

  group('Continue Watching snapshot', () {
    test('row from disk first, then the live one', () async {
      await start();
      await repo.fetchContinueWatching();
      await settle();
      client.cw = ContinueWatchingResponse(items: [
        pb.ContinueWatchingItem(pluginId: 'a', mediaId: 'm3', title: 'Tre'),
      ]);
      final bloc = ContinueWatchingBloc(repo);
      final states = <ContinueWatchingState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LoadContinueWatchingEvent());
      await settle();
      expect(states.map((s) => (s as ContinueWatchingLoaded).items.length),
          [2, 1]);
      await sub.cancel();
      await bloc.close();
    });

    test('server down keeps the row from disk', () async {
      await start();
      await repo.fetchContinueWatching();
      await settle();
      client.cw = const GrpcError.unavailable();
      final bloc = ContinueWatchingBloc(repo);
      bloc.add(const LoadContinueWatchingEvent());
      await settle();
      expect((bloc.state as ContinueWatchingLoaded).items, hasLength(2));
      await bloc.close();
    });

    test('a removed row does not come back from disk', () async {
      await start();
      await repo.fetchContinueWatching();
      await settle();
      await repo.deleteProgress(providerID: 'a', playableID: 'm1');
      await settle();
      expect(repo.cachedContinueWatching()!.map((i) => i.playableID), ['m2']);
    });

    test('filtered lookups (details buttons) never overwrite the row',
        () async {
      await start();
      await repo.fetchContinueWatching();
      await settle();
      client.cw = ContinueWatchingResponse(items: [
        pb.ContinueWatchingItem(pluginId: 'a', mediaId: 'only-this'),
      ]);
      await repo.fetchContinueWatching(parentId: 'series');
      await settle();
      expect(repo.cachedContinueWatching(), hasLength(2));
    });
  });

  group('catalog stale-while-revalidate', () {
    String cachedRow(int ageSeconds, List<Map<String, Object>> items) =>
        jsonEncode({
          'screenEndpoint': 'a/top/1',
          'jsonLayoutStructure':
              jsonEncode({'items': items, 'has_more': false}),
          'cachedAtTimestamp':
              DateTime.now().millisecondsSinceEpoch ~/ 1000 - ageSeconds,
        });
    final oldItems = [
      {'id': 'old', 'title': 'Old', 'poster_url': 'p', 'media_type': 'clip'}
    ];

    test('fresh cache: no network, not stale', () async {
      await start(stored: {'layoutcache:a/top/1': cachedRow(60, oldItems)});
      final r = await repo.getCatalog('a', 'top');
      expect(r.fromCache, isTrue);
      expect(r.stale, isFalse);
      expect(client.catalogCalls, 0);
    });

    test('past its TTL: served at once, marked stale', () async {
      await start(
          stored: {'layoutcache:a/top/1': cachedRow(2 * 86400, oldItems)});
      final r = await repo.getCatalog('a', 'top');
      expect(r.catalog.items.single.id, 'old');
      expect(r.stale, isTrue);
      expect(client.catalogCalls, 0);
    });

    test('older than a week: not shown, network', () async {
      await start(
          stored: {'layoutcache:a/top/1': cachedRow(8 * 86400, oldItems)});
      final r = await repo.getCatalog('a', 'top');
      expect(r.fromCache, isFalse);
      expect(r.catalog.items.single.id, 'x');
    });

    test('DiscoveryBloc: stale row first, then the live one', () async {
      await start(
          stored: {'layoutcache:a/top/1': cachedRow(2 * 86400, oldItems)});
      final bloc = DiscoveryBloc(repo);
      final shown = <List<String>>[];
      final sub = bloc.stream.listen((s) {
        if (s is DiscoveryLoaded) shown.add([for (final i in s.items) i.id]);
      });
      bloc.add(const LoadCatalogEvent(pluginId: 'a', catalogId: 'top'));
      await settle();
      expect(shown, [
        ['old'],
        ['x'],
      ]);
      await sub.cancel();
      await bloc.close();
    });

    test('DiscoveryBloc: same content live → no second rebuild', () async {
      await start(stored: {
        'layoutcache:a/top/1': cachedRow(2 * 86400, [
          {'id': 'x', 'title': 'X', 'poster_url': 'p', 'media_type': 'clip'}
        ])
      });
      final bloc = DiscoveryBloc(repo);
      var loaded = 0;
      final sub = bloc.stream.listen((s) {
        if (s is DiscoveryLoaded) loaded++;
      });
      bloc.add(const LoadCatalogEvent(pluginId: 'a', catalogId: 'top'));
      await settle();
      expect(client.catalogCalls, 1);
      expect(loaded, 1);
      await sub.cancel();
      await bloc.close();
    });

    test('DiscoveryBloc: server down keeps the stale row', () async {
      await start(
          stored: {'layoutcache:a/top/1': cachedRow(2 * 86400, oldItems)});
      client.catalog = const GrpcError.unavailable();
      final bloc = DiscoveryBloc(repo);
      bloc.add(const LoadCatalogEvent(pluginId: 'a', catalogId: 'top'));
      await settle();
      expect((bloc.state as DiscoveryLoaded).items.single.id, 'old');
      await bloc.close();
    });
  });

  group('Continue Watching removals while the server is down', () {
    test('queued, hidden, and sent once the server answers', () async {
      await start();
      await repo.fetchContinueWatching();
      await settle();
      client.delete = const GrpcError.unavailable();
      client.cw = const GrpcError.unavailable();

      final bloc = ContinueWatchingBloc(repo);
      bloc.add(const LoadContinueWatchingEvent());
      await settle();
      bloc.add(const RemoveContinueWatchingEvent('a', 'm1'));
      await settle();
      // Not put back: the server just didn't answer.
      expect(
          (bloc.state as ContinueWatchingLoaded).items.map((i) => i.playableID),
          ['m2']);
      await bloc.close();

      // Next cold start, still offline: not back from disk.
      expect(repo.cachedContinueWatching()!.map((i) => i.playableID), ['m2']);

      // Server back (its answer still lists m1): removal sent, row hidden,
      // and the copy on disk no longer has it.
      client.delete = DeleteProgressResponse();
      client.cw = ContinueWatchingResponse(items: [
        pb.ContinueWatchingItem(pluginId: 'a', mediaId: 'm1'),
        pb.ContinueWatchingItem(pluginId: 'a', mediaId: 'm2'),
      ]);
      final items = await repo.fetchContinueWatching();
      await settle();
      expect(items!.map((i) => i.playableID), ['m2']);
      expect(client.deleted, ['m1']);
      expect(repo.cachedContinueWatching()!.map((i) => i.playableID), ['m2']);

      // Nothing left to send.
      await repo.fetchContinueWatching();
      expect(client.deleted, ['m1']);
    });

    test('watching it again cancels the queued removal', () async {
      await start();
      await repo.fetchContinueWatching();
      await settle();
      client.delete = const GrpcError.unavailable();
      await repo.removeFromContinueWatching(providerID: 'a', playableID: 'm1');
      await repo.updateProgress(
          pluginId: 'a', mediaId: 'm1', position: const Duration(minutes: 3));
      client.delete = DeleteProgressResponse();
      final items = await repo.fetchContinueWatching();
      expect(client.deleted, isEmpty);
      expect(items!.map((i) => i.playableID), ['m1', 'm2']);
    });
  });

  group('offline state (OfflineBanner)', () {
    test(
        'cold start from disk with the server down: offline at once, '
        'cleared when it answers again', () async {
      await start();
      await repo.listPlugins();
      await settle();
      client.plugins = const GrpcError.unavailable();
      final bloc = PluginBloc(repo);
      bloc.add(const LoadPluginsEvent());
      await settle();
      expect((bloc.state as PluginsLoaded).offline, isTrue);

      client.plugins = PluginListResponse(plugins: [
        PluginInfo(pluginId: 'a', name: 'A'),
        PluginInfo(pluginId: 'b', name: 'B'),
      ]);
      bloc.add(const RefreshPluginsEvent());
      await settle();
      expect((bloc.state as PluginsLoaded).offline, isFalse);
      await bloc.close();
    });

    test('one failed poll is a blip, two in a row are offline', () async {
      await start();
      final bloc = PluginBloc(repo);
      bloc.add(const LoadPluginsEvent());
      await settle();
      client.plugins = const GrpcError.unavailable();
      bloc.add(const RefreshPluginsEvent());
      await settle();
      expect((bloc.state as PluginsLoaded).offline, isFalse);
      bloc.add(const RefreshPluginsEvent());
      await settle();
      expect((bloc.state as PluginsLoaded).offline, isTrue);
      // The list itself is untouched.
      expect((bloc.state as PluginsLoaded).plugins, hasLength(2));
      await bloc.close();
    });
  });
}
