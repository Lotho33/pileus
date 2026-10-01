// Shared "Download" page — mobile/desktop/web. TV needs its own D-pad
// screen (not built yet).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart' show DownloadInfo;
import '../../../core/theme/app_theme.dart';
import '../../media/data/media_repository.dart';
import '../bloc/downloads_list_cubit.dart';
import '../bloc/downloads_list_state.dart';
import '../data/downloads_local_index.dart';
import '../download_format.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DownloadsListCubit(
        getIt<MediaRepository>(),
        localIndex: DownloadsLocalIndex(getIt<SharedPreferences>()),
      )..start(),
      child: const _DownloadsView(),
    );
  }
}

class _DownloadsView extends StatelessWidget {
  const _DownloadsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: const Text('Download'),
      ),
      body: BlocBuilder<DownloadsListCubit, DownloadsListState>(
        builder: (context, state) => switch (state) {
          DownloadsListLoading() =>
            const Center(child: CircularProgressIndicator()),
          DownloadsListInactive() => const _CenterMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Download non attivi',
              message: 'Il server non ha questa funzione attiva al momento.',
            ),
          DownloadsListError(:final message) => _CenterMessage(
              icon: Icons.error_outline_rounded,
              title: 'Impossibile caricare i download',
              message: message,
            ),
          DownloadsListLoaded(:final downloads) => downloads.isEmpty
              ? const _CenterMessage(
                  icon: Icons.download_done_rounded,
                  title: 'Nessun download',
                  message: 'I contenuti scaricati sul server compariranno qui.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: downloads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _DownloadRow(info: downloads[i]),
                ),
        },
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _CenterMessage(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.textMid),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textMid, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  final DownloadInfo info;
  const _DownloadRow({required this.info});

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ready = info.status == 'completed';
    final subtitle = [
      downloadStatusLabel(info, formatTime: _fmtTime),
      if (info.fileBytes > 0 || info.estimatedBytes > 0)
        formatBytes((info.fileBytes > 0 ? info.fileBytes : info.estimatedBytes)
            .toInt()),
      if (ready && info.expiresAt > 0)
        'scade il ${_fmtDate(DateTime.fromMillisecondsSinceEpoch(info.expiresAt.toInt() * 1000))}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 64,
              height: 96,
              child: info.poster.isNotEmpty
                  ? Image.network(info.poster, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: AppTheme.surface2))
                  : const ColoredBox(color: AppTheme.surface2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.seriesTitle.isNotEmpty
                      ? '${info.seriesTitle} · ${info.title}'
                      : info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textMid, fontSize: 12)),
                // running: normal progress. paused: same bar, frozen at
                // wherever it stopped — no indeterminate/pulsing animation,
                // since a fixed `value` never animates on its own; this is
                // exactly the "barra di avanzamento ferma" the contract asks
                // for, not a separate visual state to build.
                if (info.status == 'running' || info.status == 'paused')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: info.progress.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: AppTheme.surface2,
                        color: info.status == 'paused'
                            ? AppTheme.textLow
                            : null,
                      ),
                    ),
                  ),
                if (info.shared || info.upgradePending)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (info.shared) const _Badge(sharedIndicatorLabel),
                        // DownloadInfo has no preferred_hours field of its
                        // own (that only lives on DownloadOptionsResponse,
                        // fetched once per stream before a download even
                        // exists) — upgradePendingLabel('') still reads
                        // fine without the parenthetical, see its own doc.
                        if (info.upgradePending)
                          _Badge(upgradePendingLabel('')),
                      ],
                    ),
                  ),
                if (ready &&
                    context.read<DownloadsListCubit>().hasQualityUpgrade(info))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton.icon(
                      // Phase 2 (fetching/replacing the file actually
                      // stored on the device) isn't built yet — for now
                      // this just re-opens Guarda against the improved
                      // file_url, same as any other "completed" row, which
                      // at least gets the user the better quality right
                      // away instead of silently doing nothing.
                      onPressed: () => _watch(context, info),
                      icon: const Icon(Icons.upgrade_rounded, size: 16),
                      label: const Text('Scarica di nuovo in qualità migliore',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (ready)
            IconButton(
              tooltip: 'Guarda',
              icon: const Icon(Icons.play_circle_fill_rounded,
                  color: AppTheme.primary),
              onPressed: () => _watch(context, info),
            ),
          if (info.status == 'queued' ||
              info.status == 'scheduled' ||
              info.status == 'running')
            IconButton(
              tooltip: 'Annulla',
              icon: const Icon(Icons.close_rounded, color: AppTheme.textMid),
              onPressed: () => context
                  .read<DownloadsListCubit>()
                  .cancelDownload(info.downloadId),
            )
          else
            IconButton(
              tooltip: 'Elimina',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFF6B6B)),
              onPressed: () => context
                  .read<DownloadsListCubit>()
                  .deleteDownload(info.downloadId),
            ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _watch(BuildContext context, DownloadInfo info) {
    context.push(
      '/player/${info.pluginId}/${Uri.encodeComponent(info.mediaId)}',
      extra: <String, dynamic>{
        'directUrl': info.fileUrl,
        'title': info.title,
        'showTitle': info.seriesTitle,
        'poster': info.poster,
        'parentId': info.parentId,
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(label,
          style: const TextStyle(color: AppTheme.textMid, fontSize: 10)),
    );
  }
}
