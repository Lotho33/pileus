import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/app_lifecycle.dart';
import '../../../core/grpc/clients/media_client.dart' show CatalogDef;

/// Re-fetches a plugin's live rows every minute while its home page is what
/// the user is looking at, so an event that starts moves from "A breve" to
/// "Live ora" (and a finished one goes away) without leaving and coming
/// back. Rows are refreshed silently (RefreshCatalogEvent): nothing changes
/// on screen unless the plugin's answer did.
///
/// Not while the page is covered (player, details on top), nor with the app
/// in the background — a box playing a match shouldn't also poll the
/// catalogs.
class LiveRowsRefresher {
  static const every = Duration(minutes: 1);

  final BuildContext Function() context;
  final void Function(CatalogDef catalog) refresh;
  Timer? _timer;
  List<CatalogDef> _live = const [];

  LiveRowsRefresher({required this.context, required this.refresh});

  /// The plugin shown changed (or its catalogs): only its live rows count.
  void watch(List<CatalogDef> catalogs) {
    _live = [
      for (final c in catalogs)
        if (c.type == 'live') c
    ];
    _timer?.cancel();
    _timer = _live.isEmpty ? null : Timer.periodic(every, (_) => _tick());
  }

  void _tick() {
    final ctx = context();
    if (!ctx.mounted) return;
    if (AppLifecycleReactor.instance.isBackgrounded) return;
    if (!(ModalRoute.of(ctx)?.isCurrent ?? true)) return;
    for (final c in _live) {
      refresh(c);
    }
  }

  void dispose() => _timer?.cancel();
}
