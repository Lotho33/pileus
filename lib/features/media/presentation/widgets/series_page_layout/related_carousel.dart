// Part of series_page_layout.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the _dmax helper and the public
// AnimeLayout / SeriesLayout entry points; private identifiers are shared
// across all parts.
part of '../series_page_layout.dart';

// ── Series related carousel (↑/↓ switches between Correlati/Simili) ──────────

class _SeriesRelatedCarousel extends StatefulWidget {
  final String pluginId;
  final List<dynamic> related;
  final List<dynamic> similar;
  final FocusNode? firstFocusNode;
  final VoidCallback? onBack;
  // Explicit card height — caller is responsible for computing this.
  final double cardHeight;

  const _SeriesRelatedCarousel({
    required this.pluginId,
    required this.related,
    required this.similar,
    required this.cardHeight,
    this.firstFocusNode,
    this.onBack,
  });

  @override
  State<_SeriesRelatedCarousel> createState() => _SeriesRelatedCarouselState();
}

class _SeriesRelatedCarouselState extends State<_SeriesRelatedCarousel> {
  int _activeIdx = 0;
  List<FocusNode> _cardFns = [];

  @override
  void initState() {
    super.initState();
    if (widget.related.isEmpty && widget.similar.isNotEmpty) _activeIdx = 1;
    _rebuildCardFns();
  }

  @override
  void dispose() {
    for (final n in _cardFns) {
      n.dispose();
    }
    super.dispose();
  }

  List<dynamic> get _activeList =>
      _activeIdx == 0 ? widget.related : widget.similar;

  List<dynamic> get _otherList =>
      _activeIdx == 0 ? widget.similar : widget.related;

  bool get _hasMultiple =>
      widget.related.isNotEmpty && widget.similar.isNotEmpty;

  String get _activeLabel => _activeIdx == 0 ? 'CORRELATI' : 'SIMILI';

  void _rebuildCardFns() {
    for (final n in _cardFns) {
      n.dispose();
    }
    _cardFns = List.generate(_activeList.length, (_) => FocusNode());
  }

  void _switchCategory(int delta) {
    if (!_hasMultiple) return;
    final next = (_activeIdx + delta).clamp(0, 1);
    if (next != _activeIdx) {
      // Park focus on the carousel's own stationary container node BEFORE
      // tearing the current card FocusNodes down. _rebuildCardFns() disposes
      // the node that currently holds focus; without a live target already
      // pending, the focus manager falls back to the enclosing scope's last
      // focused child — the episode tile the user came from, usually the
      // last one — for the frame between the teardown here and the
      // post-frame requestFocus below. That one-frame fallback is the
      // "focus flashes to the last episode" glitch when switching between
      // Correlati and Simili.
      widget.firstFocusNode?.requestFocus();
      setState(() => _activeIdx = next);
      _rebuildCardFns();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _cardFns.isNotEmpty) _cardFns[0].requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeList.isEmpty && _otherList.isEmpty) {
      return const SizedBox.shrink();
    }

    final sh = MediaQuery.sizeOf(context).height;
    final cardH = widget.cardHeight;
    // Height to reserve for the 2-line title under the poster. Same font as
    // _RelatedCard's own Text; `textScale` because that Text scales with
    // MediaQuery's textScaler (≈1.35 desktop/web) while this raw-px reserve
    // doesn't; `1.4` line factor against the Text's own `1.25` leaves real
    // slack for glyph overshoot/rounding. The poster is then sized from the
    // ListView's ACTUAL viewport height (see the LayoutBuilder below), not
    // widget.cardHeight — that's the whole footer region, before the divider
    // + header row are subtracted, so sizing the poster from it left the
    // card taller than its slot and the second title line got clipped.
    final titleFs = (sh * (16.2 / 1080.0)).clamp(13.0, 26.0);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final titleBlockH = titleFs * textScale * 1.4 * 2 + 8.0;

    return Focus(
      focusNode: widget.firstFocusNode,
      skipTraversal: true,
      onFocusChange: (gained) {
        if (gained && _cardFns.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _cardFns[0].requestFocus();
          });
        }
      },
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          widget.onBack?.call();
          return widget.onBack != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && _activeIdx == 0) {
          widget.onBack?.call();
          return widget.onBack != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        // Was mainAxisSize.min with a *fixed*-height SizedBox below sized
        // from listH — computed independently of this Column's own actual
        // incoming height constraint (which comes from footerH/cardHeight
        // upstream, both floored separately). On a device where those two
        // floors don't line up (a real one hit this: title row fonts scale
        // off the *global* screen height while the space available here
        // scales off a locally-measured region — they can disagree), the
        // Column's own natural content height exceeded what it was actually
        // given, throwing "RenderFlex overflowed" instead of degrading.
        // Expanded below makes the list take whatever room is actually
        // left after the header row, guaranteeing this Column always fits
        // its real constraints no matter how those two floors drift.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  _activeLabel,
                  style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: (sh * (32.5 / 1080.0)).clamp(23.0, 42.0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hasMultiple) ...[
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 14,
                        color:
                            _activeIdx > 0 ? Colors.white54 : Colors.white24),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color:
                            _activeIdx < 1 ? Colors.white54 : Colors.white24),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Focus(
              skipTraversal: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                    _hasMultiple &&
                    _activeIdx > 0) {
                  _switchCategory(-1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                    _hasMultiple &&
                    _activeIdx < 1) {
                  _switchCategory(1);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: LayoutBuilder(builder: (context, constraints) {
                // The real vertical room a card has — the ListView viewport,
                // after the divider + category-header row above have taken
                // their share out of widget.cardHeight.
                final availH = constraints.maxHeight;
                final posterH =
                    (availH - titleBlockH).clamp(1.0, double.infinity);
                final cardW = posterH / 1.5; // poster is exactly _w * 1.5
                final cardGap = (cardW * 0.10).clamp(8.0, 20.0);
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: AppScale.fadeCurve,
                  switchOutCurve: AppScale.fadeCurve,
                  // ListView (non-builder) → all items eagerly built → all
                  // FocusNodes always in the tree. Scrollable.ensureVisible
                  // in _RelatedCard handles scrolling when focus moves.
                  child: ListView(
                    key: ValueKey(_activeIdx),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.hardEdge,
                    children: List.generate(_activeList.length, (i) {
                      final e = _activeList[i] as Map<String, dynamic>;
                      final id = (e['id'] as String?) ?? '';
                      final title = (e['title'] as String?) ?? '';
                      final poster = (e['poster'] as String?) ?? '';
                      final rel = (e['rel'] as String?) ?? '';
                      final fn = i < _cardFns.length ? _cardFns[i] : null;
                      return Padding(
                        padding: EdgeInsets.only(right: cardGap),
                        child: _RelatedCard(
                          id: id,
                          title: title,
                          poster: poster,
                          rel: rel,
                          cardWidth: cardW,
                          cardHeight: cardH,
                          focusNode: fn,
                          onLeft: i > 0
                              ? () => _cardFns[i - 1].requestFocus()
                              : null,
                          onRight: i < _activeList.length - 1
                              ? () => _cardFns[i + 1].requestFocus()
                              : null,
                          onTap: id.isNotEmpty
                              ? () {
                                  final target =
                                      '/details/${widget.pluginId}/${Uri.encodeComponent(id)}';
                                  showDialog<void>(
                                    context: context,
                                    barrierColor: Colors.black54,
                                    builder: (_) => _RelatedDetailsPopup(
                                      pluginId: widget.pluginId,
                                      id: id,
                                      poster: poster,
                                      title: title,
                                      relLabel: _RelatedCard.relLabelOf(rel),
                                      onNavigate: () => context.push(target),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Anime metadata row ────────────────────────────────────────────────────────

class AnimeMetaRow extends StatelessWidget {
  final CatalogItem item;
  final SeriesDetails? series;
  const AnimeMetaRow({super.key, required this.item, this.series});

  @override
  Widget build(BuildContext context) {
    final d = series;
    final studio = d?.creators.isNotEmpty == true ? d!.creators.first : '';
    final episodes = item.extra['episodes'] ?? '';
    final status = item.extra['status'] ?? d?.status ?? '';
    final runtime = item.extra['runtime'] ?? d?.episodeRuntime ?? '';

    final chips = <Widget>[];
    if (studio.isNotEmpty) {
      chips.add(_InfoChip(icon: Icons.business_rounded, text: studio));
    }
    if (episodes.isNotEmpty) {
      chips.add(_InfoChip(
          icon: Icons.format_list_numbered_rounded, text: '$episodes ep.'));
    }
    if (runtime.isNotEmpty) {
      chips.add(_InfoChip(icon: Icons.schedule_rounded, text: runtime));
    }
    if (status.isNotEmpty) {
      chips.add(
          _InfoChip(icon: Icons.circle_outlined, text: _fmtStatus(status)));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 16, runSpacing: 8, children: chips);
  }

  static String _fmtStatus(String s) => switch (s) {
        'FINISHED' => 'Concluso',
        'RELEASING' => 'In corso',
        'NOT_YET_RELEASED' => 'Non ancora uscito',
        'CANCELLED' => 'Cancellato',
        'HIATUS' => 'In pausa',
        _ => s,
      };
}

// ── Series related carousel footer (thin wrapper that parses JSON) ───────────

class SeriesRelatedCarouselFooter extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  final FocusNode? firstFocusNode;
  final VoidCallback? onBack;
  // Caller provides explicit card height so the carousel doesn't need LayoutBuilder.
  final double cardHeight;

  const SeriesRelatedCarouselFooter({
    super.key,
    required this.pluginId,
    required this.item,
    required this.cardHeight,
    this.firstFocusNode,
    this.onBack,
  });

  @override
  State<SeriesRelatedCarouselFooter> createState() =>
      SeriesRelatedCarouselFooterState();
}

class SeriesRelatedCarouselFooterState
    extends State<SeriesRelatedCarouselFooter> {
  List<dynamic> _related = const [];
  List<dynamic> _similar = const [];

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(SeriesRelatedCarouselFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This widget is reconstructed on every season/episode navigation (its
    // parent rebuilds far more often than the underlying item actually
    // changes) — re-decoding the same JSON string on every one of those
    // rebuilds was pure waste. Only re-parse when related/similar actually
    // changed.
    if (oldWidget.item.extra['related'] != widget.item.extra['related'] ||
        oldWidget.item.extra['similar'] != widget.item.extra['similar']) {
      _decode();
    }
  }

  void _decode() {
    final relatedRaw = widget.item.extra['related'] ?? '';
    final similarRaw = widget.item.extra['similar'] ?? '';
    List<dynamic> related = [];
    List<dynamic> similar = [];
    try {
      related = jsonDecode(relatedRaw) as List;
    } catch (_) {}
    try {
      similar = jsonDecode(similarRaw) as List;
    } catch (_) {}
    _related = related;
    _similar = similar;
  }

  @override
  Widget build(BuildContext context) {
    if (_related.isEmpty && _similar.isEmpty) return const SizedBox.shrink();
    return _SeriesRelatedCarousel(
      pluginId: widget.pluginId,
      related: _related,
      similar: _similar,
      cardHeight: widget.cardHeight,
      firstFocusNode: widget.firstFocusNode,
      onBack: widget.onBack,
    );
  }
}

class _RelatedCard extends StatelessWidget {
  final String id;
  final String title;
  final String poster;
  final String rel;
  final VoidCallback? onTap;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final double cardWidth;
  final double cardHeight;
  final FocusNode? focusNode;
  const _RelatedCard({
    required this.id,
    required this.title,
    required this.poster,
    required this.rel,
    this.onTap,
    this.onLeft,
    this.onRight,
    this.cardWidth = 160.0,
    this.cardHeight = 240.0,
    this.focusNode,
  });

  double get _w => cardWidth;

  static String _relLabel(String r) => switch (r) {
        'SEQUEL' => 'Sequel',
        'PREQUEL' => 'Prequel',
        'SIDE_STORY' => 'Side story',
        'SPIN_OFF' => 'Spin-off',
        _ => '',
      };

  static String relLabelOf(String rel) => _relLabel(rel);
  String get _label => _relLabel(rel);

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return TvFocusable(
      focusNode: focusNode,
      onFocusChange: (v) {
        // Scroll the card into view when it gains focus — guarded + deferred
        // so it can't run Scrollable.maybeOf on a context whose viewport is
        // mid-teardown (framework.dart `_dependents.isEmpty` assert).
        if (!v || !context.mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Scrollable.ensureVisible(
            context,
            alignment: 0.1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      },
      onActivate: onTap,
      onLeft: onLeft,
      onRight: onRight,
      builder: (context, focused) => SizedBox(
        width: _w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Poster: exact 2:3 ratio; label badge overlaid in top-left corner
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: _w,
                  height: _w * 1.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: focused ? AppTheme.primary : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: focused
                        ? [
                            BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.45),
                                blurRadius: 16,
                                spreadRadius: 1)
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6.5),
                    child: poster.isNotEmpty
                        ? CachedNetworkImage(
                            // Web-only, no-op on every other platform — see image_sizing.dart's
                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                            // CachedNetworkImage call site in the app sets this.
                            imageRenderMethodForWeb:
                                ImageRenderMethodForWeb.HttpGet,
                            imageUrl:
                                posterSrc(poster, cacheWidthFor(context, _w)),
                            fit: BoxFit.cover,
                            memCacheWidth: cacheWidthFor(context, _w),
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (_, __) => const PosterSkeleton(),
                            errorWidget: (_, __, ___) =>
                                PlaceholderPoster(title: title),
                          )
                        : PlaceholderPoster(title: title),
                  ),
                ),
                if (_label.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: (_w - 12).clamp(0.0, double.infinity)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _label,
                          style: TextStyle(
                            color: AppTheme.textHigh,
                            fontSize: (sh * (11.3 / 1080.0)).clamp(8.6, 17.8),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textHigh,
                // Must match _SeriesRelatedCarousel's cardTitleFs exactly
                // (same clamp) — that's what reserves the strip's height.
                fontSize: (sh * (16.2 / 1080.0)).clamp(13.0, 26.0),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
