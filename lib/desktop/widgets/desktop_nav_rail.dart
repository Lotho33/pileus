import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../core/theme/app_theme.dart';
import '../../features/media/presentation/widgets/plugin_nav.dart'
    show PluginIcon, pluginLabel;

enum DesktopSection { home, search, settings }

/// Left navigation rail for the desktop shell. Collapsible: icon-only at
/// 68px, labelled at 236px. Fixed destinations (Home / Cerca) + the dynamic
/// plugin list + Impostazioni + a profile button.
class DesktopNavRail extends StatelessWidget {
  final bool extended;
  final VoidCallback onToggleExtended;
  final DesktopSection section;
  final ValueChanged<DesktopSection> onSection;
  final List<PluginInfo> plugins;
  final String? activePluginId;
  final ValueChanged<String> onPluginSelect;
  final VoidCallback onProfile;
  final double labelSize;

  const DesktopNavRail({
    super.key,
    required this.extended,
    required this.onToggleExtended,
    required this.section,
    required this.onSection,
    required this.plugins,
    required this.activePluginId,
    required this.onPluginSelect,
    required this.onProfile,
    this.labelSize = 13.5,
  });

  @override
  Widget build(BuildContext context) {
    // Width is snapped, not tweened: an AnimatedContainer here relayouts the
    // whole content pane each frame of the tween — that's what made the rail
    // feel janky. RepaintBoundary isolates a rail hover from the content.
    return RepaintBoundary(
      child: SizedBox(
        width: extended ? 236 : 68,
        child: ColoredBox(
          color: AppTheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Brand + collapse/expand toggle.
              if (extended)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 8, 4),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/branding/pileus_wordmark.svg',
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                            AppTheme.textHigh, BlendMode.srcIn),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Comprimi',
                        iconSize: 18,
                        onPressed: onToggleExtended,
                        icon: const Icon(Icons.chevron_left_rounded,
                            color: AppTheme.textMid),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    const SizedBox(height: 4),
                    SvgPicture.asset(
                      'assets/branding/pileus_icon.svg',
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                          AppTheme.textHigh, BlendMode.srcIn),
                    ),
                    IconButton(
                      tooltip: 'Espandi',
                      iconSize: 18,
                      onPressed: onToggleExtended,
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textMid),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              _RailItem(
                icon: Icons.home_rounded,
                label: 'Home',
                extended: extended,
                labelSize: labelSize,
                selected: section == DesktopSection.home,
                onTap: () => onSection(DesktopSection.home),
              ),
              _RailItem(
                icon: Icons.search_rounded,
                label: 'Cerca',
                extended: extended,
                labelSize: labelSize,
                selected: section == DesktopSection.search,
                onTap: () => onSection(DesktopSection.search),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppTheme.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final p in plugins)
                      _RailItem(
                        pluginId: p.pluginId,
                        label: pluginLabel(p),
                        extended: extended,
                        labelSize: labelSize,
                        selected: section == DesktopSection.home &&
                            p.pluginId == activePluginId,
                        onTap: () => onPluginSelect(p.pluginId),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              _RailItem(
                icon: Icons.settings_rounded,
                label: 'Impostazioni',
                extended: extended,
                labelSize: labelSize,
                selected: section == DesktopSection.settings,
                onTap: () => onSection(DesktopSection.settings),
              ),
              _RailItem(
                leading: const Icon(Icons.person_rounded,
                    size: 20, color: AppTheme.textMid),
                label: 'Profilo',
                extended: extended,
                labelSize: labelSize,
                selected: false,
                onTap: onProfile,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  final IconData? icon;
  final Widget? leading;
  final String? pluginId; // renders the plugin's branding icon
  final String label;
  final bool extended;
  final bool selected;
  final double labelSize;
  final VoidCallback onTap;

  const _RailItem({
    this.icon,
    this.leading,
    this.pluginId,
    required this.label,
    required this.extended,
    required this.selected,
    required this.labelSize,
    required this.onTap,
  });

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;

  Widget _leadingWidget(Color tint) {
    if (widget.pluginId != null) {
      return PluginIcon(pluginId: widget.pluginId!, size: 20, color: tint);
    }
    return widget.leading ?? Icon(widget.icon, size: 20, color: tint);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final tint = active ? AppTheme.textHigh : AppTheme.textMid;
    final bg = active
        ? AppTheme.primary.withValues(alpha: 0.20)
        : _hover
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.transparent;
    final borderCol =
        active ? AppTheme.primary.withValues(alpha: 0.5) : Colors.transparent;

    final Widget box = widget.extended
        ? Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: bg,
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(child: _leadingWidget(tint))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tint,
                      fontSize: widget.labelSize,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        // Collapsed: a centred 44×44 hit target, icon dead-centre.
        : Center(
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: bg,
                border: Border.all(color: borderCol),
              ),
              child: _leadingWidget(tint),
            ),
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.extended
            ? box
            : Tooltip(message: widget.label, child: box),
      ),
    );
  }
}
