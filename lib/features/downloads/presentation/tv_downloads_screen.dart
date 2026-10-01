// TV "Download" page — same SettingsHeader + vertical row list idiom as
// tv_download_options_screen.dart. Every row opens a small action dialog on
// Select (Guarda / Annulla / Elimina / Chiudi, whichever apply) rather than
// acting immediately — a D-pad remote has no reliable long-press, unlike
// touch, so this is the one interaction path for every action instead of
// splitting "tap = play" from "long-press = manage" the way the mobile CW
// card does.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart' show DownloadInfo;
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/back_dispatch.dart';
import '../../../shared/widgets/ambient_glow_background.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/settings/dialog_action_button.dart';
import '../../../shared/widgets/settings/settings_header.dart';
import '../../../shared/widgets/settings/settings_nav_row.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../../media/data/media_repository.dart';
import '../bloc/downloads_list_cubit.dart';
import '../bloc/downloads_list_state.dart';
import '../data/downloads_local_index.dart';
import '../download_format.dart';

class TvDownloadsScreen extends StatelessWidget {
  const TvDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DownloadsListCubit(
        getIt<MediaRepository>(),
        localIndex: DownloadsLocalIndex(getIt<SharedPreferences>()),
      )..start(),
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _backFn = FocusNode();
  final _nodes = <String, FocusNode>{};

  FocusNode _nodeFor(String key) => _nodes.putIfAbsent(key, () => FocusNode());

  @override
  void dispose() {
    _backFn.dispose();
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () {
        if (consumeBackEvent()) context.pop();
      },
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: AmbientGlowBackground(
          child: SafeArea(
            child: Column(
              children: [
                SettingsHeader(
                  title: 'Download',
                  focusNode: _backFn,
                  onBack: () => context.pop(),
                  onFocusDown: () => _nodeFor('row_0').requestFocus(),
                ),
                Expanded(
                  child: BlocBuilder<DownloadsListCubit, DownloadsListState>(
                    builder: (context, state) => switch (state) {
                      DownloadsListLoading() =>
                        const Center(child: PileusSpinner(size: 48)),
                      DownloadsListInactive() => const _Message(
                          icon: Icons.cloud_off_rounded,
                          title: 'Download non attivi',
                          message:
                              'Il server non ha questa funzione attiva al momento.'),
                      DownloadsListError(:final message) => _Message(
                          icon: Icons.error_outline_rounded,
                          title: 'Impossibile caricare i download',
                          message: message),
                      DownloadsListLoaded(:final downloads) =>
                        downloads.isEmpty
                            ? const _Message(
                                icon: Icons.download_done_rounded,
                                title: 'Nessun download',
                                message:
                                    'I contenuti scaricati sul server compariranno qui.')
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        AppScale.screenHPad(context),
                                    vertical: AppScale.space(context, 8)),
                                itemCount: downloads.length,
                                itemBuilder: (context, i) {
                                  final up = i == 0
                                      ? _backFn
                                      : _nodeFor('row_${i - 1}');
                                  final down = i < downloads.length - 1
                                      ? _nodeFor('row_${i + 1}')
                                      : null;
                                  return _DownloadRow(
                                    info: downloads[i],
                                    focusNode: _nodeFor('row_$i'),
                                    onFocusUp: () => up.requestFocus(),
                                    onFocusDown: down == null
                                        ? null
                                        : () => down.requestFocus(),
                                  );
                                },
                              ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _Message(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppScale.space(context, 32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppScale.iconL(context), color: AppTheme.textMid),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: AppScale.title(context),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: AppScale.label(context))),
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  final DownloadInfo info;
  final FocusNode focusNode;
  final VoidCallback onFocusUp;
  final VoidCallback? onFocusDown;
  const _DownloadRow({
    required this.info,
    required this.focusNode,
    required this.onFocusUp,
    this.onFocusDown,
  });

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ready = info.status == 'completed';
    final size = info.fileBytes > 0 ? info.fileBytes : info.estimatedBytes;
    final parts = [
      downloadStatusLabel(info, formatTime: _fmtTime),
      if (size > 0) formatBytes(size.toInt()),
      if (info.shared) sharedIndicatorLabel,
      if (info.upgradePending) upgradePendingLabel(''),
    ];
    return SettingsNavRow(
      icon: ready ? Icons.play_circle_fill_rounded : Icons.download_rounded,
      label: info.seriesTitle.isNotEmpty
          ? '${info.seriesTitle} · ${info.title}'
          : info.title,
      subtitle: parts.join(' · '),
      focusNode: focusNode,
      onFocusUp: onFocusUp,
      onFocusDown: onFocusDown,
      onTap: () => _openActions(context),
    );
  }

  void _openActions(BuildContext context) {
    final cubit = context.read<DownloadsListCubit>();
    final ready = info.status == 'completed';
    final cancellable = info.status == 'queued' ||
        info.status == 'scheduled' ||
        info.status == 'running' ||
        info.status == 'paused';
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => _ActionDialog(
        title: info.title,
        onWatch: ready
            ? () {
                Navigator.of(dialogCtx).pop();
                _watch(context, info);
              }
            : null,
        onCancel: cancellable
            ? () {
                Navigator.of(dialogCtx).pop();
                cubit.cancelDownload(info.downloadId);
              }
            : null,
        onDelete: !cancellable
            ? () {
                Navigator.of(dialogCtx).pop();
                cubit.deleteDownload(info.downloadId);
              }
            : null,
      ),
    );
  }

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

class _ActionDialog extends StatelessWidget {
  final String title;
  final VoidCallback? onWatch;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  const _ActionDialog({
    required this.title,
    this.onWatch,
    this.onCancel,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // No explicit FocusNode passed to the buttons below — TvFocusable
    // manages its own internal node when none is given, tied correctly to
    // this dialog's own widget lifecycle (see the same reasoning
    // dialog_controller_dispose_race fixed elsewhere: a node/controller
    // scoped to this build() method, not a State, would leak and could
    // detach mid-transition). Left/Right between the action buttons relies
    // on Flutter's own default focus traversal, same as this app's other
    // DialogActionButton rows (settings_text_dialog.dart's Annulla/Salva).
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(context).pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          if (onWatch != null)
            DialogActionButton(
              label: 'Guarda',
              primary: true,
              autofocus: true,
              onPressed: onWatch,
            ),
          if (onCancel != null)
            DialogActionButton(
              label: 'Annulla download',
              autofocus: onWatch == null,
              onPressed: onCancel,
            ),
          if (onDelete != null)
            DialogActionButton(
              label: 'Elimina',
              autofocus: onWatch == null,
              onPressed: onDelete,
            ),
          DialogActionButton(
            label: 'Chiudi',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
