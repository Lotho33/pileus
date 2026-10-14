import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/grpc/clients/media_client.dart' show SearchFilter;
import '../../../core/utils/perf_log.dart';
import 'media_repository.dart';

/// Where a plugin's search filters stand.
enum FiltersStatus {
  /// No plugin yet / not asked.
  idle,

  /// A request is in flight.
  loading,

  /// Filters are known ([SearchFiltersLoader.filters] not empty).
  ready,

  /// The server answered with no filters (this plugin has none).
  none,

  /// The request failed — including UNAVAILABLE, which the server now sends
  /// when a plugin *has* filters but can't produce them right now. Retried.
  error,
}

/// Loads a plugin's search filters and keeps retrying until it gets them.
/// Shared by the TV, mobile and desktop search screens.
///
/// Mobile/desktop search are persistent IndexedStack tabs: their first load
/// runs at app start, often before the gRPC connection/auth is ready, and a
/// single failed attempt used to leave the Filtri button dead for the whole
/// session. Here:
/// - an error retries after 1.5s, 4s, 10s, then every 30s while visible;
/// - an empty answer retries after 1.5s, 4s, 10s (older servers answered
///   "empty" while a plugin was still warming up), then counts as "none";
/// - becoming visible again ([setVisible]) retries if filters are missing;
/// - a later empty/failed answer never wipes filters already obtained;
/// - [retryNow] is for the button: tapping it while loading/failed tries
///   again immediately instead of being a dead control.
class SearchFiltersLoader extends ChangeNotifier {
  SearchFiltersLoader(this._repo);

  final MediaRepository _repo;

  static const retryDelays = [
    Duration(milliseconds: 1500),
    Duration(seconds: 4),
    Duration(seconds: 10),
  ];
  static const steadyRetry = Duration(seconds: 30);

  String? _pluginId;
  List<SearchFilter> _filters = const [];
  FiltersStatus _status = FiltersStatus.idle;
  bool _visible = true;
  int _attempt = 0;
  int _token = 0;
  Timer? _retry;
  Future<void>? _inFlight;
  bool _disposed = false;

  String? get pluginId => _pluginId;
  List<SearchFilter> get filters => _filters;
  FiltersStatus get status => _status;
  bool get hasFilters => _filters.isNotEmpty;
  bool get isLoading => _status == FiltersStatus.loading;

  /// Switches to [id] (no-op if unchanged): drops the old plugin's filters
  /// and starts loading the new one's.
  void setPlugin(String? id) {
    if (id == _pluginId) return;
    _token++;
    _retry?.cancel();
    _inFlight = null;
    _pluginId = id;
    _filters = const [];
    _attempt = 0;
    _status = FiltersStatus.idle;
    _notify();
    if (id != null) unawaited(_load());
  }

  /// The hosting screen became visible / hidden. Retries are paused while
  /// hidden; showing it again retries at once if filters are still missing.
  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) {
      _retry?.cancel();
      return;
    }
    if (_pluginId != null && _filters.isEmpty && _inFlight == null) {
      _attempt = 0;
      unawaited(_load());
    }
  }

  /// Tries again right now (resetting the backoff); joins a request already
  /// in flight instead of starting a second one.
  Future<void> retryNow() {
    _retry?.cancel();
    _attempt = 0;
    return _load();
  }

  Future<void> _load() {
    final id = _pluginId;
    if (id == null) return Future.value();
    final running = _inFlight;
    if (running != null) return running;
    final token = ++_token;
    _status = FiltersStatus.loading;
    _notify();
    final f = _fetch(id, token);
    _inFlight = f;
    return f;
  }

  Future<void> _fetch(String id, int token) async {
    try {
      final resp = await _repo.getSearchFilters(id);
      if (token != _token || _disposed) return;
      if (resp.filters.isNotEmpty) {
        _filters = resp.filters;
        _status = FiltersStatus.ready;
        _attempt = 0;
        perf('filters: $id → ${resp.filters.length}');
      } else if (_filters.isNotEmpty) {
        _status = FiltersStatus.ready; // never wipe what we already have
      } else {
        _status = FiltersStatus.none;
        perf('filters: $id empty (attempt ${_attempt + 1})');
        _schedule(error: false);
      }
    } catch (e) {
      if (token != _token || _disposed) return;
      if (_filters.isNotEmpty) {
        _status = FiltersStatus.ready;
      } else {
        _status = FiltersStatus.error;
        perf('filters: $id error (attempt ${_attempt + 1}): $e');
        _schedule(error: true);
      }
    } finally {
      if (token == _token) _inFlight = null;
      _notify();
    }
  }

  void _schedule({required bool error}) {
    _retry?.cancel();
    if (!_visible) return;
    Duration? delay;
    if (_attempt < retryDelays.length) {
      delay = retryDelays[_attempt];
    } else if (error) {
      delay = steadyRetry;
    }
    _attempt++;
    if (delay == null) return;
    _retry = Timer(delay, () {
      if (!_disposed && _visible && _filters.isEmpty) unawaited(_load());
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token++;
    _retry?.cancel();
    super.dispose();
  }
}
