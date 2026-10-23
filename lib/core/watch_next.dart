import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../features/media/data/continue_watching_item.dart';
import '../features/player/continue_watching_launch.dart';
import '../features/player/resolve_and_play.dart' show PlayerLaunchGuard;
import 'perf_profile.dart';

/// Continue Watching in the Android TV / Google TV home screen's own "Watch
/// Next" row, and back: a card there opens Pileus on that title. The native
/// half is android/app/src/tv/kotlin/.../WatchNext.kt; on every other
/// platform (and the mobile flavor) all of this is a no-op.
class WatchNext {
  WatchNext._();

  static const _channel = MethodChannel('pileus/watchnext');
  // The row is the recent part of Continue Watching, not all of it.
  static const _maxItems = 10;

  static bool get _enabled =>
      !kIsWeb && Platform.isAndroid && isAndroidTv && appFlavor != 'mobile';

  static List<String>? _lastKeys;

  /// The deep link a Watch Next card opens.
  static String uriFor(ContinueWatchingItem i) => Uri(
        scheme: 'pileus',
        host: 'resume',
        queryParameters: {'plugin': i.providerID, 'id': i.playableID},
      ).toString();

  /// What the native side gets for [items] — visible for tests.
  static List<Map<String, Object?>> payload(List<ContinueWatchingItem> items) =>
      [
        for (final i in items.take(_maxItems))
          {
            'key': '${i.providerID}|${i.playableID}',
            'episode': i.parentID.isNotEmpty,
            // An episode's card leads with its series, as the system row
            // expects (the episode's own title goes in episodeTitle).
            'title': i.parentID.isNotEmpty && i.showTitle.isNotEmpty
                ? i.showTitle
                : i.title,
            'episodeTitle': i.parentID.isNotEmpty ? i.title : '',
            'season': i.seasonNumber,
            'episodeNumber': i.episodeNumber,
            'poster': i.poster,
            'positionMs': (i.progressTime * 1000).round(),
            'durationMs': (i.totalTime * 1000).round(),
            'uri': uriFor(i),
          },
      ];

  /// Mirror [items] (newest first) into the system row. Cheap to call on
  /// every Continue Watching update: an unchanged list isn't sent again.
  static void sync(List<ContinueWatchingItem> items) {
    if (!_enabled) return;
    final data = payload(items);
    final keys = [for (final m in data) jsonEncode(m)];
    if (_lastKeys != null && listEquals(_lastKeys, keys)) return;
    _lastKeys = keys;
    unawaited(_channel
        .invokeMethod('sync', {'items': data}).catchError((Object _) => null));
  }

  /// (plugin, id) of a Watch Next card that opened the app, once — null
  /// when there's none.
  static Future<({String pluginId, String playableId})?> takeLaunch() async {
    if (!_enabled) return null;
    try {
      final raw = await _channel.invokeMethod<String>('takeLaunch');
      return parseLaunch(raw);
    } catch (_) {
      return null;
    }
  }

  static ({String pluginId, String playableId})? parseLaunch(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'pileus' || uri.host != 'resume') {
      return null;
    }
    final plugin = uri.queryParameters['plugin'] ?? '';
    final id = uri.queryParameters['id'] ?? '';
    if (plugin.isEmpty || id.isEmpty) return null;
    return (pluginId: plugin, playableId: id);
  }

  /// [onLaunch] runs when a card is opened while Pileus is already up.
  static void listen(void Function() onLaunch) {
    if (!_enabled) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'launch') onLaunch();
    });
  }

  /// Resume the title a Watch Next card asked for, the same way the home's
  /// own Continue Watching card does. [items] is the row as known now (from
  /// disk at a cold start). A title no longer in it just leaves the home.
  static Future<void> resumePending(
      GoRouter router, List<ContinueWatchingItem> Function() items) async {
    final launch = await takeLaunch();
    if (launch == null) return;
    final item = items()
        .where((i) =>
            i.providerID == launch.pluginId &&
            i.playableID == launch.playableId)
        .firstOrNull;
    if (item == null) return;
    PlayerLaunchGuard.push(
      router,
      '/player/${item.providerID}/${Uri.encodeComponent(item.playableID)}',
      extra: continueWatchingPlayerExtra(item),
    );
  }
}
