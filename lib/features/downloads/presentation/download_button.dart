// Shared "Scarica" affordance for a details screen's movie/episode play row
// — mobile/desktop/web. Renders nothing until ListPlugins confirms the
// plugin actually has the "download" capability (contract: "Un plugin è
// scaricabile solo se ListPlugins riporta la capacità 'download'") — same
// lazy self-check pattern mobile_details_screen.dart's own _PlayButton
// already uses for its resume lookup, so no capability plumbing has to be
// threaded through the whole details-screen call chain for this.
import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../bloc/download_options_cubit.dart';
import '../download_format.dart';
import '../../media/data/media_repository.dart';
import 'download_options_sheet.dart';

class DownloadButton extends StatefulWidget {
  final String pluginId;
  final String preferredSourceLabel;
  final DownloadTarget target;
  // Compact icon-only button (next to an existing Play button) vs a full
  // labelled one (nothing else on the row, e.g. a standalone episode tile
  // action).
  final bool compact;
  // "Scarica la stagione" / "Scarica i prossimi N episodi" — offered inside
  // the sheet alongside the single-episode choice, see
  // DownloadBatchGroup's own doc. Empty for a movie.
  final List<DownloadBatchGroup> batchGroups;

  const DownloadButton({
    super.key,
    required this.pluginId,
    required this.target,
    this.preferredSourceLabel = '',
    this.compact = true,
    this.batchGroups = const [],
  });

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool? _supported; // null = still checking

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final plugins = await getIt<MediaRepository>().listPlugins();
      if (!mounted) return;
      final plugin =
          plugins.where((p) => p.pluginId == widget.pluginId).firstOrNull;
      setState(
          () => _supported = plugin != null && pluginSupportsDownload(plugin));
    } catch (_) {
      if (mounted) setState(() => _supported = false);
    }
  }

  void _open() => showDownloadOptionsSheet(
        context,
        pluginId: widget.pluginId,
        preferredSourceLabel: widget.preferredSourceLabel,
        target: widget.target,
        batchGroups: widget.batchGroups,
      );

  @override
  Widget build(BuildContext context) {
    if (_supported != true) return const SizedBox.shrink();
    if (widget.compact) {
      return IconButton.filledTonal(
        tooltip: 'Scarica',
        onPressed: _open,
        icon: const Icon(Icons.download_rounded),
      );
    }
    return OutlinedButton.icon(
      onPressed: _open,
      icon: const Icon(Icons.download_rounded),
      label: const Text('Scarica'),
    );
  }
}
