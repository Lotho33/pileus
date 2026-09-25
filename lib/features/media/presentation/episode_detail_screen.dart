import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/utils/image_sizing.dart';
import '../../../shared/widgets/error_retry_view.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../data/media_repository.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

class EpisodeDetailScreen extends StatefulWidget {
  final String pluginId;
  final String mediaId;
  final List<String> episodeList;
  final List<String> episodeTitles;
  final int episodeIndex;
  final List<String> allSeasonIds;
  final List<String> allSeasonLabels;
  final int seasonIndex;
  // Show/season name — not part of EpisodeDetails, threaded down from
  // BrowseScreen (the season screen, which already knows it) so it can ride
  // along into continue-watching metadata. See MediaRepository.postProgress.
  final String showTitle;
  // Per-episode thumbnails parallel to episodeList, threaded through from
  // whichever screen already resolved them (currently only the season
  // crossover detour, view.dart/mobile_playback_screen.dart) so the
  // continue-watching cover keeps rotating across a manual source pick
  // instead of getting stuck. See posterForEpisode().
  final List<String> episodeThumbs;
  // Parallel to episodeList — the real "S{x} · E{y}" numbers, not list
  // position. Same threading as episodeThumbs above.
  final List<int> episodeNumbers;
  final List<int> seasonNumbers;

  const EpisodeDetailScreen({
    super.key,
    required this.pluginId,
    required this.mediaId,
    this.episodeList = const [],
    this.episodeTitles = const [],
    this.episodeIndex = -1,
    this.allSeasonIds = const [],
    this.allSeasonLabels = const [],
    this.seasonIndex = 0,
    this.showTitle = '',
    this.episodeThumbs = const [],
    this.episodeNumbers = const [],
    this.seasonNumbers = const [],
  });

  @override
  State<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends State<EpisodeDetailScreen> {
  late final MediaRepository _repo;
  CatalogItem? _item;
  String _plot = '';
  double _rating = 0.0;
  int _durationSeconds = 0;
  List<String> _genres = const [];
  // Series-level plot/poster — continue-watching must always store the
  // series' own plot/poster, never the episode's (a CW card must read the
  // same regardless of which episode is playing). Fetched alongside genres
  // via the same getDetails(showId) call below.
  String _seriesPlot = '';
  String _seriesPosterUrl = '';
  // Series' own horizontal extra['cover_url'] — see episode_poster.dart's
  // posterForEpisode() (tried before _seriesPosterUrl above).
  String _seriesCoverUrl = '';
  List<StreamSource> _sources = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = getIt<MediaRepository>();
    _load();
  }

  Future<void> _load() async {
    try {
      final detailsRes =
          await _repo.getDetails(widget.pluginId, widget.mediaId);
      final streamsRes =
          await _repo.getStreams(widget.pluginId, widget.mediaId);
      if (mounted) {
        setState(() {
          _item = detailsRes.item;
          final ep = detailsRes.hasEpisode() ? detailsRes.episode : null;
          _plot = ep?.plot ?? '';
          _rating = ep?.vote ?? 0.0;
          _durationSeconds =
              (ep?.duration ?? 0) * 60; // EpisodeDetails.duration is minutes
          _sources = streamsRes.sources;
          _loading = false;
        });
      }
      // Episode's own details never carry genres/series-level plot/poster —
      // those live on the parent show. Non-blocking: continue-watching
      // metadata doesn't need to hold up the loading spinner, so this fills
      // in after the fact.
      _fetchShowMeta(detailsRes.item.showId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchShowMeta(String showId) async {
    if (showId.isEmpty) return;
    try {
      final res = await _repo.getDetails(widget.pluginId, showId);
      if (mounted && res.hasSeries()) {
        setState(() {
          _genres = res.series.genres;
          _seriesPlot = res.series.plot;
          _seriesPosterUrl = res.item.posterUrl;
          _seriesCoverUrl = res.item.extra['cover_url'] ?? '';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => context.pop(),
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: _error != null
            ? ErrorRetryView(
                message: 'Impossibile caricare l\'episodio.',
                detail: _error,
                onRetry: () {
                  setState(() {
                    _error = null;
                    _loading = true;
                  });
                  _load();
                },
                onSecondary: () => context.pop(),
                secondaryLabel: 'Indietro',
              )
            : PileusLoadingSwitcher(
                isLoading: _loading,
                spinnerSize: AppScale.spinnerL(context),
                child: _item == null
                    ? const SizedBox.shrink()
                    : _EpisodeBody(
                        pluginId: widget.pluginId,
                        item: _item!,
                        plot: _plot,
                        rating: _rating,
                        durationSeconds: _durationSeconds,
                        genres: _genres,
                        showTitle: widget.showTitle,
                        sources: _sources,
                        episodeList: widget.episodeList,
                        episodeTitles: widget.episodeTitles,
                        episodeThumbs: widget.episodeThumbs,
                        episodeNumbers: widget.episodeNumbers,
                        seasonNumbers: widget.seasonNumbers,
                        episodeIndex: widget.episodeIndex,
                        allSeasonIds: widget.allSeasonIds,
                        allSeasonLabels: widget.allSeasonLabels,
                        seasonIndex: widget.seasonIndex,
                        seriesPlot: _seriesPlot,
                        seriesPosterUrl: _seriesPosterUrl,
                        seriesCoverUrl: _seriesCoverUrl,
                      ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeBody extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  final String plot;
  final double rating;
  final int durationSeconds;
  final List<String> genres;
  final String showTitle;
  final List<StreamSource> sources;
  final List<String> episodeList;
  final List<String> episodeTitles;
  final List<String> episodeThumbs;
  final List<int> episodeNumbers;
  final List<int> seasonNumbers;
  final int episodeIndex;
  final List<String> allSeasonIds;
  final List<String> allSeasonLabels;
  final int seasonIndex;
  // Series-level plot/poster for the continue-watching entry this play
  // creates — see the doc comment on _EpisodeDetailScreenState._seriesPlot.
  final String seriesPlot;
  final String seriesPosterUrl;
  final String seriesCoverUrl;

  const _EpisodeBody({
    required this.pluginId,
    required this.item,
    required this.sources,
    this.plot = '',
    this.rating = 0.0,
    this.durationSeconds = 0,
    this.genres = const [],
    this.showTitle = '',
    this.episodeList = const [],
    this.episodeTitles = const [],
    this.episodeThumbs = const [],
    this.episodeNumbers = const [],
    this.seasonNumbers = const [],
    this.episodeIndex = -1,
    this.allSeasonIds = const [],
    this.allSeasonLabels = const [],
    this.seasonIndex = 0,
    this.seriesPlot = '',
    this.seriesPosterUrl = '',
    this.seriesCoverUrl = '',
  });

  @override
  State<_EpisodeBody> createState() => _EpisodeBodyState();
}

class _EpisodeBodyState extends State<_EpisodeBody> {
  // Back button (top) ↔ play/source buttons (below): arrowDown from back
  // always lands on the first source, arrowUp from any source always goes
  // back to it — mirrors PlayerOverlayState's _topChain/_centerChain, since
  // nothing here does directional focus movement on its own (see the rest
  // of the app: every D-pad screen wires arrow keys explicitly).
  final _backFn = FocusNode();
  final List<FocusNode> _sourceFn = [];

  @override
  void initState() {
    super.initState();
    _syncSourceNodes();
  }

  @override
  void didUpdateWidget(_EpisodeBody old) {
    super.didUpdateWidget(old);
    _syncSourceNodes();
  }

  void _syncSourceNodes() {
    final needed = widget.sources.length;
    while (_sourceFn.length < needed) {
      _sourceFn.add(FocusNode());
    }
    while (_sourceFn.length > needed) {
      _sourceFn.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    _backFn.dispose();
    for (final n in _sourceFn) {
      n.dispose();
    }
    super.dispose();
  }

  void _moveIn(List<FocusNode> chain, FocusNode from, int dir) {
    final i = chain.indexOf(from);
    if (i == -1) return;
    final next = i + dir;
    if (next >= 0 && next < chain.length) chain[next].requestFocus();
  }

  void _play(BuildContext context, StreamSource source) {
    context.push(
      '/player/${widget.pluginId}/${Uri.encodeComponent(source.id)}',
      extra: {
        'streamId': source.id,
        'title': widget.item.title,
        // The episode's own thumbnail — without this, updateProgress always
        // got an empty poster from this screen, and mycelium's "keep if
        // empty" upsert then left whatever poster the series/first episode
        // had stuck in Continue Watching forever, regardless of which
        // episode was actually playing (title/episode kept updating fine,
        // only the cover never did).
        'poster': widget.item.posterUrl.isNotEmpty
            ? widget.item.posterUrl
            : (widget.seriesCoverUrl.isNotEmpty
                ? widget.seriesCoverUrl
                : widget.seriesPosterUrl),
        'seriesPoster': widget.seriesPosterUrl,
        'seriesCoverUrl': widget.seriesCoverUrl,
        'episodeList': widget.episodeList,
        'episodeTitles': widget.episodeTitles,
        'episodeThumbs': widget.episodeThumbs,
        'episodeNumbers': widget.episodeNumbers,
        'seasonNumbers': widget.seasonNumbers,
        'episodeIndex': widget.episodeIndex,
        'allSeasonIds': widget.allSeasonIds,
        'allSeasonLabels': widget.allSeasonLabels,
        'seasonIndex': widget.seasonIndex,
        'pluginId': widget.pluginId,
        'sourceLabel': source.label,
        // parentId = the show id: lets continue-watching store it and later
        // resolve the series' own logo/plot for the CW hero.
        'parentId': widget.item.showId,
        'showTitle': widget.showTitle,
        // Always the series' own plot, never the episode's synopsis (shown
        // in this screen's own body via widget.plot, unrelated) — the CW
        // card must read the same regardless of which episode is playing.
        'plot': widget.seriesPlot,
        'rating': widget.rating,
        'durationSeconds': widget.durationSeconds,
        'genres': widget.genres,
        'year': widget.item.year,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final plot = widget.plot;
    final sources = widget.sources;
    return Stack(
      children: [
        // ── Background blur: still image sfocata dietro tutto ──
        if (item.posterUrl.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              // Web-only, no-op on every other platform — see image_sizing.dart's
              // "ImageRenderMethodForWeb.HttpGet" section for why every
              // CachedNetworkImage call site in the app sets this.
              imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
              imageUrl:
                  backdropSrc(item.posterUrl, backdropCacheWidth(context)),
              fit: BoxFit.cover,
              memCacheWidth: backdropCacheWidth(context),
              fadeInDuration: Duration.zero,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xD9080810)),
          ),
        ),

        // ── Layout principale ──
        Column(
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                // Autofocus only when there's no play button below to grab
                // it instead — otherwise an empty source list leaves
                // nothing focused at all and the D-pad is completely dead.
                child: _EpBackButton(
                  onTap: () => context.pop(),
                  autofocus: sources.isEmpty,
                  focusNode: _backFn,
                  onDown: _sourceFn.isNotEmpty
                      ? () => _sourceFn.first.requestFocus()
                      : null,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, bc) {
                // Scale fonts/paddings with the available height so the
                // still + title + plot + buttons always fit without
                // overflowing when the window is resized smaller — nothing
                // here was resolution-aware before, so shrinking the window
                // just clipped the episode column.
                //
                // Anchored to 1080p (s==1.15 there, same as the analogous
                // fix in details_screen.dart, now shared via
                // AppScale.contentScale) instead of bc.maxHeight/620 — that
                // reached its own 1.15 ceiling at any bc.maxHeight above ~713
                // (i.e. sh above ~833, which is nearly every real window), so
                // it never actually resized in practice above a fairly small
                // window despite the comment above. hasFooter: true (no
                // related-content footer bump applies to this screen) — was
                // previously missing the ambient-textScaler division
                // details_screen.dart has (2026-09 audit): on the desktop/web
                // ~1.35× readability boost, these fonts were sized for *and
                // then* scaled up again on top, same double-scaling bug
                // details_screen.dart had already fixed elsewhere.
                final s =
                    AppScale.contentScale(context, hasFooter: true, floor: 0.5);
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: SingleChildScrollView(
                      padding:
                          EdgeInsets.fromLTRB(48 * s, 32 * s, 48 * s, 48 * s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top row: still + meta/titolo ────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Still 16:9
                              Expanded(
                                flex: 5,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: item.posterUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            // Web-only, no-op on every other platform — see image_sizing.dart's
                                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                                            // CachedNetworkImage call site in the app sets this.
                                            imageRenderMethodForWeb:
                                                ImageRenderMethodForWeb.HttpGet,
                                            imageUrl: posterSrc(item.posterUrl,
                                                cacheWidthFor(context, 460)),
                                            fit: BoxFit.cover,
                                            memCacheWidth:
                                                cacheWidthFor(context, 460),
                                            fadeInDuration: const Duration(
                                                milliseconds: 200),
                                            placeholder: (_, __) =>
                                                const ColoredBox(
                                                    color: Color(0xFF0D0D1A)),
                                            errorWidget: (_, __, ___) =>
                                                const _StillPlaceholder(),
                                          )
                                        : const _StillPlaceholder(),
                                  ),
                                ),
                              ),
                              SizedBox(width: 40 * s),
                              // Meta + titolo + plot
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _EpMeta(item: item, scale: s),
                                    SizedBox(height: 12 * s),
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 34 * s,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (plot.isNotEmpty) ...[
                                      SizedBox(height: 20 * s),
                                      Text(
                                        'TRAMA',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11 * s,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      SizedBox(height: 10 * s),
                                      Text(
                                        plot,
                                        style: TextStyle(
                                          color: const Color(0xB8FFFFFF),
                                          fontSize: 15 * s,
                                          height: 1.6,
                                        ),
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 40 * s),

                          // ── Bottom: play buttons ─────────────────────────────
                          if (sources.isEmpty)
                            Text('Nessun flusso disponibile.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 15 * s))
                          else if (sources.length == 1)
                            _EpPlayButton(
                              label: 'Riproduci',
                              icon: Icons.play_arrow_rounded,
                              autofocus: true,
                              primary: true,
                              scale: s,
                              onTap: () => _play(context, sources.first),
                              focusNode: _sourceFn[0],
                              onUp: () => _backFn.requestFocus(),
                            )
                          else ...[
                            Text(
                              'SELEZIONA LINGUA',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11 * s,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 16 * s),
                            Wrap(
                              spacing: 12 * s,
                              runSpacing: 12 * s,
                              children: [
                                for (int i = 0; i < sources.length; i++)
                                  _EpPlayButton(
                                    label: sources[i].label.isNotEmpty
                                        ? sources[i].label
                                        : 'Guarda',
                                    icon: _iconFor(sources[i].label),
                                    autofocus: i == 0,
                                    primary: i == 0,
                                    scale: s,
                                    onTap: () => _play(context, sources[i]),
                                    focusNode: _sourceFn[i],
                                    onLeft: () =>
                                        _moveIn(_sourceFn, _sourceFn[i], -1),
                                    onRight: () =>
                                        _moveIn(_sourceFn, _sourceFn[i], 1),
                                    onUp: () => _backFn.requestFocus(),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  static IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('giapponese') || l.contains('sub') || l.contains('jp')) {
      return Icons.subtitles_rounded;
    }
    if (l.contains('italiano') || l.contains('doppiato') || l.contains('ita')) {
      return Icons.record_voice_over_rounded;
    }
    return Icons.play_arrow_rounded;
  }
}

// ── Still placeholder ─────────────────────────────────────────────────────────

class _StillPlaceholder extends StatelessWidget {
  const _StillPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0D0D1A),
      child: Center(
        child: Icon(Icons.movie_outlined, size: 40, color: Color(0x33FFFFFF)),
      ),
    );
  }
}

// ── Meta: S·E·data ────────────────────────────────────────────────────────────

class _EpMeta extends StatelessWidget {
  final CatalogItem item;
  final double scale;
  const _EpMeta({required this.item, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final airDate = item.extra['air_date'] ?? '';
    final parts = <String>[];

    if (item.seasonNumber > 0) parts.add('S${item.seasonNumber}');
    if (item.episodeNumber > 0) parts.add('E${item.episodeNumber}');
    if (airDate.isNotEmpty) {
      final d = airDate.split('-');
      parts.add(d.length == 3 ? '${d[2]}/${d[1]}/${d[0]}' : airDate);
    }

    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: TextStyle(
        color: Colors.white38,
        fontSize: 14 * scale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Bottone play ──────────────────────────────────────────────────────────────

class _EpPlayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool autofocus;
  final bool primary;
  final double scale;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onUp;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  const _EpPlayButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
    this.primary = false,
    this.scale = 1.0,
    this.focusNode,
    this.onUp,
    this.onLeft,
    this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onTap,
      onUp: onUp,
      onLeft: onLeft,
      onRight: onRight,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 18 * s),
        decoration: BoxDecoration(
          color: focused
              ? const Color(0xFF7C6AF7)
              : primary
                  ? Colors.white
                  : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused
                ? const Color(0xFF7C6AF7)
                : primary
                    ? Colors.white
                    : const Color(0x61FFFFFF),
            width: 1.5,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                      color: const Color(0xFF7C6AF7).withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22 * s,
                color: (focused || primary) ? Colors.black : Colors.white),
            SizedBox(width: 10 * s),
            Text(
              label,
              style: TextStyle(
                color: (focused || primary) ? Colors.black : Colors.white,
                fontSize: 18 * s,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _EpBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onDown;
  const _EpBackButton({
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    // Self-contained scale, matching the rest of this screen's formula —
    // this button sits in the Column above the LayoutBuilder that computes
    // `s` for its siblings, so it can't just receive that value.
    final s =
        (MediaQuery.sizeOf(context).height / 1080.0 * 1.15).clamp(0.5, 2.4);
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onTap,
      onDown: onDown,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
        decoration: BoxDecoration(
          color: focused ? const Color(0x26FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused ? Colors.white38 : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded,
                size: 22 * s, color: focused ? Colors.white : Colors.white70),
            SizedBox(width: 8 * s),
            Text('Indietro',
                style: TextStyle(
                  color: focused ? Colors.white : Colors.white70,
                  fontSize: 17 * s,
                )),
          ],
        ),
      ),
    );
  }
}
