// Part of series_page_layout.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the _dmax helper and the public
// AnimeLayout / SeriesLayout entry points; private identifiers are shared
// across all parts.
part of '../series_page_layout.dart';

// ── Episode tile row ──────────────────────────────────────────────────────────

class _EpisodeTileRow extends StatefulWidget {
  final String pluginId;
  final EpisodeInfo item;
  final List<String> allEpisodeIds;
  final List<String> allEpisodeTitles;
  final List<String> allEpisodeThumbs;
  // Parallel to allEpisodeIds — the real "S{x} · E{y}" numbers, not list
  // position. See PlaybackArgs.episodeNumbers/seasonNumbers.
  final List<int> allEpisodeNumbers;
  final List<int> allSeasonNumbers;
  final int episodeIndex;
  final List<String> allSeasonIds;
  final List<String> allSeasonLabels;
  final int seasonIndex;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onRight;
  final VoidCallback? onDown;
  final VoidCallback? onUp;
  final String seriesPosterUrl;
  // Series' own horizontal extra['cover_url'] — see page.dart and
  // episode_poster.dart's posterForEpisode().
  final String seriesCoverUrl;
  final String parentId;
  // Series title — sent to the player as showTitle so the continue-watching
  // card shows the series, not "Episodio 5".
  final String seriesTitle;
  // Series-level metadata, threaded into the player's progress save so the
  // continue-watching card and its hero have plot / rating / year / genres
  // to show — the episode play path is the only one that stores a CW row
  // for a series, and none of this is on EpisodeInfo.
  final String seriesPlot;
  final double seriesRating;
  final int seriesYear;
  final List<String> seriesGenres;
  // Fired on KeyDownEvent (isDown: true) / KeyUpEvent (isDown: false) for
  // arrowUp/arrowDown — lets the parent (which owns the episode index/window
  // state and never gets disposed as focus moves tile-to-tile, unlike this
  // row) run its own software repeat timer as a fallback on platforms whose
  // held keys don't fire KeyRepeatEvent. See
  // _SeriesPageLayoutState._onEpisodeHoldChanged.
  final void Function(LogicalKeyboardKey key, bool isDown)? onHoldChanged;
  // Asks the parent whether [key] is already held (a repeat), so an
  // OS-repeat KeyDownEvent isn't mistaken for a fresh press.
  final bool Function(LogicalKeyboardKey key)? isDirectionHeld;
  // One held-repeat step (KeyRepeatEvent, or a KeyDownEvent the parent
  // reports as already-held) — advances but never crosses out of the list.
  final void Function(LogicalKeyboardKey key)? onHeldMove;
  const _EpisodeTileRow({
    required this.pluginId,
    required this.item,
    this.allEpisodeIds = const [],
    this.allEpisodeTitles = const [],
    this.allEpisodeThumbs = const [],
    this.allEpisodeNumbers = const [],
    this.allSeasonNumbers = const [],
    this.episodeIndex = -1,
    this.allSeasonIds = const [],
    this.allSeasonLabels = const [],
    this.seasonIndex = 0,
    this.autofocus = false,
    this.focusNode,
    this.onRight,
    this.onDown,
    this.onUp,
    this.onHoldChanged,
    this.isDirectionHeld,
    this.onHeldMove,
    this.seriesPosterUrl = '',
    this.seriesCoverUrl = '',
    this.parentId = '',
    this.seriesTitle = '',
    this.seriesPlot = '',
    this.seriesRating = 0.0,
    this.seriesYear = 0,
    this.seriesGenres = const [],
  });

  @override
  State<_EpisodeTileRow> createState() => _EpisodeTileRowState();
}

class _EpisodeTileRowState extends State<_EpisodeTileRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final epNum = item.episodeNumber > 0 ? item.episodeNumber : null;

    // Use LayoutBuilder so fonts are additionally clamped to the tile's actual
    // height — prevents the "A RenderFlex overflowed by N pixels" error.
    return LayoutBuilder(builder: (context, bc) {
      final sh = MediaQuery.sizeOf(context).height;
      // Vertical space available for text after margin(3+3) and padding(6+6).
      final availH = (bc.maxHeight - 18).clamp(12.0, 1000.0);

      // Scale with screen height, but never exceed what fits in availH. The
      // _dmax floors on the upper bound matter on a genuinely cramped tile
      // (a real device reporting less height here than this layout was
      // tuned against) — num.clamp(lower, upper) throws ArgumentError
      // outright if upper ends up below lower (e.g. availH * 0.32 dropping
      // under 9.0), which crashed this tile's entire build every frame
      // instead of just rendering it small. Plain math.max(12.0, availH *
      // 0.52) here made Dart infer the whole clamp chain as num instead of
      // double (generic type inference through the nested .clamp() context
      // widened it) — _dmax is double-typed on both ends, so it can't do
      // that.
      final epTitleFs = ((sh * (28.0 / 1080.0)).clamp(12.0, 56.0))
          .clamp(12.0, _dmax(12.0, availH * 0.52));
      final epDurFs = ((sh * (17.0 / 1080.0)).clamp(9.0, 34.0))
          .clamp(9.0, _dmax(9.0, availH * 0.32));
      final epNumFs = ((sh * (38.0 / 1080.0)).clamp(14.0, 76.0))
          .clamp(14.0, _dmax(14.0, availH * 0.70));
      final epNumW = (sh * (72.0 / 1080.0)).clamp(40.0, 144.0);

      void openPopup() {
        perf('episode_tile_row: openPopup '
            '${widget.pluginId}/${widget.item.id}');
        showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.75),
          builder: (_) => _EpisodePopup(
            pluginId: widget.pluginId,
            item: widget.item,
            allEpisodeIds: widget.allEpisodeIds,
            allEpisodeTitles: widget.allEpisodeTitles,
            allEpisodeThumbs: widget.allEpisodeThumbs,
            allEpisodeNumbers: widget.allEpisodeNumbers,
            allSeasonNumbers: widget.allSeasonNumbers,
            episodeIndex: widget.episodeIndex,
            allSeasonIds: widget.allSeasonIds,
            allSeasonLabels: widget.allSeasonLabels,
            seasonIndex: widget.seasonIndex,
            seriesPosterUrl: widget.seriesPosterUrl,
            seriesCoverUrl: widget.seriesCoverUrl,
            parentId: widget.parentId,
            seriesTitle: widget.seriesTitle,
            seriesPlot: widget.seriesPlot,
            seriesRating: widget.seriesRating,
            seriesYear: widget.seriesYear,
            seriesGenres: widget.seriesGenres,
          ),
        );
      }

      final focused = _focused;
      // A raw Focus rather than the shared TvFocusable — this needs to
      // report KeyUpEvent too (via onHoldChanged), which TvFocusable
      // deliberately doesn't expose (see its own doc: activation/back stay
      // KeyDownEvent-only for its ~106 other call sites, none of which
      // need hold-tracking).
      return Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter) {
              openPopup();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowRight) {
              if (widget.onRight == null) return KeyEventResult.ignored;
              widget.onRight!();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.arrowUp) {
              final cb = key == LogicalKeyboardKey.arrowDown
                  ? widget.onDown
                  : widget.onUp;
              if (cb == null) return KeyEventResult.ignored;
              // A held key that repeats as KeyDownEvent (rather than
              // KeyRepeatEvent) on this platform: the parent already has it
              // flagged as held → treat as a repeat step, not a fresh press,
              // so it can't cross out of the list.
              final held = widget.isDirectionHeld?.call(key) ?? false;
              widget.onHoldChanged?.call(key, true);
              if (held) {
                widget.onHeldMove?.call(key);
              } else {
                cb();
              }
              return KeyEventResult.handled;
            }
          } else if (event is KeyRepeatEvent) {
            // Native OS key-repeat (Android TV / Fire TV remotes deliver
            // these; the X11 desktop target does not — which is why the
            // parent keeps a software fallback timer). Drive one held step
            // and consume it, so a held Up/Down never reaches Flutter's
            // default directional traversal — which would otherwise walk
            // focus straight out of the episode list into the related
            // carousel below or the season pills above mid-hold. Held steps
            // stop dead at the list's boundaries.
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.arrowUp) {
              widget.onHeldMove?.call(key);
              return KeyEventResult.handled;
            }
          } else if (event is KeyUpEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.arrowUp) {
              widget.onHoldChanged?.call(key, false);
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: openPopup,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: focused
                  ? AppTheme.primary.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: focused ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: epNumW,
                  child: Text(
                    epNum != null ? '$epNum' : '—',
                    style: TextStyle(
                      color: focused ? AppTheme.textHigh : AppTheme.textLow,
                      fontSize: epNum != null && epNum >= 100
                          ? (epNumFs * 0.65).clamp(12.0, 22.0)
                          : epNumFs,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item.title.isNotEmpty)
                        Text(
                          item.title,
                          style: TextStyle(
                            color: focused
                                ? AppTheme.textHigh
                                : AppTheme.textHigh.withValues(alpha: 0.85),
                            fontSize: epTitleFs,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (item.duration > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${item.duration} min',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: epDurFs,
                                height: 1.0),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: focused ? AppTheme.textHigh : AppTheme.textLow,
                  size: (epTitleFs * 1.3).clamp(18.0, 30.0),
                ),
              ],
            ),
          ),
        ),
      );
    }); // end LayoutBuilder
  }
}
