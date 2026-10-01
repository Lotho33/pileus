import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart' show PluginInfo;
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../media/bloc/plugin_bloc.dart';
import '../../media/bloc/plugin_event.dart';
import '../../media/bloc/plugin_state.dart';
import '../../media/data/media_repository.dart';
import '../../../shared/widgets/ambient_glow_background.dart';
import '../../../shared/widgets/error_retry_view.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/settings/plugin_reorder_dialog.dart';
import '../../../shared/widgets/settings/settings_header.dart';
import '../../../shared/widgets/settings/settings_nav_row.dart';
import '../../../shared/widgets/settings/settings_section_header.dart';
import '../../../shared/widgets/tv_focusable.dart';

/// Thin navigation hub — lists all installed plugins (unfiltered, same
/// criterion as _PluginNav in home_screen.dart) and pushes the EXISTING
/// /plugin-settings/:pluginId route for each. Does not reimplement
/// plugin_settings_screen.dart.
class SettingsPluginsScreen extends StatelessWidget {
  const SettingsPluginsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // PluginBloc is a lazy singleton (see injection.dart) shared with
    // HomeScreen — BlocProvider.value reuses it without taking ownership,
    // unlike BlocProvider(create: ...), which would close the shared bloc
    // the moment this screen is popped and break the home screen's copy.
    // The still-initial-state guard mirrors home_screen.dart's own: avoids
    // a redundant reload on the (overwhelmingly common) case where the
    // bloc is already loaded by the time this screen opens.
    final pluginBloc = getIt<PluginBloc>();
    if (pluginBloc.state is PluginInitial) {
      pluginBloc.add(const LoadPluginsEvent());
    }
    return BlocProvider.value(
      value: pluginBloc,
      child: const _SettingsPluginsBody(),
    );
  }
}

class _SettingsPluginsBody extends StatefulWidget {
  const _SettingsPluginsBody();

  @override
  State<_SettingsPluginsBody> createState() => _SettingsPluginsBodyState();
}

class _SettingsPluginsBodyState extends State<_SettingsPluginsBody> {
  final _backFn = FocusNode();
  final _reorderFn = FocusNode();
  // Keyed by pluginId, not index — the list can reorder/refresh under an
  // already-mounted screen (PluginBloc polls), so a node must stay tied to
  // the same plugin rather than whatever index it happened to render at.
  final Map<String, FocusNode> _pluginFns = {};

  FocusNode _pluginFn(String id) =>
      _pluginFns.putIfAbsent(id, () => FocusNode());

  // Plugins the active profile has hidden from the home — filtered out of
  // PluginBloc's list (see MediaRepository.listPlugins), so surfaced here
  // separately, otherwise a hidden plugin would be unreachable and could
  // never be re-enabled. Reloaded whenever we come back from a plugin's
  // settings, where its visibility can change.
  List<PluginInfo> _hidden = [];

  @override
  void initState() {
    super.initState();
    _loadHidden();
  }

  Future<void> _loadHidden() async {
    try {
      final repo = getIt<MediaRepository>();
      final all = await repo.listAllPlugins();
      final prefs = await repo.loadPluginPrefs();
      if (!mounted) return;
      setState(() => _hidden =
          all.where((p) => prefs.isPluginHidden(p.pluginId)).toList());
    } catch (_) {
      // Non-critical — the visible plugins stay fully manageable.
    }
  }

  void _openPlugin(String pluginId, String pluginName) {
    context.push('/plugin-settings/$pluginId', extra: {
      'pluginName': pluginName,
    }).then((_) {
      if (mounted) _loadHidden();
    });
  }

  @override
  void dispose() {
    _backFn.dispose();
    _reorderFn.dispose();
    for (final n in _pluginFns.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => context.pop(),
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: AmbientGlowBackground(
            child: Column(
          children: [
            SettingsHeader(
              title: 'Impostazioni plugin',
              focusNode: _backFn,
              onBack: () => context.pop(),
              onFocusDown: () => _reorderFn.requestFocus(),
            ),
            Expanded(
              child: BlocBuilder<PluginBloc, PluginState>(
                builder: (context, state) {
                  if (state is PluginLoading || state is PluginInitial) {
                    return Center(
                        child: PileusSpinner(
                            size: AppScale.spinnerL(context),
                            color: AppTheme.primary));
                  }
                  if (state is PluginError) {
                    return ErrorRetryView(
                      icon: Icons.cloud_off_rounded,
                      title: 'Impossibile raggiungere il server',
                      message: 'Controlla la connessione e riprova.',
                      detail: state.message,
                      onRetry: () => context
                          .read<PluginBloc>()
                          .add(const LoadPluginsEvent()),
                    );
                  }
                  if (state is PluginsLoaded) {
                    if (state.plugins.isEmpty && _hidden.isEmpty) {
                      return const Center(
                        child: Text('Nessun plugin disponibile',
                            style: TextStyle(color: AppTheme.textLow)),
                      );
                    }
                    final pluginBloc = context.read<PluginBloc>();
                    return ListView(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppScale.screenHPad(context),
                          vertical: AppScale.space(context, 12)),
                      children: [
                        SettingsNavRow(
                          icon: Icons.swap_vert_rounded,
                          label: 'Riordina plugin',
                          focusNode: _reorderFn,
                          autofocus: true,
                          enabled: state.plugins.length > 1,
                          subtitle: state.plugins.length > 1
                              ? null
                              : 'Serve più di un plugin per riordinare',
                          onFocusUp: () => _backFn.requestFocus(),
                          onFocusDown: state.plugins.isNotEmpty
                              ? () => _pluginFn(state.plugins.first.pluginId)
                                  .requestFocus()
                              : (_hidden.isEmpty
                                  ? null
                                  : () => _pluginFn(_hidden.first.pluginId)
                                      .requestFocus()),
                          onTap: state.plugins.length > 1
                              ? () => showDialog<void>(
                                    context: context,
                                    builder: (_) => BlocProvider.value(
                                      value: pluginBloc,
                                      child: PluginReorderDialog(
                                          plugins: state.plugins),
                                    ),
                                  )
                              : null,
                        ),
                        const SettingsSectionHeader('Plugin'),
                        for (var i = 0; i < state.plugins.length; i++)
                          SettingsNavRow(
                            icon: Icons.extension_rounded,
                            label: state.plugins[i].name.isNotEmpty
                                ? state.plugins[i].name
                                : state.plugins[i].pluginId,
                            subtitle: state.plugins[i].needsConfig
                                ? 'Configurazione richiesta'
                                : null,
                            focusNode: _pluginFn(state.plugins[i].pluginId),
                            onFocusUp: () => (i == 0
                                    ? _reorderFn
                                    : _pluginFn(state.plugins[i - 1].pluginId))
                                .requestFocus(),
                            onFocusDown: i == state.plugins.length - 1
                                ? (_hidden.isEmpty
                                    ? null
                                    : () => _pluginFn(_hidden.first.pluginId)
                                        .requestFocus())
                                : () => _pluginFn(state.plugins[i + 1].pluginId)
                                    .requestFocus(),
                            onTap: () => _openPlugin(state.plugins[i].pluginId,
                                state.plugins[i].name),
                          ),
                        if (_hidden.isNotEmpty) ...[
                          const SettingsSectionHeader('Plugin nascosti'),
                          for (var j = 0; j < _hidden.length; j++)
                            SettingsNavRow(
                              icon: Icons.visibility_off_rounded,
                              label: _hidden[j].name.isNotEmpty
                                  ? _hidden[j].name
                                  : _hidden[j].pluginId,
                              subtitle: 'Nascosto dalla home',
                              focusNode: _pluginFn(_hidden[j].pluginId),
                              onFocusUp: () => (j == 0
                                      ? (state.plugins.isNotEmpty
                                          ? _pluginFn(
                                              state.plugins.last.pluginId)
                                          : _reorderFn)
                                      : _pluginFn(_hidden[j - 1].pluginId))
                                  .requestFocus(),
                              onFocusDown: j == _hidden.length - 1
                                  ? null
                                  : () => _pluginFn(_hidden[j + 1].pluginId)
                                      .requestFocus(),
                              onTap: () => _openPlugin(
                                  _hidden[j].pluginId, _hidden[j].name),
                            ),
                        ],
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        )),
      ),
    );
  }
}
