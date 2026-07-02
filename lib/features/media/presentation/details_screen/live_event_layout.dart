// Part of details_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the layout-ratio comment, the
// DetailsScreen / _DetailsView / _DetailsContent entry chain and the shared
// logo helpers (logoUrlOnly / logoDark / logoRenderSize); private
// identifiers are shared across all parts.
part of '../details_screen.dart';

// ── Live event layout ─────────────────────────────────────────────────────────
// Carica le sorgenti subito; se unica → auto-lancia il player.
// Se multiple → mostra lista selezionabile con auto-play sulla prima.

class _LiveEventLayout extends StatefulWidget {
  final String pluginId;
  final DetailsResponse response;
  const _LiveEventLayout({required this.pluginId, required this.response});

  @override
  State<_LiveEventLayout> createState() => _LiveEventLayoutState();
}

class _LiveEventLayoutState extends State<_LiveEventLayout> {
  List<StreamSource> _sources = [];
  bool _loaded = false;
  String? _error;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    _loadAndLaunch();
  }

  Future<void> _loadAndLaunch() async {
    try {
      final repo = getIt<MediaRepository>();
      final res =
          await repo.getStreams(widget.pluginId, widget.response.item.id);
      if (!mounted) return;
      if (res.sources.isEmpty) {
        setState(() {
          _loaded = true;
          _error = 'Nessuna sorgente disponibile';
        });
        return;
      }
      setState(() {
        _sources = res.sources;
        _loaded = true;
      });
      // Auto-launch with the first source (the server returns them already
      // ranked best-first).
      _launch(res.sources.first);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = e.toString();
        });
      }
    }
  }

  void _launch(StreamSource src) {
    if (_launched || !mounted) return;
    _launched = true;
    final item = widget.response.item;
    final allIds = _sources.map((s) => s.id).toList();
    final allLabels = _sources.map((s) => s.label).toList();
    context.pushReplacement(
      '/player/${widget.pluginId}/${Uri.encodeComponent(src.id)}',
      extra: {
        'streamId': src.id,
        'title': item.title,
        'sourceLabel': src.label,
        'isLive': true,
        'liveSources': allIds,
        'liveSourceLabels': allLabels,
        'livePluginId': widget.pluginId,
        'liveMediaId': item.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final item = widget.response.item;
    final isLive = item.extra['is_live'] == '1';
    final fanart = item.extra['fanart_url'] ?? '';
    final bgUrl = fanart.isNotEmpty ? fanart : item.posterUrl;
    final sportCat = item.extra['sport_cat'] ?? '';
    final plot = item.extra['plot'] ?? '';
    final sportColor = sportAccentColor(sportCat);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Base gradient colorato per sport
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [sportColor.withValues(alpha: 0.4), Colors.black],
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
          ),
          // Fanart/poster come sfondo se disponibile
          if (bgUrl.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: backdropSrc(bgUrl, backdropCacheWidth(context)),
                fit: BoxFit.cover,
                memCacheWidth: backdropCacheWidth(context),
                fadeInDuration: const Duration(milliseconds: 400),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          // Vignetta scura sopra l'immagine
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x55000000), Color(0xEE000000)],
                  stops: [0.2, 1.0],
                ),
              ),
            ),
          ),
          // Contenuto
          Column(
            children: [
              // Back
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DetailsBackButton(onTap: () => context.pop()),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sport badge
                        if (sportCat.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: sportColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sportColor.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              sportCat.toUpperCase().replaceAll('-', ' '),
                              style: TextStyle(
                                  color: AppTheme.textMid,
                                  fontSize: sh * (11.0 / 1080.0),
                                  letterSpacing: 1.4),
                            ),
                          ),
                          SizedBox(height: sh * (14.0 / 1080.0)),
                        ],
                        // Titolo
                        Text(
                          item.title,
                          style: TextStyle(
                            color: AppTheme.textHigh,
                            fontSize: sh * (40.0 / 1080.0),
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: sh * (14.0 / 1080.0)),
                        // Status
                        if (isLive)
                          Row(children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFFF3B3B),
                                    shape: BoxShape.circle)),
                            SizedBox(width: sh * (7.0 / 1080.0)),
                            Text('IN DIRETTA',
                                style: TextStyle(
                                    color: const Color(0xFFFF3B3B),
                                    fontSize: sh * (13.0 / 1080.0),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5)),
                          ])
                        else if (plot.isNotEmpty)
                          Text(plot,
                              maxLines: 2,
                              style: TextStyle(
                                  color:
                                      AppTheme.textHigh.withValues(alpha: 0.6),
                                  fontSize: sh * (13.0 / 1080.0))),
                        SizedBox(height: sh * (32.0 / 1080.0)),
                        // Spinner o sorgenti
                        if (!_loaded)
                          Row(children: [
                            PileusSpinner(
                                size: sh * (20.0 / 1080.0),
                                color: Colors.white54),
                            SizedBox(width: sh * (14.0 / 1080.0)),
                            Text('Connessione in corso...',
                                style: TextStyle(
                                    color: AppTheme.textHigh
                                        .withValues(alpha: 0.5),
                                    fontSize: sh * (14.0 / 1080.0))),
                          ])
                        else if (_error != null)
                          _ErrorWithRetry(
                              error: _error!,
                              onRetry: () {
                                setState(() {
                                  _loaded = false;
                                  _error = null;
                                  _launched = false;
                                });
                                _loadAndLaunch();
                              })
                        else
                          _SourceList(
                            sources: _sources,
                            sportColor: sportColor,
                            onTap: _launch,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceList extends StatefulWidget {
  final List<StreamSource> sources;
  final Color sportColor;
  final void Function(StreamSource) onTap;
  const _SourceList(
      {required this.sources, required this.sportColor, required this.onTap});

  @override
  State<_SourceList> createState() => _SourceListState();
}

class _SourceListState extends State<_SourceList> {
  int _focused = 0;

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SORGENTI DISPONIBILI',
            style: TextStyle(
                color: AppTheme.textHigh.withValues(alpha: 0.4),
                fontSize: sh * (11.0 / 1080.0),
                letterSpacing: 1.4)),
        SizedBox(height: sh * (12.0 / 1080.0)),
        ...List.generate(widget.sources.length, (i) {
          final src = widget.sources[i];
          final isFocused = _focused == i;
          return Padding(
            padding: EdgeInsets.only(bottom: sh * (8.0 / 1080.0)),
            child: TvFocusable(
              autofocus: i == 0,
              onFocusChange: (v) {
                if (v) setState(() => _focused = i);
              },
              onActivate: () => widget.onTap(src),
              builder: (context, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.symmetric(
                    horizontal: sh * (16.0 / 1080.0),
                    vertical: sh * (12.0 / 1080.0)),
                decoration: BoxDecoration(
                  color: isFocused
                      ? widget.sportColor.withValues(alpha: 0.35)
                      : AppTheme.textHigh.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? widget.sportColor.withValues(alpha: 0.8)
                        : AppTheme.textHigh.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline_rounded,
                        color: isFocused ? AppTheme.textHigh : Colors.white54,
                        size: sh * (20.0 / 1080.0)),
                    SizedBox(width: sh * (12.0 / 1080.0)),
                    Expanded(
                      child: Text(src.label,
                          style: TextStyle(
                            color: isFocused
                                ? AppTheme.textHigh
                                : AppTheme.textMid,
                            fontSize: sh * (15.0 / 1080.0),
                            fontWeight:
                                isFocused ? FontWeight.w600 : FontWeight.normal,
                          )),
                    ),
                    if (i == 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: sh * (8.0 / 1080.0),
                            vertical: sh * (2.0 / 1080.0)),
                        decoration: BoxDecoration(
                          color: widget.sportColor.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('MIGLIORE',
                            style: TextStyle(
                                color: AppTheme.textMid,
                                fontSize: sh * (10.0 / 1080.0),
                                letterSpacing: 1)),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ErrorWithRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorWithRetry({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(error,
            style: TextStyle(color: Colors.red, fontSize: sh * (13.0 / 1080.0)),
            maxLines: 4,
            overflow: TextOverflow.ellipsis),
        SizedBox(height: sh * (12.0 / 1080.0)),
        TvFocusable(
          autofocus: true,
          onActivate: onRetry,
          builder: (context, focused) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
                horizontal: sh * (20.0 / 1080.0),
                vertical: sh * (10.0 / 1080.0)),
            decoration: BoxDecoration(
              color: focused
                  ? AppTheme.textHigh.withValues(alpha: 0.15)
                  : AppTheme.textHigh.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: focused ? Colors.white54 : Colors.white24),
            ),
            child: Text('Riprova',
                style: TextStyle(
                    color: AppTheme.textHigh, fontSize: sh * (14.0 / 1080.0))),
          ),
        ),
      ],
    );
  }
}
