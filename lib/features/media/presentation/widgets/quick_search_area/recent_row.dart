// Part of quick_search_area.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the two consts and the
// QuickSearchArea widget; private identifiers are shared across all parts.
part of '../quick_search_area.dart';

// ── "Ricerche recenti" (empty query) ─────────────────────────────────────
// Where the results go, while nothing is typed: the profile's recent
// searches (RecentSearches, same list as the phone/desktop search screens)
// as a row of chips, then "Cancella". Down from the keyboard lands on the
// first one, Left/Right walk the row, Up goes back to the keyboard; Back is
// the panel's own (the scope Focus in area_state.dart). Every arrow is
// explicit — the scope swallows the rest, so nothing drifts out by geometry.

class _RecentSearchesRow extends StatefulWidget {
  final List<String> queries;
  final SafeFocusRef firstFocus;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;
  final VoidCallback onNavigateUp;

  const _RecentSearchesRow({
    required this.queries,
    required this.firstFocus,
    required this.onPick,
    required this.onClear,
    required this.onNavigateUp,
  });

  @override
  State<_RecentSearchesRow> createState() => _RecentSearchesRowState();
}

class _RecentSearchesRowState extends State<_RecentSearchesRow> {
  // One per query plus "Cancella" (last). Rebuilt when the list changes.
  List<FocusNode> _nodes = const [];

  @override
  void initState() {
    super.initState();
    _buildNodes();
  }

  @override
  void didUpdateWidget(_RecentSearchesRow old) {
    super.didUpdateWidget(old);
    if (old.queries.length != widget.queries.length) {
      final stale = _nodes;
      _buildNodes();
      // After this frame: a node can't be disposed while still attached.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final n in stale) {
          n.dispose();
        }
      });
    }
  }

  void _buildNodes() {
    _nodes = [
      for (var i = 0; i <= widget.queries.length; i++)
        FocusNode(debugLabel: 'recent_search_$i')
    ];
    widget.firstFocus.set(_nodes.first);
  }

  @override
  void dispose() {
    widget.firstFocus.clear();
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  Widget _chip(int i,
      {required String label,
      required IconData icon,
      required VoidCallback onActivate,
      bool dim = false}) {
    return TvFocusable(
      focusNode: _nodes[i],
      onActivate: onActivate,
      onUp: widget.onNavigateUp,
      onLeft: i > 0 ? () => _nodes[i - 1].requestFocus() : null,
      onRight:
          i < _nodes.length - 1 ? () => _nodes[i + 1].requestFocus() : null,
      semanticLabel: label,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 12),
            vertical: AppScale.space(context, 6)),
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: focused ? AppTheme.primary : Colors.transparent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: AppScale.iconS(context),
                color: focused ? AppTheme.textHigh : Colors.white54),
            SizedBox(width: AppScale.space(context, 6)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: focused
                    ? AppTheme.textHigh
                    : AppTheme.textHigh.withValues(alpha: dim ? 0.5 : 0.8),
                fontSize: AppScale.space(context, 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queries = widget.queries;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: AppScale.space(context, 10)),
          child: Text(
            'RICERCHE RECENTI',
            style: TextStyle(
              color: AppTheme.textLow,
              fontSize: AppScale.space(context, 12),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppScale.space(context, 8),
          runSpacing: AppScale.space(context, 8),
          children: [
            for (var i = 0; i < queries.length; i++)
              _chip(i,
                  label: queries[i],
                  icon: Icons.history_rounded,
                  onActivate: () => widget.onPick(queries[i])),
            _chip(queries.length,
                label: 'Cancella',
                icon: Icons.delete_outline_rounded,
                dim: true,
                onActivate: widget.onClear),
          ],
        ),
      ],
    );
  }
}
