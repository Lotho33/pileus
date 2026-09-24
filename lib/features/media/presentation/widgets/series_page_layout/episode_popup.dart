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
  final List<String> allEpisodeThumbs;
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
    this.allEpisodeThumbs = const [],
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
    perf('episode_popup: _loadAll start '
        '${widget.pluginId}/${widget.item.id}');
    final repo = getIt<MediaRepository>();
    var sessionExpired = false;
    // Each future's own completion is logged separately, BEFORE it enters
    // Future.wait — 2026-09-22: a live trace showed both the getStreams and
    // getDetails RPCs logging "ok" (media_client.dart's own timing) while
    // the "Future.wait resolved" line below never printed, for 30+ minutes,
    // across two separate episode taps — something between an RPC
    // completing and Future.wait registering it never ran. This narrows
    // down which of the two (or Future.wait itself) is where it actually
    // stalls.
    final streamsFuture = repo
        .getStreams(widget.pluginId, widget.item.id)
        .then((v) {
      perf('episode_popup: streamsFuture completed '
          'sources=${v.sources.length}');
      return v;
    }).catchError((e) {
      if (isUnauthenticated(e)) sessionExpired = true;
      perf('episode_popup: getStreams failed: $e');
      return StreamsResponse();
    });
    // urgent: true — see the trace this whole diagnostic block was added
    // for: the non-urgent path's dedup/cache Future chain was the one that
    // stalled on Android TV, not this RPC itself. Also just the right
    // semantics here regardless: a freshly opened popup is exactly the
    // "screen the user just opened" case [urgent] exists for.
    final detailsFuture = repo
        .getDetails(widget.pluginId, widget.item.id, urgent: true)
        .then((v) {
      perf('episode_popup: detailsFuture completed '
          'hasEpisode=${v.hasEpisode()}');
      return v;
    }).catchError((e) {
      if (isUnauthenticated(e)) sessionExpired = true;
      perf('episode_popup: getDetails failed: $e');
      return DetailsResponse();
    });
    // Safety net, not a fix: both RPCs are individually bounded (the client's
    // own read timeout, ~50s), so this should never actually fire — but a
    // live trace (2026-09-22) showed both completing while the Future.wait
    // below them never did, for 30+ minutes, leaving the popup on its
    // spinner with no way out short of backing out of the dialog entirely.
    // 15s is comfortably past how long either RPC normally takes; on expiry
    // this falls through to the same "no sources" state as a real empty
    // result, which the D-pad can already back out of.
    List<Object>? results;
    try {
      results =
          await Future.wait([streamsFuture, detailsFuture]).timeout(
              const Duration(seconds: 15));
    } on TimeoutException {
      perf('episode_popup: Future.wait TIMED OUT — see streamsFuture/'
          'detailsFuture completion lines above (or their absence)');
    }
    perf('episode_popup: Future.wait resolved mounted=$mounted '
        'sessionExpired=$sessionExpired timedOut=${results == null}');
    if (!mounted) return;
    if (results == null) {
      setState(() => _loading = false);
      if (_sources.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _closeFn.requestFocus();
        });
      }
      return;
    }
    if (sessionExpired) {
      // Was: `return;` here without ever clearing `_loading` — the popup
      // stayed on its spinner forever (SessionExpiredEvent's own effect,
      // e.g. a login screen, could show up separately, but THIS dialog
      // never learned the fetch was over and never repainted). Close it
      // instead of leaving a dead spinner behind whatever SessionExpiredEvent
      // triggers.
      getIt<AuthBloc>().add(const SessionExpiredEvent());
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    final streamsResp = results[0] as StreamsResponse;
    final detailsResp = results[1] as DetailsResponse;
    setState(() {
      _sources = streamsResp.sources.toList();
      _details = detailsResp.hasEpisode() ? detailsResp.episode : null;
      _loading = false;
    });
    perf('episode_popup: setState done sources=${_sources.length}');
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
                                            // Web-only, no-op on every other platform — see image_sizing.dart's
                                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                                            // CachedNetworkImage call site in the app sets this.
                                            imageRenderMethodForWeb:
                                                ImageRenderMethodForWeb.HttpGet,
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
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
                                                    'episodeThumbs':
                                                        widget.allEpisodeThumbs,
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
                                                    // + its hero. Always the
                                                    // series' own plot, never
                                                    // the episode's synopsis —
                                                    // the CW card must read the
                                                    // same regardless of which
                                                    // episode is playing.
                                                    'plot': widget.seriesPlot,
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
