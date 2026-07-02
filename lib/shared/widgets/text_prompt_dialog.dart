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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text.trim());

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
