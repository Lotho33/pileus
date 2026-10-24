import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' show StreamSource;
import '../../core/theme/app_theme.dart';
import '../../features/player/source_preference.dart';
import '../../features/player/stream_warmer.dart';
import '../utils/tap_guard.dart' show popIfCurrent;

/// The language versions of one episode, asked before it plays (mobile,
/// desktop, web) — the counterpart of the TV episode popup's buttons. Only
/// that episode's own sources: an anime episode can exist in Japanese
/// alone while the next one is dubbed too, and that used to show up only
/// once it was already playing.
///
/// [sources] come in the Play rule's order (preferredFirst): the first one
/// is highlighted and warmed while the sheet is open. With a single
/// version it says which one ("Solo giapponese (sottotitolato)") and offers
/// one button. Resolves to the source to play, or null when dismissed.
Future<StreamSource?> showEpisodeLanguageSheet(
  NavigatorState navigator, {
  required String pluginId,
  required List<StreamSource> sources,
  String title = '',
  String showTitle = '',
}) {
  return showModalBottomSheet<StreamSource>(
    context: navigator.context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _EpisodeLanguageSheet(
      pluginId: pluginId,
      sources: sources,
      title: title,
      showTitle: showTitle,
    ),
  );
}

class _EpisodeLanguageSheet extends StatefulWidget {
  final String pluginId;
  final List<StreamSource> sources;
  final String title;
  final String showTitle;

  const _EpisodeLanguageSheet({
    required this.pluginId,
    required this.sources,
    required this.title,
    required this.showTitle,
  });

  @override
  State<_EpisodeLanguageSheet> createState() => _EpisodeLanguageSheetState();
}

class _EpisodeLanguageSheetState extends State<_EpisodeLanguageSheet> {
  WarmTicket? _warm;

  @override
  void initState() {
    super.initState();
    final first = widget.sources.first;
    _warm =
        getIt<StreamWarmer>().schedule(widget.pluginId, () async => first.id);
  }

  @override
  void dispose() {
    _warm?.cancel();
    super.dispose();
  }

  String _label(StreamSource s) => s.label.isNotEmpty ? s.label : 'Sorgente';

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources;
    final single = sources.length == 1;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showTitle.isNotEmpty)
              Text(
                widget.showTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textLow,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            if (widget.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              single
                  ? 'Solo ${languageDescription(_label(sources.first))}'
                  : 'Lingua',
              style: const TextStyle(color: AppTheme.textMid, fontSize: 14),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < sources.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: i == 0
                    ? FilledButton.icon(
                        autofocus: true,
                        onPressed: () => popIfCurrent(context, sources[i]),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(single ? 'Riproduci' : _label(sources[i]),
                            overflow: TextOverflow.ellipsis),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46)),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => popIfCurrent(context, sources[i]),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(_label(sources[i]),
                            overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: AppTheme.textHigh,
                          side: const BorderSide(color: AppTheme.border),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
