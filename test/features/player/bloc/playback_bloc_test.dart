import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    show
        ResolveResponse,
        ResolveStreamEvent,
        StreamSource,
        StreamsResponse;
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:pileus/features/player/bloc/playback_bloc.dart';
import 'package:pileus/features/player/bloc/playback_event.dart';
import 'package:pileus/features/player/bloc/playback_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [MediaRepository] whose `resolveStream` is fully scripted, so
/// [PlaybackBloc]'s retry/no-retry decision can be exercised without a real
/// gRPC channel. The base class has no interface split (it's a concrete
/// class reached through `getIt` everywhere else), so this subclasses it and
/// overrides only the one method `_onSelectStream` actually calls — the
/// super constructor's `SharedPreferences`/`AuthInterceptor` are never
/// touched by that path.
class _ScriptedMediaRepository extends MediaRepository {
  _ScriptedMediaRepository(
    this._responses,
    SharedPreferences prefs,
    AuthInterceptor interceptor, {
    StreamsResponse? streamsResponse,
  })  : _streamsResponse = streamsResponse,
        super(prefs, interceptor);

  /// One entry consumed per `resolveStream` call (one per resolve attempt,
  /// i.e. the initial try plus every retry).
  final List<Stream<ResolveStreamEvent> Function()> _responses;
  int callCount = 0;
  // Every call's own takeOver flag, in call order — lets a test assert the
  // second (take-over) call was actually made with take_over = true, not
  // just that a second call happened.
  final List<bool> takeOverCalls = [];

  // Only used by _onInitialize (InitializeVideoEvent) — null is fine for
  // every test that only ever dispatches SelectStreamEvent directly.
  final StreamsResponse? _streamsResponse;

  @override
  Future<StreamsResponse> getStreams(String pluginId, String mediaId) async =>
      _streamsResponse!;

  @override
  Stream<ResolveStreamEvent> resolveStream(String pluginId, String streamId,
      {double startPositionSec = 0, bool takeOver = false}) {
    final i = callCount;
    callCount++;
    takeOverCalls.add(takeOver);
    return _responses[i]();
  }
}

ResolveStreamEvent _resultEvent(String url) =>
    ResolveStreamEvent(result: ResolveResponse(resolvedUrl: url));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('PlaybackBloc._onSelectStream — FAILED_PRECONDITION', () {
    test(
        'fails immediately with the server message (a plugin\'s own '
        'precondition failure, not the single-device lease — that moved to '
        'ABORTED, see the group below), no retry states, no raw '
        'GrpcError toString() leaking through', () async {
      const serverMessage = 'questo plugin richiede un abbonamento attivo';
      final repo = _ScriptedMediaRepository(
        [
          () => Stream.error(
              const GrpcError.custom(StatusCode.failedPrecondition, serverMessage)),
        ],
        prefs,
        AuthInterceptor(),
      );
      final bloc = PlaybackBloc(repo);
      addTearDown(bloc.close);

      final states = <PlaybackState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const SelectStreamEvent(pluginId: 'p1', streamId: 's1'));
      await bloc.stream.firstWhere((s) => s is PlaybackFailed);
      await sub.cancel();

      expect(states, hasLength(2));
      expect(states[0], isA<ResolvingMediaStream>());
      expect(states[1], isA<PlaybackFailed>());
      expect((states[1] as PlaybackFailed).errorMessage, serverMessage);
      // Only one resolveStream call: the retry loop never engaged.
      expect(repo.callCount, 1);
    });
  });

  group('PlaybackBloc._onSelectStream — ABORTED (single-device lease, '
      'contract "One device playing per profile")', () {
    test(
        'PlaybackPlayingElsewhere carries the server message and this '
        'attempt\'s own pluginId/streamId/startPositionSec, no retry states',
        () async {
      const serverMessage =
          'questo profilo è già in riproduzione su «TV salotto»';
      final repo = _ScriptedMediaRepository(
        [
          () => Stream.error(
              const GrpcError.custom(StatusCode.aborted, serverMessage)),
        ],
        prefs,
        AuthInterceptor(),
      );
      final bloc = PlaybackBloc(repo);
      addTearDown(bloc.close);

      final states = <PlaybackState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const SelectStreamEvent(
          pluginId: 'p1', streamId: 's1', startPositionSec: 42));
      await bloc.stream.firstWhere((s) => s is PlaybackPlayingElsewhere);
      await sub.cancel();

      expect(states, hasLength(2));
      expect(states[0], isA<ResolvingMediaStream>());
      final elsewhere = states[1] as PlaybackPlayingElsewhere;
      expect(elsewhere.message, serverMessage);
      expect(elsewhere.pluginId, 'p1');
      expect(elsewhere.streamId, 's1');
      expect(elsewhere.startPositionSec, 42);
      // No retry loop — a plain retry (without take_over) would just fail
      // the same way again.
      expect(repo.callCount, 1);
      expect(repo.takeOverCalls, [false]);
    });

    test('"Guarda qui" resolves again with take_over = true, same '
        'stream_id/start_position_sec', () async {
      final repo = _ScriptedMediaRepository(
        [
          () => Stream.error(const GrpcError.custom(
              StatusCode.aborted, 'in riproduzione altrove')),
          () => Stream.value(_resultEvent('https://example/stream.m3u8')),
        ],
        prefs,
        AuthInterceptor(),
      );
      final bloc = PlaybackBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const SelectStreamEvent(
          pluginId: 'p1', streamId: 's1', startPositionSec: 42));
      final elsewhere = await bloc.stream
          .firstWhere((s) => s is PlaybackPlayingElsewhere) as PlaybackPlayingElsewhere;

      // What the UI's "Guarda qui" button dispatches.
      bloc.add(SelectStreamEvent(
        pluginId: elsewhere.pluginId,
        streamId: elsewhere.streamId,
        startPositionSec: elsewhere.startPositionSec,
        takeOver: true,
      ));
      final ready =
          await bloc.stream.firstWhere((s) => s is PlaybackReady) as PlaybackReady;

      expect(ready.resolvedUrl, 'https://example/stream.m3u8');
      expect(repo.callCount, 2);
      expect(repo.takeOverCalls, [false, true]);
    });
  });

  group('PlaybackBloc._onInitialize — InitializeVideoEvent.takeOver', () {
    test('"Riprendi qui" (mid-playback take-over, which has no already-'
        'resolved stream_id) threads takeOver through to the internally-'
        'dispatched SelectStreamEvent, same as any other from-scratch '
        'InitializeVideoEvent retry', () async {
      final repo = _ScriptedMediaRepository(
        [() => Stream.value(_resultEvent('https://example/stream.m3u8'))],
        prefs,
        AuthInterceptor(),
        streamsResponse: StreamsResponse(
            sources: [StreamSource(id: 's1', label: 'Default')]),
      );
      final bloc = PlaybackBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const InitializeVideoEvent(
        pluginId: 'p1',
        mediaId: 'm1',
        startPositionSec: 930,
        takeOver: true,
      ));
      final ready =
          await bloc.stream.firstWhere((s) => s is PlaybackReady) as PlaybackReady;

      expect(ready.resolvedUrl, 'https://example/stream.m3u8');
      expect(repo.takeOverCalls, [true]);
    });

    test('the ordinary (non-take-over) path still defaults to false', () async {
      final repo = _ScriptedMediaRepository(
        [() => Stream.value(_resultEvent('https://example/stream.m3u8'))],
        prefs,
        AuthInterceptor(),
        streamsResponse: StreamsResponse(
            sources: [StreamSource(id: 's1', label: 'Default')]),
      );
      final bloc = PlaybackBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const InitializeVideoEvent(pluginId: 'p1', mediaId: 'm1'));
      await bloc.stream.firstWhere((s) => s is PlaybackReady);

      expect(repo.takeOverCalls, [false]);
    });
  });

  group('PlaybackBloc._onSelectStream — UNAVAILABLE', () {
    test('still retries (unlike FAILED_PRECONDITION), showing PlaybackRetrying',
        () async {
      final repo = _ScriptedMediaRepository(
        [
          () =>
              Stream.error(const GrpcError.unavailable('server non raggiungibile')),
          () =>
              Stream.error(const GrpcError.unavailable('server non raggiungibile')),
        ],
        prefs,
        AuthInterceptor(),
      );
      final bloc = PlaybackBloc(repo);
      addTearDown(bloc.close);

      final states = <PlaybackState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const SelectStreamEvent(pluginId: 'p1', streamId: 's1'));
      // The bloc's own retry schedule waits 2s before the first retry
      // attempt — wait for that state rather than a fixed shorter delay.
      await bloc.stream.firstWhere((s) => s is PlaybackRetrying);
      await sub.cancel();

      expect(states.first, isA<ResolvingMediaStream>());
      expect(states.last, isA<PlaybackRetrying>());
      expect((states.last as PlaybackRetrying).attempt, 1);
      expect((states.last as PlaybackRetrying).of, 3);
      // Closing here (via addTearDown) cuts the retry loop short instead of
      // waiting out the full 2+5+10s budget — `isClosed` checks in the bloc
      // make that safe.
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('PlaybackBloc._onSelectStream — success and no-result paths', () {
    test('PlaybackReady carries the resolved URL through untouched', () async {
      final repo = _ScriptedMediaRepository(
        [() => Stream.value(_resultEvent('https://example/stream.m3u8'))],
        prefs,
        AuthInterceptor(),
      );
      final bloc = PlaybackBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const SelectStreamEvent(pluginId: 'p1', streamId: 's1'));
      final ready =
          await bloc.stream.firstWhere((s) => s is PlaybackReady) as PlaybackReady;
      expect(ready.resolvedUrl, 'https://example/stream.m3u8');
      expect(repo.callCount, 1);
    });

    test('a generic (non-GrpcError) exception still shows toString()',
        () async {
      final repo = _ScriptedMediaRepository(
        [() => Stream.error(Exception('boom'))],
        prefs,
        AuthInterceptor(),
      );
      final bloc = PlaybackBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const SelectStreamEvent(pluginId: 'p1', streamId: 's1'));
      await bloc.stream.firstWhere((s) => s is PlaybackRetrying);
      // Non-FAILED_PRECONDITION errors still go through the retry loop —
      // just confirms this test's exception doesn't short-circuit like
      // FAILED_PRECONDITION does.
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
