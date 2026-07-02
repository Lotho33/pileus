// Part of series_page_layout.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the _dmax helper and the public
// AnimeLayout / SeriesLayout entry points; private identifiers are shared
// across all parts.
part of '../series_page_layout.dart';

// ── Episode popup ─────────────────────────────────────────────────────────────

class _EpisodePopup extends StatefulWidget {
  final String pluginId;
  final EpisodeInfo item;
  final List<String> allEpisodeIds;
  final List<String> allEpisodeTitles;
  final int episodeIndex;
  final List<String> allSeasonIds;
  final List<String> allSeasonLabels;
  final int seasonIndex;
  final String seriesPosterUrl;
  final String parentId;
  final String seriesTitle;
  final String seriesPlot;
  final double seriesRating;
  final int seriesYear;
  final List<String> seriesGenres;

  const _EpisodePopup({
    required this.pluginId,
    required this.item,
    required this.allEpisodeIds,
    required this.allEpisodeTitles,
    required this.episodeIndex,
    required this.allSeasonIds,
    required this.allSeasonLabels,
    required this.seasonIndex,
    this.seriesPosterUrl = '',
    this.parentId = '',
    this.seriesTitle = '',
    this.seriesPlot = '',
    this.seriesRating = 0.0,
    this.seriesYear = 0,
    this.seriesGenres = const [],
  });

  @override
  State<_EpisodePopup> createState() => _EpisodePopupState();
}

class _EpisodePopupState extends State<_EpisodePopup> {
  bool _loading = true;
  List<StreamSource> _sources = [];
  EpisodeDetails? _details;
  final _scrollCtrl = ScrollController();
  // Close ✕ (top-right) ↔ first play button — Up from the first source lands
  // on the ✕, Down from the ✕ goes back to it. The ✕ also autofocuses
  // whenever there's no play button to take focus instead (still loading, or
  // no sources at all), so the popup is never left with a dead D-pad.
  final _closeFn = FocusNode();
  final _firstPlayFn = FocusNode();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _closeFn.dispose();
    _firstPlayFn.dispose();
    super.dispose();
  }

  static String _fmtDate(String d) {
    if (d.isEmpty) return '';
    final parts = d.split('-');
    if (parts.length < 3) return d;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // MediaRepository, not a captured MediaGrpcClient — resolves
    // getIt<MediaGrpcClient>() fresh on every call instead of risking a
    // stale one after rebuildGrpcClients(). Each call keeps its own
    // catchError (an empty-response fallback) so one failing doesn't blank
    // the other's real result — but both used to swallow *any* error,
    // unauthenticated included, leaving the user looking at an emptied-out
    // popup with no sign the session had actually expired (2026-09 audit).
    final repo = getIt<MediaRepository>();
    var sessionExpired = false;
    final results = await Future.wait([
      repo.getStreams(widget.pluginId, widget.item.id).catchError((e) {
        if (isUnauthenticated(e)) sessionExpired = true;
        return StreamsResponse();
      }),
      repo.getDetails(widget.pluginId, widget.item.id).catchError((e) {
        if (isUnauthenticated(e)) sessionExpired = true;
        return DetailsResponse();
      }),
    ]);
    if (!mounted) return;
    if (sessionExpired) {
      getIt<AuthBloc>().add(const SessionExpiredEvent());
      return;
    }
    final streamsResp = results[0] as StreamsResponse;
    final detailsResp = results[1] as DetailsResponse;
    setState(() {
      _sources = streamsResp.sources.toList();
      _details = detailsResp.hasEpisode() ? detailsResp.episode : null;
      _loading = false;
    });
    if (_sources.isEmpty) {
      // No play button will be built to catch autofocus — put it on the ✕ so
      // the popup still responds to the D-pad.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _closeFn.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // Prefer rich details from GetDetails, fall back to EpisodeInfo fields
    final plot = _details?.plot.isNotEmpty == true ? _details!.plot : item.plot;
    final airDate =
        _details?.airDate.isNotEmpty == true ? _details!.airDate : item.airDate;
    final duration =
        (_details?.duration ?? 0) > 0 ? _details!.duration : item.duration;
    final vote = (_details?.vote ?? 0.0) > 0 ? _details!.vote : item.vote;
    final directors = _details?.directors ?? [];
    final guests = _details?.guestStars ?? [];

    final epLabel = item.episodeNumber > 0 ? 'Ep. ${item.episodeNumber}' : '';
    final dateLabel = _fmtDate(airDate);
    final durLabel = duration > 0 ? '$duration min' : '';
    final metaParts =
        [epLabel, dateLabel, durLabel].where((s) => s.isNotEmpty).toList();

    // Bound the dialog to the viewport and cap the thumbnail, otherwise on a
    // TV (~540 dp tall) the 16:9 image fills the screen and the play buttons
    // fall below the fold; the inner scroll view can only scroll within a
    // bounded height, so give it one explicitly.
    final sh = MediaQuery.sizeOf(context).height;
    final sw = MediaQuery.sizeOf(context).width;
    final maxDialogH = sh - 60.0;
    // Used to be a flat 900 — height scaled with sh but width never moved,
    // so resizing the window warped the popup's proportions (most visibly
    // the full-width thumbnail: its height tracked the window, its width
    // didn't). 0.469 keeps today's look unchanged at a common 1920-wide
    // desktop window (1920*0.469≈900); same clamp bounds as the
    // analogous _RelatedDetailsPopup for consistency between the two.
    final maxDialogW = (sw * 0.469).clamp(520.0, 1000.0);
    final thumbMaxH = maxDialogH * 0.42;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: TvFocusable(
        canRequestFocus: false,
        onEsc: () => Navigator.of(context).pop(),
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: maxDialogW, maxHeight: maxDialogH),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: const Color(0xFF14141F),
                child: Stack(
                  children: [
                    // Fades the scrolled content's top/bottom edges instead
                    // of hard-clipping mid-line against this popup's own
                    // ClipRRect boundary — only on whichever edge still has
                    // more content past it (see ScrollEdgeFade's doc).
                    ScrollEdgeFade(
                      controller: _scrollCtrl,
                      child: SingleChildScrollView(
                        controller: _scrollCtrl,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail (altezza fissa, larghezza piena) con gradient + titolo.
                            // Nota: niente AspectRatio qui — se lo si vincola solo in altezza,
                            // sceglie una larghezza propria in base al rapporto 16:9 e, dentro
                            // una Column con crossAxisAlignment.start, resta più stretta del
                            // resto del popup lasciando un bordo vuoto a destra. Con SizedBox a
                            // larghezza piena + StackFit.expand + BoxFit.cover l'immagine copre
                            // sempre l'intera larghezza (croppando invece di "galleggiare").
                            SizedBox(
                              width: double.infinity,
                              height: thumbMaxH,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  () {
                                    final thumb = item.thumbnailUrl.isNotEmpty
                                        ? item.thumbnailUrl
                                        : widget.seriesPosterUrl;
                                    return thumb.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: thumb,
                                            fit: thumb == item.thumbnailUrl
                                                ? BoxFit.cover
                                                : BoxFit.contain,
                                            memCacheWidth: cacheWidthFor(
                                                context, maxDialogW),
                                            fadeInDuration: const Duration(
                                                milliseconds: 200),
                                            placeholder: (_, __) =>
                                                const ColoredBox(
                                                    color: Color(0xFF111120)),
                                            errorWidget: (_, __, ___) =>
                                                const ColoredBox(
                                                    color: Color(0xFF111120)),
                                          )
                                        : const ColoredBox(
                                            color: Color(0xFF111120));
                                  }(),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.85)
                                          ],
                                          stops: const [0.35, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (item.title.isNotEmpty)
                                    Positioned(
                                      left: 24,
                                      right: 60,
                                      bottom: 18,
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          color: AppTheme.textHigh,
                                          fontSize: sh * (28.0 / 1080.0),
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                          shadows: const [
                                            Shadow(
                                                blurRadius: 10,
                                                color: Colors.black)
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 16, 24, 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Meta row: ep · data · durata
                                  if (metaParts.isNotEmpty)
                                    Row(
                                      children: [
                                        if (vote > 0) ...[
                                          Icon(Icons.star_rounded,
                                              size: sh * (16.0 / 1080.0),
                                              color: const Color(0xFFFFD700)),
                                          SizedBox(width: sh * (4.0 / 1080.0)),
                                          Text(vote.toStringAsFixed(1),
                                              style: TextStyle(
                                                  color: AppTheme.textMid,
                                                  fontSize:
                                                      sh * (16.0 / 1080.0),
                                                  fontWeight: FontWeight.w600)),
                                          SizedBox(width: sh * (12.0 / 1080.0)),
                                        ],
                                        Text(
                                          metaParts.join('  ·  '),
                                          style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: sh * (16.0 / 1080.0)),
                                        ),
                                      ],
                                    ),

                                  // Plot — no maxLines cap: this popup's outer
                                  // SingleChildScrollView is genuinely scrollable
                                  // (default physics), so a long plot is reachable
                                  // by scrolling instead of being cut off.
                                  if (plot.isNotEmpty) ...[
                                    SizedBox(height: sh * (14.0 / 1080.0)),
                                    Text(
                                      plot,
                                      style: TextStyle(
                                        color: AppTheme.textHigh
                                            .withValues(alpha: 0.80),
                                        fontSize: sh * (16.0 / 1080.0),
                                        height: 1.6,
                                      ),
                                    ),
                                  ],

                                  // Directors
                                  if (directors.isNotEmpty) ...[
                                    SizedBox(height: sh * (14.0 / 1080.0)),
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                            fontSize: sh * (14.0 / 1080.0),
                                            height: 1.4),
                                        children: [
                                          const TextSpan(
                                              text: 'Regia  ',
                                              style: TextStyle(
                                                  color: AppTheme.textLow)),
                                          TextSpan(
                                            text: directors.join(', '),
                                            style: const TextStyle(
                                                color: AppTheme.textMid),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Guest stars
                                  if (guests.isNotEmpty) ...[
                                    SizedBox(height: sh * (6.0 / 1080.0)),
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                            fontSize: sh * (14.0 / 1080.0),
                                            height: 1.4),
                                        children: [
                                          const TextSpan(
                                              text: 'Guest  ',
                                              style: TextStyle(
                                                  color: AppTheme.textLow)),
                                          TextSpan(
                                            text: guests.take(6).join(', '),
                                            style: const TextStyle(
                                                color: AppTheme.textMid),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  SizedBox(height: sh * (22.0 / 1080.0)),

                                  // Play buttons
                                  if (_loading)
                                    Center(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 12),
                                        child: PileusSpinner(
                                            size: AppScale.spinnerS(context),
                                            color: AppTheme.textLow),
                                      ),
                                    )
                                  else if (_sources.isEmpty)
                                    Text('Nessuna fonte disponibile.',
                                        style: TextStyle(
                                            color: AppTheme.textLow,
                                            fontSize: sh * (15.0 / 1080.0)))
                                  else
                                    Center(
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          for (int i = 0;
                                              i < _sources.length;
                                              i++)
                                            PopupPlayButton(
                                              label:
                                                  _sources[i].label.isNotEmpty
                                                      ? _sources[i].label
                                                      : 'Guarda',
                                              autofocus: i == 0,
                                              focusNode:
                                                  i == 0 ? _firstPlayFn : null,
                                              onUp: i == 0
                                                  ? () =>
                                                      _closeFn.requestFocus()
                                                  : null,
                                              onTap: () {
                                                final src = _sources[i];
                                                // This dialog is a raw Navigator route
                                                // (showDialog), invisible to GoRouter's own
                                                // stack — context.pop() here targets
                                                // GoRouter's stack instead and, racing the
                                                // push below, can end up popping the /player
                                                // route it just pushed. Navigator.of(context)
                                                // targets the actual route that owns this
                                                // dialog (see _RelatedDetailsPopup for the
                                                // same pattern).
                                                Navigator.of(context).pop();
                                                context.push(
                                                  '/player/${widget.pluginId}/${Uri.encodeComponent(src.id)}',
                                                  extra: {
                                                    'streamId': src.id,
                                                    'title': widget.item.title,
                                                    'showTitle':
                                                        widget.seriesTitle,
                                                    'episodeList':
                                                        widget.allEpisodeIds,
                                                    'episodeTitles':
                                                        widget.allEpisodeTitles,
                                                    'episodeIndex':
                                                        widget.episodeIndex,
                                                    'allSeasonIds':
                                                        widget.allSeasonIds,
                                                    'allSeasonLabels':
                                                        widget.allSeasonLabels,
                                                    'seasonIndex':
                                                        widget.seasonIndex,
                                                    'pluginId': widget.pluginId,
                                                    'sourceLabel': src.label,
                                                    'poster': widget
                                                            .item
                                                            .thumbnailUrl
                                                            .isNotEmpty
                                                        ? widget
                                                            .item.thumbnailUrl
                                                        : widget
                                                            .seriesPosterUrl,
                                                    'seriesPoster':
                                                        widget.seriesPosterUrl,
                                                    'parentId': widget.parentId,
                                                    // Series-level metadata for
                                                    // the continue-watching card
                                                    // + its hero (plot prefers
                                                    // the episode synopsis when
                                                    // we have it).
                                                    'plot': (_details?.plot
                                                                .isNotEmpty ??
                                                            false)
                                                        ? _details!.plot
                                                        : widget.seriesPlot,
                                                    'rating':
                                                        widget.seriesRating,
                                                    'year': widget.seriesYear,
                                                    'genres':
                                                        widget.seriesGenres,
                                                  },
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Close ✕ — top right, same affordance as the live-event
                    // popup. Esc/Back on the dialog still closes it too.
                    Positioned(
                      top: 12,
                      right: 12,
                      child: PopupCloseButton(
                        focusNode: _closeFn,
                        onClose: () => Navigator.of(context).pop(),
                        onDown: _sources.isNotEmpty
                            ? () => _firstPlayFn.requestFocus()
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

