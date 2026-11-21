// Shared "Download" page — mobile/desktop/web. TV has its own D-pad screen
// (tv_downloads_screen.dart). On mobile/desktop a finished download can
// also be copied onto the device, on request (DeviceDownloads): the server
// keeps its copy, and the device's one plays with no server at all.
import 'package:cached_network_image/cached_network_image.dart';
// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart' show DownloadInfo;
import '../../../core/grpc/grpc_errors.dart' show grpcMessage;
import '../../../core/theme/app_theme.dart';
import '../../media/data/media_repository.dart';
import '../bloc/downloads_list_cubit.dart';
import '../bloc/downloads_list_state.dart';
import '../data/downloads_local_index.dart';
import '../device/device_downloads.dart';
import '../download_format.dart';
import '../download_groups.dart';
import '../download_playback.dart';
import '../../../shared/utils/tap_guard.dart';

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

/// What the page lists in [state]: the server's downloads, then the copies
/// on this device the server no longer lists (expired or deleted there) —
/// or can't be asked about. Null [rows] = nothing to list yet, [message]
/// says why.
class _Collected {
  final List<DownloadInfo>? rows;
  final Set<String> onServer;
  final String? offlineNote;
  final Widget? message;
  const _Collected(
      {this.rows, this.onServer = const {}, this.offlineNote, this.message});
}

_Collected _collect(DownloadsListState state) {
  final local = DeviceDownloads.instance.localCopies();
  _Collected merge(List<DownloadInfo> server, String? note) {
    final listed = {for (final d in server) d.downloadId};
    return _Collected(
      rows: [
        ...server,
        for (final r in local)
          if (!listed.contains(r.downloadId)) r.toInfo(),
      ],
      onServer: listed,
      offlineNote: note,
    );
  }

  return switch (state) {
    DownloadsListLoading() when local.isEmpty => const _Collected(
        message: Center(child: CircularProgressIndicator())),
    DownloadsListLoaded(:final downloads) => merge(downloads, null),
    // Server unreachable or downloads off: what is on this device still
    // plays (a train).
    _ when local.isNotEmpty => merge(
        const [],
        state is DownloadsListLoading
            ? null
            : 'Server non raggiungibile: sono elencati solo i download '
                'salvati su questo dispositivo.'),
    DownloadsListInactive() => const _Collected(
        message: _CenterMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Download non attivi',
          message: 'Il server non ha questa funzione attiva al momento.',
        ),
      ),
    DownloadsListError(:final message) => _Collected(
        message: _CenterMessage(
          icon: Icons.error_outline_rounded,
          title: 'Impossibile caricare i download',
          message: message,
        ),
      ),
    _ => const _Collected(
        message: Center(child: CircularProgressIndicator())),
  };
}

/// Rebuilds on the server list (polled) and on this device's copies.
class _DownloadsBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, _Collected c) builder;
  const _DownloadsBuilder({required this.builder});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: DeviceDownloads.instance,
        builder: (context, _) =>
            BlocBuilder<DownloadsListCubit, DownloadsListState>(
          builder: (context, state) => builder(context, _collect(state)),
        ),
      );
}

class _DownloadsView extends StatelessWidget {
  const _DownloadsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: const GuardedBackButton(),
        backgroundColor: AppTheme.bg,
        title: const Text('Download'),
      ),
      body: _DownloadsBuilder(builder: (context, c) {
        if (c.rows == null) return c.message!;
        final groups = groupDownloads(c.rows!);
        if (groups.isEmpty) {
          return const _CenterMessage(
            icon: Icons.download_done_rounded,
            title: 'Nessun download',
            message: 'I contenuti scaricati sul server compariranno qui.',
          );
        }
        final note = c.offlineNote;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length + (note != null ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (note != null) {
              if (i == 0) return _Note(note);
              i--;
            }
            final g = groups[i];
            if (!g.isSeries) {
              final info = g.items.first;
              return _DownloadRow(
                  info: info, onServer: c.onServer.contains(info.downloadId));
            }
            return _SeriesCard(group: g);
          },
        );
      }),
    );
  }
}

/// A series in the list: poster, how many episodes, how much space — opens
/// its own page with just the downloaded episodes.
class _SeriesCard extends StatelessWidget {
  final DownloadGroup group;
  const _SeriesCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final g = group;
    final device = DeviceDownloads.instance;
    final onDevice =
        g.items.where((i) => device.localPathFor(i.downloadId) != null).length;
    final sub = [
      '${g.items.length} ${g.items.length == 1 ? 'episodio' : 'episodi'}',
      if (g.totalBytes > 0) formatBytes(g.totalBytes),
      if (g.anyInProgress) 'in preparazione',
      if (onDevice > 0) '$onDevice sul dispositivo',
    ].join(' · ');
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final cubit = context.read<DownloadsListCubit>();
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: _SeriesDownloadsPage(group: g),
            ),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              _Poster(url: g.poster),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(g.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textHigh,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(sub,
                        style: const TextStyle(
                            color: AppTheme.textMid, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMid),
            ],
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final String url;
  const _Poster({required this.url});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 64,
          height: 96,
          // Cached: the poster still shows offline once seen.
          child: url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: AppTheme.surface2),
                  placeholder: (_, __) =>
                      const ColoredBox(color: AppTheme.surface2))
              : const ColoredBox(color: AppTheme.surface2),
        ),
      );
}

/// A series' page with only what was downloaded of it — laid out like its
/// details page (backdrop, title, synopsis, then the episodes by season),
/// working offline from what the downloads carry; the backdrop and synopsis
/// come from the plugin when the server answers.
class _SeriesDownloadsPage extends StatelessWidget {
  final DownloadGroup group;
  const _SeriesDownloadsPage({required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: _DownloadsBuilder(builder: (context, c) {
        // Live: the same group from the current list (statuses move,
        // episodes get deleted); the one opened stays as a fallback.
        final live = c.rows == null
            ? null
            : groupDownloads(c.rows!)
                .where((g) => g.key == group.key)
                .firstOrNull;
        final g = live ?? group;
        final onServer = c.rows == null
            ? {for (final i in group.items) i.downloadId}
            : c.onServer;
        final device = DeviceDownloads.instance;
        final copyable = [
          for (final i in g.items)
            if (device.supported &&
                onServer.contains(i.downloadId) &&
                i.status == 'completed' &&
                i.fileUrl.isNotEmpty &&
                device.localPathFor(i.downloadId) == null &&
                device.transferFor(i.downloadId) == null)
              i
        ];
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 220,
              backgroundColor: AppTheme.bg,
              title: Text(g.title),
              flexibleSpace: FlexibleSpaceBar(
                background: _SeriesBackdrop(group: g),
              ),
            ),
            SliverToBoxAdapter(
              child: _SeriesSummary(
                group: g,
                copyable: copyable,
                offlineNote: c.offlineNote,
              ),
            ),
            for (final season in g.seasons) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Text(
                    season > 0 ? 'Stagione $season' : 'Episodi',
                    style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SliverList.separated(
                itemCount:
                    g.items.where((i) => i.seasonNumber == season).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final info = g.items
                      .where((x) => x.seasonNumber == season)
                      .elementAt(i);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _DownloadRow(
                      info: info,
                      onServer: onServer.contains(info.downloadId),
                      label: episodeRowLabel(info),
                    ),
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      }),
    );
  }
}

/// The series' backdrop from the plugin (best-effort, the server may be
/// unreachable), else its poster blurred into the header.
class _SeriesBackdrop extends StatefulWidget {
  final DownloadGroup group;
  const _SeriesBackdrop({required this.group});

  @override
  State<_SeriesBackdrop> createState() => _SeriesBackdropState();
}

// The plugin's synopsis per series, once a backdrop lookup brought it.
final ValueNotifier<Map<String, String>> _plots = ValueNotifier(const {});

class _SeriesBackdropState extends State<_SeriesBackdrop> {
  String _fanart = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = widget.group;
    try {
      final d = await getIt<MediaRepository>()
          .getDetails(g.pluginId, g.parentId)
          .timeout(const Duration(seconds: 5));
      if (!mounted || !d.hasSeries()) return;
      _plots.value = {..._plots.value, g.key: d.series.plot};
      setState(() => _fanart = d.series.fanartUrl);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final url = _fanart.isNotEmpty ? _fanart : widget.group.poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: AppTheme.surface2),
          )
        else
          const ColoredBox(color: AppTheme.surface2),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x330D0D1A), AppTheme.bg],
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesSummary extends StatelessWidget {
  final DownloadGroup group;
  final List<DownloadInfo> copyable;
  final String? offlineNote;
  const _SeriesSummary(
      {required this.group, required this.copyable, this.offlineNote});

  @override
  Widget build(BuildContext context) {
    final g = group;
    final sub = [
      '${g.items.length} ${g.items.length == 1 ? 'episodio scaricato' : 'episodi scaricati'}',
      if (g.totalBytes > 0) formatBytes(g.totalBytes),
      if (g.anyInProgress) 'alcuni in preparazione',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offlineNote != null) ...[
            _Note(offlineNote!),
            const SizedBox(height: 10),
          ],
          Text(sub,
              style: const TextStyle(color: AppTheme.textMid, fontSize: 13)),
          ValueListenableBuilder(
            valueListenable: _plots,
            builder: (context, plots, _) {
              final plot = plots[g.key] ?? '';
              if (plot.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(plot,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textMid, fontSize: 13, height: 1.35)),
              );
            },
          ),
          if (copyable.length > 1) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                for (final i in copyable) {
                  DeviceDownloads.instance.start(i);
                }
              },
              icon: const Icon(Icons.download_for_offline_outlined, size: 18),
              label: Text('Scarica sul dispositivo (${copyable.length})'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 18, color: AppTheme.textMid),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppTheme.textMid, fontSize: 12)),
          ),
        ],
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
  // false: a copy on this device only (the server doesn't list it, or can't
  // be reached) — no server actions on it.
  final bool onServer;
  // Inside a series page: "S1 · E3 — Titolo" instead of "Serie · Titolo".
  final String? label;
  const _DownloadRow({required this.info, this.onServer = true, this.label});

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ready = info.status == 'completed';
    final device = DeviceDownloads.instance;
    final localPath = device.localPathFor(info.downloadId);
    final transfer = device.transferFor(info.downloadId);
    final copying = transfer != null && transfer.error.isEmpty;
    final canCopy = device.supported &&
        onServer &&
        ready &&
        info.fileUrl.isNotEmpty &&
        localPath == null &&
        !copying;
    final subtitle = [
      if (onServer)
        downloadStatusLabel(info, formatTime: _fmtTime)
      else
        'Solo su questo dispositivo',
      if (info.fileBytes > 0 || info.estimatedBytes > 0)
        formatBytes((info.fileBytes > 0 ? info.fileBytes : info.estimatedBytes)
            .toInt()),
      if (onServer && ready && info.expiresAt > 0)
        'sul server fino al ${_fmtDate(DateTime.fromMillisecondsSinceEpoch(info.expiresAt.toInt() * 1000))}',
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
              // Cached: the poster still shows offline once seen.
              child: info.poster.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: info.poster,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: AppTheme.surface2),
                      placeholder: (_, __) =>
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
                  label ??
                      (info.seriesTitle.isNotEmpty
                          ? '${info.seriesTitle} · ${info.title}'
                          : info.title),
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
                if (copying)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: transfer.running && transfer.total > 0
                                ? transfer.fraction
                                : null,
                            minHeight: 5,
                            backgroundColor: AppTheme.surface2,
                            color: AppTheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transfer.running
                              ? 'Copia sul dispositivo · '
                                  '${formatBytes(transfer.received)}'
                                  '${transfer.total > 0 ? ' di ${formatBytes(transfer.total)}' : ''}'
                              : 'Copia sul dispositivo in coda',
                          style: const TextStyle(
                              color: AppTheme.textMid, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else if (transfer != null && transfer.error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(transfer.error,
                        style: const TextStyle(
                            color: Color(0xFFFF6B6B), fontSize: 11)),
                  )
                else if (localPath != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: _Badge('Sul dispositivo'),
                  ),
                if (canCopy || (transfer != null && transfer.error.isNotEmpty))
                  if (onServer && ready && info.fileUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: () => device.start(info),
                        icon: const Icon(Icons.download_for_offline_outlined,
                            size: 16),
                        label: Text(
                            transfer != null
                                ? 'Riprendi la copia'
                                : 'Scarica sul dispositivo',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                if (onServer &&
                    ready &&
                    localPath != null &&
                    !copying &&
                    context.read<DownloadsListCubit>().hasQualityUpgrade(info))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton.icon(
                      // The server copy got a better quality since this
                      // device took its own: copy it again (the old file
                      // is replaced once the new one is complete).
                      onPressed: () => device.start(info),
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
              tooltip:
                  localPath != null ? 'Guarda (dal dispositivo)' : 'Guarda',
              icon: Icon(
                  localPath != null
                      ? Icons.offline_pin_rounded
                      : Icons.play_circle_fill_rounded,
                  color: AppTheme.primary),
              onPressed: () => _watch(context, info, localPath: localPath),
            ),
          if (copying)
            IconButton(
              tooltip: 'Annulla la copia',
              icon: const Icon(Icons.close_rounded, color: AppTheme.textMid),
              onPressed: () => device.cancel(info.downloadId),
            )
          else if (!onServer)
            IconButton(
              tooltip: 'Rimuovi dal dispositivo',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFF6B6B)),
              onPressed: () => _confirmRemoveLocal(context, info),
            )
          else if (info.status == 'queued' ||
              info.status == 'scheduled' ||
              info.status == 'running')
            IconButton(
              tooltip: 'Annulla',
              icon: const Icon(Icons.close_rounded, color: AppTheme.textMid),
              onPressed: () => _run(
                  context,
                  () => context
                      .read<DownloadsListCubit>()
                      .cancelDownload(info.downloadId),
                  'Impossibile annullare il download'),
            )
          else
            IconButton(
              tooltip: 'Elimina',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFF6B6B)),
              onPressed: () => _confirmDelete(context, info),
            ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  /// Runs a cancel/delete, surfacing a failure instead of dropping it
  /// (it used to escape as an uncaught async error with no feedback).
  Future<void> _run(BuildContext context, Future<void> Function() action,
      String failure) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('$failure: ${grpcMessage(e)}')));
    }
  }

  /// Deleting removes the file from the server for good — one stray tap on
  /// the bin icon used to do it with no confirmation. With a copy on this
  /// device too, the choice is which one goes.
  Future<void> _confirmDelete(BuildContext context, DownloadInfo info) async {
    if (!TapGuard.acquire()) return;
    final cubit = context.read<DownloadsListCubit>();
    final device = DeviceDownloads.instance;
    final hasLocal = device.localPathFor(info.downloadId) != null;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminare il download?'),
        content: Text(hasLocal
            ? '«${info.title}» è sia sul server sia su questo dispositivo. '
                'Cosa vuoi eliminare?'
            : '«${info.title}» verrà rimosso dal server. L\'operazione non '
                'si può annullare.'),
        actions: [
          TextButton(
              onPressed: () => popIfCurrent(ctx, null),
              child: const Text('Annulla')),
          if (hasLocal)
            TextButton(
                onPressed: () => popIfCurrent(ctx, 'local'),
                child: const Text('Solo dal dispositivo')),
          FilledButton(
              onPressed: () => popIfCurrent(ctx, 'server'),
              child: Text(hasLocal ? 'Dal server' : 'Elimina')),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'local') {
      await device.removeLocal(info.downloadId);
      return;
    }
    await _run(context, () => cubit.deleteDownload(info.downloadId),
        'Impossibile eliminare il download');
  }

  Future<void> _confirmRemoveLocal(
      BuildContext context, DownloadInfo info) async {
    if (!TapGuard.acquire()) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Rimuovere dal dispositivo?'),
        content: Text('Il file di «${info.title}» verrà eliminato da questo '
            'dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => popIfCurrent(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => popIfCurrent(ctx, true),
              child: const Text('Rimuovi')),
        ],
      ),
    );
    if (yes == true) {
      await DeviceDownloads.instance.removeLocal(info.downloadId);
    }
  }

  // Resume point + progressive-format hint: see downloadPlaybackExtra. This
  // page used to pass neither — a download replayed from here always
  // started at 0, and was opened by guessing the format from the URL.
  // The tap guard is taken before the Continue Watching lookup: taken at
  // push time, a double tap would run two lookups and could push twice.
  Future<void> _watch(BuildContext context, DownloadInfo info,
      {String? localPath}) async {
    if (!TapGuard.acquire()) return;
    final extra = await downloadPlaybackExtra(info, localPath: localPath);
    if (!context.mounted) return;
    GoRouter.of(context).push(
      '/player/${info.pluginId}/${Uri.encodeComponent(info.mediaId)}',
      extra: extra,
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
