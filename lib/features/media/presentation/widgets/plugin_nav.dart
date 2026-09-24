import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/grpc/clients/media_client.dart' show PluginInfo;
import '../../../../core/grpc/host_resolver.dart' show myceliumHttpBase;
import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import '../../bloc/plugin_bloc.dart';
import '../../bloc/plugin_event.dart';

// ── plugin display names & icons ───────────────────────────────────────────
// Public (not home_screen.dart-private) — used both by PluginNav below and
// by home_screen.dart itself for the quick-search panel's plugin name.

// assets/branding/pileus_wordmark.svg's own <svg viewBox> width/height.
const double _kWordmarkAspect = 1578.305115 / 708.277230;
// assets/branding/pileus_icon.svg's own <svg viewBox> width/height — same
// source splash_screen.dart's _kIconAspect uses.
const double _kIconAspect = 1516.099470 / 1229.844208;

/// Display name for a plugin. The server is authoritative — `PluginInfo.name`
/// comes from the manifest `name:` and every plugin sets it; the raw id is
/// only a last resort if a manifest somehow omits it. No per-plugin
/// hard-coding here: this widget knows nothing about which plugins exist.
String pluginLabel(PluginInfo p) => p.name.isNotEmpty ? p.name : p.pluginId;

// Session-lifetime cache of fetched icon SVG bodies. "" = fetched, none
// available (fall back to a glyph); a missing key = not fetched yet.
final Map<String, String> _pluginSvgCache = {};

/// The plugin's branding icon for the side menu: the server-served SVG
/// (`GET /plugin-icon/{id}`), tinted to [color]; falls back to a Material glyph
/// while loading or when the server has none.
class PluginIcon extends StatefulWidget {
  final String pluginId;
  final double size;
  final Color color;
  const PluginIcon({
    super.key,
    required this.pluginId,
    required this.size,
    required this.color,
  });

  @override
  State<PluginIcon> createState() => PluginIconState();
}

class PluginIconState extends State<PluginIcon> {
  String? _svg; // null = deciding, "" = no icon, non-empty = svg body

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PluginIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The nav list is built positionally (no per-item keys), so reordering
    // the plugins hands this same element a different pluginId. Without
    // this, `_svg` kept the icon fetched for whoever used to sit in this
    // slot — the name updated, the icon didn't.
    if (oldWidget.pluginId != widget.pluginId) {
      _svg = null;
      _resolve();
    }
  }

  void _resolve() {
    final cached = _pluginSvgCache[widget.pluginId];
    if (cached != null) {
      _svg = cached;
    } else {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final base = myceliumHttpBase();
    if (base == null) {
      _pluginSvgCache[widget.pluginId] = '';
      if (mounted) setState(() => _svg = '');
      return;
    }
    var body = '';
    try {
      final res = await http
          .get(Uri.parse('$base/plugin-icon/${widget.pluginId}'))
          .timeout(const Duration(seconds: 4));
      final ct = res.headers['content-type'] ?? '';
      if (res.statusCode == 200 && ct.contains('svg')) body = res.body;
    } catch (_) {
      // network/timeout — fall through to the glyph fallback
    }
    _pluginSvgCache[widget.pluginId] = body;
    if (mounted) setState(() => _svg = body);
  }

  @override
  Widget build(BuildContext context) {
    // Shown only until the server's SVG (`GET /plugin-icon/{id}`, manifest
    // `icon:`) loads, or if a plugin ships none. Generic on purpose.
    final fallback = Icon(
      Icons.extension_rounded,
      size: widget.size,
      color: widget.color,
    );
    if (_svg == null || _svg!.isEmpty) return fallback;
    return SvgPicture.string(
      _svg!,
      width: widget.size,
      height: widget.size,
      colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
      placeholderBuilder: (_) => fallback,
    );
  }
}

// ── plugin nav (side panel) ─────────────────────────────────────────────────
// Extracted from home_screen.dart — second piece split out per the design
// audit's file-size recommendation (§08), after HomeHeroBackground.

class PluginNav extends StatefulWidget {
  final List<PluginInfo> plugins;
  final int selectedIndex;
  final List<FocusNode> pluginFocusNodes;
  final ValueChanged<int> onPluginSelected;
  final ValueChanged<int> onPluginFocused;
  final VoidCallback onClose;

  const PluginNav({
    super.key,
    required this.plugins,
    required this.selectedIndex,
    required this.pluginFocusNodes,
    required this.onPluginSelected,
    required this.onPluginFocused,
    required this.onClose,
  });

  @override
  State<PluginNav> createState() => _PluginNavState();
}

class _PluginNavState extends State<PluginNav> {
  final FocusNode _settingsFn = FocusNode();

  @override
  void dispose() {
    _settingsFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xF2141428), Color(0xD8141428)],
        ),
      ),
      // Width comes from the AnimatedPositioned this is embedded in (see
      // _HomeViewState.build()) — a single panel now, no need for the
      // ClipRect+double-AnimatedPositioned slide trick the old main/sub
      // layout required.
      child: SafeArea(child: _buildMainPanel(context)),
    );
  }

  Widget _buildMainPanel(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: sh * (48.0 / 1080.0)),
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: sh * (32.0 / 1080.0), vertical: sh * (4.0 / 1080.0)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/branding/pileus_icon.svg',
                height: sh * 0.075,
                width: sh * 0.075 * _kIconAspect,
                colorFilter:
                    const ColorFilter.mode(AppTheme.textHigh, BlendMode.srcIn),
              ),
              SizedBox(width: sh * (10.0 / 1080.0)),
              SvgPicture.asset(
                'assets/branding/pileus_wordmark.svg',
                height: sh * 0.075,
                width: sh * 0.075 * _kWordmarkAspect,
                colorFilter:
                    const ColorFilter.mode(AppTheme.textHigh, BlendMode.srcIn),
              ),
            ],
          ),
        ),
        SizedBox(height: sh * (16.0 / 1080.0)),
        Expanded(
          // Cap the visible plugin list at 7 rows; anything past that scrolls
          // (D-pad focus drags it via each item's Scrollable.ensureVisible).
          // topCenter keeps the leftover space below the list empty so the
          // Impostazioni row stays pinned to the panel bottom. Row height
          // here mirrors _PluginNavItemState's margin+padding+iconL sizing.
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: sh * (93.0 / 1080.0) * 7),
              // Plain ListView (shrinkWrap), not .builder — with many
              // plugins, .builder only lays out whichever items are already
              // within the viewport, so a D-pad Down past the last built
              // item called requestFocus() on a FocusNode with nothing
              // attached yet and just went nowhere (no scroll followed it,
              // unlike a real ListView.builder scroll which only happens
              // from an actual drag/fling gesture). Eagerly building every
              // item — the same tradeoff series_page_layout.dart already
              // makes for its own D-pad-focusable episode/related lists —
              // keeps every FocusNode real from the start; each item's own
              // Scrollable.ensureVisible (see _PluginNavItemState) handles
              // scrolling the list to follow focus.
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < widget.plugins.length; i++)
                    _PluginNavItem(
                      plugin: widget.plugins[i],
                      isSelected: i == widget.selectedIndex,
                      focusNode: widget.pluginFocusNodes[i],
                      onTap: () => widget.onPluginSelected(i),
                      onFocused: () => widget.onPluginFocused(i),
                      onFocusUp: i > 0
                          ? () => widget.pluginFocusNodes[i - 1].requestFocus()
                          : null,
                      onFocusDown: i < widget.plugins.length - 1
                          ? () => widget.pluginFocusNodes[i + 1].requestFocus()
                          : () => _settingsFn.requestFocus(),
                      onNavigateRight: widget.onClose,
                      onNavigateLeft: widget.onClose,
                      onEsc: widget.onClose,
                    ),
                ],
              ),
            ),
          ),
        ),
        const Divider(color: AppTheme.border, height: 1),
        // Profilo folded into Impostazioni; "Esci" moved there too, so this
        // panel is now just plugin switching + one way into settings.
        _NavAction(
          icon: Icons.settings_rounded,
          label: 'Impostazioni',
          focusNode: _settingsFn,
          onTap: () {
            // Impostazioni > Plugin runs its own PluginBloc instance (factory
            // in injection.dart) — a reorder committed there never reaches
            // this screen's instance on its own. Force a silent catch-up
            // refresh once the user comes back.
            final pluginBloc = context.read<PluginBloc>();
            context.push('/settings').then((_) {
              pluginBloc.add(const RefreshPluginsEvent());
            });
          },
          onFocusUp: widget.pluginFocusNodes.isNotEmpty
              ? () => widget.pluginFocusNodes.last.requestFocus()
              : null,
          onFocusDown: null,
          onNavigateRight: widget.onClose,
          onEsc: widget.onClose,
        ),
        SizedBox(height: sh * (24.0 / 1080.0)),
      ],
    );
  }
}

// ── plugin nav item ────────────────────────────────────────────────────────

class _PluginNavItem extends StatefulWidget {
  final PluginInfo plugin;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onFocused;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final VoidCallback? onNavigateRight;
  final VoidCallback? onNavigateLeft;
  final VoidCallback? onEsc;

  const _PluginNavItem({
    required this.plugin,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
    required this.onFocused,
    this.onFocusUp,
    this.onFocusDown,
    this.onNavigateRight,
    this.onNavigateLeft,
    this.onEsc,
  });

  @override
  State<_PluginNavItem> createState() => _PluginNavItemState();
}

class _PluginNavItemState extends State<_PluginNavItem> {
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return TvFocusable(
      focusNode: widget.focusNode,
      onFocusChange: (v) {
        // Guard + defer: this fires from a FocusNode listener, which can run
        // while the panel is being torn down (Esc / dpad-left / picking a
        // plugin all remove it). Calling Scrollable.ensureVisible then does
        // Scrollable.maybeOf(context) → registers this element as a
        // dependent of a _ScrollableScope that's already unmounting, which
        // trips `assert(_dependents.isEmpty)` in framework.dart. context.mounted
        // is false once the element leaves the active tree; the post-frame
        // hop also lets any in-flight teardown settle first.
        if (!v || !context.mounted) return;
        widget.onFocused();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Scrollable.ensureVisible(context,
                duration: const Duration(milliseconds: 200));
          }
        });
      },
      onActivate: widget.onTap,
      onUp: widget.onFocusUp,
      onDown: widget.onFocusDown,
      onLeft: widget.onNavigateLeft,
      onRight: widget.onNavigateRight,
      onEsc: widget.onEsc ?? widget.onNavigateLeft,
      builder: (context, focused) {
        final active = widget.isSelected || focused;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(
              horizontal: sh * (16.0 / 1080.0), vertical: sh * (4.0 / 1080.0)),
          padding: EdgeInsets.symmetric(
              horizontal: sh * (24.0 / 1080.0), vertical: sh * (20.0 / 1080.0)),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.primary.withValues(alpha: 0.2)
                : focused
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primary.withValues(alpha: 0.7)
                  : focused
                      ? AppTheme.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              PluginIcon(
                pluginId: widget.plugin.pluginId,
                size: AppScale.iconL(context),
                color: active
                    ? AppTheme.textHigh
                    : AppTheme.textHigh.withValues(alpha: 0.45),
              ),
              SizedBox(width: sh * (16.0 / 1080.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pluginLabel(widget.plugin),
                      style: TextStyle(
                        color: active
                            ? AppTheme.textHigh
                            : AppTheme.textHigh.withValues(alpha: 0.6),
                        fontSize: AppScale.label(context),
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.plugin.needsConfig ||
                        !widget.plugin.reachable ||
                        widget.plugin.statusLabel.isNotEmpty)
                      const SizedBox(height: 3),
                    PluginStatusIndicator(plugin: widget.plugin),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── status badge ─────────────────────────────────────────────────────────

/// Small colored status pill for a [PluginInfo] — "config richiesta",
/// "non raggiungibile", or a self-reported error/syncing status. Renders
/// nothing if the plugin has nothing to report.
///
/// Used here (the home side-nav) AND by plugin_settings_screen.dart — that
/// screen used to show none of this despite already loading the same data,
/// while a stale comment claimed it did. One shared widget instead of two
/// copies of this cascade drifting apart.
class PluginStatusIndicator extends StatelessWidget {
  final PluginInfo plugin;
  const PluginStatusIndicator({super.key, required this.plugin});

  @override
  Widget build(BuildContext context) {
    if (plugin.needsConfig) {
      return const _StatusBadge(
          label: 'config richiesta', color: Color(0xFFf59e0b));
    }
    // reachable is the automatic "the backend actually answered a liveness
    // check recently" signal — separate from statusLabel (self-reported by
    // the plugin, e.g. "syncing" during an import) and specifically meant to
    // catch the case statusLabel can't: a plugin that's gone quiet (process
    // died, gRPC channel stuck, repeated background task failures) without
    // ever self-reporting an error, so statusLabel is still whatever it last
    // successfully reported. Takes priority over statusLabel for exactly
    // that reason.
    if (!plugin.reachable) {
      return _StatusBadge(
          label: 'non raggiungibile · ultimo contatto: '
              '${lastSeenLabel(plugin.lastOkUnix.toInt())}',
          color: const Color(0xFFef4444));
    }
    if (plugin.statusLabel == 'error') {
      return _StatusBadge(
          label:
              plugin.statusDetail.isNotEmpty ? plugin.statusDetail : 'errore',
          color: const Color(0xFFef4444));
    }
    if (plugin.statusLabel == 'syncing') {
      return _StatusBadge(
          label: plugin.statusDetail.isNotEmpty
              ? plugin.statusDetail
              : 'sincronizzazione…',
          color: const Color(0xFF38bdf8));
    }
    return const SizedBox.shrink();
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final fs = (sh * (13.2 / 1080.0)).clamp(8.0, 34.5);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: sh * (6.0 / 1080.0), vertical: sh * (2.0 / 1080.0)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: AppTheme.textHigh,
            fontSize: fs,
            fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── nav action ───────────────────────────────────────────────────────────

class _NavAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final FocusNode focusNode;
  final VoidCallback? onTap;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final VoidCallback? onNavigateRight;
  final VoidCallback? onEsc;

  const _NavAction({
    required this.icon,
    required this.label,
    required this.focusNode,
    this.onTap,
    this.onFocusUp,
    this.onFocusDown,
    this.onNavigateRight,
    this.onEsc,
  });

  @override
  State<_NavAction> createState() => _NavActionState();
}

class _NavActionState extends State<_NavAction> {
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return TvFocusable(
      focusNode: widget.focusNode,
      onActivate: widget.onTap,
      onUp: widget.onFocusUp,
      onDown: widget.onFocusDown,
      onRight: widget.onNavigateRight,
      onEsc: widget.onEsc,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.symmetric(
            horizontal: sh * (16.0 / 1080.0), vertical: sh * (4.0 / 1080.0)),
        padding: EdgeInsets.symmetric(
            horizontal: sh * (24.0 / 1080.0), vertical: sh * (20.0 / 1080.0)),
        // Same violet focus treatment as the plugin rows above
        // (_PluginNavItem's non-selected focused state).
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(widget.icon,
                size: AppScale.iconL(context),
                color: focused
                    ? AppTheme.textHigh
                    : AppTheme.textHigh.withValues(alpha: 0.55)),
            SizedBox(width: sh * (20.0 / 1080.0)),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(
                    color: focused
                        ? AppTheme.textHigh
                        : AppTheme.textHigh.withValues(alpha: 0.55),
                    fontSize: sh * 0.0238,
                  ),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
