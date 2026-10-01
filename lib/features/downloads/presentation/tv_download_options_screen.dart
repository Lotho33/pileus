// TV download-options screen — a full-screen D-pad-navigable settings-style
// list rather than the mobile/desktop/web bottom sheet (a modal sheet with
// several rows of side-by-side chips has no sane D-pad traversal; a single
// vertical column of SettingsNavRow/SettingsToggleRow, the same idiom every
// other TV settings screen in the app already uses, does). Drives the exact
// same DownloadOptionsCubit as the other three platforms — only the
// presentation differs.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/back_dispatch.dart';
import '../../../shared/widgets/ambient_glow_background.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/settings/settings_header.dart';
import '../../../shared/widgets/settings/settings_nav_row.dart';
import '../../../shared/widgets/settings/settings_section_header.dart';
import '../../../shared/widgets/settings/settings_toggle_row.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../../media/data/media_repository.dart';
import '../bloc/download_options_cubit.dart';
import '../bloc/download_options_state.dart';
import '../download_format.dart';

/// Convenience wrapper — mirrors showDownloadOptionsSheet's call shape so a
/// call site can pass the same arguments regardless of platform, letting
/// TvFocusable/route wiring be app_router.dart's concern, not every caller's.
void pushTvDownloadOptions(
  BuildContext context, {
  required String pluginId,
  required DownloadTarget target,
  String preferredSourceLabel = '',
  List<DownloadBatchGroup> batchGroups = const [],
}) {
  context.push('/download-options', extra: <String, dynamic>{
    'pluginId': pluginId,
    'target': target,
    'preferredSourceLabel': preferredSourceLabel,
    'batchGroups': batchGroups,
  });
}

class TvDownloadOptionsScreen extends StatelessWidget {
  final String pluginId;
  final String preferredSourceLabel;
  final DownloadTarget target;
  final List<DownloadBatchGroup> batchGroups;

  const TvDownloadOptionsScreen({
    super.key,
    required this.pluginId,
    required this.target,
    this.preferredSourceLabel = '',
    this.batchGroups = const [],
  });

  @override
  Widget build(BuildContext context) {
    final repo = getIt<MediaRepository>();
    return FutureBuilder(
      // Same GetStreams + default-source pick as the sheet's own entry
      // point (showDownloadOptionsSheet) — kept here rather than a second
      // shared helper since the TV screen also needs a widget to show
      // while it's in flight (the bottom sheet's caller instead awaits it
      // before ever opening anything).
      future: repo.getStreams(pluginId, target.mediaId),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return const _Scaffold(
            body: Center(child: PileusSpinner(size: 48)),
          );
        }
        if (snap.hasError || snap.data!.sources.isEmpty) {
          return _Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: Text('Nessuna sorgente disponibile.',
                    style: TextStyle(
                        color: AppTheme.textMid,
                        fontSize: AppScale.label(context))),
              ),
            ),
          );
        }
        final sources = snap.data!.sources;
        final source = preferredSourceLabel.isNotEmpty
            ? (sources
                    .where((s) =>
                        s.label.toLowerCase() ==
                        preferredSourceLabel.toLowerCase())
                    .firstOrNull ??
                sources.first)
            : sources.first;
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
        return BlocProvider(
          create: (_) => DownloadOptionsCubit(repo, pluginId: pluginId)
            ..load(resolvedTarget.streamId),
          child: _Body(
            target: resolvedTarget,
            pluginId: pluginId,
            preferredSourceLabel: preferredSourceLabel,
            batchGroups: batchGroups,
          ),
        );
      },
    );
  }
}

class _Scaffold extends StatelessWidget {
  final Widget body;
  const _Scaffold({required this.body});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () {
        if (consumeBackEvent()) context.pop();
      },
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: AmbientGlowBackground(child: SafeArea(child: body)),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  final DownloadTarget target;
  final String pluginId;
  final String preferredSourceLabel;
  final List<DownloadBatchGroup> batchGroups;
  const _Body({
    required this.target,
    required this.pluginId,
    required this.preferredSourceLabel,
    required this.batchGroups,
  });

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _backFn = FocusNode();
  // Stable identity across rebuilds, created lazily per logical row (see
  // _nodeFor) — the row COUNT is fixed once DownloadOptionsReady is first
  // reached (toggling a selection changes what a row shows, never how many
  // there are), so caching by a string key is enough; no row is ever
  // recreated with a fresh node under a still-focused finger.
  final _nodes = <String, FocusNode>{};
  bool _resolvingBatch = false;
  // null = "solo questo episodio" — same meaning/default as the sheet's own
  // _selectedGroup.
  int? _selectedGroup;

  FocusNode _nodeFor(String key) => _nodes.putIfAbsent(key, () => FocusNode());

  @override
  void dispose() {
    _backFn.dispose();
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _cycleBatchGroup() {
    final n = widget.batchGroups.length;
    setState(() {
      _selectedGroup =
          _selectedGroup == null ? 0 : (_selectedGroup! + 1 >= n ? null : _selectedGroup! + 1);
    });
  }

  /// Resolves every other candidate in [group] to its own stream (the
  /// episode this screen was opened for is already resolved, reused as-is)
  /// then hands the full list to confirmBatch — same approach as the
  /// mobile/desktop/web sheet's own _confirmGroup.
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
        if (streamsRes.sources.isEmpty) continue;
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
      // Whatever resolved so far still goes into confirmBatch — see the
      // sheet's identical reasoning.
    }
    if (!mounted) return;
    setState(() => _resolvingBatch = false);
    if (targets.isEmpty) return;
    context.read<DownloadOptionsCubit>().confirmBatch(targets);
  }

  void _confirm() {
    final cubit = context.read<DownloadOptionsCubit>();
    final sel = _selectedGroup;
    if (sel == null) {
      cubit.confirmSingle(widget.target);
    } else {
      _confirmGroup(widget.batchGroups[sel]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Scaffold(
      body: Column(
        children: [
          SettingsHeader(
            title: 'Scarica',
            focusNode: _backFn,
            onBack: () => context.pop(),
            onFocusDown: () => _nodeFor('first').requestFocus(),
          ),
          Expanded(
            child: BlocConsumer<DownloadOptionsCubit, DownloadOptionsState>(
              listener: (context, state) {
                if (state is DownloadOptionsSubmitted) {
                  // No further action needed here — same as the sheet's
                  // "Chiudi" pane, just auto-dismissed on TV instead of
                  // waiting for an extra confirm press.
                  Future.delayed(const Duration(milliseconds: 900), () {
                    if (context.mounted) context.pop();
                  });
                }
              },
              builder: (context, state) => switch (state) {
                DownloadOptionsLoading() =>
                  const Center(child: PileusSpinner(size: 48)),
                DownloadOptionsUnavailable(:final reason) => _Message(
                    icon: Icons.download_for_offline_outlined,
                    title: 'Non scaricabile',
                    message: reason),
                DownloadOptionsError(:final message) => _Message(
                    icon: Icons.error_outline_rounded,
                    title: 'Impossibile caricare le opzioni',
                    message: message),
                DownloadOptionsReady() => _ReadyList(
                    state: state,
                    target: widget.target,
                    batchGroups: widget.batchGroups,
                    selectedGroup: _selectedGroup,
                    onCycleBatchGroup: _cycleBatchGroup,
                    nodeFor: _nodeFor,
                    backFn: _backFn,
                    resolvingBatch: _resolvingBatch,
                    onConfirm: _confirm,
                  ),
                DownloadOptionsSubmitting(:final done, :final total) =>
                  _Message(
                      icon: Icons.cloud_download_outlined,
                      title: total > 1
                          ? 'Avvio download $done/$total…'
                          : 'Avvio download…',
                      message: '',
                      spinner: true),
                DownloadOptionsSubmitted(:final created) => _Message(
                    icon: Icons.check_circle_outline_rounded,
                    title: created.length > 1
                        ? '${created.length} download avviati'
                        : 'Download avviato',
                    message: 'Lo trovi nella pagina Download.'),
                DownloadOptionsSubmitFailed(:final message) => _Message(
                    icon: Icons.error_outline_rounded,
                    title: 'Download non avviato',
                    message: message),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool spinner;
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.spinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppScale.space(context, 32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: PileusSpinner(size: 40),
              )
            else
              Icon(icon,
                  size: AppScale.iconL(context), color: AppTheme.textMid),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: AppScale.title(context),
                    fontWeight: FontWeight.w700)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textMid,
                      fontSize: AppScale.label(context))),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadyList extends StatelessWidget {
  final DownloadOptionsReady state;
  final DownloadTarget target;
  final List<DownloadBatchGroup> batchGroups;
  final int? selectedGroup;
  final VoidCallback onCycleBatchGroup;
  final FocusNode Function(String key) nodeFor;
  final FocusNode backFn;
  final bool resolvingBatch;
  final VoidCallback onConfirm;

  const _ReadyList({
    required this.state,
    required this.target,
    required this.batchGroups,
    required this.selectedGroup,
    required this.onCycleBatchGroup,
    required this.nodeFor,
    required this.backFn,
    required this.resolvingBatch,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DownloadOptionsCubit>();
    final resp = state.response;

    // Flat, ordered list of every row's stable key — used both to render
    // and to chain each row's onFocusUp/onFocusDown to its neighbour, same
    // "linear list of focus nodes" idiom as SettingsScreen's fixed rows,
    // just built dynamically since the row count depends on how many
    // variants/tracks/groups this stream actually has.
    final keys = <String>[
      for (final v in resp.variants) 'variant_${v.id}',
      for (final a in resp.audio) 'audio_${a.id}',
      for (final s in resp.subtitles) 'subtitle_${s.id}',
      if (batchGroups.isNotEmpty) 'batch',
      'schedule',
      'upgrade',
      'confirm',
    ];
    FocusNode? up(int i) => i > 0 ? nodeFor(keys[i - 1]) : backFn;
    FocusNode? down(int i) =>
        i < keys.length - 1 ? nodeFor(keys[i + 1]) : null;

    final selectedVariant = state.selectedVariant;
    final batchEstimate = selectedGroup != null
        ? state.estimateBatchBytes(batchGroups[selectedGroup!].candidates.length)
        : state.totalBytes;
    final totalLabel = formatBytes(batchEstimate);
    final fits = batchEstimate <= resp.serverFreeBytes.toInt();
    final scheduleLabel = switch (state.scheduleKind) {
      DownloadScheduleKind.now => 'Ora',
      DownloadScheduleKind.preferredWindow =>
        'Fascia consigliata${resp.preferredHours.isNotEmpty ? ' (${resp.preferredHours})' : ''}',
      DownloadScheduleKind.specificTime => 'Ora',
    };

    var idx = 0;
    return ListView(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.screenHPad(context),
          vertical: AppScale.space(context, 8)),
      children: [
        if (target.title.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppScale.space(context, 24),
                vertical: AppScale.space(context, 4)),
            child: Text(target.title,
                style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: AppScale.caption(context))),
          ),
        const SettingsSectionHeader('Qualità'),
        for (final v in resp.variants) ...[
          Builder(builder: (_) {
            final i = idx++;
            return SettingsNavRow(
              icon: v.id == selectedVariant?.id
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              label: '${v.label} · ${formatVariantSize(v)}',
              focusNode: nodeFor(keys[i]),
              onFocusUp: () => up(i)?.requestFocus(),
              onFocusDown: () => down(i)?.requestFocus(),
              onTap: () => cubit.selectVariant(v.id),
            );
          }),
        ],
        if (resp.audio.isNotEmpty) ...[
          const SettingsSectionHeader('Audio'),
          for (final a in resp.audio) ...[
            Builder(builder: (_) {
              final i = idx++;
              return SettingsToggleRow(
                label: '${a.language.isNotEmpty ? a.language : a.name} '
                    '· ${formatBytes(a.estimatedBytes.toInt())}',
                value: state.selectedAudioIds.contains(a.id),
                onChanged: (_) => cubit.toggleAudio(a.id),
                focusNode: nodeFor(keys[i]),
                onFocusUp: () => up(i)?.requestFocus(),
                onFocusDown: () => down(i)?.requestFocus(),
              );
            }),
          ],
        ],
        if (resp.subtitles.isNotEmpty) ...[
          const SettingsSectionHeader('Sottotitoli'),
          for (final s in resp.subtitles) ...[
            Builder(builder: (_) {
              final i = idx++;
              return SettingsToggleRow(
                label: s.language.isNotEmpty ? s.language : s.name,
                value: state.selectedSubtitleIds.contains(s.id),
                onChanged: (_) => cubit.toggleSubtitle(s.id),
                focusNode: nodeFor(keys[i]),
                onFocusUp: () => up(i)?.requestFocus(),
                onFocusDown: () => down(i)?.requestFocus(),
              );
            }),
          ],
        ],
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppScale.space(context, 24),
              vertical: AppScale.space(context, 4)),
          child: Text(
              'Peso totale stimato: $totalLabel'
              '${fits ? '' : ' — non c’è abbastanza spazio libero sul server'}',
              style: TextStyle(
                  color: fits ? AppTheme.textMid : const Color(0xFFFF6B6B),
                  fontSize: AppScale.caption(context))),
        ),
        if (batchGroups.isNotEmpty) ...[
          const SettingsSectionHeader('Cosa scaricare'),
          Builder(builder: (_) {
            final i = idx++;
            // Cycles: solo questo → gruppo 1 → gruppo 2 → … → solo questo.
            // A single Select press to page through, same idiom as every
            // other single-choice-among-few row on TV in this app (no chip
            // grid, which has no sane D-pad traversal — see this file's own
            // top doc).
            return SettingsNavRow(
              icon: Icons.playlist_play_rounded,
              label: 'Cosa scaricare',
              subtitle: selectedGroup == null
                  ? 'Solo questo episodio'
                  : batchGroups[selectedGroup!].label,
              focusNode: nodeFor(keys[i]),
              onFocusUp: () => up(i)?.requestFocus(),
              onFocusDown: () => down(i)?.requestFocus(),
              onTap: onCycleBatchGroup,
            );
          }),
        ],
        Builder(builder: (_) {
          final i = idx++;
          return SettingsNavRow(
            icon: Icons.schedule_rounded,
            label: 'Quando',
            subtitle: scheduleLabel,
            focusNode: nodeFor(keys[i]),
            onFocusUp: () => up(i)?.requestFocus(),
            onFocusDown: () => down(i)?.requestFocus(),
            // Cycles ora → fascia consigliata (if any) → ora — TV skips the
            // free-text "programma a un orario" choice mobile/desktop/web
            // offer: typing an exact time with a D-pad remote has no good
            // input widget in this app yet, and "adesso"/"fascia
            // consigliata" already cover the common cases.
            onTap: () {
              if (state.scheduleKind == DownloadScheduleKind.now &&
                  resp.preferredHours.isNotEmpty) {
                cubit.setSchedulePreferredWindow();
              } else {
                cubit.setScheduleNow();
              }
            },
          );
        }),
        Builder(builder: (_) {
          final i = idx++;
          return SettingsToggleRow(
            label: 'Se la qualità è più bassa del solito, riprova di notte',
            value: state.upgradeIfBetter,
            onChanged: (_) => cubit.toggleUpgradeIfBetter(),
            focusNode: nodeFor(keys[i]),
            onFocusUp: () => up(i)?.requestFocus(),
          );
        }),
        SizedBox(height: AppScale.space(context, 12)),
        Builder(builder: (_) {
          final i = idx++;
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppScale.space(context, 16),
                vertical: AppScale.space(context, 4)),
            child: SettingsNavRow(
              icon: resolvingBatch
                  ? Icons.hourglass_top_rounded
                  : Icons.download_rounded,
              label: resolvingBatch ? 'Preparazione…' : 'Scarica',
              enabled: fits && !resolvingBatch,
              focusNode: nodeFor(keys[i]),
              onFocusUp: () => up(i)?.requestFocus(),
              onTap: onConfirm,
            ),
          );
        }),
      ],
    );
  }
}
