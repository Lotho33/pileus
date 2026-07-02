import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../on_screen_keyboard.dart';
import '../tv_focusable.dart';
import 'dialog_action_button.dart';

/// Simple text-input dialog (rename, avatar URL, ...). Returns the trimmed
/// value, or null if cancelled / left empty.
///
/// Pairs the field with OnScreenKeyboard — it used to be a bare TextField
/// with no D-pad-native way to type into it at all, blocking "Rinomina
/// profilo" and "URL avatar" entirely for a remote-control user.
///
/// The `controller` / `FocusNode` live on a real State ([_SettingsTextInput],
/// below), NOT as function-scoped locals disposed right after
/// `await showDialog`. That old shape disposed the controller a frame or two
/// before the dialog's exit transition finished painting, so the still-
/// mounted `EditableText` rebuilt against a disposed controller and threw
/// ("A TextEditingController was used after being disposed") — a red screen
/// for the duration of the fade-out. Tying disposal to the widget's own
/// lifecycle removes that race entirely.
Future<String?> showSettingsTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? hintText,
}) async {
  final result = await showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => _SettingsTextInput(
      title: title,
      initialValue: initialValue,
      hintText: hintText,
    ),
  );
  return (result != null && result.isNotEmpty) ? result : null;
}

class _SettingsTextInput extends StatefulWidget {
  final String title;
  final String initialValue;
  final String? hintText;
  const _SettingsTextInput({
    required this.title,
    required this.initialValue,
    this.hintText,
  });

  @override
  State<_SettingsTextInput> createState() => _SettingsTextInputState();
}

class _SettingsTextInputState extends State<_SettingsTextInput> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _fieldFn = FocusNode();
  final _keyboardKey = GlobalKey<OnScreenKeyboardState>();

  @override
  void initState() {
    super.initState();
    // The keyboard's first key isn't in the tree on this same frame — hand
    // focus to it on the next one (same idiom as the search bar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardKey.currentState?.firstFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _fieldFn.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _pop([String? value]) => Navigator.of(context).pop(value);

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => _pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ancestor-only catcher — EditableText only binds left/right
            // (caret) itself, so arrowDown is free to bubble up here and
            // hand off to the on-screen keyboard below.
            TvFocusable(
              canRequestFocus: false,
              onDown: () =>
                  _keyboardKey.currentState?.firstFocusNode.requestFocus(),
              builder: (context, _) => TextField(
                controller: _controller,
                focusNode: _fieldFn,
                // OnScreenKeyboard below is the only intended input source —
                // readOnly stops Android's own IME popping up on top of it.
                readOnly: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: widget.hintText),
                onSubmitted: (v) => _pop(v.trim()),
              ),
            ),
            const SizedBox(height: 14),
            OnScreenKeyboard(
              key: _keyboardKey,
              controller: _controller,
              onSubmit: () => _pop(_controller.text.trim()),
              onNavigateUp: () => _fieldFn.requestFocus(),
            ),
          ],
        ),
        actions: [
          DialogActionButton(label: 'Annulla', onPressed: () => _pop()),
          DialogActionButton(
            label: 'Salva',
            primary: true,
            onPressed: () => _pop(_controller.text.trim()),
          ),
        ],
      ),
    );
  }
}
