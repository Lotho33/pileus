import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    show
        BrowseResponse,
        EpisodeInfo,
        ResolveResponse,
        ResolveStreamEvent,
        SeasonInfo,
        StreamSource,
        StreamsResponse;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/bloc/playback_bloc.dart';
import 'package:pileus/features/player/bloc/playback_event.dart';
import 'package:pileus/features/player/bloc/playback_state.dart';
import 'package:pileus/features/player/source_continuity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The warm ahead of Play only helps when it resolves exactly the stream id
/// the Play then sends to ResolveStream (mycelium coalesces on it, plugins
/// cache per language). These pin the two sides to the same choice.
class _Repo extends MediaRepository {
  _Repo(SharedPreferences prefs) : super(prefs, AuthInterceptor());

  final Map<String, List<StreamSource>> streams = {};
  final Map<String, List<EpisodeInfo>> seasons = {};
  final List<String> resolved = [];
  final List<bool> browseCached = [];

  @override
  Future<StreamsResponse> getStreams(String pluginId, String mediaId) async =>
      StreamsResponse(sources: streams[mediaId] ?? const []);

  @override
  Future<BrowseResponse> browse(
      String pluginId, String parentId, String childId,
      {bool cache = false}) async {
    browseCached.add(cache);
    return BrowseResponse(episodes: seasons[parentId] ?? const []);
  }

  @override
  Stream<ResolveStreamEvent> resolveStream(String pluginId, String streamId,
      {double startPositionSec = 0, bool takeOver = false}) {
    resolved.add(streamId);
    return Stream.value(ResolveStreamEvent(
        result: ResolveResponse(resolvedUrl: 'http://x/$streamId')));
  }
}

StreamSource _src(String id, String label) =>
    StreamSource(id: id, label: label);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo(await SharedPreferences.getInstance());
    // The language is part of the stream id, as on real plugins.
    repo.streams['603'] = [
      _src('603:it', 'Italiano'),
      _src('603:en', 'Inglese')
    ];
  });

  Future<String> playedStreamId(String mediaId, {String label = ''}) async {
    final bloc = PlaybackBloc(repo);
    bloc.add(InitializeVideoEvent(
        pluginId: 'movies', mediaId: mediaId, preferredLabel: label));
    await bloc.stream.firstWhere((s) => s is PlaybackReady);
    await bloc.close();
    return repo.resolved.last;
  }

  for (final label in ['', 'Inglese', 'inglese', 'Giapponese']) {
    test('Play and warm pick the same stream (preferred label "$label")',
        () async {
      final warm = await playStreamIdFor(repo,
          pluginId: 'movies', mediaId: '603', preferredLabel: label);
      expect(await playedStreamId('603', label: label), warm);
    });
  }

  test('no sources → nothing to warm', () async {
    expect(await playStreamIdFor(repo, pluginId: 'movies', mediaId: 'none'),
        isNull);
  });

  group('defaultPlayStreamId (details main button, nothing to resume)', () {
    test('movie: the title itself, first source', () async {
      expect(
          await defaultPlayStreamId(repo,
              pluginId: 'movies', itemId: '603', isSeries: false),
          '603:it');
    });

    test('series: first episode of the first season that has any', () async {
      repo.seasons['s0'] = const [];
      repo.seasons['s1'] = [
        EpisodeInfo(id: '9_1_1'),
        EpisodeInfo(id: '9_1_2'),
      ];
      repo.streams['9_1_1'] = [_src('9_1_1:it', 'Italiano')];
      final id = await defaultPlayStreamId(repo,
          pluginId: 'series',
          itemId: '9',
          isSeries: true,
          seasons: [
            SeasonInfo(directoryId: 's0', episodeCount: 0),
            SeasonInfo(directoryId: 's1', episodeCount: 2),
          ]);
      expect(id, '9_1_1:it');
      // The season list the page already loaded is reused, not refetched.
      expect(repo.browseCached, [true]);
    });

    test('series with no seasons loaded yet, or an empty season: null',
        () async {
      expect(
          await defaultPlayStreamId(repo,
              pluginId: 'series', itemId: '9', isSeries: true),
          isNull);
      expect(
          await defaultPlayStreamId(repo,
              pluginId: 'series',
              itemId: '9',
              isSeries: true,
              seasons: [SeasonInfo(directoryId: 'empty', episodeCount: 3)]),
          isNull);
    });
  });
}
