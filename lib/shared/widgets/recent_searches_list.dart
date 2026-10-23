import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/media/data/recent_searches.dart';

/// "Ricerche recenti" while the search box is empty (mobile, desktop, web).
/// Shows [fallback] when there are none. Tapping one runs it again.
class RecentSearchesList extends StatefulWidget {
  final ValueChanged<String> onPick;
  final Widget fallback;

  const RecentSearchesList(
      {super.key, required this.onPick, required this.fallback});

  @override
  State<RecentSearchesList> createState() => _RecentSearchesListState();
}

class _RecentSearchesListState extends State<RecentSearchesList> {
  late List<String> _items = RecentSearches.list();

  Future<void> _remove(String q) async {
    await RecentSearches.remove(q);
    if (mounted) setState(() => _items = RecentSearches.list());
  }

  Future<void> _clear() async {
    await RecentSearches.clear();
    if (mounted) setState(() => _items = const []);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return widget.fallback;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('RICERCHE RECENTI',
                    style: TextStyle(
                        color: AppTheme.textLow,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
              TextButton(onPressed: _clear, child: const Text('Cancella')),
            ],
          ),
        ),
        for (final q in _items)
          ListTile(
            leading: const Icon(Icons.history_rounded, color: AppTheme.textLow),
            title: Text(q, style: const TextStyle(color: AppTheme.textHigh)),
            trailing: IconButton(
              tooltip: 'Rimuovi',
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppTheme.textLow),
              onPressed: () => _remove(q),
            ),
            onTap: () => widget.onPick(q),
          ),
      ],
    );
  }
}
