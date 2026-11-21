import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/grpc/clients/media_client.dart' show ProgressRequest;
import '../../player/cw_advance.dart' show CwAdvanceRequest;

/// One Continue Watching write the server didn't get (offline: a download
/// watched on a train, a Wi-Fi drop mid-episode).
sealed class CwQueuedOp {
  const CwQueuedOp();
}

/// An UpdateProgress, kept as the request itself.
class CwQueuedUpdate extends CwQueuedOp {
  final ProgressRequest request;
  const CwQueuedUpdate(this.request);
}

/// An automatic row removal (a movie or series finished).
class CwQueuedDelete extends CwQueuedOp {
  final String pluginId;
  final String mediaId;
  const CwQueuedDelete(this.pluginId, this.mediaId);
}

/// "Move this row to the next episode" — needs the server to find it.
class CwQueuedAdvance extends CwQueuedOp {
  final CwAdvanceRequest request;
  const CwQueuedAdvance(this.request);
}

/// Per-profile, ordered (replayed oldest first: the order is what makes
/// "finished S1E10 → moved to S2E1 → watched S2E1 to 12 min" come out
/// right). Only the latest write per row is kept, and a newer write for a
/// series obsoletes a pending "move to the next episode" of that series.
class CwOfflineQueue {
  final SharedPreferences _prefs;
  CwOfflineQueue(this._prefs);

  static const _prefix = 'cw_offline_queue:';
  // Bounded: an offline week of heartbeats collapses to one entry per row
  // anyway; this only stops a pathological case growing without limit.
  static const _maxOps = 300;

  String _key(String profileId) => '$_prefix$profileId';

  List<CwQueuedOp> read(String profileId) {
    final raw = _prefs.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (_decode(e as Map<String, dynamic>) case final op?) op
      ];
    } catch (_) {
      return [];
    }
  }

  bool isEmpty(String profileId) {
    final raw = _prefs.getString(_key(profileId));
    return raw == null || raw.isEmpty || raw == '[]';
  }

  Future<void> write(String profileId, List<CwQueuedOp> ops) async {
    if (ops.isEmpty) {
      await _prefs.remove(_key(profileId));
      return;
    }
    final kept = ops.length > _maxOps ? ops.sublist(ops.length - _maxOps) : ops;
    await _prefs.setString(
        _key(profileId), jsonEncode([for (final op in kept) _encode(op)]));
  }

  Future<void> addUpdate(String profileId, ProgressRequest req) async {
    final ops = read(profileId)
      ..removeWhere((op) => _sameRow(op, req.pluginId, req.mediaId))
      ..removeWhere((op) => _obsoleteAdvance(op, req.pluginId, req.parentId));
    ops.add(CwQueuedUpdate(req));
    await write(profileId, ops);
  }

  Future<void> addDelete(
      String profileId, String pluginId, String mediaId) async {
    final ops = read(profileId)
      ..removeWhere((op) => _sameRow(op, pluginId, mediaId));
    ops.add(CwQueuedDelete(pluginId, mediaId));
    await write(profileId, ops);
  }

  Future<void> addAdvance(String profileId, CwAdvanceRequest r) async {
    final ops = read(profileId)
      ..removeWhere((op) => _obsoleteAdvance(op, r.pluginId, r.seriesId));
    ops.add(CwQueuedAdvance(r));
    await write(profileId, ops);
  }

  /// The server took a newer write for this row/series directly: what's
  /// queued for it would now overwrite fresher data.
  Future<void> dropSuperseded(String profileId, String pluginId, String mediaId,
      String parentId) async {
    if (isEmpty(profileId)) return;
    final ops = read(profileId);
    final before = ops.length;
    ops
      ..removeWhere((op) => _sameRow(op, pluginId, mediaId))
      ..removeWhere((op) => _obsoleteAdvance(op, pluginId, parentId));
    if (ops.length != before) await write(profileId, ops);
  }

  static bool _sameRow(CwQueuedOp op, String pluginId, String mediaId) =>
      switch (op) {
        CwQueuedUpdate(:final request) =>
          request.pluginId == pluginId && request.mediaId == mediaId,
        CwQueuedDelete() => op.pluginId == pluginId && op.mediaId == mediaId,
        CwQueuedAdvance() => false,
      };

  static bool _obsoleteAdvance(
          CwQueuedOp op, String pluginId, String seriesId) =>
      seriesId.isNotEmpty &&
      op is CwQueuedAdvance &&
      op.request.pluginId == pluginId &&
      op.request.seriesId == seriesId;

  static Map<String, dynamic> _encode(CwQueuedOp op) => switch (op) {
        CwQueuedUpdate(:final request) => {
            'k': 'u',
            'r': base64Encode(request.writeToBuffer()),
          },
        CwQueuedDelete() => {'k': 'd', 'p': op.pluginId, 'm': op.mediaId},
        CwQueuedAdvance(:final request) => {'k': 'a', 'r': request.toJson()},
      };

  static CwQueuedOp? _decode(Map<String, dynamic> j) {
    try {
      return switch (j['k']) {
        'u' => CwQueuedUpdate(
            ProgressRequest.fromBuffer(base64Decode(j['r'] as String))),
        'd' => CwQueuedDelete(j['p'] as String, j['m'] as String),
        'a' => CwQueuedAdvance(
            CwAdvanceRequest.fromJson(j['r'] as Map<String, dynamic>)),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}
