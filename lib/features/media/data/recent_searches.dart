import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/auth_interceptor.dart';

/// The profile's recent searches, newest first — offered on every search
/// screen while the box is empty. Device-local and per profile.
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

  static String _key() {
    String pid;
    try {
      pid = getIt<AuthInterceptor>().profileId ?? '';
    } catch (_) {
      pid = '';
    }
    return 'recent_searches:$pid';
  }

  static SharedPreferences? get _prefs {
    try {
      return getIt<SharedPreferences>();
    } catch (_) {
      return null;
    }
  }

  static List<String> list() => _prefs?.getStringList(_key()) ?? const [];

  static Future<void> add(String query) async {
    final q = query.trim();
    if (q.length < minLength) return;
    final lower = q.toLowerCase();
    final next = [
      q,
      for (final old in list())
        if (old.toLowerCase() != lower && !lower.startsWith(old.toLowerCase()))
          old,
    ];
    await _prefs?.setStringList(_key(), next.take(max).toList());
  }

  static Future<void> remove(String query) async {
    await _prefs?.setStringList(
        _key(), [for (final q in list()) if (q != query) q]);
  }

  static Future<void> clear() async => _prefs?.remove(_key());
}

/// Per search screen: [settled] when results for a query arrive, [typing]
/// on every edit. Only a query that stays put for [RecentSearches.settleAfter]
/// with results is kept.
class RecentSearchRecorder {
  Timer? _timer;

  void typing() => _timer?.cancel();

  void settled(String query, {required bool hasResults}) {
    _timer?.cancel();
    if (!hasResults) return;
    _timer = Timer(RecentSearches.settleAfter, () => RecentSearches.add(query));
  }

  void submit(String query) {
    _timer?.cancel();
    RecentSearches.add(query);
  }

  void dispose() => _timer?.cancel();
}
