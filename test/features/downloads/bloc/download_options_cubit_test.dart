import 'package:fixnum/fixnum.dart' show Int64;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    show
        CreateDownloadRequest,
        CreateDownloadsRequest,
        CreateDownloadsResponse,
        DownloadInfo,
        DownloadOptionsResponse,
        DownloadTrack,
        DownloadVariant;
import 'package:pileus/features/downloads/bloc/download_options_cubit.dart';
import 'package:pileus/features/downloads/bloc/download_options_state.dart';
import 'package:pileus/features/downloads/download_format.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scripted [MediaRepository] — same "subclass, override only what's called"
/// approach as playback_bloc_test.dart's _ScriptedMediaRepository.
class _ScriptedMediaRepository extends MediaRepository {
  _ScriptedMediaRepository(
    super.prefs,
    super.interceptor, {
    this.optionsResponse,
    this.optionsError,
    this.createResponse,
    this.createError,
    this.createDownloadsResponse,
    this.createDownloadsError,
  });

  final DownloadOptionsResponse? optionsResponse;
  final Object? optionsError;
  final DownloadInfo? createResponse;
  final Object? createError;
  final CreateDownloadsResponse? createDownloadsResponse;
  final Object? createDownloadsError;
  int createCallCount = 0;
  int createDownloadsCallCount = 0;
  final List<CreateDownloadRequest> createRequests = [];
  final List<CreateDownloadsRequest> createDownloadsRequests = [];

  @override
  Future<DownloadOptionsResponse> getDownloadOptions(
      String pluginId, String streamId) async {
    if (optionsError != null) throw optionsError!;
    return optionsResponse!;
  }

  @override
  Future<DownloadInfo> createDownload(CreateDownloadRequest request) async {
    createRequests.add(request);
    createCallCount++;
    if (createError != null) throw createError!;
    return createResponse!;
  }

  @override
  Future<CreateDownloadsResponse> createDownloads(
      CreateDownloadsRequest request) async {
    createDownloadsRequests.add(request);
    createDownloadsCallCount++;
    if (createDownloadsError != null) throw createDownloadsError!;
    return createDownloadsResponse!;
  }
}

const _target = DownloadTarget(
  mediaId: 'ep1',
  streamId: 's1',
  parentId: 'series1',
  title: 'Episodio 1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('DownloadOptionsCubit.load', () {
    test('available: true with variants → DownloadOptionsReady, default '
        'audio pre-selected', () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [
          DownloadVariant(id: 'v1', label: '1080p', estimatedBytes: Int64(1000)),
          DownloadVariant(id: 'v2', label: '720p', estimatedBytes: Int64(500)),
        ],
        audio: [
          DownloadTrack(id: 'a1', language: 'ita', isDefault: true),
          DownloadTrack(id: 'a2', language: 'eng', isDefault: false),
        ],
        serverFreeBytes: Int64(1000000),
      );
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp);
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);

      await cubit.load('s1');

      final s = cubit.state;
      expect(s, isA<DownloadOptionsReady>());
      s as DownloadOptionsReady;
      expect(s.selectedVariantId, 'v1'); // best/first, per contract
      expect(s.selectedAudioIds, {'a1'}); // only the default track
      expect(s.scheduleKind, DownloadScheduleKind.now);
      expect(s.fitsServerSpace, isTrue);
    });

    test('available: false → DownloadOptionsUnavailable with the server '
        'reason verbatim', () async {
      final resp = DownloadOptionsResponse(
        available: false,
        unavailableReason: 'contenuto non scaricabile per questo plugin',
      );
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp);
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);

      await cubit.load('s1');

      expect(cubit.state, isA<DownloadOptionsUnavailable>());
      expect((cubit.state as DownloadOptionsUnavailable).reason,
          'contenuto non scaricabile per questo plugin');
    });

    test('available: true but no variants → treated as unavailable too', () async {
      final resp = DownloadOptionsResponse(available: true, variants: []);
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp);
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);

      await cubit.load('s1');

      expect(cubit.state, isA<DownloadOptionsUnavailable>());
    });

    test('a genuine RPC failure → DownloadOptionsError, not Unavailable', () async {
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsError:
              const GrpcError.custom(StatusCode.internal, 'boom'));
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);

      await cubit.load('s1');

      expect(cubit.state, isA<DownloadOptionsError>());
    });
  });

  group('DownloadOptionsCubit — selection + total size (space check)', () {
    late _ScriptedMediaRepository repo;
    late DownloadOptionsCubit cubit;

    setUp(() async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [
          DownloadVariant(id: 'v1', label: '1080p', estimatedBytes: Int64(900)),
        ],
        audio: [
          DownloadTrack(id: 'a1', isDefault: true, estimatedBytes: Int64(50)),
          DownloadTrack(id: 'a2', isDefault: false, estimatedBytes: Int64(50)),
        ],
        serverFreeBytes: Int64(920), // fits v1+a1 (950) NOT, only <=920
      );
      repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp);
      cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      await cubit.load('s1');
    });

    tearDown(() => cubit.close());

    test('total already over server_free_bytes with just the default audio',
        () {
      final s = cubit.state as DownloadOptionsReady;
      expect(s.totalBytes, 950); // 900 + 50
      expect(s.fitsServerSpace, isFalse);
    });

    test('adding a second audio track grows the total further', () {
      cubit.toggleAudio('a2');
      final s = cubit.state as DownloadOptionsReady;
      expect(s.totalBytes, 1000); // 900 + 50 + 50
      expect(s.fitsServerSpace, isFalse);
    });

    test('toggling the same track twice is a no-op', () {
      cubit.toggleAudio('a2');
      cubit.toggleAudio('a2');
      final s = cubit.state as DownloadOptionsReady;
      expect(s.selectedAudioIds, {'a1'});
    });
  });

  group('DownloadOptionsCubit.confirmSingle — one CreateDownload call', () {
    test('Submitted with the created info', () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [DownloadVariant(id: 'v1', estimatedBytes: Int64(10))],
      );
      final created = DownloadInfo(downloadId: 'd1', status: 'queued');
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp, createResponse: created);
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);
      await cubit.load('s1');

      await cubit.confirmSingle(_target);

      // cubit.state is a plain field, always current the instant
      // confirmSingle's Future resolves — unlike a stream listener's own
      // delivery, which runs on a separate microtask from the awaited
      // Future's completion and isn't guaranteed to have caught up yet.
      expect(cubit.state, isA<DownloadOptionsSubmitted>());
      expect((cubit.state as DownloadOptionsSubmitted).created, [created]);
      expect(repo.createRequests.single.mediaId, 'ep1');
      expect(repo.createRequests.single.variantId, 'v1');
      expect(repo.createDownloadsCallCount, 0); // never the batch RPC
    });

    test('FAILED_PRECONDITION surfaces the server message verbatim, no retry',
        () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [DownloadVariant(id: 'v1', estimatedBytes: Int64(10))],
      );
      const serverMessage = 'spazio insufficiente sul server';
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp,
          createError: const GrpcError.custom(
              StatusCode.failedPrecondition, serverMessage));
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);
      await cubit.load('s1');

      await cubit.confirmSingle(_target);

      expect(cubit.state, isA<DownloadOptionsSubmitFailed>());
      expect((cubit.state as DownloadOptionsSubmitFailed).message,
          serverMessage);
      expect(repo.createCallCount, 1); // never retried
    });
  });

  group('DownloadOptionsCubit.confirmBatch — one CreateDownloads call '
      '(contract: "sostituisce il ciclo di CreateDownload")', () {
    test('sends every target as one CreateDownloads request, criteria shared',
        () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [DownloadVariant(id: 'v1', estimatedBytes: Int64(300))],
        audio: [DownloadTrack(id: 'a1', isDefault: true, estimatedBytes: Int64(20))],
      );
      final created = [
        DownloadInfo(downloadId: 'd1', mediaId: 'ep1', status: 'queued'),
        DownloadInfo(downloadId: 'd2', mediaId: 'ep2', status: 'queued'),
      ];
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp,
          createDownloadsResponse: CreateDownloadsResponse(
              downloads: created, estimatedTotalBytes: Int64(640)));
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);
      await cubit.load('s1');

      const target2 = DownloadTarget(mediaId: 'ep2', streamId: 's2');
      await cubit.confirmBatch([_target, target2]);

      expect(repo.createDownloadsCallCount, 1); // ONE call, not a loop
      expect(repo.createCallCount, 0); // never the single-item RPC
      final req = repo.createDownloadsRequests.single;
      expect(req.items.map((i) => i.mediaId), ['ep1', 'ep2']);
      // Quality/audio choice is set once at the request level, not per item.
      expect(req.variantId, 'v1');
      expect(req.audioIds, ['a1']);

      final s = cubit.state;
      expect(s, isA<DownloadOptionsSubmitted>());
      s as DownloadOptionsSubmitted;
      expect(s.created, created);
      expect(s.serverEstimatedTotalBytes, 640);
    });

    test('a failure fails the whole batch (the server decides, not a '
        'client-side per-item loop)', () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [DownloadVariant(id: 'v1', estimatedBytes: Int64(10))],
      );
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp,
          createDownloadsError:
              const GrpcError.custom(StatusCode.failedPrecondition, 'pieno'));
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);
      await cubit.load('s1');

      const target2 = DownloadTarget(mediaId: 'ep2', streamId: 's2');
      await cubit.confirmBatch([_target, target2]);

      expect(cubit.state, isA<DownloadOptionsSubmitFailed>());
      expect((cubit.state as DownloadOptionsSubmitFailed).message, 'pieno');
      expect(repo.createDownloadsCallCount, 1);
    });

    test('estimateBatchBytes: client-side pre-confirm estimate is this '
        "episode's weight × N (contract, shown before the real call runs)",
        () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [DownloadVariant(id: 'v1', estimatedBytes: Int64(300))],
        audio: [DownloadTrack(id: 'a1', isDefault: true, estimatedBytes: Int64(20))],
      );
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp);
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);
      await cubit.load('s1');

      final s = cubit.state as DownloadOptionsReady;
      expect(s.totalBytes, 320); // 300 + 20
      expect(s.estimateBatchBytes(5), 1600); // × 5 episodes
    });
  });

  group('DownloadOptionsCubit — upgrade_if_better', () {
    test('defaults to true when quality_below_usual is flagged', () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [DownloadVariant(id: 'v1', estimatedBytes: Int64(10))],
        qualityBelowUsual: true,
      );
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp);
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);
      await cubit.load('s1');

      expect((cubit.state as DownloadOptionsReady).upgradeIfBetter, isTrue);
    });

    test('defaults to false otherwise, and the checkbox can be toggled',
        () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [DownloadVariant(id: 'v1', estimatedBytes: Int64(10))],
        qualityBelowUsual: false,
      );
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp);
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);
      await cubit.load('s1');

      expect((cubit.state as DownloadOptionsReady).upgradeIfBetter, isFalse);
      cubit.toggleUpgradeIfBetter();
      expect((cubit.state as DownloadOptionsReady).upgradeIfBetter, isTrue);
    });

    test('is threaded through to CreateDownloadRequest.upgradeIfBetter',
        () async {
      final resp = DownloadOptionsResponse(
        available: true,
        variants: [DownloadVariant(id: 'v1', estimatedBytes: Int64(10))],
        qualityBelowUsual: true,
      );
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          optionsResponse: resp,
          createResponse: DownloadInfo(downloadId: 'd1'));
      final cubit = DownloadOptionsCubit(repo, pluginId: 'p1');
      addTearDown(cubit.close);
      await cubit.load('s1');

      await cubit.confirmSingle(_target);

      expect(repo.createRequests.single.upgradeIfBetter, isTrue);
    });
  });
}
