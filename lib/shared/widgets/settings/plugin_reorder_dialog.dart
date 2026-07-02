import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/clients/media_client.dart' show PluginInfo;
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/media/bloc/plugin_bloc.dart';
import '../../../features/media/bloc/plugin_event.dart';
import '../../utils/back_dispatch.dart';

// Distinct from AppTheme.primary (used for plain focus everywhere else in
// Settings) so "this row is actively being moved" reads unambiguously
// different from "this row is merely highlighted".
const _kGrabbedColor = Color(0xFF34D399);

/// Pick-up-and-move plugin reorder dialog — a two-phase D-pad interaction
/// (navigate with Su/Giù, OK to grab the highlighted row, Su/Giù again to
/// relocate it live, OK to drop) instead of the previous "always-moving
/// first item, then hunt for a Confirm button" flow, which in practice could
/// only ever reorder the very first plugin and needed an extra screen just
/// to save. Moves reorder a local working copy instantly; the new order is
/// committed to [PluginBloc] as a single [ReorderPluginEvent] (one
/// savePluginOrder gRPC write) only when the grabbed row is dropped, so a
/// multi-slot move costs one network write instead of one per D-pad step.
/// Back while grabbed restores the pre-grab order; closing (Back/Chiudi)
/// otherwise leaves the already-committed order as-is. Requires a
/// [PluginBloc] to already be available above it in the tree (via
/// BlocProvider.value).
class PluginReorderDialog extends StatefulWidget {
  final List<PluginInfo> plugins;

  const PluginReorderDialog({super.key, required this.plugins});

  @override
  State<PluginReorderDialog> createState() => _PluginReorderDialogState();
}

class _PluginReorderDialogState extends State<PluginReorderDialog> {
  final FocusNode _listFn = FocusNode();
  final FocusNode _closeFn = FocusNode();

  // Local working copy. Moves reorder this list instantly (no per-step
  // round-trip); the order is committed to PluginBloc — a single
  // savePluginOrder gRPC write — only when a grabbed row is dropped. The
  // previous flow fired one ReorderPluginEvent (→ one network save) per
  // D-pad step, so nudging a plugin four slots hammered the backend with
  // four sequential writes and visibly lagged the move on a slow box.
  late List<PluginInfo> _order;
  int _focusIdx = 0;
  bool _grabbed = false;
  // Row index the current grab started from, and a snapshot of the list at
  // that moment — so OK commits the net move as one (from, to) and Back
  // (Esc while grabbed) restores the pre-grab order instead of leaving a
  // half-finished drag applied.
  int _grabOrigin = 0;
  List<PluginInfo>? _preGrabOrder;

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.plugins);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listFn.requestFocus();
    });
  }

  void _toggleGrab() {
    if (_grabbed) {
      final from = _grabOrigin;
      final to = _focusIdx;
      setState(() {
        _grabbed = false;
        _preGrabOrder = null;
      });
      if (from != to) {
        context.read<PluginBloc>().add(ReorderPluginEvent(from, to));
      }
    } else {
      setState(() {
        _grabbed = true;
        _grabOrigin = _focusIdx;
        _preGrabOrder = List.of(_order);
      });
    }
  }

  void _cancelGrab() {
    setState(() {
      if (_preGrabOrder != null) _order = _preGrabOrder!;
      _focusIdx = _grabOrigin;
      _grabbed = false;
      _preGrabOrder = null;
    });
  }

  @override
  void dispose() {
    _listFn.dispose();
    _closeFn.dispose();
    super.dispose();
  }

  void _handleMove(int delta) {
    final newIdx = _focusIdx + delta;
    if (_grabbed) {
      if (newIdx < 0 || newIdx >= _order.length) return;
      setState(() {
        final item = _order.removeAt(_focusIdx);
        _order.insert(newIdx, item);
        _focusIdx = newIdx;
      });
      return;
    }
    if (newIdx < 0) return;
    if (newIdx >= _order.length) {
      _closeFn.requestFocus();
      return;
    }
    setState(() => _focusIdx = newIdx);
  }

  KeyEventResult _onListKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _handleMove(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _handleMove(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _toggleGrab();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.goBack:
        if (!_grabbed && !consumeBackEvent()) return KeyEventResult.handled;
        if (_grabbed) {
          _cancelGrab();
        } else {
          Navigator.of(context).pop();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugins = _order;
    if (plugins.isEmpty) return const SizedBox.shrink();
    final focusIdx = _focusIdx.clamp(0, plugins.length - 1);
    // Same fix as settings_select_row.dart's picker: width used to be a
    // flat 420 while the text inside scales with sh via AppScale.
    final maxDialogW =
        (MediaQuery.sizeOf(context).width * 0.219).clamp(360.0, 520.0);

    return Dialog(
      backgroundColor: const Color(0xF2141428),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDialogW),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Riordina plugin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppScale.title(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppScale.space(context, 6)),
              Text(
                _grabbed
                    ? 'Su/Giù per spostare · OK per rilasciare'
                    : 'Su/Giù per navigare, poi OK per afferrare e spostare',
                style: TextStyle(
                  color: _grabbed
                      ? _kGrabbedColor.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.55),
                  fontSize: AppScale.caption(context),
                  fontWeight: _grabbed ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              Focus(
                focusNode: _listFn,
                onKeyEvent: _onListKey,
                child: Column(
                  children: [
                    for (var i = 0; i < plugins.length; i++)
                      _ReorderPluginRow(
                        plugin: plugins[i],
                        isFocused: i == focusIdx,
                        isGrabbed: _grabbed && i == focusIdx,
                        onTap: () {
                          _listFn.requestFocus();
                          if (i == _focusIdx) {
                            _toggleGrab();
                          } else if (!_grabbed) {
                            setState(() => _focusIdx = i);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CwMenuButton(
                icon: Icons.check_rounded,
                label: 'Chiudi',
                color: Colors.white,
                focusNode: _closeFn,
                onTap: () => Navigator.of(context).pop(),
                onUp: () => _listFn.requestFocus(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderPluginRow extends StatelessWidget {
  final PluginInfo plugin;
  final bool isFocused;
  final bool isGrabbed;
  final VoidCallback onTap;

  const _ReorderPluginRow({
    required this.plugin,
    required this.isFocused,
    required this.isGrabbed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = plugin.name.isNotEmpty ? plugin.name : plugin.pluginId;
    final accent = isGrabbed ? _kGrabbedColor : AppTheme.primary;
    final highlighted = isFocused || isGrabbed;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isGrabbed
            ? (AppScale.focusScaleRow + AppScale.focusScaleCard) /
                2 // between "row" and "card" — a
            // grabbed row is more "lifted" than
            // plain focus but still full-width
            : (isFocused ? AppScale.focusScaleRow : 1.0),
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: AnimatedContainer(
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          margin: EdgeInsets.symmetric(vertical: AppScale.space(context, 3)),
          padding: EdgeInsets.symmetric(
              horizontal: AppScale.space(context, 16),
              vertical: AppScale.space(context, 12)),
          decoration: BoxDecoration(
            color: isGrabbed
                ? accent.withValues(alpha: 0.22)
                : isFocused
                    ? accent.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: highlighted
                  ? accent.withValues(alpha: isGrabbed ? 0.9 : 0.5)
                  : Colors.transparent,
              width: isGrabbed ? 2 : 1.5,
            ),
            boxShadow: highlighted
                ? AppScale.focusGlow(accent,
                    alpha: isGrabbed ? 0.35 : 0.22, blur: isGrabbed ? 14 : 10)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isGrabbed
                    ? Icons.open_with_rounded
                    : Icons.drag_indicator_rounded,
                size: AppScale.iconS(context),
                color: highlighted
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.3),
              ),
              SizedBox(width: AppScale.space(context, 12)),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: highlighted
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.65),
                    fontSize: AppScale.label(context),
                    fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isGrabbed)
                Icon(Icons.swap_vert_rounded,
                    size: AppScale.iconS(context), color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic focusable icon+label menu button — used by [PluginReorderDialog]
/// and by home_screen.dart's own confirm dialogs/context menus.
class CwMenuButton extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  const CwMenuButton({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
  });

  @override
  State<CwMenuButton> createState() => _CwMenuButtonState();
}

class _CwMenuButtonState extends State<CwMenuButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          widget.onUp?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          widget.onDown?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          widget.onLeft?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          widget.onRight?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          if (consumeBackEvent()) Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _focused
                ? widget.color.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused
                  ? widget.color.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(color: widget.color, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
