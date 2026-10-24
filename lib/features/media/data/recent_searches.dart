import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/auth_interceptor.dart';

/// The profile's recent searches for one plugin, newest first — offered on
/// every search screen while the box is empty. Device-local, kept per
/// profile *and* per plugin: one profile's searches are never shown to
/// another (no profile yet → nothing is kept or shown), and a plugin only
/// offers what was searched in it.
///
/// Search runs live as the user types, so "a search" is decided here, not
/// by a submit button: a query is kept when it [settled] on results for a
/// few seconds, or was [submit]ted explicitly. Keeping "breaking bad" drops
/// the "brea" kept a moment earlier (a stored prefix of a newer query).
class RecentSearches {
  RecentSearches._();

  static const max = 8;
  static const minLength = 2;
  static const settleAfter = Duration(seconds: 3);

  // v2: per plugin. The v1 lists ('recent_searches:<profile>') mixed every
  // plugin — and, before a profile was known, every profile — so they're
  // dropped rather than migrated.
  static const _prefix = 'recent_searches2:';
  static const _legacyPrefix = 'recent_searches:';

  static String? _key(String pluginId) {
    String pid;
    try {
      pid = getIt<AuthInterceptor>().profileId ?? '';
    } catch (_) {
      pid = '';
    }
    if (pid.isEmpty || pluginId.isEmpty) return null;
    return '$_prefix$pid:$pluginId';
  }

  static SharedPreferences? get _prefs {
    try {
      return getIt<SharedPreferences>();
    } catch (_) {
      return null;
    }
  }

  // In-memory key scan, only when a search screen asks for its list.
  static void _dropLegacy(SharedPreferences prefs) {
    for (final k in prefs.getKeys().toList()) {
      if (k.startsWith(_legacyPrefix)) prefs.remove(k);
    }
  }

  static List<String> list(String pluginId) {
    final prefs = _prefs;
    final key = _key(pluginId);
    if (prefs == null || key == null) return const [];
    _dropLegacy(prefs);
    return prefs.getStringList(key) ?? const [];
  }

  static Future<void> add(String pluginId, String query) async {
    final q = query.trim();
    final key = _key(pluginId);
    if (q.length < minLength || key == null) return;
    final lower = q.toLowerCase();
    final next = [
      q,
      for (final old in list(pluginId))
        if (old.toLowerCase() != lower && !lower.startsWith(old.toLowerCase()))
          old,
    ];
    await _prefs?.setStringList(key, next.take(max).toList());
  }

  static Future<void> remove(String pluginId, String query) async {
    final key = _key(pluginId);
    if (key == null) return;
    await _prefs?.setStringList(key, [
      for (final q in list(pluginId))
        if (q != query) q
    ]);
  }

  static Future<void> clear(String pluginId) async {
    final key = _key(pluginId);
    if (key != null) await _prefs?.remove(key);
  }
}

/// Per search screen: [settled] when results for a query arrive, [typing]
/// on every edit. Only a query that stays put for [RecentSearches.settleAfter]
/// with results is kept — under the plugin it was searched in.
class RecentSearchRecorder {
  Timer? _timer;

  void typing() => _timer?.cancel();

  void settled(String pluginId, String query, {required bool hasResults}) {
    _timer?.cancel();
    if (!hasResults) return;
    _timer = Timer(
        RecentSearches.settleAfter, () => RecentSearches.add(pluginId, query));
  }

  void submit(String pluginId, String query) {
    _timer?.cancel();
    RecentSearches.add(pluginId, query);
  }

  void dispose() => _timer?.cancel();
}
