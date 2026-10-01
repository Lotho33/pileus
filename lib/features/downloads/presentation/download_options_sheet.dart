// Shared download-options bottom sheet — mobile/desktop/web (touch/mouse;
// TV needs its own D-pad-navigable screen, not built yet, see the module's
// own tracking note). One instance covers all three since they're all
// pointer-driven and Material's ModalBottomSheet already adapts reasonably
// to a mouse on desktop/web (same reasoning mobile_item_sheet.dart's bottom
// sheet already relies on).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../media/data/media_repository.dart';
import '../bloc/download_options_cubit.dart';
import '../bloc/download_options_state.dart';
import '../download_format.dart';

/// Opens the sheet, resolves a download-worthy stream itself (GetStreams +
/// same default-source pick the "Riproduci" button uses), then walks the
/// user through GetDownloadOptions. Returns once the sheet closes — the
/// caller doesn't need the result, everything lands in the Download page via
/// ListDownloads.
///
/// [batchGroups]: "Scarica la stagione" / "Scarica i prossimi N episodi" —
/// offered alongside the single-episode choice when non-empty (contract:
/// "per le serie"). Left empty for a movie or when calling from a context
/// with no season/episode list at hand.
Future<void> showDownloadOptionsSheet(
  BuildContext context, {
  required String pluginId,
  required String preferredSourceLabel,
  required DownloadTarget target,
  List<DownloadBatchGroup> batchGroups = const [],
}) async {
  final repo = getIt<MediaRepository>();
  final streamsRes = await repo.getStreams(pluginId, target.mediaId);
  if (!context.mounted) return;
  if (streamsRes.sources.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna sorgente disponibile.')));
    return;
  }
  final source = preferredSourceLabel.isNotEmpty
      ? (streamsRes.sources
              .where((s) =>
                  s.label.toLowerCase() == preferredSourceLabel.toLowerCase())
              .firstOrNull ??
          streamsRes.sources.first)
      : streamsRes.sources.first;
  final resolvedTarget = DownloadTarget(
    mediaId: target.mediaId,
    streamId: source.id,
    parentId: target.parentId,
    title: target.title,
    seriesTitle: target.seriesTitle,
    poster: target.poster,
    seasonNumber: target.seasonNumber,
    episodeNumber: target.episodeNumber,
  );
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141428),
    showDragHandle: true,
    builder: (sheetCtx) => BlocProvider(
      create: (_) => DownloadOptionsCubit(repo, pluginId: pluginId)
        ..load(resolvedTarget.streamId),
      child: _DownloadOptionsSheetBody(
        target: resolvedTarget,
        pluginId: pluginId,
        preferredSourceLabel: preferredSourceLabel,
        batchGroups: batchGroups,
      ),
    ),
  );
}

class _DownloadOptionsSheetBody extends StatelessWidget {
  final DownloadTarget target;
  final String pluginId;
  final String preferredSourceLabel;
  final List<DownloadBatchGroup> batchGroups;
  const _DownloadOptionsSheetBody({
    required this.target,
    required this.pluginId,
    required this.preferredSourceLabel,
    required this.batchGroups,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: BlocBuilder<DownloadOptionsCubit, DownloadOptionsState>(
          builder: (context, state) => switch (state) {
            DownloadOptionsLoading() => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator())),
            DownloadOptionsUnavailable(:final reason) => _MessagePane(
                icon: Icons.download_for_offline_outlined,
                title: 'Non scaricabile',
                message: reason,
              ),
            DownloadOptionsError(:final message) => _MessagePane(
                icon: Icons.error_outline_rounded,
                title: 'Impossibile caricare le opzioni',
                message: message,
                onRetry: () => context
                    .read<DownloadOptionsCubit>()
                    .load(target.streamId),
              ),
            DownloadOptionsReady() => _ReadyBody(
                state: state,
                target: target,
                pluginId: pluginId,
                preferredSourceLabel: preferredSourceLabel,
                batchGroups: batchGroups,
              ),
            DownloadOptionsSubmitting(:final done, :final total) =>
              _MessagePane(
                icon: Icons.cloud_download_outlined,
                title: total > 1
                    ? 'Avvio download $done/$total…'
                    : 'Avvio download…',
                message: '',
                spinner: true,
              ),
            DownloadOptionsSubmitted(:final created) => _MessagePane(
                icon: Icons.check_circle_outline_rounded,
                title: created.length > 1
                    ? '${created.length} download avviati'
                    : 'Download avviato',
                message: 'Lo trovi nella pagina Download.',
                onDone: () => Navigator.of(context).pop(),
              ),
            DownloadOptionsSubmitFailed(:final message) => _MessagePane(
                icon: Icons.error_outline_rounded,
                title: 'Download non avviato',
                message: message,
                onDone: () => Navigator.of(context).pop(),
              ),
          },
        ),
      ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool spinner;
  final VoidCallback? onRetry;
  final VoidCallback? onDone;
  const _MessagePane({
    required this.icon,
    required this.title,
    required this.message,
    this.spinner = false,
    this.onRetry,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CircularProgressIndicator(),
            )
          else
            Icon(icon, size: 40, color: AppTheme.textMid),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: AppTheme.textMid, fontSize: 14),
                textAlign: TextAlign.center),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
          if (onDone != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onDone, child: const Text('Chiudi')),
          ],
        ],
      ),
    );
  }
}

class _ReadyBody extends StatefulWidget {
  final DownloadOptionsReady state;
  final DownloadTarget target;
  final String pluginId;
  final String preferredSourceLabel;
  final List<DownloadBatchGroup> batchGroups;
  const _ReadyBody({
    required this.state,
    required this.target,
    required this.pluginId,
    required this.preferredSourceLabel,
    required this.batchGroups,
  });

  @override
  State<_ReadyBody> createState() => _ReadyBodyState();
}

class _ReadyBodyState extends State<_ReadyBody> {
  // null = "solo questo episodio" (the default, and the only choice when
  // widget.batchGroups is empty).
  int? _selectedGroup;
  bool _resolvingBatch = false;

  /// Resolves every OTHER candidate in the chosen group to its own stream id
  /// (the episode the sheet was opened for is already resolved — reused as-
  /// is via widget.target, matched by mediaId, saving one GetStreams call)
  /// and hands the full list to confirmBatch. A season can be a couple dozen
  /// GetStreams calls — deliberately only done once the user actually picks
  /// this group, not while just showing the choice.
  Future<void> _confirmGroup(DownloadBatchGroup group) async {
    setState(() => _resolvingBatch = true);
    final repo = getIt<MediaRepository>();
    final targets = <DownloadTarget>[];
    try {
      for (final c in group.candidates) {
        if (c.mediaId == widget.target.mediaId) {
          targets.add(widget.target);
          continue;
        }
        final streamsRes = await repo.getStreams(widget.pluginId, c.mediaId);
        if (streamsRes.sources.isEmpty) continue; // skip, don't fail the batch
        final source = widget.preferredSourceLabel.isNotEmpty
            ? (streamsRes.sources
                    .where((s) =>
                        s.label.toLowerCase() ==
                        widget.preferredSourceLabel.toLowerCase())
                    .firstOrNull ??
                streamsRes.sources.first)
            : streamsRes.sources.first;
        targets.add(DownloadTarget(
          mediaId: c.mediaId,
          streamId: source.id,
          parentId: c.parentId,
          title: c.title,
          seriesTitle: c.seriesTitle,
          poster: c.poster,
          seasonNumber: c.seasonNumber,
          episodeNumber: c.episodeNumber,
        ));
      }
    } catch (_) {
      // Whatever resolved so far still goes into confirmBatch below — a
      // single episode's GetStreams failing shouldn't lose the rest of an
      // otherwise-fine season.
    }
    if (!mounted) return;
    setState(() => _resolvingBatch = false);
    if (targets.isEmpty) return;
    context.read<DownloadOptionsCubit>().confirmBatch(targets);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final target = widget.target;
    final cubit = context.read<DownloadOptionsCubit>();
    final resp = state.response;
    final totalLabel = formatBytes(state.totalBytes);
    // A batch group's estimated total replaces the single-episode fit check
    // once one is selected — the whole point of showing that estimate
    // (contract point 3) is so "does this fit" is meaningful for what's
    // actually about to be requested, not just the reference episode alone.
    final fits = _selectedGroup != null
        ? state.estimateBatchBytes(
                widget.batchGroups[_selectedGroup!].candidates.length) <=
            resp.serverFreeBytes.toInt()
        : state.fitsServerSpace;
    final eta =
        formatEtaLabel(state.totalBytes, resp.bytesPerSec.toInt());
    final warning = qualityBelowUsualWarning(
      qualityBelowUsual: resp.qualityBelowUsual,
      usualMaxHeight: resp.usualMaxHeight,
      bestHeightNow: resp.variants.isNotEmpty ? resp.variants.first.height : 0,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Scarica',
              style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          if (target.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(target.title,
                  style: const TextStyle(
                      color: AppTheme.textMid, fontSize: 13)),
            ),
          if (widget.batchGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Cosa scaricare',
                style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Solo questo episodio'),
                  selected: _selectedGroup == null,
                  onSelected: (_) => setState(() => _selectedGroup = null),
                ),
                for (var i = 0; i < widget.batchGroups.length; i++)
                  ChoiceChip(
                    label: Text(widget.batchGroups[i].label),
                    selected: _selectedGroup == i,
                    onSelected: (_) => setState(() => _selectedGroup = i),
                  ),
              ],
            ),
            if (_selectedGroup != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    // Contract: "stimalo come peso del primo episodio × N"
                    // — the real per-batch total only exists once
                    // CreateDownloads actually runs.
                    'Stima: ${formatBytes(state.estimateBatchBytes(widget.batchGroups[_selectedGroup!].candidates.length))} totali '
                    '(${widget.batchGroups[_selectedGroup!].candidates.length} episodi)',
                    style: const TextStyle(
                        color: AppTheme.textMid, fontSize: 12)),
              ),
          ],
          const SizedBox(height: 16),
          const Text('Qualità',
              style: TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in resp.variants)
                ChoiceChip(
                  label: Text('${v.label} · ${formatVariantSize(v)}'),
                  selected: state.selectedVariantId == v.id,
                  onSelected: (_) => cubit.selectVariant(v.id),
                ),
            ],
          ),
          if (resp.audio.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Audio',
                style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in resp.audio)
                  FilterChip(
                    label: Text(
                        '${a.language.isNotEmpty ? a.language : a.name} '
                        '· ${formatBytes(a.estimatedBytes.toInt())}'),
                    selected: state.selectedAudioIds.contains(a.id),
                    onSelected: (_) => cubit.toggleAudio(a.id),
                  ),
              ],
            ),
          ],
          if (resp.subtitles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Sottotitoli',
                style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in resp.subtitles)
                  FilterChip(
                    label: Text(s.language.isNotEmpty ? s.language : s.name),
                    selected: state.selectedSubtitleIds.contains(s.id),
                    onSelected: (_) => cubit.toggleSubtitle(s.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Peso totale stimato',
                  style: TextStyle(color: AppTheme.textMid, fontSize: 13)),
              Text(totalLabel,
                  style: TextStyle(
                      color: fits ? AppTheme.textHigh : const Color(0xFFFF6B6B),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          if (!fits)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Non c’è abbastanza spazio libero sul server.',
                  style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
            ),
          if (eta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tempo di preparazione stimato: $eta',
                  style: const TextStyle(
                      color: AppTheme.textMid, fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(retentionLabel(resp.retentionDays),
                style: const TextStyle(color: AppTheme.textMid, fontSize: 12)),
          ),
          if (resp.pluginNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(resp.pluginNote,
                  style: const TextStyle(
                      color: AppTheme.textMid,
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
            ),
          if (resp.pluginNotice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(resp.pluginNotice,
                  style: const TextStyle(
                      color: AppTheme.secondary, fontSize: 12)),
            ),
          if (warning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(warning,
                  style: const TextStyle(
                      color: Color(0xFFF5A623), fontSize: 12)),
            ),
          const SizedBox(height: 16),
          const Text('Quando',
              style: TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Scarica ora'),
                selected: state.scheduleKind == DownloadScheduleKind.now,
                onSelected: (_) => cubit.setScheduleNow(),
              ),
              if (resp.preferredHours.isNotEmpty)
                ChoiceChip(
                  label: Text('Fascia consigliata (${resp.preferredHours})'),
                  selected: state.scheduleKind ==
                      DownloadScheduleKind.preferredWindow,
                  onSelected: (_) => cubit.setSchedulePreferredWindow(),
                ),
              ChoiceChip(
                label: Text(state.scheduledAt != null
                    ? 'Alle ${_fmtTime(state.scheduledAt!)}'
                    : 'Programma alle…'),
                selected:
                    state.scheduleKind == DownloadScheduleKind.specificTime,
                onSelected: (_) async {
                  final now = TimeOfDay.now();
                  final picked = await showTimePicker(
                      context: context, initialTime: now);
                  if (picked == null) return;
                  final today = DateTime.now();
                  var when = DateTime(today.year, today.month, today.day,
                      picked.hour, picked.minute);
                  if (when.isBefore(today)) {
                    when = when.add(const Duration(days: 1));
                  }
                  if (context.mounted) cubit.setScheduleAt(when);
                },
              ),
            ],
          ),
          // "consigliata dalla sorgente" / "in queste ore la qualità di
          // solito è migliore" — where preferred_hours comes from, shown
          // only once the user has actually picked that chip (otherwise it's
          // just noise under a choice they haven't made).
          if (state.scheduleKind == DownloadScheduleKind.preferredWindow &&
              preferredHoursSourceLabel(resp.preferredHoursSource).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  preferredHoursSourceLabel(resp.preferredHoursSource),
                  style: const TextStyle(
                      color: AppTheme.textMid, fontSize: 12)),
            ),
          const SizedBox(height: 14),
          // Default-checked exactly when the server already flagged
          // quality_below_usual (contract) — see DownloadOptionsCubit.load.
          CheckboxListTile(
            value: state.upgradeIfBetter,
            onChanged: (_) => cubit.toggleUpgradeIfBetter(),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
                'Se la qualità ora è più bassa del solito, riprova di notte '
                'e sostituisci il file',
                style: TextStyle(color: AppTheme.textHigh, fontSize: 13)),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: !fits || _resolvingBatch
                ? null
                : (_selectedGroup == null
                    ? () => cubit.confirmSingle(target)
                    : () => _confirmGroup(widget.batchGroups[_selectedGroup!])),
            icon: _resolvingBatch
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            label: Text(_resolvingBatch ? 'Preparazione…' : 'Scarica'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
