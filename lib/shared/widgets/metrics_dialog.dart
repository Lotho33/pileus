import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/metrics.dart';
import 'settings/dialog_action_button.dart';
import 'tv_focusable.dart';

/// Preferenze → "Tempi di risposta": the persisted [Metrics] samples, one
/// row per wait (median, last, worst, sample count). Same dialog on every
/// platform — D-pad focusable buttons, Up/Down scroll the list (the focus
/// stays on the buttons, so on a TV that's the only way to see it all),
/// Back closes.
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
  var _smooth = Metrics.fluidity();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Arrow keys the buttons don't use bubble up here.
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent || !_scroll.hasClients) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final dir = k == LogicalKeyboardKey.arrowDown
        ? 1
        : k == LogicalKeyboardKey.arrowUp
            ? -1
            : 0;
    if (dir == 0) return KeyEventResult.ignored;
    final pos = _scroll.position;
    final to = (pos.pixels + dir * pos.viewportDimension * 0.6)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    _scroll.animateTo(to,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    return KeyEventResult.handled;
  }

  static String _fmt(int ms) =>
      ms < 1000 ? '$ms ms' : '${(ms / 1000).toStringAsFixed(1)} s';

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(
        color: AppTheme.textLow, fontSize: 12, fontWeight: FontWeight.w700);
    const cell = TextStyle(color: AppTheme.textHigh, fontSize: 14);
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _onKey,
      child: AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Tempi di risposta'),
        content: SizedBox(
          width: 560,
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _times(head, cell),
                  if (_smooth.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('FLUIDITÀ — fotogrammi lenti per schermata',
                        style: head),
                    const SizedBox(height: 6),
                    for (final f in _smooth)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(f.label, style: cell)),
                            Text('${f.slowPct.toStringAsFixed(1)} %',
                                style: cell.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: f.slowPct > 5
                                        ? const Color(0xFFFFB74D)
                                        : AppTheme.textHigh)),
                            SizedBox(
                              width: 90,
                              child: Text('${f.frames}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      color: AppTheme.textLow, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: _actions(context),
      ),
    );
  }

  Widget _times(TextStyle head, TextStyle cell) {
    return _rows.isEmpty
        ? const Text(
            'Nessuna misura ancora. Usa l\'app normalmente: avvio, '
            'apertura dei titoli e Play vengono misurati da soli.',
            style: TextStyle(color: AppTheme.textMid))
        : Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1.3),
              2: FlexColumnWidth(1.3),
              3: FlexColumnWidth(1.3),
              4: FlexColumnWidth(0.6),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
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
          );
  }

  List<Widget> _actions(BuildContext context) => [
        DialogActionButton(
          label: 'Azzera',
          onPressed: _rows.isEmpty && _smooth.isEmpty
              ? null
              : () async {
                  await Metrics.clear();
                  if (mounted) {
                    setState(() {
                      _rows = Metrics.summaries();
                      _smooth = Metrics.fluidity();
                    });
                  }
                },
        ),
        DialogActionButton(
          label: 'Chiudi',
          primary: true,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
}
