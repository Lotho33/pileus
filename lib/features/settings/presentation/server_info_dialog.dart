// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/settings/dialog_action_button.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../server_diagnostics.dart';

/// Impostazioni › Server: where this device connects and whether the server
/// answers now (server_diagnostics.dart). [tv]: D-pad buttons and Back.
Future<void> showServerInfoDialog(BuildContext context, {bool tv = false}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => _ServerInfoDialog(tv: tv),
  );
}

class _ServerInfoDialog extends StatefulWidget {
  final bool tv;
  const _ServerInfoDialog({required this.tv});

  @override
  State<_ServerInfoDialog> createState() => _ServerInfoDialogState();
}

class _ServerInfoDialogState extends State<_ServerInfoDialog> {
  late Future<ServerDiagnostics> _load = loadServerDiagnostics();

  void _reload() => setState(() => _load = loadServerDiagnostics());

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).pop();
    final dialog = AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Server'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<ServerDiagnostics>(
          future: _load,
          builder: (context, snap) {
            final d = snap.data;
            if (d == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [for (final (k, v) in d.rows) _row(k, v, d)],
              ),
            );
          },
        ),
      ),
      actions: widget.tv
          ? [
              DialogActionButton(label: 'Aggiorna', onPressed: _reload),
              DialogActionButton(
                  label: 'Chiudi',
                  primary: true,
                  autofocus: true,
                  onPressed: close),
            ]
          : [
              TextButton(onPressed: _reload, child: const Text('Aggiorna')),
              FilledButton(onPressed: close, child: const Text('Chiudi')),
            ],
    );
    if (!widget.tv) return dialog;
    return TvFocusable(
      canRequestFocus: false,
      onEsc: close,
      builder: (context, _) => dialog,
    );
  }

  Widget _row(String label, String value, ServerDiagnostics d) {
    final isState = label == 'Stato';
    final style = TextStyle(
      color: isState
          ? (d.reachable ? Colors.greenAccent : Colors.redAccent)
          : AppTheme.textHigh,
      fontSize: 14,
      fontWeight: isState ? FontWeight.w600 : FontWeight.w400,
    );
    final labelText = Text(label,
        style: const TextStyle(color: AppTheme.textLow, fontSize: 14));
    // Not selectable on TV: a SelectableText takes D-pad focus.
    final valueText = widget.tv
        ? Text(value, style: style)
        : SelectableText(value, style: style);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // A phone's dialog is too narrow for the two columns (the values broke
      // a letter or two per line): the label goes above its value instead.
      // (By the screen, not a LayoutBuilder: AlertDialog measures its
      // content's intrinsic width, which a LayoutBuilder can't answer.)
      child: Builder(
        builder: (context) => MediaQuery.sizeOf(context).width < 600
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelText, const SizedBox(height: 2), valueText],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 190, child: labelText),
                  Expanded(child: valueText),
                ],
              ),
      ),
    );
  }
}
