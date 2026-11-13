// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    hide ContinueWatchingItem;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/media/my_list.dart';
import 'package:pileus/features/media/presentation/my_list_screen.dart';
import 'package:pileus/shared/widgets/media_catalog_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClient implements MediaGrpcClient {
  List<MyListItem> stored = [];
  Object? failSet;
  Object? failGet;
  int gets = 0;

  @override
  Future<MyListResponse> getMyList(MyListRequest request) async {
    gets++;
    if (failGet != null) throw failGet!;
    return MyListResponse(items: stored);
  }

  @override
  Future<SetMyListItemResponse> setMyListItem(
      SetMyListItemRequest request) async {
    if (failSet != null) throw failSet!;
    final it = request.item;
    stored = [
      for (final s in stored)
        if (!(s.pluginId == it.pluginId && s.mediaId == it.mediaId)) s
    ];
    if (request.inList) stored = [it, ...stored];
    return SetMyListItemResponse(ok: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MyListItem _item(String plugin, String id) => MyListItem(
    pluginId: plugin, mediaId: id, title: id.toUpperCase(), mediaType: 'movie');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClient client;
  late AuthInterceptor auth;
  late MediaRepository repo;
  final list = MyList.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    client = _FakeClient();
    auth = AuthInterceptor()..setCredentials('jwt', 'anna');
    getIt.registerSingleton<MediaGrpcClient>(client);
    getIt.registerSingleton<AuthInterceptor>(auth);
    repo = MediaRepository(prefs, auth);
    getIt.registerSingleton<MediaRepository>(repo);
    list.resetForTest();
  });

  tearDown(() async => getIt.reset());

  test('loads per profile and hides another profile\'s list', () async {
    client.stored = [_item('p', 'a')];
    await list.refresh();
    expect(list.contains('p', 'a'), isTrue);
    auth.setCredentials('jwt', 'luca');
    expect(list.items, isEmpty);
  });

  test('toggle is optimistic and rolls back on failure', () async {
    await list.refresh();
    expect(await list.toggle(_item('p', 'a')), isTrue);
    expect(client.stored.single.mediaId, 'a');

    client.failSet = const GrpcError.unavailable();
    final pending = list.toggle(_item('p', 'a'));
    expect(list.contains('p', 'a'), isFalse); // flipped at once
    expect(await pending, isNull);
    expect(list.contains('p', 'a'), isTrue); // rolled back
  });

  test('a server without the RPCs turns the feature off', () async {
    client.failGet = const GrpcError.unimplemented();
    await list.refresh();
    expect(list.supported, isFalse);
    expect(list.items, isEmpty);
  });

  test('a saved card keeps the metadata the home shows', () {
    final card = MyList.toCatalogItem(MyList.itemFrom(
        'p',
        CatalogItem(id: 'x', title: 'X', mediaType: 'series', extra: {
          'anilist_id': '42',
          'plot': 'dal catalogo',
        }.entries),
        genres: ['Azione', 'Drama'],
        fanartUrl: 'f'));
    expect(card.extra['plot'], 'dal catalogo');
    expect(card.extra['genres'], 'Azione, Drama');
    expect(card.extra['anilist_id'], '42');
    expect(card.extra['fanart_url'], 'f');
    expect(card.isDir, isTrue);
  });

  testWidgets('the page: every plugin, titles under the posters fit',
      (tester) async {
    client.stored = [
      for (var i = 0; i < 20; i++) _item(i.isEven ? 'p' : 'q', 'id$i')
    ];
    await tester.runAsync(list.refresh);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MyListScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull); // no RenderFlex overflow
    expect(find.byType(MediaCatalogCard), findsWidgets);
  });

  testWidgets('empty list: Back has the focus', (tester) async {
    await tester.runAsync(list.refresh);
    await tester.pumpWidget(const MaterialApp(home: MyListScreen()));
    await tester.pump();
    await tester.pump();
    expect(find.text('Non hai ancora salvato nessun titolo.'), findsOneWidget);
    final primary = FocusManager.instance.primaryFocus;
    expect(primary, isNotNull);
    expect(primary, isNot(isA<FocusScopeNode>()));
  });
}
