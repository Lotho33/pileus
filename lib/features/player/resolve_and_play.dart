import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/theme/app_theme.dart';
import '../media/data/media_repository.dart';

/// Fetch the stream sources for [mediaId]; if there's more than one, show a
/// source / language picker first (the mobile equivalent of the TV inline
/// source list), then navigate to the player. `extra` carries the playback
/// context (title, episode list, resume position, …).
/// If [sourcePicker] is given it replaces the built-in bottom sheet used to
/// choose between multiple sources — the desktop build passes a centered
/// dialog instead.
typedef SourcePicker = Future<StreamSource?> Function(
    BuildContext context, List<StreamSource> sources);

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

  List<StreamSource> sources;
  try {
    final res = await getIt<MediaRepository>().getStreams(pluginId, mediaId);
    sources = res.sources;
  } catch (_) {
    sources = const [];
  }

  // The root navigator outlives the caller's popped sheet, but if the whole
  // app is being torn down (session expiry) it can be gone too.
  if (!navigator.mounted) return;

  // No sources and no already-resolved stream id in `extra` (a Continue
  // Watching resume passes one) → there's nothing to play. Say so instead of
  // pushing the player straight into its error overlay.
  final hasDirectStream = ((extra?['streamId'] as String?) ?? '').isNotEmpty;
  if (sources.isEmpty && !hasDirectStream) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Nessuna sorgente disponibile per questo contenuto.'),
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
                      onTap: () => Navigator.of(sheetCtx).pop(sources[i]),
                    ),
                ],
              ),
            ),
          );
    // Picker was shown and dismissed without a pick → abort.
    if (chosen == null) return;
  }
  chosen ??= sources.isNotEmpty ? sources.first : null;

  router.push(
    '/player/$pluginId/${Uri.encodeComponent(mediaId)}',
    extra: <String, dynamic>{
      ...?extra,
      if (chosen != null) 'streamId': chosen.id,
      if (chosen != null) 'sourceLabel': chosen.label,
    },
  );
}
