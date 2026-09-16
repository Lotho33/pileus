import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/theme/app_theme.dart';
import '../features/media/bloc/plugin_bloc.dart';
import '../features/media/bloc/plugin_event.dart';
import '../features/media/bloc/plugin_state.dart';
import '../features/media/data/media_repository.dart';

/// Plugin ordering / visibility. Renders from **local state**, seeded once
/// from [PluginBloc] and only re-seeded if the plugin *set* changes — so a
/// drag-drop settle (and the bloc's 30s poll re-emitting the same list)
/// never rebuilds the [ReorderableListView] mid-interaction, which was the
/// flicker. Persisted immediately; the bloc is refreshed on the way out so
/// the home / drawer pick up the new order.
class MobilePluginsScreen extends StatefulWidget {
  const MobilePluginsScreen({super.key});

  @override
  State<MobilePluginsScreen> createState() => _MobilePluginsScreenState();
}

class _MobilePluginsScreenState extends State<MobilePluginsScreen> {
  final _repo = getIt<MediaRepository>();
  List<PluginInfo> _visible = [];
  List<PluginInfo> _hidden = [];
  bool _seeded = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final s = getIt<PluginBloc>().state;
    if (s is PluginsLoaded) _seed(s.plugins);
    getIt<PluginBloc>().add(const RefreshPluginsEvent(force: true));
  }

  @override
  void dispose() {
    if (_dirty) {
      getIt<PluginBloc>().add(const RefreshPluginsEvent(force: true));
    }
    super.dispose();
  }

  Set<String> _idsOf(Iterable<PluginInfo> l) =>
      l.map((p) => p.pluginId).toSet();

  void _seed(List<PluginInfo> fromBloc, {bool viaSetState = false}) {
    void apply() {
      _visible = List.of(fromBloc);
      _seeded = true;
    }

    // initState calls this before the first build (plain assignment); a
    // later re-seed from _onBlocState must go through setState or the new
    // order only paints when _loadHidden's trailing setState lands.
    if (viaSetState) {
      setState(apply);
    } else {
      apply();
    }
    _loadHidden();
  }

  Future<void> _loadHidden() async {
    try {
      final prefs = await _repo.loadPluginPrefs();
      final all = await _repo.listAllPlugins();
      if (!mounted) return;
      setState(() => _hidden =
          all.where((p) => prefs.hiddenPlugins.contains(p.pluginId)).toList());
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _onBlocState(PluginState s) {
    if (s is! PluginsLoaded) return;
    // Re-seed only when the set of plugins actually changed (installed /
    // removed server-side) — otherwise the local order is authoritative and
    // the bloc's periodic re-emit is ignored (no list rebuild = no flicker).
    final incoming = _idsOf(s.plugins);
    final known = {..._idsOf(_visible), ..._idsOf(_hidden)};
    final added = incoming.difference(known);
    final removed =
        _idsOf(_visible).difference(incoming).difference(_idsOf(_hidden));
    if (!_seeded || added.isNotEmpty || removed.isNotEmpty) {
      _seed(s.plugins, viaSetState: true);
    }
  }

  Future<void> _persistOrder() async {
    _dirty = true;
    await _repo.savePluginOrder(_visible.map((p) => p.pluginId).toList());
  }

  Future<void> _persistHidden(String id, bool hidden) async {
    _dirty = true;
    final prefs = await _repo.loadPluginPrefs();
    await _repo.savePluginPrefs(prefs.withPluginHidden(id, hidden));
  }

  void _reorder(int oldI, int newI) {
    setState(() {
      if (newI > oldI) newI -= 1;
      _visible.insert(newI, _visible.removeAt(oldI));
    });
    _persistOrder();
  }

  void _hide(PluginInfo p) {
    setState(() {
      _visible.removeWhere((x) => x.pluginId == p.pluginId);
      _hidden = [..._hidden, p];
    });
    _persistHidden(p.pluginId, true);
  }

  void _unhide(PluginInfo p) {
    setState(() {
      _hidden.removeWhere((x) => x.pluginId == p.pluginId);
      _visible = [..._visible, p];
    });
    _persistHidden(p.pluginId, false);
    _persistOrder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: const Text('Plugin'),
      ),
      body: BlocListener<PluginBloc, PluginState>(
        bloc: getIt<PluginBloc>(),
        listener: (_, s) => _onBlocState(s),
        child: !_seeded
            ? const Center(child: CircularProgressIndicator())
            : (_visible.isEmpty && _hidden.isEmpty)
                ? const Center(
                    child: Text('Nessun plugin',
                        style: TextStyle(color: AppTheme.textMid)))
                : ListView(
                    children: [
                      if (_visible.isNotEmpty) ...[
                        _header('Attivi — trascina per riordinare'),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: true,
                          itemCount: _visible.length,
                          // onReorder→onReorderItem migration is post-release
                          // churn (different newIndex semantics).
                          // ignore: deprecated_member_use
                          onReorder: _reorder,
                          itemBuilder: (_, i) {
                            final p = _visible[i];
                            return ListTile(
                              key: ValueKey(p.pluginId),
                              title: Text(
                                  p.name.isNotEmpty ? p.name : p.pluginId,
                                  style: const TextStyle(
                                      color: AppTheme.textHigh)),
                              subtitle: p.needsConfig
                                  ? const Text('Configurazione richiesta',
                                      style: TextStyle(
                                          color: Color(0xFFf59e0b),
                                          fontSize: 12))
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.visibility_off_outlined,
                                        color: AppTheme.textMid),
                                    tooltip: 'Nascondi dalla home',
                                    onPressed: () => _hide(p),
                                  ),
                                  const Icon(Icons.drag_handle,
                                      color: AppTheme.textLow),
                                ],
                              ),
                              onTap: () => context.push(
                                '/plugin-settings/${p.pluginId}',
                                extra: {'pluginName': p.name},
                              ),
                            );
                          },
                        ),
                      ],
                      if (_hidden.isNotEmpty) ...[
                        _header('Nascosti'),
                        for (final p in _hidden)
                          ListTile(
                            title: Text(p.name.isNotEmpty ? p.name : p.pluginId,
                                style:
                                    const TextStyle(color: AppTheme.textMid)),
                            trailing: IconButton(
                              icon: const Icon(Icons.visibility_outlined,
                                  color: AppTheme.textMid),
                              tooltip: 'Mostra sulla home',
                              onPressed: () => _unhide(p),
                            ),
                            onTap: () => context.push(
                              '/plugin-settings/${p.pluginId}',
                              extra: {'pluginName': p.name},
                            ),
                          ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .8)),
      );
}
