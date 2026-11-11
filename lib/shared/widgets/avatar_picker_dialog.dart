import 'package:flutter/material.dart';

import '../../core/theme/app_scale.dart';
import '../../core/theme/app_theme.dart';
import '../utils/tap_guard.dart';
import 'default_avatars.dart';
import 'settings/dialog_action_button.dart';
import 'tv_focusable.dart';

/// The avatar picker every flavor shares (TV, mobile, desktop, web): the
/// built-in set from default_avatars.dart, D-pad navigable and tappable /
/// clickable alike (TvFocusable carries a tap handler).
///
/// With [initialName] set (profile creation), the first tile is the
/// profile's initial — the "no avatar" choice, saved as an empty
/// `avatarUrl`, which every profile screen already renders as the initial.
/// It is not offered when editing an existing profile: mycelium's
/// UpdateProfile reads an empty avatar_url as "leave unchanged", so there
/// is no way to go back to it (a photo is set from mycelium's dashboard).
///
/// Returns the chosen `avatarUrl` (`''` for the initial), or null when the
/// dialog was dismissed.
Future<String?> showAvatarPicker(
  BuildContext context, {
  String currentAvatarUrl = '',
  String? initialName,
  String title = 'Scegli avatar',
  double? tileSize,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _AvatarPickerDialog(
      title: title,
      currentAvatarUrl: currentAvatarUrl,
      initialName: initialName,
      tileSize: tileSize,
    ),
  );
}

class _AvatarPickerDialog extends StatefulWidget {
  final String title;
  final String currentAvatarUrl;
  final String? initialName;
  final double? tileSize;
  const _AvatarPickerDialog({
    required this.title,
    required this.currentAvatarUrl,
    required this.initialName,
    required this.tileSize,
  });

  @override
  State<_AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<_AvatarPickerDialog> {
  // Owned by the State, not disposed after `await showDialog` — see
  // dialog_controller_dispose_race: a focus handoff still in flight during
  // the exit transition must not hit a disposed node.
  final _gridKey = GlobalKey<_AvatarPickerGridState>();
  final _cancelFn = FocusNode();

  @override
  void dispose() {
    _cancelFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => popIfCurrent(context),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(widget.title),
        content: _AvatarPickerGrid(
          key: _gridKey,
          currentAvatarUrl: widget.currentAvatarUrl,
          initialName: widget.initialName,
          tileSize: widget.tileSize ?? AppScale.space(context, 84),
          onSelected: (url) => popIfCurrent(context, url),
          onDownFromLastRow: () => _cancelFn.requestFocus(),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            focusNode: _cancelFn,
            onUp: () => _gridKey.currentState?.focusCurrent(),
            onPressed: () => popIfCurrent(context),
          ),
        ],
      ),
    );
  }
}

class _AvatarPickerGrid extends StatefulWidget {
  final String currentAvatarUrl;
  final String? initialName;
  final double tileSize;
  final ValueChanged<String> onSelected;
  final VoidCallback? onDownFromLastRow;
  const _AvatarPickerGrid({
    super.key,
    required this.currentAvatarUrl,
    required this.initialName,
    required this.tileSize,
    required this.onSelected,
    this.onDownFromLastRow,
  });

  @override
  State<_AvatarPickerGrid> createState() => _AvatarPickerGridState();
}

class _AvatarPickerGridState extends State<_AvatarPickerGrid> {
  static const _columns = 5;

  /// Tile values in order: `''` (the initial) first when offered, then
  /// `avatar://0..n`.
  late final List<String> _values = [
    if (widget.initialName != null) '',
    for (var i = 0; i < kDefaultAvatars.length; i++) defaultAvatarUrlFor(i),
  ];
  late final _nodes = List.generate(_values.length, (_) => FocusNode());
  late int _focused = () {
    final i = _values.indexOf(widget.currentAvatarUrl);
    return i < 0 ? 0 : i;
  }();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[_focused].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Re-focuses wherever the grid was left — "Annulla" calls this on Up so
  /// leaving it lands back where the user actually was.
  void focusCurrent() {
    if (_focused >= 0 && _focused < _nodes.length) {
      _nodes[_focused].requestFocus();
    }
  }

  void _moveFocus(int delta) {
    final next = (_focused + delta).clamp(0, _values.length - 1);
    if (next == _focused) return;
    setState(() => _focused = next);
    _nodes[next].requestFocus();
  }

  void _moveDown() {
    final next = _focused + _columns;
    if (next >= _values.length) {
      // Last row may be partial: land on the last tile when there is one
      // below-right, otherwise leave the grid for the buttons.
      final lastRowStart = (_values.length - 1) ~/ _columns * _columns;
      if (_focused < lastRowStart) {
        setState(() => _focused = _values.length - 1);
        _nodes[_focused].requestFocus();
        return;
      }
      widget.onDownFromLastRow?.call();
      return;
    }
    setState(() => _focused = next);
    _nodes[next].requestFocus();
  }

  Widget _tile(String value, double size) {
    if (value.isEmpty) {
      final name = widget.initialName!.trim();
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withValues(alpha: 0.8),
              AppTheme.primary.withValues(alpha: 0.3),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return DefaultAvatarView(index: defaultAvatarIndex(value), size: size);
  }

  @override
  Widget build(BuildContext context) {
    final tileSize = widget.tileSize;
    const gap = 12.0;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: _columns * tileSize + (_columns - 1) * gap),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _values.length; i++)
              TvFocusable(
                focusNode: _nodes[i],
                onActivate: () => widget.onSelected(_values[i]),
                onLeft: () => _moveFocus(-1),
                onRight: () => _moveFocus(1),
                onUp: () => _moveFocus(-_columns),
                onDown: _moveDown,
                builder: (context, isFocused) => Container(
                  width: tileSize,
                  height: tileSize,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isFocused ? AppTheme.primary : Colors.transparent,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: _tile(_values[i], tileSize - 6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
