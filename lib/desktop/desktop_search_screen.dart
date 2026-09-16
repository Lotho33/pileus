import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' show PluginInfo, SearchFilter;
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/media/bloc/discovery_bloc.dart';
import '../features/media/bloc/discovery_event.dart';
import '../features/media/bloc/discovery_state.dart';
import '../features/media/bloc/plugin_bloc.dart';
import '../features/media/bloc/plugin_state.dart';
import '../features/media/data/media_repository.dart';
import '../features/media/presentation/widgets/plugin_nav.dart'
    show pluginLabel;
import '../shared/widgets/filter_sheet.dart';
import '../shared/responsive.dart';
import 'widgets/desktop_card.dart';

const _kMinLen = 2;

/// Desktop search pane: a wide search field + plugin selector + filter
/// sheet, results in a responsive grid.
class DesktopSearchScreen extends StatefulWidget {
  const DesktopSearchScreen({super.key});

  @override
  State<DesktopSearchScreen> createState() => _DesktopSearchScreenState();
}

class _DesktopSearchScreenState extends State<DesktopSearchScreen> {
  late final DiscoveryBloc _bloc;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  String? _pluginId;
  String _submitted = '';
  List<SearchFilter> _filters = const [];
  int _filtersToken = 0;
  final Map<String, String> _active = {};

  @override
  void initState() {
    super.initState();
    _bloc = DiscoveryBloc(
      getIt<MediaRepository>(),
      onSessionExpired: () =>
          getIt<AuthBloc>().add(const SessionExpiredEvent()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _bloc.close();
    super.dispose();
  }

  List<PluginInfo> _pluginsOf(PluginState s) =>
      s is PluginsLoaded ? s.plugins : const [];

  PluginInfo? _resolve(List<PluginInfo> plugins) {
    if (plugins.isEmpty) return null;
    PluginInfo? match;
    for (final p in plugins) {
      if (p.pluginId == _pluginId) match = p;
    }
    final found = match ??
        plugins.firstWhere((p) => p.isReady, orElse: () => plugins.first);
    if (found.pluginId != _pluginId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pluginId != found.pluginId) {
          _switchPlugin(found.pluginId);
        }
      });
    }
    return found;
  }

  void _switchPlugin(String id) {
    if (id == _pluginId) return;
    setState(() {
      _pluginId = id;
      _active.clear();
      _filters = const [];
      _submitted = '';
    });
    _ctrl.clear();
    _bloc.add(const ClearSearchEvent());
    _loadFilters(id);
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
    final id = _pluginId;
    if (id == null) return;
    if (q.length < _kMinLen && _active.isEmpty) {
      if (_submitted.isNotEmpty) {
        setState(() => _submitted = '');
        _bloc.add(const ClearSearchEvent());
      }
      return;
    }
    _focus.unfocus();
    setState(() => _submitted = q.isEmpty ? '·' : q);
    _bloc.add(
        SearchRequestEvent(pluginId: id, query: q, filters: Map.of(_active)));
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context,
        filters: _filters, active: _active, centered: true);
    if (result == null || !mounted) return;
    setState(() => _active
      ..clear()
      ..addAll(result));
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PluginBloc, PluginState>(
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

        return ResponsiveBuilder(
          builder: (context, bp, _) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(bp.gutter, 20, bp.gutter, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: _SearchField(
                            controller: _ctrl,
                            focusNode: _focus,
                            hint: active != null
                                ? 'Cerca in ${pluginLabel(active)}'
                                : 'Cerca…',
                            onSubmit: _run,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (plugins.length > 1)
                        _PluginDropdown(
                          plugins: plugins,
                          value: active?.pluginId,
                          onChanged: (id) {
                            if (id != null) _switchPlugin(id);
                          },
                        ),
                      const SizedBox(width: 8),
                      // Always present so the toolbar doesn't reflow between
                      // plugins — just disabled when the plugin has no
                      // filters.
                      Badge(
                        isLabelVisible: _active.isNotEmpty,
                        label: Text('${_active.length}'),
                        child: OutlinedButton.icon(
                          onPressed: hasFilters ? _openFilters : null,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Filtri'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_active.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(bp.gutter, 0, bp.gutter, 4),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final e in _active.entries)
                            InputChip(
                              label: Text(e.value),
                              onDeleted: () {
                                setState(() => _active.remove(e.key));
                                _run();
                              },
                              backgroundColor: AppTheme.surface2,
                              labelStyle: const TextStyle(
                                  fontSize: 12, color: AppTheme.textHigh),
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: BlocBuilder<DiscoveryBloc, DiscoveryState>(
                    bloc: _bloc,
                    builder: (context, s) {
                      if (_submitted.isEmpty) {
                        return _Hint(
                          icon: Icons.search_rounded,
                          text: hasFilters
                              ? 'Scrivi un titolo o imposta un filtro.'
                              : 'Scrivi e premi Invio.',
                        );
                      }
                      if (s is DiscoveryLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (s is DiscoveryError) {
                        return const _Hint(
                            icon: Icons.error_outline_rounded,
                            text: 'Ricerca non riuscita.');
                      }
                      if (s is DiscoveryLoaded) {
                        if (s.items.isEmpty) {
                          return const _Hint(
                              icon: Icons.sentiment_dissatisfied_rounded,
                              text: 'Nessun risultato.');
                        }
                        final capH =
                            captionBoxHeight(context, bp.cardTitleSize);
                        final cellH = bp.cardWidth * 1.5 + 8 + capH + 20;
                        return GridView.builder(
                          padding:
                              EdgeInsets.fromLTRB(bp.gutter, 10, bp.gutter, 40),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: bp.cardWidth + 24,
                            mainAxisExtent: cellH,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 18,
                          ),
                          itemCount: s.items.length,
                          itemBuilder: (_, i) => Center(
                            child: DesktopCard(
                              pluginId: active?.pluginId ?? '',
                              item: s.items[i],
                              width: bp.cardWidth,
                              titleSize: bp.cardTitleSize,
                              captionHeight: capH,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onSubmit;
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      style: const TextStyle(color: AppTheme.textHigh, fontSize: 15),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppTheme.surface,
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textLow, fontSize: 15),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMid),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppTheme.textMid,
                  onPressed: () {
                    controller.clear();
                    onSubmit();
                  },
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PluginDropdown extends StatelessWidget {
  final List<PluginInfo> plugins;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _PluginDropdown(
      {required this.plugins, required this.value, required this.onChanged});

  PluginInfo? get _current {
    for (final p in plugins) {
      if (p.pluginId == value) return p;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft =
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay);
    final picked = await showMenu<String>(
      context: context,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position:
          RelativeRect.fromLTRB(topLeft.dx, topLeft.dy + 4, topLeft.dx, 0),
      items: [
        for (final p in plugins)
          PopupMenuItem<String>(
            value: p.pluginId,
            child: Text(pluginLabel(p),
                style: TextStyle(
                    color: p.pluginId == value
                        ? AppTheme.primary
                        : AppTheme.textHigh,
                    fontSize: 13)),
          ),
      ],
    );
    if (picked != null && picked != value) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = _current != null ? pluginLabel(_current!) : 'Plugin';
    return Material(
      color: AppTheme.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: AppTheme.textHigh, fontSize: 13)),
              const Icon(Icons.arrow_drop_down_rounded,
                  color: AppTheme.textMid),
            ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppTheme.textLow),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: AppTheme.textMid)),
        ],
      ),
    );
  }
}
