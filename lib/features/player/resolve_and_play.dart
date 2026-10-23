import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/grpc/grpc_errors.dart';
import '../../shared/utils/tap_guard.dart';
import '../../core/theme/app_scale.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/metrics.dart';
import '../../shared/widgets/pileus_spinner.dart';
import '../media/data/media_repository.dart';
import 'source_continuity.dart';

/// Fetch the stream sources for [mediaId]; if there's more than one, show a
/// source / language picker first (the mobile equivalent of the TV inline
/// source list), then navigate to the player. `extra` carries the playback
/// context (title, episode list, resume position, …).
/// If [sourcePicker] is given it replaces the built-in bottom sheet used to
/// choose between multiple sources — the desktop build passes a centered
/// dialog instead.
typedef SourcePicker = Future<StreamSource?> Function(
    BuildContext context, List<StreamSource> sources);

/// One player launch at a time. GetStreams can take seconds on a slow
/// plugin, and with no feedback a second (third…) tap on Play / an episode /
/// a Continue Watching card pushed one player route per tap — several
/// ExoPlayer instances fighting over the profile's single playback lease.
/// Also swallows a double tap right *after* a push (the route transition is
/// still running, the old screen still receives taps).
class PlayerLaunchGuard {
  PlayerLaunchGuard._();
  static bool _busy = false;
  static DateTime? _lastPush;
  static const _cooldown = Duration(milliseconds: 1200);

  static bool get _blocked =>
      _busy ||
      (_lastPush != null && DateTime.now().difference(_lastPush!) < _cooldown);

  /// Push the player route unless a launch is already in flight / just
  /// happened. For call sites that already know the stream (Continue
  /// Watching, "Riprendi").
  static void push(GoRouter router, String location, {Object? extra}) {
    if (_blocked || !TapGuard.acquire()) return;
    Metrics.playBegin();
    _lastPush = DateTime.now();
    router.push(location, extra: extra);
  }
}

/// Dim + spinner over the whole app while sources are being fetched —
/// inserted only if the fetch is still running after a short delay, so a
/// fast server never flashes it.
OverlayEntry? _showLaunchSpinner(NavigatorState navigator) {
  final overlay = navigator.overlay;
  if (overlay == null) return null;
  final entry = OverlayEntry(
    builder: (ctx) => ColoredBox(
      color: const Color(0x88000000),
      child: Center(child: PileusSpinner(size: AppScale.spinnerL(ctx))),
    ),
  );
  overlay.insert(entry);
  return entry;
}

Future<void> resolveAndPlay(
  BuildContext context,
  String pluginId,
  String mediaId, {
  Map<String, dynamic>? extra,
  SourcePicker? sourcePicker,
}) async {
  // Capture everything that depends on `context` up-front and synchronously:
  // the caller (e.g. a long-press sheet) pops its own route right before
  // calling this, so by the first `await` below `context` may already be on
  // its way out. `navigator` is the root navigator (survives the caller's
  // pop) — used to host the source picker; `messenger` for the no-sources
  // toast.
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  if (PlayerLaunchGuard._blocked || !TapGuard.acquire()) return;
  PlayerLaunchGuard._busy = true;
  Metrics.playBegin();
  OverlayEntry? spinner;
  final spinnerTimer = Timer(const Duration(milliseconds: 250), () {
    if (navigator.mounted) spinner = _showLaunchSpinner(navigator);
  });
  void hideSpinner() {
    spinnerTimer.cancel();
    spinner?.remove();
    spinner = null;
  }

  try {
    await _resolveAndPush(router, navigator, messenger, pluginId, mediaId,
        extra: extra, sourcePicker: sourcePicker, hideSpinner: hideSpinner);
  } finally {
    hideSpinner();
    PlayerLaunchGuard._busy = false;
  }
}

Future<void> _resolveAndPush(
  GoRouter router,
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  String pluginId,
  String mediaId, {
  Map<String, dynamic>? extra,
  SourcePicker? sourcePicker,
  required VoidCallback hideSpinner,
}) async {
  List<StreamSource> sources;
  Object? fetchError;
  try {
    final res = await getIt<MediaRepository>().getStreams(pluginId, mediaId);
    sources = res.sources;
  } catch (e) {
    sources = const [];
    fetchError = e;
  }
  hideSpinner();

  // The root navigator outlives the caller's popped sheet, but if the whole
  // app is being torn down (session expiry) it can be gone too.
  if (!navigator.mounted) return;

  // No sources and no already-resolved stream id in `extra` (a Continue
  // Watching resume passes one) → there's nothing to play. Say so instead of
  // pushing the player straight into its error overlay.
  final hasDirectStream = ((extra?['streamId'] as String?) ?? '').isNotEmpty;
  if (sources.isEmpty && !hasDirectStream) {
    // A failed lookup (server unreachable, timeout…) is not "this title has
    // no sources" — say which one it was.
    messenger.showSnackBar(SnackBar(
      content: Text(fetchError != null
          ? 'Impossibile recuperare le sorgenti: ${grpcMessage(fetchError)}'
          : 'Nessuna sorgente disponibile per questo contenuto.'),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }

  StreamSource? chosen;
  if (sources.length > 1) {
    chosen = sourcePicker != null
        ? await sourcePicker(navigator.context, sources)
        : await showModalBottomSheet<StreamSource>(
            context: navigator.context,
            backgroundColor: AppTheme.surface,
            showDragHandle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (sheetCtx) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text('SCEGLI LA SORGENTE',
                        style: TextStyle(
                            color: AppTheme.textLow,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  for (var i = 0; i < sources.length; i++)
                    ListTile(
                      leading: const Icon(Icons.play_arrow_rounded,
                          color: AppTheme.textHigh),
                      title: Text(
                        sources[i].label.isNotEmpty
                            ? sources[i].label
                            : 'Sorgente ${i + 1}',
                        style: const TextStyle(color: AppTheme.textHigh),
                      ),
                      onTap: () => popIfCurrent(sheetCtx, sources[i]),
                    ),
                ],
              ),
            ),
          );
    // Picker was shown and dismissed without a pick → abort.
    if (chosen == null) return;
  }
  // Same choice as the warm ahead of Play — see pickSourceByLabel.
  chosen ??= pickSourceByLabel(sources, '');

  PlayerLaunchGuard._lastPush = DateTime.now();
  router.push(
    '/player/$pluginId/${Uri.encodeComponent(mediaId)}',
    extra: <String, dynamic>{
      ...?extra,
      if (chosen != null) 'streamId': chosen.id,
      if (chosen != null) 'sourceLabel': chosen.label,
    },
  );
}
