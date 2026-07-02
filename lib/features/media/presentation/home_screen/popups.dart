// Part of home_screen.dart — split out for readability (plan 2e). The library
// file holds the shared imports plus the _HomeFsm enum and the HomeScreen
// entry point; private identifiers are shared across all parts.
part of '../home_screen.dart';

// ── Context menu shown on long-press of a catalog card ────────────────────────

class _CardContextMenu extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  // True when the catalog this item came from backs a live_refresh task
  // (proto: CatalogDef.live_refreshable) — e.g. sport's "Live Ora". Adds an
  // "Aggiorna ora" entry that calls PluginService.TriggerRefresh instead of
  // waiting for the plugin's own cron schedule.
  final bool liveRefreshable;

  const _CardContextMenu({
    required this.pluginId,
    required this.item,
    this.liveRefreshable = false,
  });

  @override
  State<_CardContextMenu> createState() => _CardContextMenuState();
}

class _CardContextMenuState extends State<_CardContextMenu> {
  late final List<({IconData icon, String label, VoidCallback action})> _items;
  late final List<FocusNode> _fns;

  bool get _isSeries => widget.item.mediaType == 'series';
  // Dettagli/Riproduci/Episodi assume a catalog/details item shape this
  // dialog was originally built for (series/movie/episode) — a live item
  // reached only via the liveRefreshable bypass below skips them rather
  // than risk those flows on a media type they were never verified against.
  bool get _isCatalogable => widget.item.mediaType != 'live';

  @override
  void initState() {
    super.initState();
    _items = [
      if (_isCatalogable) ...[
        (
          icon: Icons.info_outline_rounded,
          label: 'Dettagli',
          action: _openDetailsPopup,
        ),
        if (_isSeries)
          (
            icon: Icons.playlist_play_rounded,
            label: 'Episodi',
            action: _openEpisodes,
          )
        else
          (
            icon: Icons.play_arrow_rounded,
            label: 'Riproduci',
            action: _openPlay,
          ),
      ],
      if (widget.liveRefreshable)
        (
          icon: Icons.refresh_rounded,
          label: 'Aggiorna ora',
          action: _triggerRefresh,
        ),
    ];
    _fns = List.generate(_items.length, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fns[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final f in _fns) {
      f.dispose();
    }
    super.dispose();
  }

  void _openDetailsPopup() {
    Navigator.of(context).pop();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (_) =>
          _MediaDetailsPopup(pluginId: widget.pluginId, item: widget.item),
    );
  }

  void _openEpisodes() {
    Navigator.of(context).pop();
    context.push(
        '/details/${widget.pluginId}/${Uri.encodeComponent(widget.item.id)}',
        extra: widget.item);
  }

  void _openPlay() {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    _fetchAndPlay(router, messenger);
  }

  void _triggerRefresh() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    _requestRefresh(messenger);
  }

  // Non-blocking on the core side (see TriggerRefreshResponse's doc) — this
  // just reports whether the refresh actually started, it doesn't wait for
  // it to finish. ok=false (e.g. a task already in flight) is an expected,
  // routine outcome here, not an error path.
  Future<void> _requestRefresh(ScaffoldMessengerState messenger) async {
    try {
      final res =
          await getIt<MediaRepository>().triggerRefresh(widget.pluginId);
      messenger.showSnackBar(SnackBar(
        content: Text(res.message.isNotEmpty
            ? res.message
            : (res.ok
                ? 'Aggiornamento avviato.'
                : 'Impossibile avviare l\'aggiornamento.')),
      ));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Impossibile avviare l\'aggiornamento: $e')),
      );
    }
  }

  Future<void> _fetchAndPlay(
      GoRouter router, ScaffoldMessengerState messenger) async {
    try {
      final repo = getIt<MediaRepository>();
      final res = await repo.getStreams(widget.pluginId, widget.item.id);
      if (res.sources.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nessuna sorgente disponibile.')),
        );
        return;
      }
      final source = res.sources.first;
      router.push(
        '/player/${widget.pluginId}/${Uri.encodeComponent(source.id)}',
        extra: {
          'streamId': source.id,
          'title': widget.item.title,
          'episodeList': <String>[],
          'episodeTitles': <String>[],
          'episodeIndex': -1,
          'allSeasonIds': <String>[],
          'allSeasonLabels': <String>[],
          'seasonIndex': 0,
          'pluginId': widget.pluginId,
          'sourceLabel': source.label,
        },
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Impossibile avviare la riproduzione: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: TvFocusable(
        canRequestFocus: false,
        onEsc: () => Navigator.of(context).pop(),
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: const Color(0xFF14141F),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: AppScale.space(context, 17),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < _items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      CwMenuButton(
                        focusNode: _fns[i],
                        icon: _items[i].icon,
                        label: _items[i].label,
                        color: AppTheme.textHigh,
                        onTap: _items[i].action,
                        onUp: i > 0 ? () => _fns[i - 1].requestFocus() : null,
                        onDown: i < _fns.length - 1
                            ? () => _fns[i + 1].requestFocus()
                            : null,
                      ),
                    ],
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

// ── Full metadata popup (loaded via gRPC) ─────────────────────────────────────

class _MediaDetailsPopup extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;

  const _MediaDetailsPopup({required this.pluginId, required this.item});

  @override
  State<_MediaDetailsPopup> createState() => _MediaDetailsPopupState();
}

class _MediaDetailsPopupState extends State<_MediaDetailsPopup> {
  final _scrollCtrl = ScrollController();
  DetailsResponse? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = getIt<MediaRepository>();
      final res = await repo.getDetails(widget.pluginId, widget.item.id);
      if (mounted) {
        setState(() {
          _details = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      (_scrollCtrl.offset + delta)
          .clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final sw = MediaQuery.sizeOf(context).width;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
          horizontal: sw * (60.0 / 1920.0), vertical: sh * (40.0 / 1080.0)),
      child: TvFocusable(
        canRequestFocus: false,
        onEsc: () => Navigator.of(context).pop(),
        builder: (context, _) => ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: const Color(0xFF0E0E1A),
            child: _loading
                ? SizedBox(
                    height: 200,
                    child: Center(
                        child: PileusSpinner(
                            size: AppScale.spinnerL(context),
                            color: AppTheme.primary)),
                  )
                : _error != null
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red[300])),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            // Fades the scrolled content's top/bottom edges
                            // instead of hard-clipping mid-line against this
                            // popup's own ClipRRect boundary — only on
                            // whichever edge still has more content past it
                            // (see ScrollEdgeFade's doc).
                            child: ScrollEdgeFade(
                              controller: _scrollCtrl,
                              child: SingleChildScrollView(
                                controller: _scrollCtrl,
                                padding: EdgeInsets.zero,
                                child: _buildContent(),
                              ),
                            ),
                          ),
                          _TvCloseBar(
                            onClose: () => Navigator.of(context).pop(),
                            onScrollUp: () => _scrollBy(-140),
                            onScrollDown: () => _scrollBy(140),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final sh = MediaQuery.sizeOf(context).height;
    final item = _details?.item ?? widget.item;
    final d = _details;

    String plot = '';
    int year = item.year;
    double rating = item.rating;
    List<String> genres = [];
    String contentRating = '';
    String runtime = '';
    String status = '';
    String network = '';
    List<String> cast = [];

    if (d != null) {
      if (d.hasMovie()) {
        final m = d.movie;
        plot = m.plot;
        if (m.year > 0) year = m.year;
        genres = m.genres;
        contentRating = m.contentRating;
        runtime = m.runtime;
        cast = m.cast;
      } else if (d.hasSeries()) {
        final s = d.series;
        plot = s.plot;
        if (s.year > 0) year = s.year;
        genres = s.genres;
        contentRating = s.contentRating;
        status = s.status;
        network = s.network;
        cast = s.cast;
      }
    }
    if (plot.isEmpty) plot = item.extra['plot'] ?? '';

    final posterUrl = item.posterUrl.isNotEmpty ? item.posterUrl : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: poster + title + quick meta
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (posterUrl.isNotEmpty)
                SizedBox(
                  width: (sh * (140.0 / 1080.0)).clamp(100.0, 360.0),
                  child: CachedNetworkImage(
                    imageUrl: posterSrc(
                        posterUrl,
                        cacheWidthFor(context,
                            (sh * (140.0 / 1080.0)).clamp(100.0, 360.0))),
                    fit: BoxFit.cover,
                    memCacheWidth: cacheWidthFor(
                        context, (sh * (140.0 / 1080.0)).clamp(100.0, 360.0)),
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF1A1A2A)),
                  ),
                ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      sh * (24.0 / 1080.0),
                      sh * (24.0 / 1080.0),
                      sh * (24.0 / 1080.0),
                      sh * (20.0 / 1080.0)),
                  color: const Color(0xFF13131E),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: (sh * (22.0 / 1080.0)).clamp(14.0, 52.0),
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: sh * (10.0 / 1080.0)),
                      Wrap(
                        spacing: sh * (12.0 / 1080.0),
                        runSpacing: sh * (6.0 / 1080.0),
                        children: [
                          if (year > 0)
                            _PopupMetaChip(
                                Icons.calendar_today_rounded, year.toString()),
                          if (rating > 0)
                            _PopupMetaChip(
                                Icons.star_rounded, rating.toStringAsFixed(1),
                                color: const Color(0xFFFFB300)),
                          if (contentRating.isNotEmpty)
                            _PopupMetaChip(
                                Icons.shield_outlined, contentRating),
                          if (runtime.isNotEmpty)
                            _PopupMetaChip(Icons.timer_outlined, runtime),
                          if (status.isNotEmpty)
                            _PopupMetaChip(Icons.info_outline_rounded, status),
                          if (network.isNotEmpty)
                            _PopupMetaChip(Icons.tv_rounded, network),
                        ],
                      ),
                      if (genres.isNotEmpty) ...[
                        SizedBox(height: sh * (10.0 / 1080.0)),
                        Wrap(
                          spacing: sh * (6.0 / 1080.0),
                          runSpacing: sh * (6.0 / 1080.0),
                          children: genres
                              .map((g) => Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: sh * (10.0 / 1080.0),
                                        vertical: sh * (3.0 / 1080.0)),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(g,
                                        style: TextStyle(
                                          color: const Color(0xFFB8A9FF),
                                          fontSize: (sh * (12.0 / 1080.0))
                                              .clamp(9.0, 30.0),
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Plot
        if (plot.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
                sh * (24.0 / 1080.0),
                sh * (20.0 / 1080.0),
                sh * (24.0 / 1080.0),
                sh * (4.0 / 1080.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRAMA',
                  style: TextStyle(
                    color: AppTheme.textLow,
                    fontSize: (sh * (11.0 / 1080.0)).clamp(8.0, 28.0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: sh * (10.0 / 1080.0)),
                Text(
                  plot,
                  style: TextStyle(
                    color: const Color(0xCCFFFFFF),
                    fontSize: (sh * (15.0 / 1080.0)).clamp(11.0, 36.0),
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),

        // Cast
        if (cast.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
                sh * (24.0 / 1080.0),
                sh * (20.0 / 1080.0),
                sh * (24.0 / 1080.0),
                sh * (4.0 / 1080.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAST',
                  style: TextStyle(
                    color: AppTheme.textLow,
                    fontSize: (sh * (11.0 / 1080.0)).clamp(8.0, 28.0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: sh * (8.0 / 1080.0)),
                Text(
                  cast.take(10).join(', '),
                  style: TextStyle(
                    color: const Color(0xB3FFFFFF),
                    fontSize: (sh * (14.0 / 1080.0)).clamp(10.0, 34.0),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

        SizedBox(height: sh * (24.0 / 1080.0)),
      ],
    );
  }
}

class _TvCloseBar extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onScrollUp;
  final VoidCallback onScrollDown;

  const _TvCloseBar({
    required this.onClose,
    required this.onScrollUp,
    required this.onScrollDown,
  });

  @override
  State<_TvCloseBar> createState() => _TvCloseBarState();
}

class _TvCloseBarState extends State<_TvCloseBar> {
  bool _focused = false;
  final _fn = FocusNode();

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _fn,
      autofocus: true,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          widget.onScrollDown();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          widget.onScrollUp();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onClose,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _focused
                ? AppTheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border(
              top: BorderSide(color: AppTheme.textHigh.withValues(alpha: 0.08)),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: AppScale.space(context, 16),
                  color: _focused ? const Color(0xFFB8A9FF) : AppTheme.textLow,
                ),
                const SizedBox(width: 10),
                Text(
                  'CHIUDI',
                  style: TextStyle(
                    color:
                        _focused ? const Color(0xFFB8A9FF) : AppTheme.textLow,
                    fontSize: AppScale.space(context, 13),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 24),
                const _TvKey('ESC'),
                const SizedBox(width: 8),
                const _TvKey('↑↓ scorri'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvKey extends StatelessWidget {
  final String label;
  const _TvKey(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.textHigh.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: AppTheme.textLow,
            fontSize: AppScale.space(context, 11),
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PopupMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PopupMetaChip(this.icon, this.label,
      {this.color = const Color(0xFF9E9EA8)});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final fs = (sh * (13.0 / 1080.0)).clamp(10.0, 32.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fs * 1.08, color: color),
        SizedBox(width: fs * 0.31),
        Text(label,
            style: TextStyle(
                color: color, fontSize: fs, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
