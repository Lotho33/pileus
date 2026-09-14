import 'package:flutter/material.dart';

import '../../core/grpc/clients/media_client.dart' show PluginInfo;
import '../../core/theme/app_theme.dart';
import '../../features/media/presentation/widgets/plugin_nav.dart'
    show pluginLabel, PluginIcon;

/// Compact "current plugin" control for the mobile top bars (Home, Cerca):
/// the active plugin's icon + name, tap opens a bottom sheet to switch.
///
/// Replaces the horizontal `ChoiceChip` row both screens used to render
/// independently — reported uncomfortable to hit precisely once there are
/// more than a handful of plugins, and required scrolling to find one that
/// wasn't currently in view (2026-09-14). Same `showModalBottomSheet`
/// pattern the profile menu already uses (`_profileSheet` in
/// mobile_home_screen.dart), not a side drawer — this is an occasional
/// action, not primary navigation, and the app has no drawer pattern
/// elsewhere on mobile to match.
class PluginSwitcherPill extends StatelessWidget {
  final List<PluginInfo> plugins;
  final PluginInfo? active;
  final ValueChanged<String> onSelect;

  const PluginSwitcherPill({
    super.key,
    required this.plugins,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Nothing to switch between — same gate the old chip row used.
    if (plugins.length <= 1 || active == null) return const SizedBox.shrink();
    final a = active!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        // Centered, not left — reported more prominent/comfortable to hit
        // this way (2026-09-14), and it's the only thing on this row now
        // that the old chip strip is gone, so there's no longer a reason to
        // hug the left edge like the wordmark/profile row above it does.
        alignment: Alignment.center,
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openPicker(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PluginIcon(
                      pluginId: a.pluginId, size: 22, color: AppTheme.textHigh),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      pluginLabel(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textHigh,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      size: 20, color: AppTheme.textMid),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PLUGIN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textLow,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in plugins)
                    ListTile(
                      leading: PluginIcon(
                          pluginId: p.pluginId,
                          size: 22,
                          color: AppTheme.textHigh),
                      title: Text(
                        pluginLabel(p),
                        style: const TextStyle(
                          color: AppTheme.textHigh,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: p.pluginId == active?.pluginId
                          ? const Icon(Icons.check_rounded,
                              color: AppTheme.primary)
                          : null,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (p.pluginId != active?.pluginId) {
                          onSelect(p.pluginId);
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
