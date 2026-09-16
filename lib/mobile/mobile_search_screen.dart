import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' show PluginInfo, SearchFilter;
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/media/active_plugin_controller.dart';
import '../features/media/bloc/discovery_bloc.dart';
import '../features/media/bloc/discovery_event.dart';
import '../features/media/bloc/discovery_state.dart';
import '../features/media/bloc/plugin_bloc.dart';
import '../features/media/bloc/plugin_event.dart';
import '../features/media/bloc/plugin_state.dart';
import '../features/media/data/media_repository.dart';
import '../features/media/presentation/widgets/plugin_nav.dart'
    show pluginLabel;
import '../shared/widgets/filter_sheet.dart';
import 'widgets/mobile_poster_card.dart';

/// Shortest query the search will dispatch, unless a filter is carrying it.
const _kMinLen = 2;

/// Tab-hosted search (the "Cerca" destination of [MobileShell]). Own plugin
/// picker + a filter sheet; no route arguments.
class MobileSearchScreen extends StatefulWidget {
  const MobileSearchScreen({super.key});

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  late final DiscoveryBloc _bloc;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  // Shared with MobileHomeScreen (see the class doc on
  // ActivePluginController) — switching plugin here or on Home now updates
  // both instead of each tab tracking its own, independent selection
  // (reported 2026-09-14: Cerca always reopened on the first plugin no
  // matter what was active on Home). _pluginId mirrors _activePlugin.value
  // purely so the rest of this file — _run/_resolve/the search hint — reads
  // the same local field it always did; _onActiveChanged is the one place
  // that writes it, whether the change originated here (_switchPlugin, via
  // the shared controller) or on the Home tab.
  final _activePlugin = getIt<ActivePluginController>();
  String? _pluginId;
  String _submitted = '';

  List<SearchFilter> _filters = const [];
  int _filtersToken = 0; // guards against a stale getSearchFilters response
  final Map<String, String> _active = {};

  @override
  void initState() {
    super.initState();
    _bloc = DiscoveryBloc(
      getIt<MediaRepository>(),
      onSessionExpired: () =>
          getIt<AuthBloc>().add(const SessionExpiredEvent()),
    );
    final pb = getIt<PluginBloc>();
    if (pb.state is PluginInitial) pb.add(const LoadPluginsEvent());
    _pluginId = _activePlugin.value;
    _activePlugin.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    _activePlugin.removeListener(_onActiveChanged);
    _ctrl.dispose();
    _focus.dispose();
    _bloc.close();
    super.dispose();
  }

  List<PluginInfo> _pluginsOf(PluginState s) =>
      s is PluginsLoaded ? s.plugins : const [];

  /// Picks the effective plugin, seeding the shared controller the first
  /// time plugins arrive (post-frame, so we don't write to it during build).
  PluginInfo? _resolve(List<PluginInfo> plugins) {
    if (plugins.isEmpty) return null;
    PluginInfo? match;
    for (final p in plugins) {
      if (p.pluginId == _pluginId) match = p;
    }
    final found = match ??
        plugins.firstWhere((p) => p.isReady, orElse: () => plugins.first);
    // Seed on first load, and re-seed if the selected plugin vanished
    // server-side (else _run() keeps firing SearchRequestEvent at a dead id).
    // _onActiveChanged below does the actual reset once this lands.
    if (found.pluginId != _pluginId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activePlugin.value != found.pluginId) {
          _activePlugin.value = found.pluginId;
        }
      });
    }
    return found;
  }

  // Switching plugin happens only from Home's own PluginSwitcherPill now
  // (2026-09-16) — one shared, atomic choice rather than two independent
  // pickers that both write the same ActivePluginController. This just
  // reacts to whatever Home (or the _resolve seed above) set it to.
  void _onActiveChanged() {
    final id = _activePlugin.value;
    if (!mounted || id == _pluginId) return;
    setState(() {
      _pluginId = id;
      _active.clear();
      _filters = const [];
      _submitted = '';
    });
    _ctrl.clear();
    _bloc.add(const ClearSearchEvent());
    if (id != null) _loadFilters(id);
  }

  Future<void> _loadFilters(String pluginId) async {
    final token = ++_filtersToken;
    try {
      final resp = await getIt<MediaRepository>().getSearchFilters(pluginId);
      if (!mounted || token != _filtersToken) return;
      setState(() => _filters = resp.filters);
    } catch (_) {
      if (!mounted || token != _filtersToken) return;
      setState(() => _filters = const []);
    }
  }

  void _run() {
    final q = _ctrl.text.trim();
    if (q.length < _kMinLen && _active.isEmpty) {
      if (_submitted.isNotEmpty) {
        setState(() => _submitted = '');
        _bloc.add(const ClearSearchEvent());
      }
      return;
    }
    final id = _pluginId;
    if (id == null) return;
    _focus.unfocus();
    setState(() => _submitted = q.isEmpty ? '·' : q);
    _bloc.add(SearchRequestEvent(
      pluginId: id,
      query: q,
      filters: Map.of(_active),
    ));
  }

  void _clearQuery() {
    _ctrl.clear();
    _run();
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(
      context,
      filters: _filters,
      active: _active,
    );
    if (result == null || !mounted) return;
    setState(() {
      _active
        ..clear()
        ..addAll(result);
    });
    _run();
  }

  void _removeFilter(String id) {
    setState(() => _active.remove(id));
    _run();
  }

  String _chipLabel(String id, String value) {
    SearchFilter? f;
    for (final x in _filters) {
      if (x.id == id) f = x;
    }
    if (f == null) return value;
    final name = f.label.isNotEmpty ? f.label : id;
    return '$name: ${_valueLabel(f, value)}';
  }

  String _valueLabel(SearchFilter f, String value) {
    switch (f.type) {
      case 'bool':
        return value == 'true' ? 'Sì' : 'No';
      case 'range':
        final p = value.split('..');
        return p.length == 2
            ? (p[0] == p[1] ? p[0] : '${p[0]}–${p[1]}')
            : value;
      case 'multiselect':
        return value
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((oid) {
          for (final o in f.options) {
            if (o.id == oid) return o.label;
          }
          return oid;
        }).join(', ');
      default:
        for (final o in f.options) {
          if (o.id == value) return o.label;
        }
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PluginBloc, PluginState>(
      bloc: getIt<PluginBloc>(),
      builder: (context, ps) {
        final plugins = _pluginsOf(ps);
        final active = _resolve(plugins);
        final hasFilters = _filters.any((f) => const {
              'select',
              'multiselect',
              'bool',
              'number',
              'range'
            }.contains(f.type));

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Search field + filter button ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: _ctrl,
                        focusNode: _focus,
                        hintText: active != null
                            ? 'Cerca in ${pluginLabel(active)}'
                            : 'Cerca film, serie, canali…',
                        onSubmitted: _run,
                        onClear: _clearQuery,
                      ),
                    ),
                    // Always rendered so the search bar doesn't reflow when
                    // switching between plugins — disabled when the plugin
                    // exposes no filters.
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Badge(
                        isLabelVisible: _active.isNotEmpty,
                        label: Text('${_active.length}'),
                        child: IconButton(
                          tooltip: 'Filtri',
                          onPressed: hasFilters ? _openFilters : null,
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Active filter chips ───────────────────────────────────
              if (_active.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final e in _active.entries)
                          InputChip(
                            label: Text(_chipLabel(e.key, e.value)),
                            onDeleted: () => _removeFilter(e.key),
                            backgroundColor: AppTheme.surface2,
                            labelStyle: const TextStyle(
                                fontSize: 12, color: AppTheme.textHigh),
                            deleteIconColor: AppTheme.textMid,
                          ),
                      ],
                    ),
                  ),
                ),
              // ── Results ───────────────────────────────────────────────
              Expanded(
                child: BlocBuilder<DiscoveryBloc, DiscoveryState>(
                  bloc: _bloc,
                  builder: (context, s) {
                    if (_submitted.isEmpty) {
                      return _Hint(
                        icon: Icons.search_rounded,
                        text: hasFilters
                            ? 'Scrivi un titolo o imposta un filtro.'
                            : 'Scrivi e premi Cerca.',
                      );
                    }
                    if (s is DiscoveryLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (s is DiscoveryError) {
                      return const _Hint(
                        icon: Icons.error_outline_rounded,
                        text: 'Ricerca non riuscita.',
                      );
                    }
                    if (s is DiscoveryLoaded) {
                      if (s.items.isEmpty) {
                        return const _Hint(
                          icon: Icons.sentiment_dissatisfied_rounded,
                          text: 'Nessun risultato.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Text(
                              '${s.items.length} risultati',
                              style: const TextStyle(
                                  color: AppTheme.textLow, fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: GridView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 118,
                                childAspectRatio: 0.48,
                                mainAxisSpacing: 20,
                                crossAxisSpacing: 14,
                              ),
                              itemCount: s.items.length,
                              itemBuilder: (_, i) => MobilePosterCard(
                                pluginId: active?.pluginId ?? '',
                                item: s.items[i],
                                width: 118,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Self-contained search box. Rebuilds only itself as the user types (via a
/// listener on its own controller, for the clear button) so a keystroke never
/// rebuilds the plugin picker / filter chips / results grid above and below.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmitted(),
        style: const TextStyle(color: AppTheme.textHigh, fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppTheme.surface,
          hintText: hintText,
          hintStyle: const TextStyle(color: AppTheme.textLow, fontSize: 15),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: AppTheme.textMid),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTheme.textMid,
                    onPressed: onClear,
                  ),
          ),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.textLow),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMid)),
          ],
        ),
      ),
    );
  }
}
