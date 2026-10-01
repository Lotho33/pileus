// Local bookkeeping for offline downloads — survives a server-side "delete
// after fetched" cleanup (contract: "l'indice locale del dispositivo resta
// la fonte di verità per i file già scaricati"). Phase 2 (the real device
// file fetch, not built yet) is meant to call [markFetched] once a download
// finishes and is verified complete; this class only tracks the bookkeeping
// (quality at fetch time, ack status) that Phase 2 and this ack queue need —
// not the file bytes themselves or where they live on disk.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  const LocalDownloadRecord({
    required this.downloadId,
    required this.qualityLabel,
    required this.fileBytes,
    required this.acked,
  });

  LocalDownloadRecord copyWith({bool? acked}) => LocalDownloadRecord(
        downloadId: downloadId,
        qualityLabel: qualityLabel,
        fileBytes: fileBytes,
        acked: acked ?? this.acked,
      );

  Map<String, dynamic> toJson() => {
        'downloadId': downloadId,
        'qualityLabel': qualityLabel,
        'fileBytes': fileBytes,
        'acked': acked,
      };

  factory LocalDownloadRecord.fromJson(Map<String, dynamic> j) =>
      LocalDownloadRecord(
        downloadId: j['downloadId'] as String? ?? '',
        qualityLabel: j['qualityLabel'] as String? ?? '',
        fileBytes: (j['fileBytes'] as num?)?.toInt() ?? 0,
        acked: j['acked'] as bool? ?? false,
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

  /// Called once the device's own copy of a download is verified complete
  /// (contract: "dimensione uguale a file_bytes, file integro") — records it
  /// with acked=false so [syncPendingAcks] picks it up.
  Future<void> markFetched(
    String downloadId, {
    required String qualityLabel,
    required int fileBytes,
  }) async {
    final all = _readAll();
    all[downloadId] = LocalDownloadRecord(
      downloadId: downloadId,
      qualityLabel: qualityLabel,
      fileBytes: fileBytes,
      acked: false,
    );
    await _writeAll(all);
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
      } catch (_) {
        // Leave pending — retried on the next call.
      }
    }
    if (changed) await _writeAll(all);
  }
}
