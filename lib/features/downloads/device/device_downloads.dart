import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/auth_interceptor.dart';
import '../../../core/grpc/clients/media_client.dart' show DownloadInfo;
import '../../media/data/media_repository.dart';
import '../data/downloads_local_index.dart';
import 'device_files.dart';

/// One copy onto this device in progress (or failed).
class DeviceTransfer {
  final int received;
  final int total;
  final bool running; // false: queued behind another one
  final String error; // '' while fine
  const DeviceTransfer({
    this.received = 0,
    this.total = 0,
    this.running = false,
    this.error = '',
  });

  double get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : 0;
}

/// Copies finished server downloads onto this device, on request only: the
/// server keeps its copy (it stays there for every profile and device until
/// it expires or is deleted), this just adds one on the phone/PC that plays
/// with no server at all. One file at a time, resumed from where it
/// stopped (a `.part` next to the final file) after a dropped connection
/// or an app restart. Lives for the whole app session, so a copy carries
/// on when the downloads page is closed.
class DeviceDownloads extends ChangeNotifier {
  DeviceDownloads._();
  static final DeviceDownloads instance = DeviceDownloads._();

  bool get supported => deviceFilesSupported;

  DownloadsLocalIndex get _index =>
      DownloadsLocalIndex(getIt<SharedPreferences>());

  final Map<String, DeviceTransfer> _transfers = {};
  final List<DownloadInfo> _queue = [];
  final Set<String> _cancelled = {};
  bool _working = false;

  DeviceTransfer? transferFor(String downloadId) => _transfers[downloadId];

  /// The playable file on this device for [downloadId], or null.
  String? localPathFor(String downloadId) {
    if (!supported) return null;
    final r = _index.recordFor(downloadId);
    if (r == null || r.localPath.isEmpty) return null;
    return localFileExists(r.localPath) ? r.localPath : null;
  }

  /// This profile's copies on the device (files that went missing dropped).
  List<LocalDownloadRecord> localCopies() {
    if (!supported) return const [];
    final pid = getIt<AuthInterceptor>().profileId;
    return [
      for (final r in _index.localCopies(pid))
        if (localFileExists(r.localPath)) r
    ];
  }

  /// Queues a copy of a completed server download ([DownloadInfo.fileUrl]
  /// set). A second tap on one already queued or running does nothing.
  void start(DownloadInfo info) {
    if (!supported || info.fileUrl.isEmpty) return;
    final id = info.downloadId;
    final t = _transfers[id];
    if (t != null && t.error.isEmpty) return;
    _cancelled.remove(id);
    _transfers[id] = DeviceTransfer(total: info.fileBytes.toInt());
    _queue.add(info);
    notifyListeners();
    unawaited(_pump());
  }

  /// Stops a copy; its partial file goes too.
  Future<void> cancel(String downloadId) async {
    _cancelled.add(downloadId);
    _queue.removeWhere((i) => i.downloadId == downloadId);
    _transfers.remove(downloadId);
    notifyListeners();
    final dir = await deviceDownloadsDir();
    if (dir != null) await deleteLocalFile(_partPath(dir, downloadId));
  }

  /// Removes this device's copy (the server's is not touched).
  Future<void> removeLocal(String downloadId) async {
    await cancel(downloadId);
    final r = _index.recordFor(downloadId);
    if (r != null) await deleteLocalFile(r.localPath);
    await _index.remove(downloadId);
    notifyListeners();
  }

  Future<void> _pump() async {
    if (_working) return;
    _working = true;
    try {
      while (_queue.isNotEmpty) {
        final info = _queue.removeAt(0);
        await _copy(info);
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _copy(DownloadInfo info) async {
    final id = info.downloadId;
    if (_cancelled.contains(id)) return;
    final total = info.fileBytes.toInt();
    _transfers[id] = DeviceTransfer(total: total, running: true);
    notifyListeners();
    try {
      final dir = await deviceDownloadsDir();
      if (dir == null) throw StateError('nessuna cartella');
      final ext = info.container.isNotEmpty ? info.container : 'mkv';
      final finalPath = '$dir/${_safe(id)}.$ext';
      await fetchToFile(
        url: info.fileUrl,
        partPath: _partPath(dir, id),
        finalPath: finalPath,
        expectedBytes: total,
        cancelled: () => _cancelled.contains(id),
        onProgress: (n) {
          if (_cancelled.contains(id)) return;
          _transfers[id] =
              DeviceTransfer(received: n, total: total, running: true);
          notifyListeners();
        },
      );
      if (_cancelled.contains(id)) return;
      // Replacing an older copy (the server one got a better quality).
      final old = _index.recordFor(id);
      if (old != null &&
          old.localPath.isNotEmpty &&
          old.localPath != finalPath) {
        await deleteLocalFile(old.localPath);
      }
      await _index.markFetched(
        info,
        localPath: finalPath,
        profileId: getIt<AuthInterceptor>().profileId ?? '',
        fileBytes: total > 0 ? total : await localFileLength(finalPath),
      );
      _transfers.remove(id);
      notifyListeners();
      unawaited(_index.syncPendingAcks(getIt<MediaRepository>()));
    } catch (e) {
      if (kDebugMode) debugPrint('[DeviceDownloads] $id: $e');
      if (_cancelled.contains(id)) return;
      final prev = _transfers[id];
      _transfers[id] = DeviceTransfer(
        received: prev?.received ?? 0,
        total: total,
        error: 'Copia interrotta: riprova per riprendere da dove si è fermata.',
      );
      notifyListeners();
    }
  }

  static String _partPath(String dir, String id) => '$dir/${_safe(id)}.part';

  // Download ids are hex from the server; anything else never reaches a path.
  static String _safe(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
