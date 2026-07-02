import 'package:flutter/material.dart';

import '../../core/grpc/clients/media_client.dart' show SearchFilter;
import '../../core/theme/app_theme.dart';

/// Bottom sheet that edits the active search filters for a plugin.
///
/// Returns the new `{filterId: value}` map on "Applica", or `null` if the
/// sheet is dismissed without applying. Value shapes match what the server's
/// search-filter parser expects back (the same contract the TV screen uses):
///
///  * `select`      → the chosen option id ('' clears)
///  * `multiselect` → comma-joined option ids
///  * `bool`        → 'true' when on, absent when off
///  * `number`      → an integer string (year stepper)
///  * `range`       → 'lo..hi'; a full span clears
///
/// A filter whose `type` is none of the above is skipped.
///
/// [centered] uses a centred dialog instead of a bottom sheet — the desktop
/// build passes this so it matches the rest of its dialogs.
Future<Map<String, String>?> showFilterSheet(
  BuildContext context, {
  required List<SearchFilter> filters,
  required Map<String, String> active,
  bool centered = false,
}) {
  if (centered) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _FilterSheet(filters: filters, active: active),
        ),
      ),
    );
  }
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FilterSheet(filters: filters, active: active),
  );
}

class _FilterSheet extends StatefulWidget {
  final List<SearchFilter> filters;
  final Map<String, String> active;
  const _FilterSheet({required this.filters, required this.active});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Map<String, String> _draft = Map.of(widget.active);

  static const _supported = {'select', 'multiselect', 'bool', 'number', 'range'};

  void _set(String id, String value) {
    setState(() {
      if (value.isEmpty) {
        _draft.remove(id);
      } else {
        _draft[id] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        widget.filters.where((f) => _supported.contains(f.type)).toList();
    final maxH = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  const Text(
                    'Filtri',
                    style: TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_draft.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _draft = {}),
                      child: const Text('Azzera'),
                    ),
                ],
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(
                  'Questo plugin non offre filtri di ricerca.',
                  style: TextStyle(color: AppTheme.textMid),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 28,
                    color: AppTheme.border,
                  ),
                  itemBuilder: (_, i) => _FilterRow(
                    filter: rows[i],
                    value: _draft[rows[i].id] ?? '',
                    onChanged: (v) => _set(rows[i].id, v),
                  ),
                ),
              ),
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: Text(_draft.isEmpty
                          ? 'Applica'
                          : 'Applica (${_draft.length})'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final SearchFilter filter;
  final String value;
  final ValueChanged<String> onChanged;
  const _FilterRow({
    required this.filter,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filter.label.isNotEmpty ? filter.label : filter.id,
          style: const TextStyle(
            color: AppTheme.textHigh,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        switch (filter.type) {
          'select' => _SelectField(filter: filter, value: value, onChanged: onChanged),
          'multiselect' =>
            _MultiField(filter: filter, value: value, onChanged: onChanged),
          'bool' => _BoolField(value: value, onChanged: onChanged),
          'number' => _NumberField(value: value, onChanged: onChanged),
          'range' => _RangeField(filter: filter, value: value, onChanged: onChanged),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

class _SelectField extends StatelessWidget {
  final SearchFilter filter;
  final String value;
  final ValueChanged<String> onChanged;
  const _SelectField({
    required this.filter,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in filter.options)
          ChoiceChip(
            label: Text(o.label.isNotEmpty ? o.label : o.id),
            selected: value == o.id,
            showCheckmark: false,
            backgroundColor: AppTheme.surface2,
            selectedColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.border),
            labelStyle: TextStyle(
              fontSize: 13,
              color: value == o.id ? Colors.white : AppTheme.textHigh,
            ),
            onSelected: (_) => onChanged(value == o.id ? '' : o.id),
          ),
      ],
    );
  }
}

class _MultiField extends StatelessWidget {
  final SearchFilter filter;
  final String value;
  final ValueChanged<String> onChanged;
  const _MultiField({
    required this.filter,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final picked = value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in filter.options)
          FilterChip(
            label: Text(o.label.isNotEmpty ? o.label : o.id),
            selected: picked.contains(o.id),
            showCheckmark: true,
            backgroundColor: AppTheme.surface2,
            selectedColor: AppTheme.primary,
            checkmarkColor: Colors.white,
            side: const BorderSide(color: AppTheme.border),
            labelStyle: TextStyle(
              fontSize: 13,
              color: picked.contains(o.id) ? Colors.white : AppTheme.textHigh,
            ),
            onSelected: (on) {
              final next = {...picked};
              if (on) {
                next.add(o.id);
              } else {
                next.remove(o.id);
              }
              onChanged(next.join(','));
            },
          ),
      ],
    );
  }
}

class _BoolField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _BoolField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Switch(
        value: value == 'true',
        onChanged: (on) => onChanged(on ? 'true' : ''),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _NumberField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final maxYear = DateTime.now().year;
    const minYear = 1900;
    final current = int.tryParse(value);
    return _Stepper(
      text: current != null ? '$current' : 'Qualsiasi anno',
      onMinus: () =>
          onChanged('${((current ?? maxYear) - 1).clamp(minYear, maxYear)}'),
      onPlus: () =>
          onChanged('${((current ?? maxYear) + 1).clamp(minYear, maxYear)}'),
      onClear: current != null ? () => onChanged('') : null,
    );
  }
}

class _RangeField extends StatelessWidget {
  final SearchFilter filter;
  final String value;
  final ValueChanged<String> onChanged;
  const _RangeField({
    required this.filter,
    required this.value,
    required this.onChanged,
  });

  double _opt(String id, double fallback) {
    for (final o in filter.options) {
      if (o.id == id) return double.tryParse(o.label) ?? fallback;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final lo = _opt('min', 0);
    final hiRaw = _opt('max', 100);
    final hi = hiRaw < lo ? lo : hiRaw;
    final stepRaw = _opt('step', 1);
    final step = stepRaw > 0 ? stepRaw : 1.0;

    final parts = value.split('..');
    double curLo = lo, curHi = hi;
    if (parts.length == 2) {
      curLo = (double.tryParse(parts[0]) ?? lo).clamp(lo, hi);
      curHi = (double.tryParse(parts[1]) ?? hi).clamp(lo, hi);
      if (curHi < curLo) curHi = curLo;
    }

    String fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

    void emit(double l, double h) {
      l = l.clamp(lo, hi);
      h = h.clamp(lo, hi);
      if (h < l) h = l;
      if (l <= lo && h >= hi) {
        onChanged(''); // full span → no filter
      } else {
        onChanged('${fmt(l)}..${fmt(h)}');
      }
    }

    return Column(
      children: [
        _Stepper(
          leading: 'Da',
          text: fmt(curLo),
          onMinus: () => emit(curLo - step, curHi),
          onPlus: () => emit(curLo + step, curHi),
        ),
        const SizedBox(height: 8),
        _Stepper(
          leading: 'A',
          text: fmt(curHi),
          onMinus: () => emit(curLo, curHi - step),
          onPlus: () => emit(curLo, curHi + step),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  final String? leading;
  final String text;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback? onClear;
  const _Stepper({
    required this.text,
    required this.onMinus,
    required this.onPlus,
    this.leading,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          SizedBox(
            width: 28,
            child: Text(leading!,
                style: const TextStyle(color: AppTheme.textMid, fontSize: 13)),
          ),
          const SizedBox(width: 4),
        ],
        IconButton.filledTonal(
          onPressed: onMinus,
          icon: const Icon(Icons.remove, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 96),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
                color: AppTheme.textHigh,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ),
        IconButton.filledTonal(
          onPressed: onPlus,
          icon: const Icon(Icons.add, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('Azzera')),
      ],
    );
  }
}
