import 'package:flutter/material.dart';

import '../../core/theme/app_scale.dart';
import '../../core/theme/app_theme.dart';
import 'tv_focusable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// D-pad-navigable on-screen keyboard. Two layers — letters (with a caps
// toggle) and numbers/symbols — reachable via a mode-toggle key, since this
// widget backs both case-insensitive search fields and arbitrary free text
// (admin password on device pairing, profile names, plugin settings) that
// need digits, symbols and real casing. Writes directly into the
// TextEditingController it's given — pairs naturally with a normal (non
// readOnly) TextField sharing the same controller, so hardware/IME input
// keeps working in parallel (e.g. a Bluetooth keyboard on a TV box). Every
// insertion/deletion goes through controller.value, which fires the
// TextField's own onChanged exactly like hardware typing would — callers
// doing live search (see search_screen.dart) don't need any extra wiring.
// ─────────────────────────────────────────────────────────────────────────────

enum _KbMode { letters, symbols }

class _KeyDef {
  final String label;
  // Character to insert on select/enter — null marks a special key
  // (backspace/space/enter/shift/mode-toggle), handled by comparing against
  // the constants below instead.
  final String? insert;
  final int flex;
  const _KeyDef(this.label, {this.insert, this.flex = 1});
}

const _kBackspaceLabel = '⌫';
const _kSpaceLabel = 'Spazio';
const _kEnterLabel = 'Invio';
const _kShiftLabel = '⇧';
const _kSymbolsLabel = '123';
const _kLettersLabel = 'ABC';

List<List<_KeyDef>> _lettersRows(bool shift, bool showEnter) {
  String cased(String ch) => shift ? ch.toUpperCase() : ch;
  List<_KeyDef> row(String chars) =>
      [for (final ch in chars.split('')) _KeyDef(cased(ch), insert: cased(ch))];
  return [
    row('abcdefg'),
    row('hijklmn'),
    row('opqrstu'),
    row('vwxyz'),
    [
      const _KeyDef(_kShiftLabel, flex: 2),
      const _KeyDef(_kSymbolsLabel, flex: 2),
      const _KeyDef(_kBackspaceLabel, flex: 2),
      if (showEnter) const _KeyDef(_kEnterLabel, flex: 2),
    ],
    [const _KeyDef(_kSpaceLabel, flex: 7)],
  ];
}

const _kSymbolChars = [
  '1234567890',
  '-_.,:;!?',
  '@#\$%&*+=',
  '()[]{}/\\',
];

// Single fixed layer: digits + uppercase letters, no shift / symbols /
// space. For fixed-charset codes (the Mycelium pairing code) where
// lowercase, symbols and spaces are never valid input.
List<List<_KeyDef>> _upperAlnumRows(bool showEnter) {
  List<_KeyDef> row(String chars) =>
      [for (final ch in chars.split('')) _KeyDef(ch, insert: ch)];
  return [
    row('1234567890'),
    row('ABCDEFG'),
    row('HIJKLMN'),
    row('OPQRSTU'),
    row('VWXYZ'),
    [
      const _KeyDef(_kBackspaceLabel, flex: 3),
      if (showEnter) const _KeyDef(_kEnterLabel, flex: 3),
    ],
  ];
}

// Digits-first + lowercase letters + '.'/'-', no space/shift/symbols-toggle.
// For host/IP address entry (192.168.1.10, mycelium.local): a space is
// never valid there, and — unlike the default letters layer, which buries
// digits behind the "123" mode switch — the digits most IPs start with are
// on the very first row (2026-09 audit: server_discovery_screen's manual
// address field used the generic letters keyboard, hiding the characters
// it needed most).
List<List<_KeyDef>> _hostAddressRows(bool showEnter) {
  List<_KeyDef> row(String chars) =>
      [for (final ch in chars.split('')) _KeyDef(ch, insert: ch)];
  return [
    row('1234567890'),
    row('abcdefghij'),
    row('klmnopqrst'),
    row('uvwxyz'),
    [
      const _KeyDef('.', insert: '.', flex: 2),
      const _KeyDef('-', insert: '-', flex: 2),
      const _KeyDef(_kBackspaceLabel, flex: 3),
      if (showEnter) const _KeyDef(_kEnterLabel, flex: 3),
    ],
  ];
}

List<List<_KeyDef>> _symbolsRows(bool showEnter) {
  return [
    for (final chars in _kSymbolChars)
      [for (final ch in chars.split('')) _KeyDef(ch, insert: ch)],
    [
      const _KeyDef(_kLettersLabel, flex: 3),
      const _KeyDef(_kBackspaceLabel, flex: 3),
      if (showEnter) const _KeyDef(_kEnterLabel, flex: 3),
    ],
    [const _KeyDef(_kSpaceLabel, flex: 7)],
  ];
}

class OnScreenKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmit;
  // Arrow-up from the top row and arrow-down from the bottom row escape the
  // keyboard entirely — typically wired to refocus the search field above
  // and, if present, the first result below.
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  // Whether to show the "Invio" key. Search fields (quick + full) dispatch
  // automatically once the query passes a minimum length, so an explicit
  // submit key there is dead weight — they pass false. Flows where the
  // typed value is only consumed on an explicit confirm (manual server
  // address, profile name, generic text dialogs) keep it.
  final bool showEnter;
  // Restrict to a single layer of 0-9 + A-Z (no shift, symbols toggle or
  // space). For the device-pairing code, whose charset is exactly that.
  final bool upperAlphanumericOnly;

  // Restrict to digits-first + lowercase + '.'/'-' (no shift, symbols
  // toggle or space). For a host/IP address field — see _hostAddressRows.
  final bool hostAddressOnly;

  const OnScreenKeyboard({
    super.key,
    required this.controller,
    this.onSubmit,
    this.onNavigateUp,
    this.onNavigateDown,
    this.showEnter = true,
    this.upperAlphanumericOnly = false,
    this.hostAddressOnly = false,
  });

  @override
  State<OnScreenKeyboard> createState() => OnScreenKeyboardState();
}

class OnScreenKeyboardState extends State<OnScreenKeyboard> {
  _KbMode _mode = _KbMode.letters;
  bool _shift = false;

  List<List<_KeyDef>> get _rows => widget.upperAlphanumericOnly
      ? _upperAlnumRows(widget.showEnter)
      : widget.hostAddressOnly
          ? _hostAddressRows(widget.showEnter)
          : _mode == _KbMode.letters
              ? _lettersRows(_shift, widget.showEnter)
              : _symbolsRows(widget.showEnter);

  late List<List<FocusNode>> _nodes = _buildNodes();

  List<List<FocusNode>> _buildNodes() => [
        for (final row in _rows) [for (final _ in row) FocusNode()],
      ];

  /// First key of the keyboard — the landing spot for a caller handing focus
  /// down from a search field above.
  FocusNode get firstFocusNode => _nodes.first.first;

  /// Focuses the first key of the last row — the mirror-image landing spot
  /// for a caller below the keyboard (e.g. a submit button) handing focus
  /// back up via Up, matching onNavigateDown's own exit point.
  void focusLastRow() => _nodes.last.first.requestFocus();

  @override
  void dispose() {
    _disposeNodes();
    super.dispose();
  }

  void _disposeNodes() {
    for (final row in _nodes) {
      for (final n in row) {
        n.dispose();
      }
    }
  }

  void _replaceText(String Function(String current) transform) {
    final newText = transform(widget.controller.text);
    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  // Row/column shapes differ between letters and symbols mode, so switching
  // mode needs a fresh set of FocusNodes (shift alone doesn't — the letters
  // grid keeps the same shape whether upper- or lower-case). Refocuses the
  // control-row key at [focusCol] in the new layout so focus lands back near
  // the toggle that was just pressed instead of jumping to the first key.
  //
  // Disposing the *old* nodes used to happen up front, before the new ones
  // existed — but the key being pressed right now (e.g. "123") still holds
  // focus at that point, and disposing a focused FocusNode makes Flutter's
  // focus system immediately hand focus to whatever it finds nearest via
  // its own default policy, not necessarily anything in this keyboard. The
  // postFrameCallback's explicit requestFocus() a frame later didn't always
  // win that race, leaving focus stuck wherever that default jump landed —
  // reported as "wrong focus" after switching letters/numbers. Disposing
  // the old nodes only *after* the new node has actually claimed focus
  // closes that gap entirely.
  void _switchMode(_KbMode mode, {required int focusCol}) {
    final oldNodes = _nodes;
    setState(() {
      _mode = mode;
      _nodes = _buildNodes();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controlRow = _nodes.length - 2;
        final col = focusCol.clamp(0, _nodes[controlRow].length - 1);
        _nodes[controlRow][col].requestFocus();
      }
      for (final row in oldNodes) {
        for (final n in row) {
          n.dispose();
        }
      }
    });
  }

  void _activate(_KeyDef key) {
    switch (key.label) {
      case _kBackspaceLabel:
        _replaceText(
            (t) => t.isEmpty ? t : t.characters.skipLast(1).toString());
        return;
      case _kSpaceLabel:
        _replaceText((t) => '$t ');
        return;
      case _kEnterLabel:
        widget.onSubmit?.call();
        return;
      case _kShiftLabel:
        setState(() => _shift = !_shift);
        return;
      case _kSymbolsLabel:
        _switchMode(_KbMode.symbols, focusCol: 0);
        return;
      case _kLettersLabel:
        _switchMode(_KbMode.letters, focusCol: 1);
        return;
      default:
        _replaceText((t) => t + key.insert!);
    }
  }

  void _moveHorizontal(int row, int col, int dir) {
    final newCol = col + dir;
    // stop at edges, no wrap
    if (newCol < 0 || newCol >= _rows[row].length) return;
    _nodes[row][newCol].requestFocus();
  }

  void _moveVertical(int row, int col, int dir) {
    final newRow = row + dir;
    if (newRow < 0) {
      widget.onNavigateUp?.call();
      return;
    }
    if (newRow >= _rows.length) {
      widget.onNavigateDown?.call();
      return;
    }
    final newCol = col.clamp(0, _rows[newRow].length - 1);
    _nodes[newRow][newCol].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppScale.space(context, 3)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var c = 0; c < rows[r].length; c++)
                  Flexible(
                    flex: rows[r][c].flex,
                    child: _KeyButton(
                      keyDef: rows[r][c],
                      active: rows[r][c].label == _kShiftLabel && _shift,
                      focusNode: _nodes[r][c],
                      onActivate: () => _activate(rows[r][c]),
                      onMoveHorizontal: (dir) => _moveHorizontal(r, c, dir),
                      onMoveVertical: (dir) => _moveVertical(r, c, dir),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KeyButton extends StatefulWidget {
  final _KeyDef keyDef;
  final bool active;
  final FocusNode focusNode;
  final VoidCallback onActivate;
  final ValueChanged<int> onMoveHorizontal;
  final ValueChanged<int> onMoveVertical;

  const _KeyButton({
    required this.keyDef,
    required this.active,
    required this.focusNode,
    required this.onActivate,
    required this.onMoveHorizontal,
    required this.onMoveVertical,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  @override
  Widget build(BuildContext context) {
    final isSpecial = widget.keyDef.insert == null;
    // The keyboard is often taller than the viewport once it's stacked
    // under a text field and above whatever comes next (see
    // server_discovery_screen.dart) — nothing here previously followed
    // focus with a scroll, so D-pad-ing down through the rows could park
    // the current key below the visible area with no indication it had.
    // A no-op if there's no ancestor Scrollable.

    // Reserves room for the focused-key growth (AppScale.focusScaleIcon,
    // 1.06x about the key's own center — roughly 3% of its width per side)
    // on both the gap between keys and the row's own outer edges, since
    // this Padding wraps every key symmetrically including the first/last
    // in a row. At the old 2px-per-side value, any key wider than ~65px
    // grew past its own padding and visibly overlapped its neighbor —
    // effectively every letter key, since rows are only 5-7 keys wide.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppScale.space(context, 6)),
      child: TvFocusable(
        focusNode: widget.focusNode,
        onActivate: widget.onActivate,
        onLeft: () => widget.onMoveHorizontal(-1),
        onRight: () => widget.onMoveHorizontal(1),
        onUp: () => widget.onMoveVertical(-1),
        onDown: () => widget.onMoveVertical(1),
        onFocusChange: (focused) {
          // Guard + defer — the letters/symbols switch disposes and rebuilds
          // every key node, so this can fire mid-teardown. See the same fix
          // in plugin_nav.dart's _PluginNavItem for why an unguarded
          // Scrollable.ensureVisible here can trip framework.dart's
          // `_dependents.isEmpty` assert.
          if (!focused || !context.mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Scrollable.ensureVisible(context,
                  duration: const Duration(milliseconds: 150), alignment: 0.5);
            }
          });
        },
        builder: (context, focused) => AnimatedScale(
          // AppScale.focusScaleIcon is a percentage — fine for a normal
          // single-flex key, but the wider control/space keys are already
          // many times wider, so the same 6% reads as a large,
          // disproportionate jump in absolute pixels. Wide keys rely on the
          // border/glow below for focus instead of also growing.
          scale: focused && widget.keyDef.flex <= 1
              ? AppScale.focusScaleIcon
              : 1.0,
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          child: Container(
            height: AppScale.space(context, 40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.active
                  ? AppTheme.primary.withValues(alpha: 0.35)
                  : AppTheme.surface2,
              borderRadius: BorderRadius.circular(8),
              border: focused
                  ? Border.all(color: AppTheme.primary, width: 1.6)
                  : null,
              boxShadow: focused ? AppScale.focusGlow(AppTheme.primary) : null,
            ),
            child: Text(
              widget.keyDef.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSpecial
                    ? AppScale.caption(context)
                    : AppScale.space(context, 15),
                fontWeight: isSpecial ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
