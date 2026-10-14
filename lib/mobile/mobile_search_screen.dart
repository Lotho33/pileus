import 'dart:async';

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
import '../features/media/data/search_filters_loader.dart';
import '../features/media/presentation/widgets/plugin_nav.dart'
    show pluginLabel;
import '../shared/widgets/filter_sheet.dart';
import 'widgets/mobile_poster_card.dart';
import '../shared/utils/tap_guard.dart';

/// Shortest query the search will dispatch, unless a filter is carrying it.
const _kMinLen = 2;

/// Tab-hosted search (the "Cerca" destination of [MobileShell]). Own plugin
/// picker + a filter sheet; no route arguments.
class MobileSearchScreen extends StatefulWidget {
  /// Whether this tab is the one on screen (MobileShell's IndexedStack keeps
  /// it alive while hidden). Filter retries pause while hidden and fire
  /// again when it comes back.
  final bool visible;
  const MobileSearchScreen({super.key, this.visible = true});

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  late final DiscoveryBloc _bloc;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  // Pagination: results used to be capped at whatever the
  // first SearchRequestEvent page returned — DiscoveryBloc's
  // LoadMoreSearchEvent already existed (wired up on TV, see
  // search_screen/results.dart) but nothing on mobile ever dispatched it.
  // Auto-fires near the bottom of the grid, same idiom as any touch-scroll
  // feed; the footer button underneath is the fallback for whenever the
  // first page doesn't fill the viewport (nothing to scroll, so the
  // listener below would never fire on its own) and for VoiceOver/
  // TalkBack, where a discoverable tap target beats a scroll gesture.
  final _scrollCtrl = ScrollController();

  // Shared with MobileHomeScreen (see the class doc on
  // ActivePluginController) — switching plugin here or on Home now updates
  // both instead of each tab tracking its own, independent selection —
  // without this, Cerca always reopened on the first plugin no matter what
  // was active on Home. _pluginId mirrors _activePlugin.value
  // purely so the rest of this file — _run/_resolve/the search hint — reads
  // the same local field it always did; _onActiveChanged is the one place
  // that writes it, whether the change originated here (_switchPlugin, via
  // the shared controller) or on the Home tab.
  final _activePlugin = getIt<ActivePluginController>();
  String? _pluginId;
  String _submitted = '';

  // Retries until the plugin's filters actually arrive — see
  // SearchFiltersLoader. This tab's initState runs at app start, often
  // before gRPC/auth is ready; the single attempt it used to make could
  // leave the filters empty for the whole session.
  late final _filtersLoader = SearchFiltersLoader(getIt<MediaRepository>())
    ..addListener(_onFiltersChanged);
  List<SearchFilter> get _filters => _filtersLoader.filters;
  final Map<String, String> _active = {};
  // Live-as-you-type search, matching TV (quick_search_area/area_state.dart)
  // and the desktop search screen — this used to only fire on submit/enter,
  // the one platform where typing a query silently did nothing until the
  // user pressed the keyboard's search action.
  Timer? _debounce;
  static const _debounceDelay = Duration(milliseconds: 350);

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
    // Bug: this seeds _pluginId directly from the shared
    // controller's current value instead of going through _onActiveChanged
    // (which only fires on an actual change notification) — so whenever
    // Search opened with a plugin already active from Home (the common
    // case), its filters were never fetched at all: the filter button
    // stayed permanently disabled for that plugin, even when it genuinely
    // has filters, until the user happened to switch plugins from Home.
    _filtersLoader.setVisible(widget.visible);
    _filtersLoader.setPlugin(_pluginId);
    _activePlugin.addListener(_onActiveChanged);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MobileSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _filtersLoader.setVisible(widget.visible);
  }

  void _onFiltersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _filtersLoader.dispose();
    _debounce?.cancel();
    _activePlugin.removeListener(_onActiveChanged);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _ctrl.dispose();
    _focus.dispose();
    _bloc.close();
    super.dispose();
  }

  // Fires LoadMoreSearchEvent once the grid is scrolled within one screen's
  // worth of its end — _bloc itself is the guard against duplicate/overlapping
  // requests (isLoadingMore/hasMore, see discovery_bloc.dart's
  // _onLoadMoreSearch), so this can fire on every scroll tick with no
  // debounce of its own.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final s = _bloc.state;
    if (s is! DiscoveryLoaded || !s.hasMore || s.isLoadingMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 600) {
      _bloc.add(const LoadMoreSearchEvent());
    }
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
  // — one shared, atomic choice rather than two independent
  // pickers that both write the same ActivePluginController. This just
  // reacts to whatever Home (or the _resolve seed above) set it to.
  void _onActiveChanged() {
    final id = _activePlugin.value;
    if (!mounted || id == _pluginId) return;
    setState(() {
      _pluginId = id;
      _active.clear();
      _submitted = '';
    });
    _ctrl.clear();
    _bloc.add(const ClearSearchEvent());
    _filtersLoader.setPlugin(id);
  }

  /// [unfocus] dismisses the keyboard — right for an explicit submit/clear/
  /// filter change, wrong for a live-as-you-type call (would drop focus
  /// after every keystroke).
  void _run({bool unfocus = true}) {
    _debounce?.cancel();
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
    if (unfocus) _focus.unfocus();
    setState(() => _submitted = q.isEmpty ? '·' : q);
    _bloc.add(SearchRequestEvent(
      pluginId: id,
      query: q,
      filters: Map.of(_active),
    ));
  }

  /// Debounced live search as the user types — same 350ms window as the TV
  /// quick-search and search screens (quick_search_area/area_state.dart,
  /// features/media/presentation/search_screen/view.dart).
  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (mounted) _run(unfocus: false);
    });
  }

  void _clearQuery() {
    _ctrl.clear();
    _run();
  }

  static const _supportedFilterTypes = {
    'select',
    'multiselect',
    'bool',
    'number',
    'range',
  };

  /// Opens the filter sheet. If the filters aren't there yet (still
  /// loading, or the last attempt failed) the tap retries right away instead
  /// of being a dead button, and opens the sheet if they arrive.
  Future<void> _openFilters() async {
    if (!TapGuard.acquire()) return; // double tap — see tap_guard.dart
    if (_pluginId == null) return;
    if (!_filtersLoader.hasFilters) {
      await _filtersLoader.retryNow();
      if (!mounted) return;
    }
    if (!_filters.any((f) => _supportedFilterTypes.contains(f.type))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_filtersLoader.status == FiltersStatus.error
            ? 'Filtri non disponibili al momento: riprovo in automatico.'
            : 'Questo plugin non ha filtri di ricerca.'),
      ));
      return;
    }
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
        final hasFilters =
            _filters.any((f) => _supportedFilterTypes.contains(f.type));

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
                        onChanged: _onQueryChanged,
                        onSubmitted: _run,
                        onClear: _clearQuery,
                      ),
                    ),
                    // Always rendered so the search bar doesn't reflow when
                    // switching between plugins, and enabled whenever a
                    // plugin is selected: while the filters are loading it
                    // shows a spinner, and a tap while loading/failed retries
                    // at once (see _openFilters).
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Badge(
                        isLabelVisible: _active.isNotEmpty,
                        label: Text('${_active.length}'),
                        child: IconButton(
                          tooltip: 'Filtri',
                          onPressed: active != null ? _openFilters : null,
                          icon: _filtersLoader.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.tune_rounded),
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
                            : 'Scrivi un titolo da cercare.',
                      );
                    }
                    if (s is DiscoveryLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (s is DiscoveryError) {
                      // Retryable in place — a dropped connection used to
                      // leave a dead-end message until the query was edited.
                      return _Hint(
                        icon: Icons.error_outline_rounded,
                        text: 'Ricerca non riuscita.',
                        actionLabel: 'Riprova',
                        onAction: _run,
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
                            child: CustomScrollView(
                              controller: _scrollCtrl,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 6, 16, 8),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 118,
                                      childAspectRatio: 0.48,
                                      mainAxisSpacing: 20,
                                      crossAxisSpacing: 14,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) => MobilePosterCard(
                                        pluginId: active?.pluginId ?? '',
                                        item: s.items[i],
                                        width: 118,
                                      ),
                                      childCount: s.items.length,
                                    ),
                                  ),
                                ),
                                if (s.hasMore)
                                  SliverToBoxAdapter(
                                    child: _LoadMoreFooter(
                                      isLoading: s.isLoadingMore,
                                      onPressed: () => _bloc
                                          .add(const LoadMoreSearchEvent()),
                                    ),
                                  ),
                              ],
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
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
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
        onChanged: onChanged,
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

/// Trailing "load more" row under the results grid — a fallback for when
/// [_MobileSearchScreenState._onScroll]'s auto-trigger never fires (the
/// first page doesn't fill the screen, so there's nothing to scroll) and a
/// plain, discoverable tap target for accessibility.
class _LoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _LoadMoreFooter({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28, top: 4),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : TextButton(
                onPressed: onPressed,
                child: const Text('Carica altri'),
              ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _Hint(
      {required this.icon, required this.text, this.actionLabel, this.onAction});

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
