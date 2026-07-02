import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart' show CatalogDef;
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/back_dispatch.dart';
import '../../../shared/widgets/ambient_glow_background.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/settings/settings_header.dart';
import '../../../shared/widgets/settings/settings_section_header.dart';
import '../../../shared/widgets/settings/settings_toggle_row.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/plugin_bloc.dart';
import '../bloc/plugin_event.dart';
import '../data/media_repository.dart';
import '../data/plugin_prefs.dart';

/// Per-plugin, per-profile home-layout settings: show/hide the whole plugin
/// and reorder / hide its catalogs (carousels). Styled like the rest of the
/// Settings module (SettingsHeader + AmbientGlowBackground + AppTheme).
///
/// Heartbeat and server-driven plugin configuration are intentionally NOT
/// here yet — that path still needs backend work.
class PluginSettingsScreen extends StatelessWidget {
  final String pluginId;
  final String pluginName;

  const PluginSettingsScreen({
    super.key,
    required this.pluginId,
    required this.pluginName,
  });

  @override
  Widget build(BuildContext context) {
    // Shared lazy singleton — value, not create, so popping this screen
    // doesn't close HomeScreen's copy.
    return BlocProvider.value(
      value: getIt<PluginBloc>(),
      child: _PluginSettingsBody(pluginId: pluginId, pluginName: pluginName),
    );
  }
}

class _PluginSettingsBody extends StatefulWidget {
  final String pluginId;
  final String pluginName;

  const _PluginSettingsBody({required this.pluginId, required this.pluginName});

  @override
  State<_PluginSettingsBody> createState() => _PluginSettingsBodyState();
}

class _PluginSettingsBodyState extends State<_PluginSettingsBody> {
  static const _grabbedColor = Color(0xFF34D399);

  final _repo = getIt<MediaRepository>();
  final _backFn = FocusNode();
  final _visibilityFn = FocusNode();
  final _catListFn = FocusNode();

  bool _loading = true;
  bool _pluginVisible = true;
  List<_CatRow> _rows = [];
  final List<GlobalKey> _rowKeys = [];
  int _focusIdx = 0;
  bool _grabbed = false;
  // Coalesces a burst of moves (held D-pad while grabbed) into one write
  // instead of one per position stepped through.
  Timer? _persistDebounce;
  // The home only needs to be told to rebuild once, when we leave — doing it
  // per debounced edit fired a full listPlugins() gRPC round-trip and a
  // whole-home carousel rebuild while this (covering) screen was still open.
  bool _homeRefreshPending = false;

  @override
  void initState() {
    super.initState();
    // Focus the visibility toggle right away — it renders immediately,
    // before _load() resolves the catalog list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _visibilityFn.requestFocus();
    });
    _load();
  }

  @override
  void dispose() {
    // Flush a pending write so a change made right before leaving isn't lost.
    if (_persistDebounce?.isActive ?? false) {
      _persistDebounce!.cancel();
      _persistNow();
    }
    // Single home refresh on the way out (see _homeRefreshPending).
    if (_homeRefreshPending) {
      getIt<PluginBloc>().add(const RefreshPluginsEvent(force: true));
    }
    _backFn.dispose();
    _visibilityFn.dispose();
    _catListFn.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = await _repo.listAllPlugins();
      final info = all.where((p) => p.pluginId == widget.pluginId).firstOrNull;
      final catalogs = info?.catalogs.toList() ?? const <CatalogDef>[];
      final prefs = await _repo.loadPluginPrefs();
      final cp = prefs.catalogPrefs(widget.pluginId);

      final byId = {for (final c in catalogs) c.id: c};
      final ordered = <CatalogDef>[];
      final seen = <String>{};
      for (final id in cp.order) {
        final c = byId[id];
        if (c != null && seen.add(id)) ordered.add(c);
      }
      for (final c in catalogs) {
        if (seen.add(c.id)) ordered.add(c);
      }

      if (!mounted) return;
      setState(() {
        _pluginVisible = !prefs.isPluginHidden(widget.pluginId);
        _rows = [
          for (final c in ordered)
            _CatRow(
              id: c.id,
              name: c.name.isNotEmpty ? c.name : c.id,
              visible: !cp.isHidden(c.id),
            ),
        ];
        _rowKeys
          ..clear()
          ..addAll(List.generate(_rows.length, (_) => GlobalKey()));
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _visibilityFn.requestFocus();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _visibilityFn.requestFocus();
        });
      }
    }
  }

  void _persist() {
    _homeRefreshPending = true;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), _persistNow);
  }

  Future<void> _persistNow() async {
    var prefs = await _repo.loadPluginPrefs();
    prefs = prefs.withPluginHidden(widget.pluginId, !_pluginVisible);
    prefs = prefs.withCatalogPrefs(
      widget.pluginId,
      PluginCatalogPrefs(
        order: _rows.map((r) => r.id).toList(),
        hidden: {
          for (final r in _rows)
            if (!r.visible) r.id,
        },
      ),
    );
    await _repo.savePluginPrefs(prefs);
  }

  void _setPluginVisible(bool v) {
    setState(() => _pluginVisible = v);
    _persist();
  }

  void _toggleRowVisible(int i) {
    if (i < 0 || i >= _rows.length) return;
    setState(() => _rows[i] = _rows[i].copyWith(visible: !_rows[i].visible));
    _persist();
  }

  void _move(int delta) {
    final target = _focusIdx + delta;
    if (_grabbed) {
      if (target < 0 || target >= _rows.length) return;
      setState(() {
        final row = _rows.removeAt(_focusIdx);
        _rows.insert(target, row);
        _focusIdx = target;
      });
      _persist();
      return;
    }
    if (target < 0) {
      _visibilityFn.requestFocus();
      return;
    }
    if (target >= _rows.length) return;
    setState(() => _focusIdx = target);
  }

  KeyEventResult _onListKey(FocusNode _, KeyEvent event) {
    final k = event.logicalKey;
    final isArrow = k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight;
    // Handle held-key REPEATS as well as the initial press: without this a
    // grabbed row could only ever be nudged one position per physical press
    // (the repeats fell through to Flutter's default focus traversal, which
    // stole focus off this list). Non-arrow keys stay press-only.
    if (event is KeyRepeatEvent) {
      if (isArrow) {
        _handleArrow(k);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (isArrow) {
      _handleArrow(k);
      return KeyEventResult.handled;
    }
    switch (k) {
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        setState(() => _grabbed = !_grabbed);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
      case LogicalKeyboardKey.backspace:
        if (!_grabbed && !consumeBackEvent()) return KeyEventResult.handled;
        if (_grabbed) {
          setState(() => _grabbed = false);
        } else {
          context.pop();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _handleArrow(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      _ensureRowVisible();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
      _ensureRowVisible();
    } else if (!_grabbed) {
      // Left / Right toggle the focused carousel's visibility.
      _toggleRowVisible(_focusIdx);
    }
  }

  void _ensureRowVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = (_focusIdx >= 0 && _focusIdx < _rowKeys.length)
          ? _rowKeys[_focusIdx]
          : null;
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut);
      }
    });
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
                title: widget.pluginName,
                focusNode: _backFn,
                onBack: () => context.pop(),
                onFocusDown: () => _visibilityFn.requestFocus(),
              ),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return ListView(
      // Horizontal inset matches the other Settings screens: combined with
      // each row's own ~16px margin it clears Google's TV safe margin AND
      // gives the focus scale/glow room to paint without hitting the screen
      // edge (see AppScale.screenHPad's doc).
      padding: EdgeInsets.fromLTRB(
        AppScale.screenHPad(context),
        0,
        AppScale.screenHPad(context),
        AppScale.space(context, 24),
      ),
      children: [
        const SettingsSectionHeader('Visibilità'),
        SettingsToggleRow(
          label: 'Mostra nella home',
          value: _pluginVisible,
          focusNode: _visibilityFn,
          onChanged: _setPluginVisible,
          onFocusUp: () => _backFn.requestFocus(),
          onFocusDown: () {
            if (_pluginVisible && _rows.isNotEmpty) _catListFn.requestFocus();
          },
        ),
        if (!_pluginVisible)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppScale.space(context, 8),
              AppScale.space(context, 6),
              AppScale.space(context, 8),
              0,
            ),
            child: Text(
              'Il plugin è nascosto: non comparirà nel menù né nella home '
              'finché non lo riattivi qui.',
              style: TextStyle(
                color: AppTheme.textLow,
                fontSize: AppScale.caption(context),
                height: 1.4,
              ),
            ),
          ),
        if (_pluginVisible) ...[
          const SettingsSectionHeader('Caroselli'),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppScale.space(context, 8),
              0,
              AppScale.space(context, 8),
              AppScale.space(context, 10),
            ),
            child: Text(
              _grabbed
                  ? 'Su / Giù per spostare · OK per rilasciare'
                  : 'OK per afferrare e riordinare · Sinistra / Destra per '
                      'mostrare o nascondere',
              style: TextStyle(
                color: _grabbed ? _grabbedColor : AppTheme.textLow,
                fontSize: AppScale.caption(context),
                height: 1.4,
              ),
            ),
          ),
          if (_loading)
            Padding(
              padding:
                  EdgeInsets.symmetric(vertical: AppScale.space(context, 24)),
              child: Center(
                  child: PileusSpinner(
                      size: AppScale.spinnerL(context),
                      color: AppTheme.primary)),
            )
          else if (_rows.isEmpty)
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppScale.space(context, 8)),
              child: const Text('Questo plugin non ha caroselli.',
                  style: TextStyle(color: AppTheme.textLow)),
            )
          else
            Focus(
              focusNode: _catListFn,
              onKeyEvent: _onListKey,
              onFocusChange: (_) => setState(() {}),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _rows.length; i++)
                    _CatRowView(
                      key: i < _rowKeys.length ? _rowKeys[i] : null,
                      row: _rows[i],
                      focused: _catListFn.hasFocus && i == _focusIdx,
                      grabbed: _grabbed && i == _focusIdx,
                      grabbedColor: _grabbedColor,
                      onTap: () {
                        _catListFn.requestFocus();
                        setState(() {
                          if (i == _focusIdx) {
                            _grabbed = !_grabbed;
                          } else if (!_grabbed) {
                            _focusIdx = i;
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _CatRow {
  final String id;
  final String name;
  final bool visible;
  const _CatRow({required this.id, required this.name, required this.visible});

  _CatRow copyWith({bool? visible}) =>
      _CatRow(id: id, name: name, visible: visible ?? this.visible);
}

/// Styled to match SettingsToggleRow / SettingsNavRow: focus scale + purple
/// glow, AppTheme.surface2 base, AppScale sizing. Green accent while grabbed.
class _CatRowView extends StatelessWidget {
  final _CatRow row;
  final bool focused;
  final bool grabbed;
  final Color grabbedColor;
  final VoidCallback onTap;

  const _CatRowView({
    super.key,
    required this.row,
    required this.focused,
    required this.grabbed,
    required this.grabbedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = grabbed ? grabbedColor : AppTheme.primary;
    final hi = focused || grabbed;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: hi ? AppScale.focusScaleRow : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: AnimatedContainer(
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          margin: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 16),
            vertical: AppScale.space(context, 8),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 20),
            vertical: AppScale.space(context, 16),
          ),
          decoration: BoxDecoration(
            color: hi
                ? accent.withValues(alpha: grabbed ? 0.20 : 0.16)
                : AppTheme.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hi ? accent : Colors.transparent,
              width: 2,
            ),
            boxShadow: hi ? AppScale.focusGlow(accent) : const [],
          ),
          child: Row(
            children: [
              Icon(
                grabbed
                    ? Icons.open_with_rounded
                    : Icons.drag_indicator_rounded,
                size: AppScale.iconS(context),
                color: hi ? Colors.white : AppTheme.textLow,
              ),
              SizedBox(width: AppScale.space(context, 14)),
              Expanded(
                child: Text(
                  row.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: row.visible
                        ? (hi ? Colors.white : AppTheme.textMid)
                        : AppTheme.textLow,
                    fontSize: AppScale.label(context),
                    fontWeight: FontWeight.w600,
                    decoration: row.visible ? null : TextDecoration.lineThrough,
                  ),
                ),
              ),
              SizedBox(width: AppScale.space(context, 12)),
              Icon(
                row.visible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: AppScale.iconS(context),
                color: row.visible
                    ? (hi ? accent : AppTheme.textMid)
                    : AppTheme.textLow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
