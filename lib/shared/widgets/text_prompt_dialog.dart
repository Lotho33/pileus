import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A single-field text prompt dialog. Returns the trimmed text, or `null` if
/// dismissed. The `TextEditingController` lives on a `State` (disposed in
/// `dispose`) — never a local in an `async` helper disposed right after
/// `await showDialog`, which red-screens during the close transition while
/// the still-mounted `TextField` reads a disposed controller.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String confirmLabel = 'OK',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String hint;
  final String confirmLabel;

  const _TextPromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  // Was: confirming with an empty field popped '' (not null), which every
  // caller's `if (name != null && name.isNotEmpty)` then silently ignored —
  // the dialog closed as if it had worked, with zero feedback. Now an empty
  // confirm is refused in-dialog instead.
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_error != null && _ctrl.text.trim().isNotEmpty) {
      setState(() => _error = null);
    }
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'Inserisci un testo.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: widget.hint.isEmpty ? null : widget.hint,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
