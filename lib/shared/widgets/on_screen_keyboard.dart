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

// [forceUppercase]: locked to caps, no shift key at all — for search fields
// (quick search + the full TV search screen), where casing never affects
// the result (search is case-insensitive everywhere in this app) and
// uppercase glyphs read better at 10-foot TV viewing distance than lower-
// case ones (simpler shapes, less prone to smearing on a soft/upscaled
// panel) — the same reasoning the fixed-charset pairing-code keyboard
// (_upperAlnumRows) already happens to benefit from. Free text that
// genuinely has a case (a profile name, a generic settings value) keeps the
// normal shift-toggle layout — this is opt-in per field, not a global
// change.
List<List<_KeyDef>> _lettersRows(bool shift, bool showEnter,
    {bool forceUppercase = false}) {
  final effectiveShift = forceUppercase || shift;
  String cased(String ch) => effectiveShift ? ch.toUpperCase() : ch;
  List<_KeyDef> row(String chars) =>
      [for (final ch in chars.split('')) _KeyDef(cased(ch), insert: cased(ch))];
  return [
    row('abcdefg'),
    row('hijklmn'),
    row('opqrstu'),
    row('vwxyz'),
    [
      if (!forceUppercase) const _KeyDef(_kShiftLabel, flex: 2),
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

// Digits-first + lowercase letters + '.'/'-'/':'/'/' , no space/shift/
// symbols-toggle. For host/IP/URL address entry (192.168.1.10,
// https://demo.example.com:8443): a space is never valid there, and —
// unlike the default letters layer, which buries digits behind the "123"
// mode switch — the digits most IPs start with are on the very first row.
// ':' and '/' are here too, alongside remote server mode (see
// server_address.dart) — a "https://host:port" URL needs both.
List<List<_KeyDef>> _hostAddressRows(bool showEnter) {
  List<_KeyDef> row(String chars) =>
      [for (final ch in chars.split('')) _KeyDef(ch, insert: ch)];
  return [
    row('1234567890'),
    row('abcdefghij'),
    row('klmnopqrst'),
    row('uvwxyz'),
    [
      const _KeyDef('.', insert: '.'),
      const _KeyDef('-', insert: '-'),
      const _KeyDef(':', insert: ':'),
      const _KeyDef('/', insert: '/'),
      const _KeyDef(_kBackspaceLabel, flex: 2),
      if (showEnter) const _KeyDef(_kEnterLabel, flex: 2),
    ],
  ];
}

// Numeric keypad: 1-9 / 0 + backspace (+ optional submit), phone-keypad
// shaped. For a PIN (4-8 digits, proto/auth.proto's Profile PIN section) —
// no letters/symbols/space are ever valid there, and a phone-style 3x3+0
// grid is the layout D-pad users already expect for numeric-only entry
// (device pairing/search reuse the generic keyboards above since those take
// more than digits).
List<List<_KeyDef>> _digitsRows(bool showEnter) {
  List<_KeyDef> row(String digits) =>
      [for (final d in digits.split('')) _KeyDef(d, insert: d)];
  return [
    row('123'),
    row('456'),
    row('789'),
    [
      const _KeyDef(_kBackspaceLabel),
      const _KeyDef('0', insert: '0'),
      if (showEnter) const _KeyDef(_kEnterLabel),
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

  // Restrict to a phone-style 1-9/0 + backspace keypad — see _digitsRows.
  // For a profile PIN (4-8 digits, proto/auth.proto's Profile PIN section).
  final bool digitsOnly;

  // Locks the standard letters layout to caps with no shift key — see
  // _lettersRows's own doc. Only meaningful in the default (not digits/
  // upperAlphanumeric/hostAddress) layer.
  final bool forceUppercase;

  // Caps how long controller.text can grow from this keyboard's own
  // inserts/space (never blocks backspace). Every insert/delete here goes
  // straight through controller.value (see _replaceText), bypassing
  // TextField's own `maxLength`/LengthLimitingTextInputFormatter entirely —
  // that formatter only runs on IME-routed input, never a raw
  // controller.value assignment — so a field that needs an actual cap (the
  // pairing code: up to 16 chars for a longer static demo
  // code) has to enforce it here instead. Null (most callers) means
  // unbounded, same as before this existed.
  final int? maxLength;

  const OnScreenKeyboard({
    super.key,
    required this.controller,
    this.onSubmit,
    this.onNavigateUp,
    this.onNavigateDown,
    this.showEnter = true,
    this.upperAlphanumericOnly = false,
    this.hostAddressOnly = false,
    this.digitsOnly = false,
    this.forceUppercase = false,
    this.maxLength,
  });

  @override
  State<OnScreenKeyboard> createState() => OnScreenKeyboardState();
}

class OnScreenKeyboardState extends State<OnScreenKeyboard> {
  _KbMode _mode = _KbMode.letters;
  bool _shift = false;

  List<List<_KeyDef>> get _rows => widget.digitsOnly
      ? _digitsRows(widget.showEnter)
      : widget.upperAlphanumericOnly
          ? _upperAlnumRows(widget.showEnter)
          : widget.hostAddressOnly
              ? _hostAddressRows(widget.showEnter)
              : _mode == _KbMode.letters
                  ? _lettersRows(_shift, widget.showEnter,
                      forceUppercase: widget.forceUppercase)
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
    var newText = transform(widget.controller.text);
    final cap = widget.maxLength;
    if (cap != null && newText.length > cap) newText = newText.substring(0, cap);
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
            // Bumped from 40 (at the user's request — the
            // letters "non si vedono molto") alongside the font size below,
            // same +~30% so the bigger glyph doesn't look cramped against
            // the key's own edges.
            height: AppScale.space(context, 46),
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
                // Letters were 15 (smaller than the special keys' own 21px
                // caption size, backwards for the keys pressed most often) —
                // bumped to 20, close enough to the special keys' size that
                // the two no longer read as two different scales.
                fontSize: isSpecial
                    ? AppScale.caption(context)
                    : AppScale.space(context, 20),
                fontWeight: isSpecial ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
