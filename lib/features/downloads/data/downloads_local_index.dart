// Local bookkeeping for offline downloads copied onto this device — the
// source of truth for what is on disk here, whatever the server still has
// (contract: "l'indice locale del dispositivo resta la fonte di verità per
// i file già scaricati"). Holds enough of the download's metadata to list
// and play it with no server at all (a train), plus the ack queue and the
// quality the copy was taken at.
import 'dart:convert';

import 'package:fixnum/fixnum.dart' show Int64;
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/grpc/clients/media_client.dart' show DownloadInfo;
import '../../media/data/media_repository.dart';

class LocalDownloadRecord {
  final String downloadId;
  // DownloadInfo.quality_label as it was the moment this device fetched the
  // file — compared against the server's current value to notice the server
  // copy got upgraded since (contract point 5).
  final String qualityLabel;
  final int fileBytes;
  // Whether AckDownloadFetched has already succeeded for this download.
  final bool acked;
  // The file on this device ('' for a record from before local copies).
  final String localPath;
  // The profile that copied it: the list only shows a profile its own.
  final String profileId;
  final String pluginId;
  final String mediaId;
  final String parentId;
  final String title;
  final String seriesTitle;
  final String poster;
  final int seasonNumber;
  final int episodeNumber;
  final String container;
  final double durationSec;
  final int fetchedAt; // unix seconds

  const LocalDownloadRecord({
    required this.downloadId,
    required this.qualityLabel,
    required this.fileBytes,
    required this.acked,
    this.localPath = '',
    this.profileId = '',
    this.pluginId = '',
    this.mediaId = '',
    this.parentId = '',
    this.title = '',
    this.seriesTitle = '',
    this.poster = '',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.container = '',
    this.durationSec = 0,
    this.fetchedAt = 0,
  });

  LocalDownloadRecord copyWith({bool? acked}) => LocalDownloadRecord(
        downloadId: downloadId,
        qualityLabel: qualityLabel,
        fileBytes: fileBytes,
        acked: acked ?? this.acked,
        localPath: localPath,
        profileId: profileId,
        pluginId: pluginId,
        mediaId: mediaId,
        parentId: parentId,
        title: title,
        seriesTitle: seriesTitle,
        poster: poster,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        container: container,
        durationSec: durationSec,
        fetchedAt: fetchedAt,
      );

  /// The row the downloads page draws for a copy the server no longer
  /// lists (expired, deleted) or can't be asked about (offline).
  DownloadInfo toInfo() => DownloadInfo(
        downloadId: downloadId,
        pluginId: pluginId,
        mediaId: mediaId,
        parentId: parentId,
        title: title,
        seriesTitle: seriesTitle,
        poster: poster,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        status: 'completed',
        fileBytes: Int64(fileBytes),
        qualityLabel: qualityLabel,
        durationSec: durationSec,
        container: container,
        completedAt: Int64(fetchedAt),
      );

  Map<String, dynamic> toJson() => {
        'downloadId': downloadId,
        'qualityLabel': qualityLabel,
        'fileBytes': fileBytes,
        'acked': acked,
        'localPath': localPath,
        'profileId': profileId,
        'pluginId': pluginId,
        'mediaId': mediaId,
        'parentId': parentId,
        'title': title,
        'seriesTitle': seriesTitle,
        'poster': poster,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'container': container,
        'durationSec': durationSec,
        'fetchedAt': fetchedAt,
      };

  factory LocalDownloadRecord.fromJson(Map<String, dynamic> j) =>
      LocalDownloadRecord(
        downloadId: j['downloadId'] as String? ?? '',
        qualityLabel: j['qualityLabel'] as String? ?? '',
        fileBytes: (j['fileBytes'] as num?)?.toInt() ?? 0,
        acked: j['acked'] as bool? ?? false,
        localPath: j['localPath'] as String? ?? '',
        profileId: j['profileId'] as String? ?? '',
        pluginId: j['pluginId'] as String? ?? '',
        mediaId: j['mediaId'] as String? ?? '',
        parentId: j['parentId'] as String? ?? '',
        title: j['title'] as String? ?? '',
        seriesTitle: j['seriesTitle'] as String? ?? '',
        poster: j['poster'] as String? ?? '',
        seasonNumber: (j['seasonNumber'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episodeNumber'] as num?)?.toInt() ?? 0,
        container: j['container'] as String? ?? '',
        durationSec: (j['durationSec'] as num?)?.toDouble() ?? 0,
        fetchedAt: (j['fetchedAt'] as num?)?.toInt() ?? 0,
      );
}

class DownloadsLocalIndex {
  final SharedPreferences _prefs;
  static const _key = 'downloads_local_index';

  DownloadsLocalIndex(this._prefs);

  Map<String, LocalDownloadRecord> _readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
          k, LocalDownloadRecord.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      // Corrupt/foreign value under this key — start clean rather than
      // crashing the downloads page on it.
      return {};
    }
  }

  Future<void> _writeAll(Map<String, LocalDownloadRecord> all) => _prefs
      .setString(_key, jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))));

  LocalDownloadRecord? recordFor(String downloadId) => _readAll()[downloadId];

  /// The copies on this device that [profileId] may see, newest first.
  List<LocalDownloadRecord> localCopies(String? profileId) {
    final out = [
      for (final r in _readAll().values)
        if (r.localPath.isNotEmpty &&
            (r.profileId.isEmpty || r.profileId == profileId))
          r
    ]..sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
    return out;
  }

  /// Called once the device's own copy of a download is verified complete
  /// (contract: "dimensione uguale a file_bytes, file integro") — records it
  /// with acked=false so [syncPendingAcks] picks it up.
  Future<void> markFetched(
    DownloadInfo info, {
    required String localPath,
    required String profileId,
    required int fileBytes,
  }) async {
    final all = _readAll();
    all[info.downloadId] = LocalDownloadRecord(
      downloadId: info.downloadId,
      qualityLabel: info.qualityLabel,
      fileBytes: fileBytes,
      acked: false,
      localPath: localPath,
      profileId: profileId,
      pluginId: info.pluginId,
      mediaId: info.mediaId,
      parentId: info.parentId,
      title: info.title,
      seriesTitle: info.seriesTitle,
      poster: info.poster,
      seasonNumber: info.seasonNumber,
      episodeNumber: info.episodeNumber,
      container: info.container,
      durationSec: info.durationSec,
      fetchedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await _writeAll(all);
  }

  Future<void> remove(String downloadId) async {
    final all = _readAll();
    if (all.remove(downloadId) != null) await _writeAll(all);
  }

  List<String> pendingAckIds() => _readAll()
      .values
      .where((r) => !r.acked)
      .map((r) => r.downloadId)
      .toList();

  /// True once a download this device already fetched comes back from the
  /// server with a different quality_label than what was saved at fetch
  /// time — the server copy was re-prepared (e.g. an upgrade_pending retry
  /// landed a better rendition) since this device last fetched it. The
  /// downloads page offers "Scarica di nuovo in qualità migliore" for this
  /// (contract point 5); no record at all (never fetched) is NOT a change.
  bool hasQualityChanged(String downloadId, String currentServerQualityLabel) {
    final r = recordFor(downloadId);
    if (r == null) return false;
    return r.qualityLabel != currentServerQualityLabel;
  }

  /// Sends AckDownloadFetched for every not-yet-acked local record. Safe to
  /// call repeatedly — e.g. every app start while online (contract: "riprova
  /// al prossimo avvio online", "coda come per l'avanzamento offline") — each
  /// id is marked acked locally the instant its RPC succeeds, so it's never
  /// sent twice, and one id failing (still offline, transient error) never
  /// blocks the others in the same pass.
  Future<void> syncPendingAcks(MediaRepository repo) async {
    final all = _readAll();
    var changed = false;
    for (final id in pendingAckIds()) {
      try {
        final ok = await repo.ackDownloadFetched(id);
        if (ok) {
          all[id] = all[id]!.copyWith(acked: true);
          changed = true;
        }
      } on GrpcError catch (e) {
        // The server already forgot it (expired, deleted): nothing to ack.
        if (e.code == StatusCode.notFound) {
          all[id] = all[id]!.copyWith(acked: true);
          changed = true;
        }
      } catch (_) {
        // Leave pending — retried on the next call.
      }
    }
    if (changed) await _writeAll(all);
  }
}
