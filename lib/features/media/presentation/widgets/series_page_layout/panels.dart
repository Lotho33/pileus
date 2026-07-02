// Part of series_page_layout.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the _dmax helper and the public
// AnimeLayout / SeriesLayout entry points; private identifiers are shared
// across all parts.
part of '../series_page_layout.dart';

// ── Left-column panels ────────────────────────────────────────────────────────

// ── Page button ───────────────────────────────────────────────────────────────

class _PageButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PageButton({required this.label, required this.onTap});

  @override
  State<_PageButton> createState() => _PageButtonState();
}

class _PageButtonState extends State<_PageButton> {
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return TvFocusable(
      onActivate: widget.onTap,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
            horizontal: sh * (28.0 / 1080.0), vertical: sh * (14.0 / 1080.0)),
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.primary.withValues(alpha: 0.20)
              : AppTheme.textHigh.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: focused ? AppTheme.primary : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: focused ? AppTheme.textHigh : AppTheme.textMid,
            fontSize: sh * (17.0 / 1080.0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Season poster panel ───────────────────────────────────────────────────────

class _SeasonPosterPanel extends StatelessWidget {
  final String posterUrl;
  final String title;
  const _SeasonPosterPanel(
      {super.key, required this.posterUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: posterUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: posterSrc(posterUrl, cacheWidthFor(context, 360)),
                fit: BoxFit.cover,
                memCacheWidth: cacheWidthFor(context, 360),
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) =>
                    const ColoredBox(color: Color(0xFF1A1A2A)),
                errorWidget: (_, __, ___) => PlaceholderPoster(title: title),
              )
            : PlaceholderPoster(title: title),
      ),
    );
  }
}

