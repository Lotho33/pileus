import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/auth_interceptor.dart';
import '../../media/data/media_repository.dart';
import '../device/device_downloads.dart';

/// What the active profile already downloaded (or is downloading), by
/// plugin + media id — so a details screen shows "Scaricato" instead of
/// offering the same episode/movie again (the server would answer with the
/// download it already has anyway). One ListDownloads shared by every
/// button on screen, refreshed at most every [_ttl]; copies on this device
/// count too, so it also answers offline.
class DownloadedIndex extends ChangeNotifier {
  DownloadedIndex._();
  static final DownloadedIndex instance = DownloadedIndex._();

  static const _ttl = Duration(seconds: 20);
  // Statuses that mean "you have it, or it is coming".
  static const _active = {
    'queued',
    'scheduled',
    'running',
    'paused',
    'completed',
  };

  Set<String> _server = {};
  String? _profile;
  DateTime? _at;
  Future<void>? _loading;

  static String? get _pid => getIt.isRegistered<AuthInterceptor>()
      ? getIt<AuthInterceptor>().profileId
      : null;

  static String _key(String pluginId, String mediaId) =>
      '$pluginId\u0000$mediaId';

  bool has(String pluginId, String mediaId) {
    if (mediaId.isEmpty) return false;
    final k = _key(pluginId, mediaId);
    if (_profile == _pid && _server.contains(k)) {
      return true;
    }
    return DeviceDownloads.instance.localCopies().any(
        (r) => r.pluginId == pluginId && r.mediaId == mediaId);
  }

  /// Fetches the list unless a fresh one (same profile) is already here.
  Future<void> refresh({bool force = false}) {
    final pid = _pid;
    final fresh = _at != null &&
        _profile == pid &&
        DateTime.now().difference(_at!) < _ttl;
    if (fresh && !force) return Future.value();
    return _loading ??= _load(pid).whenComplete(() => _loading = null);
  }

  Future<void> _load(String? pid) async {
    try {
      final resp = await getIt<MediaRepository>().listDownloads();
      _server = {
        for (final d in resp.downloads)
          if (_active.contains(d.status)) _key(d.pluginId, d.mediaId)
      };
      _profile = pid;
      _at = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Offline or downloads off: local copies still answer has().
    }
  }

  /// A download was just requested: mark it at once, the next list confirms.
  void markRequested(String pluginId, Iterable<String> mediaIds) {
    _server = {..._server, for (final m in mediaIds) _key(pluginId, m)};
    _profile = _pid;
    notifyListeners();
  }
}
