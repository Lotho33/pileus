// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'source_tree.dart';

/// The live sources as tiles (mobile sheets, desktop dialogs): flat as
/// before when the plugin gives no groups; otherwise group headers that open
/// and close, with the group of [current] (or of the first source) open.
class SourceTreeList extends StatefulWidget {
  final List<List<String>> paths;
  final List<String> labels;

  /// Index of the source playing (marked), -1 for none.
  final int current;
  final void Function(int index) onPick;

  /// Optional trailing widget for a source (e.g. "MIGLIORE" on the first).
  final Widget? Function(int index)? trailing;
  final bool dense;

  const SourceTreeList({
    super.key,
    required this.paths,
    required this.labels,
    required this.onPick,
    this.current = -1,
    this.trailing,
    this.dense = false,
  });

  @override
  State<SourceTreeList> createState() => _SourceTreeListState();
}

class _SourceTreeListState extends State<SourceTreeList> {
  late List<String> _open =
      groupOf(widget.paths, widget.current >= 0 ? widget.current : 0);

  void _toggle(SourceRow r) => setState(() => _open = toggleGroup(_open, r.group));

  @override
  Widget build(BuildContext context) {
    final grouped = hasSourceGroups(widget.paths);
    final rows =
        sourceRows(widget.paths, widget.labels, open: grouped ? _open : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rows)
          if (r.isGroup)
            ListTile(
              dense: widget.dense,
              contentPadding: EdgeInsets.only(left: 16.0 * r.depth),
              leading: Icon(
                  groupIsOpen(_open, r.group)
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  color: AppTheme.textHigh),
              title: Text(r.title,
                  style: const TextStyle(
                      color: AppTheme.textHigh, fontWeight: FontWeight.w600)),
              subtitle: Text(r.count == 1 ? '1 sorgente' : '${r.count} sorgenti',
                  style:
                      const TextStyle(color: AppTheme.textLow, fontSize: 12)),
              onTap: () => _toggle(r),
            )
          else
            ListTile(
              dense: widget.dense,
              contentPadding: EdgeInsets.only(left: 16.0 * r.depth),
              leading: Icon(
                  r.index == widget.current
                      ? Icons.check_rounded
                      : Icons.play_arrow_rounded,
                  color: r.index == widget.current
                      ? AppTheme.primary
                      : AppTheme.textHigh),
              title: Text(r.title,
                  style: TextStyle(
                      color: r.index == widget.current
                          ? AppTheme.primary
                          : AppTheme.textHigh)),
              trailing: widget.trailing?.call(r.index!),
              onTap: () => widget.onPick(r.index!),
            ),
      ],
    );
  }
}
