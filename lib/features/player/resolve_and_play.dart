import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/grpc/grpc_errors.dart';
import '../../shared/utils/tap_guard.dart';
import '../../core/theme/app_scale.dart';
import '../../core/utils/metrics.dart';
import '../../shared/widgets/episode_language_sheet.dart';
import '../../shared/widgets/pileus_spinner.dart';
import '../media/data/media_repository.dart';
import 'source_preference.dart';

/// Fetch the stream sources for [mediaId], pick one with the shared rule
/// (choosePlaySource — never a question at Play) and navigate to the
/// player. `extra` carries the playback context (title, episode list,
/// resume position, …); its 'sourceLabel', when set, is a language the user
/// chose explicitly (a details screen's chips). [chooseLanguage] — a tap on
/// an episode — asks first instead, on the episode language sheet, when
/// the sources are language versions.

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
  bool chooseLanguage = false,
  EpisodeInfo? episode,
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
        extra: extra,
        chooseLanguage: chooseLanguage,
        episode: episode,
        hideSpinner: hideSpinner);
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
  bool chooseLanguage = false,
  EpisodeInfo? episode,
  required VoidCallback hideSpinner,
}) async {
  // The language sheet also describes the episode: ask for its details
  // alongside the sources, not after.
  final details = chooseLanguage
      ? getIt<MediaRepository>()
          .getDetails(pluginId, mediaId, urgent: true)
          .then<DetailsResponse?>((d) => d, onError: (_) => null)
      : null;
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

  // The language is a preference (Preferenze → "Lingua preferita", the
  // series' last one, or the label the caller passes — a details screen's
  // language chips), source_preference.dart. The one question: a tap on an
  // episode shows its languages first, the rule's pick highlighted.
  final explicitLabel = (extra?['sourceLabel'] as String?) ?? '';
  final seriesId = (extra?['parentId'] as String?) ?? '';
  StreamSource? chosen;
  final ask = chooseLanguage &&
      explicitLabel.isEmpty &&
      sources.any((s) => languageOfLabel(s.label) != null);
  if (ask) {
    chosen = await showEpisodeLanguageSheet(
      navigator,
      pluginId: pluginId,
      sources: preferredFirst(sources, pluginId: pluginId, seriesId: seriesId),
      title: (extra?['title'] as String?) ?? '',
      showTitle: (extra?['showTitle'] as String?) ?? '',
      episode: episode,
      details: details,
    );
    if (chosen == null || !navigator.mounted) {
      Metrics.playAbandon();
      return;
    }
    // The clock measures Play → first frame, not the time spent choosing.
    Metrics.playBegin();
  } else {
    chosen = choosePlaySource(sources,
        explicitLabel: explicitLabel, pluginId: pluginId, seriesId: seriesId);
  }
  // The sheet already said which languages there are.
  final notice = ask ? '' : languageNotice(sources, chosen);

  PlayerLaunchGuard._lastPush = DateTime.now();
  router.push(
    '/player/$pluginId/${Uri.encodeComponent(mediaId)}',
    extra: <String, dynamic>{
      ...?extra,
      if (chosen != null) 'streamId': chosen.id,
      if (chosen != null) 'sourceLabel': chosen.label,
      if (notice.isNotEmpty) 'languageNotice': notice,
    },
  );
}
