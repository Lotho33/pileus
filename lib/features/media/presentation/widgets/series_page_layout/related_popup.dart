// Part of series_page_layout.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the _dmax helper and the public
// AnimeLayout / SeriesLayout entry points; private identifiers are shared
// across all parts.
part of '../series_page_layout.dart';

// ── Related item details popup (shown on Enter/Select on a related card) ─────
//
// Shows poster + title + rel badge and lets the user navigate to the full
// details page. Replaces the old focus-triggered overlay popup.

class _RelatedDetailsPopup extends StatefulWidget {
  final String pluginId;
  final String id;
  final String poster;
  final String title;
  final String relLabel;
  final VoidCallback onNavigate;

  const _RelatedDetailsPopup({
    required this.pluginId,
    required this.id,
    required this.poster,
    required this.title,
    required this.relLabel,
    required this.onNavigate,
  });

  @override
  State<_RelatedDetailsPopup> createState() => _RelatedDetailsPopupState();
}

class _RelatedDetailsPopupState extends State<_RelatedDetailsPopup> {
  late final MediaRepository _repo;
  late Future<({String plot, String year, String runtime, String rating})>
      _detailsFuture;

  @override
  void initState() {
    super.initState();
    _repo = getIt<MediaRepository>();
    _detailsFuture = _loadDetails();
  }

  Future<({String plot, String year, String runtime, String rating})>
      _loadDetails() async {
    try {
      final res = await _repo.getDetails(widget.pluginId, widget.id);
      String plot = '';
      String runtime = '';
      String rating = '';
      String year = '';
      if (res.hasMovie()) {
        plot = res.movie.plot;
        runtime = res.movie.runtime;
        rating = res.item.rating > 0 ? res.item.rating.toStringAsFixed(1) : '';
        year = res.item.year > 0 ? '${res.item.year}' : '';
      } else if (res.hasSeries()) {
        plot = res.series.plot;
        rating = res.item.rating > 0 ? res.item.rating.toStringAsFixed(1) : '';
        year = res.item.year > 0 ? '${res.item.year}' : '';
      }
      return (plot: plot, year: year, runtime: runtime, rating: rating);
    } catch (_) {
      return (plot: '', year: '', runtime: '', rating: '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final sw = MediaQuery.sizeOf(context).width;

    // Fixed dimensions: poster never resizes when plot loads. Sized up from
    // the original 0.52/0.62 ratios so the plot column (an Expanded that
    // fills whatever's left after title/meta, see _loadDetails' builder
    // below) gets meaningfully more room, not just a few extra pixels.
    // The 520/420 floors are a preferred minimum, not a guarantee — this
    // dialog has insetPadding: EdgeInsets.zero, so nothing else stops it
    // from requesting a size bigger than the actual window on a small
    // enough one. The second .clamp keeps it from ever exceeding the real
    // screen bounds even when that happens.
    final dialogW = (sw * 0.60).clamp(520.0, 1000.0).clamp(0.0, sw - 24.0);
    final dialogH = (sh * 0.72).clamp(420.0, 760.0).clamp(0.0, sh - 24.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: TvFocusable(
        canRequestFocus: false,
        onEsc: () => Navigator.of(context).pop(),
        builder: (context, _) => SizedBox(
          width: dialogW,
          height: dialogH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: const Color(0xFF0E0E1A),
              child: Column(
                children: [
                  // ── Body: fills all space above action bar ─────────────────
                  // LayoutBuilder measures the *real* space left after the
                  // action bar's own natural height, instead of the fixed
                  // 64px this used to just assume — the action bar's actual
                  // height is screen-relative (_PopupActionButton scales its
                  // padding from sh), so a guessed constant drifted off the
                  // true value at anything other than ~1080p, throwing the
                  // poster's 2:3 aspect ratio off by a bit on every other
                  // screen size.
                  Expanded(
                    child: LayoutBuilder(builder: (context, bodyConstraints) {
                      final posterW = bodyConstraints.maxHeight * (2.0 / 3.0);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Poster — fixed width & height
                          SizedBox(
                            width: posterW,
                            child: widget.poster.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: posterSrc(widget.poster,
                                        cacheWidthFor(context, posterW)),
                                    fit: BoxFit.cover,
                                    memCacheWidth:
                                        cacheWidthFor(context, posterW),
                                    placeholder: (_, __) => const ColoredBox(
                                        color: Color(0xFF1A1A2A)),
                                    errorWidget: (_, __, ___) =>
                                        const ColoredBox(
                                            color: Color(0xFF1A1A2A)),
                                  )
                                : const ColoredBox(color: Color(0xFF1A1A2A)),
                          ),
                          // Info panel — fills remaining space with plot
                          Expanded(
                            child: Container(
                              color: const Color(0xFF13131E),
                              padding:
                                  const EdgeInsets.fromLTRB(22, 22, 22, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      color: AppTheme.textHigh,
                                      fontSize: (sh * 0.026).clamp(18.0, 56.0),
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.relLabel.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppTheme.primary
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        widget.relLabel,
                                        style: TextStyle(
                                            color: const Color(0xFFB8A9FF),
                                            fontSize: (sh * (13.0 / 1080.0))
                                                .clamp(10.0, 18.0),
                                            fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  // Meta + plot expand to fill all remaining height
                                  Expanded(
                                    child: FutureBuilder(
                                      future: _detailsFuture,
                                      builder: (ctx, snap) {
                                        if (!snap.hasData) {
                                          return const Center(
                                            child: PileusSpinner(
                                                size: 18,
                                                color: AppTheme.textLow),
                                          );
                                        }
                                        final det = snap.data!;
                                        final hasMeta = det.rating.isNotEmpty ||
                                            det.year.isNotEmpty ||
                                            det.runtime.isNotEmpty;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (hasMeta) ...[
                                              Wrap(
                                                spacing: 10,
                                                runSpacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  if (det.rating.isNotEmpty)
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.star_rounded,
                                                            size: (sh *
                                                                    (15.0 /
                                                                        1080.0))
                                                                .clamp(
                                                                    11.0, 20.0),
                                                            color: const Color(
                                                                0xFFFFD700)),
                                                        SizedBox(
                                                            width: sh *
                                                                (3.0 / 1080.0)),
                                                        Text(det.rating,
                                                            style: TextStyle(
                                                                color: AppTheme
                                                                    .textMid,
                                                                fontSize: (sh *
                                                                        (15.0 /
                                                                            1080.0))
                                                                    .clamp(11.0,
                                                                        20.0))),
                                                      ],
                                                    ),
                                                  if (det.year.isNotEmpty)
                                                    Text(det.year,
                                                        style: TextStyle(
                                                            color: AppTheme
                                                                .textLow,
                                                            fontSize: (sh *
                                                                    (15.0 /
                                                                        1080.0))
                                                                .clamp(11.0,
                                                                    20.0))),
                                                  if (det.runtime.isNotEmpty)
                                                    Text(det.runtime,
                                                        style: TextStyle(
                                                            color: AppTheme
                                                                .textLow,
                                                            fontSize: (sh *
                                                                    (15.0 /
                                                                        1080.0))
                                                                .clamp(11.0,
                                                                    20.0))),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                            if (det.plot.isNotEmpty)
                                              // Used to be a fixed maxLines: 5
                                              // — conservative enough to never
                                              // overflow the *smallest*
                                              // possible dialogH (420, see the
                                              // clamp floor above), which
                                              // meant it truncated the plot
                                              // partway through the box on
                                              // every dialog taller than that
                                              // (i.e. most real screens,
                                              // dialogH goes up to 760).
                                              // FocusableScrollTarget already
                                              // solves exactly this — long
                                              // text scrolls via the D-pad
                                              // instead of being cut off —
                                              // just needed the real
                                              // available height (this
                                              // Expanded's, not the 18%-of-
                                              // screen default meant for a
                                              // full details page) instead of
                                              // a guessed line cap.
                                              Expanded(
                                                child: LayoutBuilder(
                                                  builder: (context, plotBc) =>
                                                      FocusableScrollTarget(
                                                    maxHeightOverride:
                                                        plotBc.maxHeight,
                                                    child: Text(
                                                      det.plot,
                                                      style: TextStyle(
                                                        color: const Color(
                                                            0xA0FFFFFF),
                                                        fontSize: (sh *
                                                                (15.0 / 1080.0))
                                                            .clamp(12.0, 22.0),
                                                        height: 1.6,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  // ── Action bar ─────────────────────────────────────────────
                  // Fixed, screen-scaled height with a sane floor: the two
                  // buttons used to size themselves off their own
                  // `sh`-scaled vertical padding while the divider between
                  // them was a hard-coded `height: 56`, so away from ~1080p
                  // the bar's height and the divider disagreed and the
                  // labels clipped. Now the bar owns the height and the
                  // buttons + divider just stretch to fill it.
                  SizedBox(
                    height: (sh * 0.055).clamp(46.0, 74.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _PopupActionButton(
                            label: 'Vai ai dettagli',
                            icon: Icons.open_in_new_rounded,
                            autofocus: true,
                            primary: true,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onNavigate();
                            },
                          ),
                        ),
                        Container(
                            width: 1,
                            color: AppTheme.textHigh.withValues(alpha: 0.07)),
                        Expanded(
                          child: _PopupActionButton(
                            label: 'Chiudi',
                            icon: Icons.close_rounded,
                            primary: false,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool autofocus;
  final bool primary;
  final VoidCallback onTap;
  const _PopupActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
    this.primary = false,
  });
  @override
  State<_PopupActionButton> createState() => _PopupActionButtonState();
}

class _PopupActionButtonState extends State<_PopupActionButton> {
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final iconSz = (sh * (16.0 / 1080.0)).clamp(13.0, 20.0);
    final fontSz = (sh * (13.0 / 1080.0)).clamp(11.0, 17.0);
    return TvFocusable(
      autofocus: widget.autofocus,
      onActivate: widget.onTap,
      // Fills the action bar's fixed height (no own vertical padding driving
      // it). FittedBox.scaleDown guarantees the icon+label never clip on a
      // narrow dialog / small screen — they shrink to fit instead.
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border(
              top:
                  BorderSide(color: AppTheme.textHigh.withValues(alpha: 0.08))),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon,
                    size: iconSz,
                    color: focused ? const Color(0xFFB8A9FF) : Colors.white54),
                SizedBox(width: iconSz * 0.5),
                Text(
                  widget.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: focused ? const Color(0xFFB8A9FF) : Colors.white54,
                    fontSize: fontSz,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonRatingRow extends StatelessWidget {
  final CatalogItem item;
  final String contentRating;
  final String seasonAirDate;
  const _SeasonRatingRow(
      {required this.item, this.contentRating = '', this.seasonAirDate = ''});

  static const _months = [
    '',
    'Gen',
    'Feb',
    'Mar',
    'Apr',
    'Mag',
    'Giu',
    'Lug',
    'Ago',
    'Set',
    'Ott',
    'Nov',
    'Dic'
  ];

  String _fmtAirDate(String d) {
    if (d.isEmpty) return '';
    final parts = d.split('-');
    if (parts.length < 2) return parts[0];
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 0;
    final mon = (month >= 1 && month <= 12) ? _months[month] : '';
    return mon.isNotEmpty ? '$mon $year' : year;
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final extraRating = item.extra['content_rating'] ?? contentRating;
    final airDateLabel = _fmtAirDate(seasonAirDate);
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (item.rating > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_rounded,
                size: sh * (15.0 / 1080.0), color: const Color(0xFFFFD700)),
            SizedBox(width: sh * (4.0 / 1080.0)),
            Text(item.rating.toStringAsFixed(1),
                style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: sh * (13.0 / 1080.0),
                    fontWeight: FontWeight.w600)),
          ]),
        if (airDateLabel.isNotEmpty)
          Text(airDateLabel,
              style: TextStyle(
                  color: Colors.white54, fontSize: sh * (13.0 / 1080.0))),
        if (extraRating.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.textLow),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(extraRating,
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: sh * (11.0 / 1080.0),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: sh * (18.0 / 1080.0), color: Colors.white54),
        SizedBox(width: sh * (5.0 / 1080.0)),
        Text(text,
            style: TextStyle(
                color: Colors.white54, fontSize: sh * (16.0 / 1080.0))),
      ],
    );
  }
}
