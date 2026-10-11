import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    show StreamSource, StreamsResponse;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/audio_lang_pref.dart';
import 'package:pileus/features/player/engine/player_engine.dart'
    show MediaTrack;
import 'package:pileus/features/player/episode_prefetch.dart';
import 'package:pileus/features/player/models/playback_args.dart';
import 'package:pileus/features/player/source_continuity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GetStreams scripted per media id; an id absent from [_byId] throws (a
/// lookup failure — server unreachable, plugin rejecting a stream id, …).
class _FakeRepo extends MediaRepository {
  _FakeRepo(this._byId, SharedPreferences prefs)
      : super(prefs, AuthInterceptor());

  final Map<String, List<StreamSource>> _byId;
  final List<String> calls = [];

  @override
  Future<StreamsResponse> getStreams(String pluginId, String mediaId) async {
    calls.add(mediaId);
    final s = _byId[mediaId];
    if (s == null) throw StateError('no streams for $mediaId');
    return StreamsResponse(sources: s);
  }
}

StreamSource _src(String id, String label) =>
    StreamSource(id: id, label: label);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final ep2 = [_src('ep2|ita', 'ITA'), _src('ep2|sub', 'SUB ITA')];

  group('pickSourceByLabel', () {
    test('matches the label case-insensitively', () {
      expect(pickSourceByLabel(ep2, 'sub ita')!.id, 'ep2|sub');
    });
    test('falls back to the first source when the label is unknown/empty',
        () {
      expect(pickSourceByLabel(ep2, 'ENG')!.id, 'ep2|ita');
      expect(pickSourceByLabel(ep2, '')!.id, 'ep2|ita');
    });
    test('null only with no sources', () {
      expect(pickSourceByLabel(const [], 'ITA'), isNull);
    });
  });

  group('inferSourceLabel (Continue Watching launch → label of its stream)',
      () {
    test('finds the label of the stream id among the episode sources',
        () async {
      final repo = _FakeRepo({'ep2': ep2}, prefs);
      expect(
          await inferSourceLabel(repo,
              pluginId: 'p', episodeId: 'ep2', streamId: 'ep2|sub'),
          'SUB ITA');
    });
    test('null when the stored id is the bare episode id (legacy row)',
        () async {
      final repo = _FakeRepo({'ep2': ep2}, prefs);
      expect(
          await inferSourceLabel(repo,
              pluginId: 'p', episodeId: 'ep2', streamId: 'ep2'),
          isNull);
      expect(repo.calls, isEmpty, reason: 'no lookup needed for that case');
    });
    test('null (never throws) when the lookup fails', () async {
      final repo = _FakeRepo({}, prefs);
      expect(
          await inferSourceLabel(repo,
              pluginId: 'p', episodeId: 'ep2', streamId: 'ep2|sub'),
          isNull);
    });
  });

  group('streamIdForNextEpisode (roll-forward keeps the language)', () {
    test('uses the prefetched stream when it covers that episode', () async {
      final repo = _FakeRepo({}, prefs);
      const pre = PrefetchedEpisode(
        mediaId: 'ep2',
        streamId: 'ep2|sub',
        resolvedUrl: 'http://x',
        httpHeaders: {},
        sourceLabel: 'SUB ITA',
      );
      expect(
          await streamIdForNextEpisode(repo,
              pluginId: 'p',
              nextEpisodeId: 'ep2',
              sourceLabel: 'SUB ITA',
              prefetched: pre),
          'ep2|sub');
      expect(repo.calls, isEmpty);
    });
    test('otherwise looks up the same-label source', () async {
      final repo = _FakeRepo({'ep2': ep2}, prefs);
      expect(
          await streamIdForNextEpisode(repo,
              pluginId: 'p', nextEpisodeId: 'ep2', sourceLabel: 'SUB ITA'),
          'ep2|sub');
    });
    test('ignores a prefetch for a different episode', () async {
      final repo = _FakeRepo({'ep2': ep2}, prefs);
      const pre = PrefetchedEpisode(
        mediaId: 'ep9',
        streamId: 'ep9|sub',
        resolvedUrl: 'http://x',
        httpHeaders: {},
        sourceLabel: 'SUB ITA',
      );
      expect(
          await streamIdForNextEpisode(repo,
              pluginId: 'p',
              nextEpisodeId: 'ep2',
              sourceLabel: 'SUB ITA',
              prefetched: pre),
          'ep2|sub');
    });
    test('falls back to the bare episode id when the lookup fails', () async {
      final repo = _FakeRepo({}, prefs);
      expect(
          await streamIdForNextEpisode(repo,
              pluginId: 'p', nextEpisodeId: 'ep2', sourceLabel: 'ITA'),
          'ep2');
    });
  });

  group('matchAudioTrack', () {
    const tracks = [
      MediaTrack(id: '0', label: 'ITA · Italiano'),
      MediaTrack(id: '1', label: 'JPN · Japanese'),
      MediaTrack(id: '2', label: 'SLV · Slovenian'),
    ];
    test('exact label first', () {
      expect(matchAudioTrack(tracks, 'JPN · Japanese')!.id, '1');
    });
    test('same language token when the label text differs', () {
      expect(matchAudioTrack(tracks, 'JPN · Giapponese')!.id, '1');
      expect(matchAudioTrack(tracks, 'jpn')!.id, '1');
    });
    test('never a loose substring match', () {
      expect(matchAudioTrack(tracks, 'en'), isNull);
      expect(matchAudioTrack(tracks, 'SL'), isNull);
    });
  });

  group('PlaybackArgs.withSeriesMeta', () {
    final base = PlaybackArgs.fromExtra(
      {'title': 'Ep 1', 'showTitle': 'Già noto', 'rating': 7.5},
      pluginId: 'p',
      mediaId: 'm',
    );
    test('fills only what is missing', () {
      final a = base.withSeriesMeta(
        parentId: 'series1',
        showTitle: 'Altro',
        plot: 'Trama serie',
        genres: const ['Drama'],
        rating: 9,
        year: 2020,
      );
      expect(a.parentId, 'series1');
      expect(a.showTitle, 'Già noto');
      expect(a.plot, 'Trama serie');
      expect(a.genres, ['Drama']);
      expect(a.rating, 7.5);
      expect(a.year, 2020);
      expect(a.title, 'Ep 1');
    });
    test('empty values keep the current ones', () {
      final a = base.withSeriesMeta();
      expect(a.parentId, '');
      expect(a.showTitle, 'Già noto');
      expect(a.rating, 7.5);
    });
  });
}
