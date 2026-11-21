import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart' show DownloadInfo;
import 'package:pileus/features/downloads/data/downloads_local_index.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scripted [MediaRepository] — same "subclass, override only what's
/// called" approach used throughout this app's bloc tests.
class _ScriptedMediaRepository extends MediaRepository {
  _ScriptedMediaRepository(super.prefs, super.interceptor,
      {this.results = const {}});

  /// downloadId -> what ackDownloadFetched should do: true/false for a
  /// result, or a thrown Object for a network/RPC failure.
  final Map<String, Object> results;
  final List<String> ackedCalls = [];

  @override
  Future<bool> ackDownloadFetched(String downloadId) async {
    ackedCalls.add(downloadId);
    final r = results[downloadId];
    if (r is Exception || r is Error) throw r as Object;
    return r as bool? ?? true;
  }
}

Future<void> _mark(
        DownloadsLocalIndex index, String id, String quality, int bytes,
        {String path = '', String profileId = ''}) =>
    index.markFetched(
      DownloadInfo(downloadId: id, qualityLabel: quality, title: 'T $id'),
      localPath: path,
      profileId: profileId,
      fileBytes: bytes,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('DownloadsLocalIndex — markFetched / recordFor', () {
    test('a fresh record starts unacked', () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'd1', '1080p', 1000);

      final r = index.recordFor('d1');
      expect(r, isNotNull);
      expect(r!.qualityLabel, '1080p');
      expect(r.fileBytes, 1000);
      expect(r.acked, isFalse);
    });

    test('survives round-tripping through a fresh index instance '
        '(persisted, not just in-memory)', () async {
      await _mark(DownloadsLocalIndex(prefs), 'd1', '720p', 500);

      final reopened = DownloadsLocalIndex(prefs);
      expect(reopened.recordFor('d1')?.qualityLabel, '720p');
    });

    test('unknown id has no record', () {
      final index = DownloadsLocalIndex(prefs);
      expect(index.recordFor('missing'), isNull);
    });
  });

  group('DownloadsLocalIndex.hasQualityChanged', () {
    test('false when never fetched at all', () {
      final index = DownloadsLocalIndex(prefs);
      expect(index.hasQualityChanged('d1', '1080p'), isFalse);
    });

    test('false when the server still reports the same quality_label',
        () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'd1', '1080p', 1000);
      expect(index.hasQualityChanged('d1', '1080p'), isFalse);
    });

    test('true once the server reports a different quality_label — offer '
        '"Scarica di nuovo in qualità migliore"', () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'd1', '720p', 500);
      expect(index.hasQualityChanged('d1', '1080p'), isTrue);
    });
  });

  group('DownloadsLocalIndex.syncPendingAcks', () {
    test('acks every pending record exactly once', () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'd1', '1080p', 100);
      await _mark(index, 'd2', '720p', 50);
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor());

      await index.syncPendingAcks(repo);

      expect(repo.ackedCalls.toSet(), {'d1', 'd2'});
      expect(index.recordFor('d1')!.acked, isTrue);
      expect(index.recordFor('d2')!.acked, isTrue);
      expect(index.pendingAckIds(), isEmpty);
    });

    test('a second sync call never re-acks an already-acked download',
        () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'd1', '1080p', 100);
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor());

      await index.syncPendingAcks(repo);
      await index.syncPendingAcks(repo);
      await index.syncPendingAcks(repo);

      expect(repo.ackedCalls, ['d1']); // called exactly once, ever
    });

    test('a failure (network/RPC) leaves the record pending for the next '
        'sync — retried on next app start, per the contract', () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'd1', '1080p', 100);
      final failingRepo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          results: {'d1': Exception('offline')});

      await index.syncPendingAcks(failingRepo);

      expect(index.recordFor('d1')!.acked, isFalse);
      expect(index.pendingAckIds(), ['d1']);

      // Network's back — a later sync (e.g. next app start) succeeds and
      // finally marks it acked.
      final workingRepo = _ScriptedMediaRepository(prefs, AuthInterceptor());
      await index.syncPendingAcks(workingRepo);

      expect(index.recordFor('d1')!.acked, isTrue);
      expect(workingRepo.ackedCalls, ['d1']);
    });

    test('one failing id in a batch does not block the others in the same '
        'pass', () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'd1', '1080p', 100);
      await _mark(index, 'd2', '720p', 50);
      final repo = _ScriptedMediaRepository(prefs, AuthInterceptor(),
          results: {'d1': Exception('boom')});

      await index.syncPendingAcks(repo);

      expect(index.recordFor('d1')!.acked, isFalse);
      expect(index.recordFor('d2')!.acked, isTrue);
    });
  });

  group('DownloadsLocalIndex — copies on the device', () {
    test('localCopies: only records with a file, only the profile\'s own',
        () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'mine', '1080p', 10,
          path: '/x/mine.mkv', profileId: 'p1');
      await _mark(index, 'other', '1080p', 10,
          path: '/x/other.mkv', profileId: 'p2');
      await _mark(index, 'nofile', '1080p', 10, profileId: 'p1');

      expect(index.localCopies('p1').map((r) => r.downloadId), ['mine']);
    });

    test('toInfo keeps what the page needs to list and play it offline',
        () async {
      final index = DownloadsLocalIndex(prefs);
      await index.markFetched(
        DownloadInfo(
          downloadId: 'd1',
          pluginId: 'example.series',
          mediaId: 'ep-5',
          parentId: 'show-1',
          title: 'Episodio 5',
          seriesTitle: 'Serie',
          seasonNumber: 2,
          episodeNumber: 5,
          container: 'mkv',
        ),
        localPath: '/x/d1.mkv',
        profileId: 'p1',
        fileBytes: 42,
      );
      final info = index.recordFor('d1')!.toInfo();
      expect(info.status, 'completed');
      expect(info.pluginId, 'example.series');
      expect(info.mediaId, 'ep-5');
      expect(info.parentId, 'show-1');
      expect(info.seasonNumber, 2);
      expect(info.fileBytes.toInt(), 42);
      expect(info.fileUrl, isEmpty);
    });

    test('remove forgets the record', () async {
      final index = DownloadsLocalIndex(prefs);
      await _mark(index, 'd1', '1080p', 10, path: '/x/d1.mkv');
      await index.remove('d1');
      expect(index.recordFor('d1'), isNull);
    });
  });
}
