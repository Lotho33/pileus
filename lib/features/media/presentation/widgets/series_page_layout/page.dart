// Part of series_page_layout.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the _dmax helper and the public
// AnimeLayout / SeriesLayout entry points; private identifiers are shared
// across all parts.
part of '../series_page_layout.dart';

class _SeriesPageLayout extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  final List<SeasonInfo> seasons;
  final SeriesDetails? series;
  final bool isAnime;

  const _SeriesPageLayout({
    required this.pluginId,
    required this.item,
    required this.seasons,
    required this.series,
    required this.isAnime,
  });

  @override
  State<_SeriesPageLayout> createState() => _SeriesPageLayoutState();
}

class _SeriesPageLayoutState extends State<_SeriesPageLayout> {
  late final MediaRepository _repo;
  int _selectedIdx = 0;
  List<EpisodeInfo> _episodes = [];
  List<EpisodeInfo> _prevEpisodes = [];
  bool _loadingEpisodes = false;
  int _loadingToken = 0;

  // Dynamic — recomputed every build from the actual available height (see
  // build()) so the episode list always fits without the CustomScrollView
  // needing to actually scroll on a shorter window. 5 is only the pre-layout
  // default before the first frame measures anything.
  int _pageSize = 5;

  late List<FocusNode> _seasonFns;
  List<FocusNode> _epFns = [];
  // True while _focusEpisode (below) has a specific target tile it still
  // needs to focus after the window-shift setState it just triggered lands.
  // build()'s own "a page-size change disposed the focused node, put focus
  // somewhere sane" fallback runs in that same window and used to always
  // win the race — it schedules its postFrameCallback second, after
  // _focusEpisode's, so it fired second and silently snapped focus back to
  // the first tile of the new page no matter which specific tile
  // _focusEpisode was actually trying to land on (e.g. the last tile of the
  // previous page when navigating Up across a boundary). This flag lets
  // that fallback recognize a specific target is already being handled and
  // stand down instead of overriding it.
  bool _pendingSpecificEpisodeFocus = false;
  final _firstRelatedFn = FocusNode();
  final _seasonScrollCtrl = ScrollController();
  final _rightScrollCtrl = ScrollController();

  int _windowStart = 0;

  @override
  void initState() {
    super.initState();
    _repo = getIt<MediaRepository>();
    _seasonFns = List.generate(widget.seasons.length, (_) => FocusNode());
    if (widget.seasons.isNotEmpty) _loadSeason(0);
  }

  @override
  void dispose() {
    for (final n in _seasonFns) {
      n.dispose();
    }
    for (final n in _epFns) {
      n.dispose();
    }
    _firstRelatedFn.dispose();
    _seasonScrollCtrl.dispose();
    _rightScrollCtrl.dispose();
    _epHoldTimer?.cancel();
    super.dispose();
  }

  void _rebuildEpFns(int count) {
    for (final n in _epFns) {
      n.dispose();
    }
    _epFns = List.generate(count, (_) => FocusNode());
  }

  String get _posterUrl {
    if (widget.seasons.isNotEmpty) {
      final s = widget.seasons[_selectedIdx];
      if (s.posterUrl.isNotEmpty) return s.posterUrl;
    }
    return widget.item.posterUrl;
  }

  Future<void> _loadSeason(int idx) async {
    if (idx < 0 || idx >= widget.seasons.length) return;
    final token = ++_loadingToken;
    setState(() {
      _selectedIdx = idx;
      _loadingEpisodes = true;
      _prevEpisodes = _episodes;
    });
    try {
      final res = await _repo.browse(
          widget.pluginId, widget.seasons[idx].directoryId, '');
      if (mounted && token == _loadingToken) {
        final episodes = res.episodes.isNotEmpty
            ? res.episodes.toList()
            : res.items
                .map((e) => EpisodeInfo(
                      id: e.id,
                      title: e.title,
                      episodeNumber: e.episodeNumber,
                      seasonNumber: e.seasonNumber,
                    ))
                .toList();
        _rebuildEpFns(episodes.length);
        setState(() {
          _episodes = episodes;
          _prevEpisodes = [];
          _loadingEpisodes = false;
          _windowStart = 0;
        });
        // Focus first episode after rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _epFns.isNotEmpty) _epFns[0].requestFocus();
        });
      }
    } catch (_) {
      if (mounted && token == _loadingToken) {
        setState(() {
          _prevEpisodes = [];
          _loadingEpisodes = false;
        });
      }
    }
  }

  // Moves focus one episode tile from local window index [localIdx] in
  // direction [delta] (+1 down / -1 up). Single source for both a plain
  // keypress (via _EpisodeTileRow's onUp/onDown) and the hold-repeat paths,
  // which re-derive localIdx fresh from FocusNode.hasFocus every tick
  // instead of a value bound once when the hold started — that's what lets
  // a hold keep advancing tile-to-tile instead of re-targeting the same
  // neighbour forever.
  //
  // Interior moves and window-edge slides both fire freely and repeatedly:
  // they keep focus inside the episode list, so a hold or a burst of fast
  // presses just keeps travelling through it (an earlier time-based guard
  // here throttled every window-edge crossing to ~4/sec and silently
  // swallowed anything faster, which read as "up/down often does nothing").
  // Only the two transitions that actually LEAVE the list — off the end →
  // related/similar carousel, off the top → season pills — are suppressed
  // while a direction is held ([fromHold] true): otherwise a hold that runs
  // off the end of a short season cascades straight into the next section
  // in the same gesture. A deliberate discrete press still crosses.
  void _moveEpisode(int localIdx, int delta, {bool fromHold = false}) {
    final allEpisodes = _loadingEpisodes && _prevEpisodes.isNotEmpty
        ? _prevEpisodes
        : _episodes;
    final winStart =
        _windowStart.clamp(0, (allEpisodes.length - 1).clamp(0, 9999));
    final winEnd = (winStart + _pageSize).clamp(0, allEpisodes.length);
    final displayLen = winEnd - winStart;
    final hasRelated = (widget.item.extra['related'] ?? '').isNotEmpty ||
        (widget.item.extra['similar'] ?? '').isNotEmpty;

    if (delta > 0) {
      if (localIdx < displayLen - 1) {
        if (localIdx + 1 < _epFns.length) _epFns[localIdx + 1].requestFocus();
        return;
      }
      if (winEnd < allEpisodes.length) {
        _focusEpisode(winStart + _pageSize);
        return;
      }
      if (hasRelated && !fromHold) _firstRelatedFn.requestFocus();
      return;
    }

    if (localIdx > 0) {
      if (localIdx - 1 < _epFns.length) _epFns[localIdx - 1].requestFocus();
      return;
    }
    if (winStart > 0) {
      _focusEpisode(winStart - 1);
      return;
    }
    if (widget.seasons.length > 1 && !fromHold) {
      _seasonFns[_selectedIdx].requestFocus();
    }
  }

  // Hold-to-repeat for the episode list. This app's actual desktop/X11
  // target doesn't reliably repeat a held key at the framework level (a
  // hold shows up, if at all, as ordinary KeyDownEvents rather than
  // KeyRepeatEvent — see player_seek_bar.dart's own _holdTickInterval doc
  // for the same finding), so this drives its own timer instead of relying
  // on that. Lives on this State (not on any one tile) because it needs to
  // survive focus moving from tile to tile as the hold advances — a Timer
  // owned by the tile that was focused when the hold *started* would go
  // stale the instant focus left it. Each tick re-finds whichever tile is
  // *currently* focused via FocusNode.hasFocus (plain, guaranteed-public
  // API — no reliance on redispatching through the focus tree) and moves
  // one more step from there.
  Timer? _epHoldTimer;
  LogicalKeyboardKey? _epHeldKey;
  static const _epHoldInitialDelay = Duration(milliseconds: 380);
  static const _epHoldInterval = Duration(milliseconds: 110);

  void _onEpisodeHoldChanged(LogicalKeyboardKey key, bool isDown) {
    if (key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown) {
      return;
    }
    if (isDown) {
      _epHeldKey = key;
      _epHoldTimer?.cancel();
      _epHoldTimer = Timer(_epHoldInitialDelay, _epHoldTick);
    } else if (key == _epHeldKey) {
      _epHoldTimer?.cancel();
      _epHoldTimer = null;
      _epHeldKey = null;
    }
  }

  /// True while [key] is currently held down on some episode tile — lets a
  /// tile that receives an OS-repeat KeyDownEvent (some remotes send those
  /// instead of KeyRepeatEvent) tell it apart from a genuinely fresh press.
  bool _isEpisodeDirectionHeld(LogicalKeyboardKey key) => _epHeldKey == key;

  /// Native OS key-repeat is driving the hold directly (KeyRepeatEvent, or a
  /// repeated KeyDownEvent the tile recognised via [_isEpisodeDirectionHeld]).
  /// Cancel the software fallback timer so the two don't both advance, then
  /// step once as a held move — so it stops at the list's boundaries instead
  /// of spilling into the related carousel / season pills mid-hold.
  void _onEpisodeHeldMove(LogicalKeyboardKey key) {
    if (key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown) {
      return;
    }
    _epHoldTimer?.cancel();
    _epHoldTimer = null;
    final localIdx = _epFns.indexWhere((n) => n.hasFocus);
    if (localIdx == -1) return;
    _moveEpisode(localIdx, key == LogicalKeyboardKey.arrowDown ? 1 : -1,
        fromHold: true);
  }

  void _epHoldTick() {
    final key = _epHeldKey;
    if (key == null || !mounted) return;
    final localIdx = _epFns.indexWhere((n) => n.hasFocus);
    if (localIdx == -1) {
      // Focus left the episode list entirely (e.g. the hold already
      // carried it into related/season pills) — nothing left to repeat.
      _epHoldTimer = null;
      _epHeldKey = null;
      return;
    }
    _moveEpisode(localIdx, key == LogicalKeyboardKey.arrowDown ? 1 : -1,
        fromHold: true);
    _epHoldTimer = Timer(_epHoldInterval, _epHoldTick);
  }

  // Slide window so that episode [globalIdx] is visible, then focus it.
  void _focusEpisode(int globalIdx) {
    final all = _loadingEpisodes && _prevEpisodes.isNotEmpty
        ? _prevEpisodes
        : _episodes;
    final clamped = globalIdx.clamp(0, (all.length - 1).clamp(0, 9999));
    // Keep window start so that clamped is inside [windowStart, windowStart+_pageSize)
    int newStart = _windowStart;
    if (clamped < newStart) newStart = clamped;
    if (clamped >= newStart + _pageSize) newStart = clamped - _pageSize + 1;
    newStart = newStart.clamp(0, (all.length - _pageSize).clamp(0, 9999));
    _pendingSpecificEpisodeFocus = true;
    setState(() => _windowStart = newStart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingSpecificEpisodeFocus = false;
      if (!mounted) return;
      final localIdx = clamped - newStart;
      if (localIdx >= 0 && localIdx < _epFns.length) {
        _epFns[localIdx].requestFocus();
      }
    });
  }

  String _seasonLabel(int i) {
    final s = widget.seasons[i];
    if (s.label.isNotEmpty) return s.label;
    return s.number > 0 ? 'Stagione ${s.number}' : 'Gruppo ${i + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final sd = widget.series;
    final fanartUrl = (sd?.fanartUrl.isNotEmpty == true)
        ? sd!.fanartUrl
        : (item.extra['fanart_url'] ?? '');
    final bgUrl = fanartUrl.isNotEmpty ? fanartUrl : item.posterUrl;
    final seriesPlot = sd?.plot ?? '';
    final currentSeasonPlot =
        widget.seasons.isNotEmpty ? widget.seasons[_selectedIdx].overview : '';

    final allEpisodes = _loadingEpisodes && _prevEpisodes.isNotEmpty
        ? _prevEpisodes
        : _episodes;

    // Visible window: _pageSize episodes starting at _windowStart
    final winStart =
        _windowStart.clamp(0, (allEpisodes.length - 1).clamp(0, 9999));
    final winEnd = (winStart + _pageSize).clamp(0, allEpisodes.length);
    final displayEpisodes = allEpisodes.isNotEmpty
        ? allEpisodes.sublist(winStart, winEnd)
        : <EpisodeInfo>[];

    // Ensure we have the right number of focus nodes (no-op if count unchanged)
    if (_epFns.length != displayEpisodes.length) {
      // _rebuildEpFns disposes the old nodes outright — if one of them
      // currently holds focus (this branch can fire mid-session, e.g. when
      // _pageSize gets corrected after first layout measurement), disposing
      // it without requesting focus elsewhere leaves the D-pad dead. Same
      // fix as _loadSeason's own rebuild path below (requestFocus in a
      // postFrameCallback, since the new nodes don't exist until the
      // rebuild triggered by this build() pass actually completes).
      final hadFocus = anyHasFocus(_epFns);
      _rebuildEpFns(displayEpisodes.length);
      // Skip this generic fallback when _focusEpisode is already mid-flight
      // for this exact rebuild — its own postFrameCallback (scheduled
      // before this build() call ever ran) knows the specific tile to
      // land on; this one only knows "focus was somewhere in here" and
      // would otherwise always win the race and override it with tile 0.
      if (hadFocus && !_pendingSpecificEpisodeFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _epFns.isNotEmpty) _epFns[0].requestFocus();
        });
      }
    }

    final allEpisodeIds = allEpisodes.map((e) => e.id).toList();
    final allEpisodeTitles = allEpisodes.map((e) => e.title).toList();
    final allSeasonIds = widget.seasons.map((s) => s.directoryId).toList();
    final allSeasonLabels = widget.seasons.map((s) => s.label).toList();

    final hasRelated = (widget.item.extra['related'] ?? '').isNotEmpty ||
        (widget.item.extra['similar'] ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background fanart ──────────────────────────────────────────
          if (bgUrl.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: backdropSrc(bgUrl, backdropCacheWidth(context)),
                fit: BoxFit.cover,
                memCacheWidth: backdropCacheWidth(context),
                fadeInDuration: Duration.zero,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55000000),
                    Color(0xBB000000),
                    Color(0xFF000000)
                  ],
                  stops: [0.0, 0.30, 0.65],
                ),
              ),
            ),
          ),

          // ── Fixed two-column layout ────────────────────────────────────
          Column(
            children: [
              // Back button row
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 24, 40, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DetailsBackButton(onTap: () => context.pop()),
                ),
              ),

              // Main content — fills remaining height
              Expanded(
                child: LayoutBuilder(builder: (context, bc) {
                  final w = bc.maxWidth;
                  final h = bc.maxHeight;
                  final hPad = AppScale.catalogHPadRatio(w);
                  final posterWBase = w * detailsPosterWRatio;
                  final infoW = w * detailsInfoWRatio;
                  final gap = w * detailsGapRatio;
                  final tileH = h * detailsEpisodeTileHRatio;
                  final sh = MediaQuery.sizeOf(context).height;
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  // Must stay numerically consistent with _SeasonPillState's own
                  // pillFs/vPad formulas (same sh basis) — otherwise this fixed
                  // row height clips the pill text top/bottom instead of fitting
                  // it. The extra 1.1x matches the selected-pill font bump there
                  // (the tallest case), the 1.35x covers real line-height (~1.2x
                  // a font's point size) plus the ambient text scaler main.dart
                  // applies on desktop, with a little headroom rather than an
                  // exact match.
                  final pillsH = (sh * (10.0 / 1080.0)).clamp(6.0, 20.0) * 2 +
                      (sh * (18.0 / 1080.0)).clamp(12.0, 36.0) *
                          1.1 *
                          textScale *
                          1.35;
                  // Was .clamp(230.0, 400.0) — a floor/ceiling in *fixed*
                  // pixels, independent of h. On a device where h (this
                  // LayoutBuilder's actual local height budget) comes in
                  // smaller than the 1080p baseline this was tuned against,
                  // that 230px floor alone could eat most or all of h,
                  // squeezing mainH (the poster+episodes area above it,
                  // see below) down to almost nothing — "the footer is
                  // enormous and compresses everything else". Bounding it
                  // to a share of h itself instead guarantees mainH always
                  // keeps at least half the available height, however
                  // small h actually is.
                  final footerH =
                      hasRelated ? (h * 0.40).clamp(0.0, h * 0.5) : 0.0;
                  final mainH = h - footerH;
                  // Derived from footerH itself now, not a separate sh-based
                  // subtraction — that used to let cardH stay at its 120px
                  // floor even once footerH had shrunk well below what that
                  // floor needs, overflowing past the footer's own actual
                  // height.
                  final cardH =
                      hasRelated ? (footerH * 0.86).clamp(76.0, 330.0) : 0.0;
                  // Without a footer, mainH grows to fill h but the poster
                  // (fixed 2:3 aspect off posterWBase) stayed the same size,
                  // leaving dead space below it — let it grow toward mainH's
                  // height instead, capped at +30% so it doesn't crowd out
                  // the info/episode columns next to it. No other column
                  // needs rebalancing: the episode column is Expanded and
                  // simply absorbs whatever width this leaves it.
                  final posterW = hasRelated
                      ? posterWBase
                      : (mainH / 1.5).clamp(posterWBase, posterWBase * 1.3);
                  // See the analogous _MovieLayout definition for why this is
                  // anchored to 1080p (s==1.15 there) instead of 540p, now
                  // shared via AppScale.contentScale. Bumped further when
                  // there's no footer, for the same reason as the poster
                  // above — more room to spend on the text block. Was
                  // missing the ambient-textScaler division
                  // details_screen.dart has (2026-09 audit) — on desktop/web
                  // this text was exposed to main.dart's ~1.35× readability
                  // boost stacking on top of the already-inflated `s`.
                  final s = AppScale.contentScale(context,
                      hasFooter: hasRelated, floor: 0.7);
                  // Fixed at 5 whenever the related/similar footer is shown
                  // — that's the common case, and a constant page size keeps
                  // the episode list identical across every resolution
                  // instead of drifting with how much fixed-pixel chrome
                  // (season pills, header) happens to eat into the
                  // proportional space at a given height. The CustomScrollView
                  // below already scrolls, so a very short window just
                  // scrolls to see the 5th tile instead of shrinking the count.
                  // Without the footer there's extra vertical room to spend,
                  // so that case keeps the old "fit as many as actually fit"
                  // math (mirrors pillsH's own row-height estimate — icon bar
                  // vs text line height, whichever is taller — plus the
                  // Column's own spacers (10 under the pills, 8 under the
                  // header) and the Padding this whole area sits in
                  // (detailsVPadRatio top, 16 fixed bottom)).
                  final pillsBlockH =
                      widget.seasons.length > 1 ? pillsH + 10.0 : 0.0;
                  final headerRowH = (sh * (20.0 / 1080.0) * 1.3 * textScale)
                          .clamp(22.0, double.infinity) +
                      8.0;
                  final rowPadding = h * detailsVPadRatio + 16.0;
                  final availForTiles =
                      (mainH - rowPadding - pillsBlockH - headerRowH)
                          .clamp(0.0, double.infinity);
                  // Always 5 episodes on screen — the season pills + header
                  // eat different amounts of fixed-pixel space at different
                  // resolutions / text scales, and the tiles were being
                  // hard-clipped (Column overflow) when pills were present.
                  // Shrink the tile height instead so 5 always physically
                  // fit, with or without pills, at any resolution.
                  const targetEpisodes = 5;
                  const computedPageSize = targetEpisodes;
                  // Floor guarded: on a very short layout box `tileH` itself
                  // can be below 40, and `clamp(lo, hi)` throws when lo > hi
                  // (that ArgumentError was the blank page when season pills
                  // squeezed the height).
                  final tileFloor = tileH < 40.0 ? tileH : 40.0;
                  final tileHFit = availForTiles > 0
                      ? (availForTiles / targetEpisodes).clamp(tileFloor, tileH)
                      : tileH;
                  // winStart/winEnd/displayEpisodes above are already computed
                  // for this frame using the OLD _pageSize (they run before
                  // this LayoutBuilder measures anything) — updating the field
                  // directly here wouldn't reach them until some later,
                  // unrelated rebuild. Scheduling a setState instead forces an
                  // immediate follow-up build that recomputes them with the
                  // right value — same "measure now, correct next frame"
                  // pattern already used for _selectedPlugin in home_screen.dart.
                  if (computedPageSize != _pageSize) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _pageSize = computedPageSize);
                    });
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: mainH,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, h * detailsVPadRatio, hPad, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── POSTER COLUMN ──────────────────────────────────
                              SizedBox(
                                width: posterW,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    switchInCurve: AppScale.fadeCurve,
                                    switchOutCurve: AppScale.fadeCurve,
                                    child: _SeasonPosterPanel(
                                      key: ValueKey(_posterUrl),
                                      posterUrl: _posterUrl,
                                      title: item.title,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(width: gap),

                              // ── INFO + PLOT COLUMN ─────────────────────────────
                              SizedBox(
                                width: infoW,
                                // Plain Column, not a SingleChildScrollView —
                                // the Row above stretches this SizedBox to
                                // exactly the available height, and the plot
                                // below is Flexible(loose) so it takes
                                // whatever's left after everything else here,
                                // instead of a fixed/guessed cap. A Flex
                                // child can't sit inside an unbounded-height
                                // ancestor (which is what a
                                // SingleChildScrollView gives its child), so
                                // this can't be scrollable itself anymore —
                                // everything above the plot already has its
                                // own bounds (maxLines/.take(n)), so it isn't
                                // expected to need one.
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          color: AppTheme.textHigh,
                                          fontSize: 38 * s,
                                          fontWeight: FontWeight.w800,
                                          height: 1.1,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 6 * s),
                                      if (widget.seasons.isNotEmpty)
                                        Text(
                                          _episodes.isNotEmpty
                                              ? '${_seasonLabel(_selectedIdx)}  ·  ${_episodes.length} ep.'
                                              : _seasonLabel(_selectedIdx),
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 18 * s,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      SizedBox(height: 6 * s),
                                      _SeasonRatingRow(
                                        item: item,
                                        contentRating: sd?.contentRating ?? '',
                                        seasonAirDate: widget.seasons.isNotEmpty
                                            ? widget
                                                .seasons[_selectedIdx].airDate
                                            : '',
                                      ),
                                      SizedBox(height: 8 * s),
                                      if (sd != null &&
                                          sd.genres.isNotEmpty) ...[
                                        Wrap(
                                          spacing: 5,
                                          runSpacing: 5,
                                          children: sd.genres
                                              .take(3)
                                              .map((g) => Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 10 * s,
                                                            vertical: 4 * s),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.textHigh
                                                          .withValues(
                                                              alpha: 0.08),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                          color:
                                                              Colors.white24),
                                                    ),
                                                    child: Text(g,
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white60,
                                                            fontSize: 15 * s,
                                                            letterSpacing:
                                                                0.2)),
                                                  ))
                                              .toList(),
                                        ),
                                        SizedBox(height: 8 * s),
                                      ],
                                      if (widget.seasons.length > 1)
                                        Text(
                                          'Stagione ${widget.seasons[_selectedIdx].number} di ${widget.seasons.length}',
                                          style: TextStyle(
                                              color: AppTheme.textLow,
                                              fontSize: 15 * s),
                                        ),
                                      if (widget.isAnime) ...[
                                        SizedBox(height: 6 * s),
                                        AnimeMetaRow(
                                            item: item, series: widget.series),
                                      ],
                                      if (!widget.isAnime && sd != null) ...[
                                        SizedBox(height: 6 * s),
                                        Wrap(
                                            spacing: 6,
                                            runSpacing: 5,
                                            children: [
                                              if (sd.episodeRuntime.isNotEmpty)
                                                _InfoChip(
                                                    icon:
                                                        Icons.schedule_rounded,
                                                    text: sd.episodeRuntime),
                                              if (sd.network.isNotEmpty)
                                                _InfoChip(
                                                    icon: Icons.tv_rounded,
                                                    text: sd.network),
                                              if (sd.status.isNotEmpty)
                                                _InfoChip(
                                                    icon: Icons.circle_outlined,
                                                    text:
                                                        _fmtStatus(sd.status)),
                                            ]),
                                      ],
                                      if (seriesPlot.isNotEmpty ||
                                          currentSeasonPlot.isNotEmpty) ...[
                                        SizedBox(height: 10 * s),
                                        Flexible(
                                          fit: FlexFit.loose,
                                          child: FocusableScrollTarget(
                                            maxHeightOverride: double.infinity,
                                            child: Text(
                                              currentSeasonPlot.isNotEmpty
                                                  ? currentSeasonPlot
                                                  : seriesPlot,
                                              style: TextStyle(
                                                color: const Color(0xA0FFFFFF),
                                                fontSize: 16 * s,
                                                height: 1.55,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ]),
                              ),

                              SizedBox(width: gap),

                              // ── EPISODES COLUMN ────────────────────────────────
                              Expanded(
                                child: CustomScrollView(
                                  controller: _rightScrollCtrl,
                                  slivers: [
                                    // Season pills
                                    if (widget.seasons.length > 1)
                                      SliverToBoxAdapter(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              height: pillsH,
                                              child: ListView.separated(
                                                controller: _seasonScrollCtrl,
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount:
                                                    widget.seasons.length,
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(width: 8),
                                                itemBuilder: (_, i) =>
                                                    _SeasonPill(
                                                  label: _seasonLabel(i),
                                                  selected: i == _selectedIdx,
                                                  focusNode: _seasonFns[i],
                                                  autofocus: i == 0,
                                                  onTap: () => _loadSeason(i),
                                                  onLeft: i > 0
                                                      ? () => _seasonFns[i - 1]
                                                          .requestFocus()
                                                      : null,
                                                  onRight: i <
                                                          widget.seasons
                                                                  .length -
                                                              1
                                                      ? () => _seasonFns[i + 1]
                                                          .requestFocus()
                                                      : null,
                                                  // Direct, synchronous requestFocus() — not wrapped in
                                                  // addPostFrameCallback, which doesn't by itself schedule a
                                                  // frame (see the episode↔related tiles below, which rely on
                                                  // this same direct call). _epFns is already populated by the
                                                  // time the season pills are visible/focusable.
                                                  onDown: () {
                                                    if (mounted &&
                                                        _epFns.isNotEmpty) {
                                                      _epFns[0].requestFocus();
                                                    }
                                                  },
                                                  onFocused: () {
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback(
                                                            (_) {
                                                      final ctx =
                                                          _seasonFns[i].context;
                                                      if (mounted &&
                                                          ctx != null) {
                                                        // Left-anchored on every navigation step, same
                                                        // spirit as the home screen carousels — not just
                                                        // centered-while-browsing, on-select-snap-left.
                                                        Scrollable.ensureVisible(
                                                            ctx,
                                                            alignment: 0.0,
                                                            duration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        200),
                                                            curve: Curves
                                                                .easeInOut);
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      ),

                                    // Episode header
                                    SliverToBoxAdapter(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 3,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                widget.seasons.length == 1
                                                    ? _seasonLabel(0)
                                                    : 'Episodi',
                                                style: TextStyle(
                                                  color: AppTheme.textHigh,
                                                  fontSize:
                                                      sh * (20.0 / 1080.0),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (allEpisodes.length >
                                                  _pageSize) ...[
                                                SizedBox(
                                                    width:
                                                        sh * (12.0 / 1080.0)),
                                                Text(
                                                  '${winStart + 1}–$winEnd / ${allEpisodes.length}',
                                                  style: TextStyle(
                                                      color: AppTheme.textLow,
                                                      fontSize:
                                                          sh * (15.0 / 1080.0)),
                                                ),
                                              ],
                                              if (_loadingEpisodes) ...[
                                                const SizedBox(width: 12),
                                                const PileusSpinner(
                                                    size: 14,
                                                    color: AppTheme.textLow),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),

                                    // Episode list — sliding window of _pageSize tiles
                                    SliverToBoxAdapter(
                                      child: AnimatedOpacity(
                                        opacity: _loadingEpisodes ? 0.45 : 1.0,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: displayEpisodes.isEmpty
                                            ? Align(
                                                alignment: Alignment.topLeft,
                                                child: Text(
                                                    'Nessun episodio disponibile.',
                                                    style: TextStyle(
                                                        color: AppTheme.textLow,
                                                        fontSize: sh *
                                                            (16.0 / 1080.0))),
                                              )
                                            : Builder(builder: (context) {
                                                // Whether a related/similar panel can be opened at the bottom.
                                                final hasRelated = (widget
                                                                    .item.extra[
                                                                'related'] ??
                                                            '')
                                                        .isNotEmpty ||
                                                    (widget.item.extra[
                                                                'similar'] ??
                                                            '')
                                                        .isNotEmpty;
                                                return Column(
                                                  children: [
                                                    for (int i = 0;
                                                        i <
                                                            displayEpisodes
                                                                .length;
                                                        i++)
                                                      SizedBox(
                                                        height: tileHFit,
                                                        child: _EpisodeTileRow(
                                                          pluginId:
                                                              widget.pluginId,
                                                          item: displayEpisodes[
                                                              i],
                                                          allEpisodeIds:
                                                              allEpisodeIds,
                                                          allEpisodeTitles:
                                                              allEpisodeTitles,
                                                          episodeIndex:
                                                              winStart + i,
                                                          allSeasonIds:
                                                              allSeasonIds,
                                                          allSeasonLabels:
                                                              allSeasonLabels,
                                                          seasonIndex:
                                                              _selectedIdx,
                                                          autofocus: i == 0 &&
                                                              !_loadingEpisodes,
                                                          focusNode:
                                                              _epFns.length > i
                                                                  ? _epFns[i]
                                                                  : null,
                                                          seriesPosterUrl:
                                                              _posterUrl,
                                                          parentId:
                                                              widget.item.id,
                                                          seriesTitle:
                                                              widget.item.title,
                                                          seriesPlot: (widget
                                                                      .series
                                                                      ?.plot
                                                                      .isNotEmpty ??
                                                                  false)
                                                              ? widget
                                                                  .series!.plot
                                                              : (widget.item
                                                                          .extra[
                                                                      'plot'] ??
                                                                  ''),
                                                          seriesRating: widget
                                                              .item.rating,
                                                          seriesYear: (widget
                                                                          .series
                                                                          ?.year ??
                                                                      0) >
                                                                  0
                                                              ? widget
                                                                  .series!.year
                                                              : widget
                                                                  .item.year,
                                                          seriesGenres: widget
                                                                  .series
                                                                  ?.genres
                                                                  .toList() ??
                                                              const <String>[],
                                                          onRight: hasRelated
                                                              ? () => _firstRelatedFn
                                                                  .requestFocus()
                                                              : null,
                                                          // Explicit onDown/onUp for every tile — prevents key
                                                          // from escaping to the CustomScrollView or a parent
                                                          // widget. Logic lives in _moveEpisode (single source
                                                          // shared with the hold-repeat timer below).
                                                          onDown: () =>
                                                              _moveEpisode(
                                                                  i, 1),
                                                          onUp: () =>
                                                              _moveEpisode(
                                                                  i, -1),
                                                          onHoldChanged:
                                                              _onEpisodeHoldChanged,
                                                          isDirectionHeld:
                                                              _isEpisodeDirectionHeld,
                                                          onHeldMove:
                                                              _onEpisodeHeldMove,
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ), // closes Padding
                      ), // closes SizedBox(height: mainH)
                      if (hasRelated)
                        SizedBox(
                          height: footerH,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
                            child: SeriesRelatedCarouselFooter(
                              pluginId: widget.pluginId,
                              item: widget.item,
                              cardHeight: cardH,
                              firstFocusNode: _firstRelatedFn,
                              onBack: () {
                                if (_epFns.isNotEmpty) {
                                  _epFns[_epFns.length - 1].requestFocus();
                                }
                              },
                            ),
                          ),
                        ),
                    ], // closes Column.children
                  ); // closes Column
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtStatus(String s) => switch (s) {
        'Returning Series' => 'In corso',
        'Ended' => 'Conclusa',
        'Canceled' => 'Cancellata',
        'In Production' => 'In produzione',
        'FINISHED' => 'Concluso',
        'RELEASING' => 'In corso',
        'CANCELLED' => 'Cancellato',
        'HIATUS' => 'In pausa',
        _ => s,
      };
}

