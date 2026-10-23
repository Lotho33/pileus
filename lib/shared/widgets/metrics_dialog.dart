import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/metrics.dart';
import 'settings/dialog_action_button.dart';
import 'tv_focusable.dart';

/// Preferenze → "Tempi di risposta": the persisted [Metrics] samples, one
/// row per wait (median, last, worst, sample count). Same dialog on every
/// platform — D-pad focusable buttons, Back closes.
Future<void> showMetricsDialog(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => TvFocusable(
        canRequestFocus: false,
        onEsc: () => Navigator.of(dialogCtx).pop(),
        builder: (_, __) => const _MetricsDialog(),
      ),
    );

class _MetricsDialog extends StatefulWidget {
  const _MetricsDialog();

  @override
  State<_MetricsDialog> createState() => _MetricsDialogState();
}

class _MetricsDialogState extends State<_MetricsDialog> {
  var _rows = Metrics.summaries();

  static String _fmt(int ms) =>
      ms < 1000 ? '$ms ms' : '${(ms / 1000).toStringAsFixed(1)} s';

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(
        color: AppTheme.textLow, fontSize: 12, fontWeight: FontWeight.w700);
    const cell = TextStyle(color: AppTheme.textHigh, fontSize: 14);
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Tempi di risposta'),
      content: SizedBox(
        width: 560,
        child: _rows.isEmpty
            ? const Text(
                'Nessuna misura ancora. Usa l\'app normalmente: avvio, '
                'apertura dei titoli e Play vengono misurati da soli.',
                style: TextStyle(color: AppTheme.textMid))
            : SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1.3),
                    2: FlexColumnWidth(1.3),
                    3: FlexColumnWidth(1.3),
                    4: FlexColumnWidth(0.6),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    const TableRow(children: [
                      Text('', style: head),
                      Text('MEDIANA', style: head),
                      Text('ULTIMA', style: head),
                      Text('PEGGIORE', style: head),
                      Text('N', style: head),
                    ]),
                    for (final r in _rows)
                      TableRow(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.metric.label, style: cell),
                              Text(r.metric.hint,
                                  style: const TextStyle(
                                      color: AppTheme.textLow, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(_fmt(r.median),
                            style: cell.copyWith(fontWeight: FontWeight.w700)),
                        Text(_fmt(r.last), style: cell),
                        Text(_fmt(r.worst), style: cell),
                        Text('${r.samples.length}', style: cell),
                      ]),
                  ],
                ),
              ),
      ),
      actions: [
        DialogActionButton(
          label: 'Azzera',
          onPressed: _rows.isEmpty
              ? null
              : () async {
                  await Metrics.clear();
                  if (mounted) setState(() => _rows = Metrics.summaries());
                },
        ),
        DialogActionButton(
          label: 'Chiudi',
          primary: true,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
