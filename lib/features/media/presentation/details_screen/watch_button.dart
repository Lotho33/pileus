// Part of details_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the layout-ratio comment, the
// DetailsScreen / _DetailsView / _DetailsContent entry chain and the shared
// logo helpers (logoUrlOnly / logoDark / logoRenderSize); private
// identifiers are shared across all parts.
part of '../details_screen.dart';

// _WatchButton: per audio/clip → push diretto. Per anime film → carica streams
// e se ci sono più sorgenti mostra selezione lingua inline.
class _WatchButton extends StatefulWidget {
  final String pluginId;
  final String mediaId;
  final bool isAudio;
  final String posterUrl;
  final String fanartUrl;
  // Horizontal `extra['cover_url']` (a plugin-provided field) — see
  // posterForMovie() and episode_poster.dart's doc comment: the CW poster
  // for a movie must prefer this over fanartUrl/posterUrl, not the plain
  // backdrop.
  final String coverUrl;
  final String itemTitle;
  // Continue-watching metadata — see MediaRepository.updateProgress. Only
  // ever populated by _MovieLayout/_AnimeMovieLayout (already have a
  // MovieDetails/genres list in scope); audio/clip callers leave these at
  // their defaults, same as before this metadata existed.
  final String plot;
  final List<String> genres;
  final double rating;
  final int year;
  const _WatchButton({
    required this.pluginId,
    required this.mediaId,
    this.isAudio = false,
    this.posterUrl = '',
    this.fanartUrl = '',
    this.coverUrl = '',
    this.itemTitle = '',
    this.plot = '',
    this.genres = const [],
    this.rating = 0.0,
    this.year = 0,
  });

  @override
  State<_WatchButton> createState() => _WatchButtonState();
}

class _WatchButtonState extends State<_WatchButton> {
  List<StreamSource> _sources = [];
  bool _sourcesLoaded = false;
  bool _sourcesError = false;

  // Resume-awareness: checked in parallel with _loadSources (below) so
  // there's no flicker between "Guarda" and "Riprendi «title»" once both
  // settle — see _resumeChecked in the loading gate in build().
  ContinueWatchingItem? _resume;
  bool _resumeChecked = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAudio) {
      _checkResume();
      _loadSources();
    }
  }

  Future<void> _checkResume() async {
    try {
      final repo = getIt<MediaRepository>();
      final items = await repo.getContinueWatching(pluginId: widget.pluginId);
      if (!mounted) return;
      final match = items
          .where((i) => i.parentID.isEmpty && i.playableID == widget.mediaId)
          .firstOrNull;
      // A "next episode" row parked at ~31s just to clear mycelium's
      // progress_time>=30 filter (see PlaybackProgress.maybeClear) isn't a
      // real resume point — same guard the home Continue Watching card uses.
      final isRealProgress =
          match != null && !(match.totalTime <= 0 && match.progressTime <= 35);
      if (isRealProgress) setState(() => _resume = match);
    } catch (_) {
      // best-effort — falls back to "Guarda"
    } finally {
      if (mounted) setState(() => _resumeChecked = true);
    }
  }

  void _playResume(BuildContext context, ContinueWatchingItem resume) {
    // Same minimal push as the home Continue Watching card's resume — see
    // mobile_home_screen.dart's _CwCard._resume() for the identical pattern.
    context.push(
      '/player/${widget.pluginId}/${Uri.encodeComponent(resume.playableID)}',
      extra: {
        'streamId': resume.playableID,
        'title': resume.title,
        'showTitle': resume.showTitle,
        'poster': resume.poster.isNotEmpty
            ? resume.poster
            : posterForMovie(
                coverUrl: widget.coverUrl,
                fanartUrl: widget.fanartUrl,
                posterUrl: widget.posterUrl,
              ),
        'parentId': resume.parentID,
        'seekTo': resume.progressTime.toInt(),
        'plot': widget.plot,
        'genres': widget.genres,
        'rating': widget.rating,
        'year': widget.year,
      },
    );
  }

  Future<void> _loadSources() async {
    if (mounted) {
      setState(() {
        _sourcesLoaded = false;
        _sourcesError = false;
      });
    }
    try {
      final repo = getIt<MediaRepository>();
      final res = await repo.getStreams(widget.pluginId, widget.mediaId);
      if (mounted) {
        setState(() {
          _sources = res.sources;
          _sourcesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sourcesLoaded = true;
          _sourcesError = true;
        });
      }
    }
  }

  void _play(BuildContext context, StreamSource src) {
    final cwPoster = posterForMovie(
      coverUrl: widget.coverUrl,
      fanartUrl: widget.fanartUrl,
      posterUrl: widget.posterUrl,
    );
    context.push(
      '/player/${widget.pluginId}/${Uri.encodeComponent(src.id)}',
      extra: {
        'streamId': src.id,
        'title': widget.itemTitle.isNotEmpty ? widget.itemTitle : null,
        'sourceLabel': src.label,
        'poster': cwPoster,
        'parentId': '',
        'plot': widget.plot,
        'genres': widget.genres,
        'rating': widget.rating,
        'year': widget.year,
      },
    );
  }

  void _playDirect(BuildContext context) {
    context.push(
      '/player/${widget.pluginId}/${Uri.encodeComponent(widget.mediaId)}',
      extra: widget.isAudio
          ? {'mediaType': 'music'}
          : {
              'poster': posterForMovie(
                coverUrl: widget.coverUrl,
                fanartUrl: widget.fanartUrl,
                posterUrl: widget.posterUrl,
              ),
              'plot': widget.plot,
              'genres': widget.genres,
              'rating': widget.rating,
              'year': widget.year,
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Audio: bottone singolo diretto
    if (widget.isAudio) {
      return TvFocusable(
        autofocus: true,
        onActivate: () => _playDirect(context),
        builder: (context, focused) =>
            _buildSingleButton(focused, 'Ascolta', Icons.play_arrow_rounded),
      );
    }

    // Streams (e resume-check) non ancora caricati
    if (!_sourcesLoaded || !_resumeChecked) {
      return SizedBox(
        height: 56,
        child: Center(
            child: PileusSpinner(
                size: AppScale.spinnerS(context), color: AppTheme.textLow)),
      );
    }

    // Continue Watching ha un progresso reale per questo contenuto →
    // riprendi direttamente invece di proporre sempre "Guarda" da zero.
    final resume = _resume;
    if (resume != null) {
      return TvFocusable(
        autofocus: true,
        onActivate: () => _playResume(context, resume),
        builder: (context, focused) => _buildSingleButton(
            focused, 'Riprendi «${resume.title}»', Icons.play_arrow_rounded),
      );
    }

    // Errore nel caricamento sorgenti → bottone di retry, non tentare il
    // direct-play "alla cieca" (mediaId non è detto sia risolvibile come
    // stream) mascherando il vero problema (rete/sessione scaduta).
    if (_sourcesError) {
      return TvFocusable(
        autofocus: true,
        onActivate: _loadSources,
        builder: (context, focused) =>
            _buildSingleButton(focused, 'Riprova', Icons.refresh_rounded),
      );
    }

    // Una sola sorgente (o nessuna) → bottone singolo
    if (_sources.length <= 1) {
      void onActivate() => _sources.isEmpty
          ? _playDirect(context)
          : _play(context, _sources.first);
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TvFocusable(
            autofocus: true,
            onActivate: onActivate,
            builder: (context, focused) => _buildSingleButton(
                focused, 'Guarda', Icons.play_arrow_rounded),
          ),
          _DownloadChip(
            pluginId: widget.pluginId,
            mediaId: widget.mediaId,
            preferredSourceLabel:
                _sources.isNotEmpty ? _sources.first.label : '',
            itemTitle: widget.itemTitle,
            posterUrl: posterForMovie(
              coverUrl: widget.coverUrl,
              fanartUrl: widget.fanartUrl,
              posterUrl: widget.posterUrl,
            ),
          ),
        ],
      );
    }

    // Più sorgenti → selezione lingua
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELEZIONA LINGUA',
          style: TextStyle(
            color: AppTheme.textLow,
            fontSize: MediaQuery.sizeOf(context).height * (11.0 / 1080.0),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (int i = 0; i < _sources.length; i++)
              PopupPlayButton(
                label:
                    _sources[i].label.isNotEmpty ? _sources[i].label : 'Guarda',
                autofocus: i == 0,
                onTap: () => _play(context, _sources[i]),
              ),
            _DownloadChip(
              pluginId: widget.pluginId,
              mediaId: widget.mediaId,
              preferredSourceLabel: _sources.first.label,
              itemTitle: widget.itemTitle,
              posterUrl: posterForMovie(
                coverUrl: widget.coverUrl,
                fanartUrl: widget.fanartUrl,
                posterUrl: widget.posterUrl,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleButton(bool focused, String label, IconData icon) {
    final sh = MediaQuery.sizeOf(context).height;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(
          horizontal: sh * (40.0 / 1080.0), vertical: sh * (18.0 / 1080.0)),
      decoration: BoxDecoration(
        color: focused ? AppTheme.primary : Colors.white24,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? AppTheme.primary : AppTheme.textLow,
          width: focused ? 0 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 2)
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textHigh,
          fontSize: sh * (20.0 / 1080.0),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Renders nothing until ListPlugins confirms the plugin actually has the
// "download" capability — same lazy self-check as download_button.dart's
// DownloadButton (mobile/desktop/web). No explicit FocusNode/onUp/onLeft
// wiring, matching this file's own play button(s): they don't either, and
// rely on Flutter's default focus traversal across this Wrap.
class _DownloadChip extends StatefulWidget {
  final String pluginId;
  final String mediaId;
  final String preferredSourceLabel;
  final String itemTitle;
  final String posterUrl;

  const _DownloadChip({
    required this.pluginId,
    required this.mediaId,
    required this.preferredSourceLabel,
    required this.itemTitle,
    required this.posterUrl,
  });

  @override
  State<_DownloadChip> createState() => _DownloadChipState();
}

class _DownloadChipState extends State<_DownloadChip> {
  bool? _supported;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final plugins = await getIt<MediaRepository>().listPlugins();
      if (!mounted) return;
      final plugin =
          plugins.where((p) => p.pluginId == widget.pluginId).firstOrNull;
      setState(
          () => _supported = plugin != null && pluginSupportsDownload(plugin));
    } catch (_) {
      if (mounted) setState(() => _supported = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_supported != true) return const SizedBox.shrink();
    return TvFocusable(
      onActivate: () => pushTvDownloadOptions(
        context,
        pluginId: widget.pluginId,
        preferredSourceLabel: widget.preferredSourceLabel,
        target: DownloadTarget(
          mediaId: widget.mediaId,
          streamId: '',
          title: widget.itemTitle,
          poster: widget.posterUrl,
        ),
      ),
      builder: (context, focused) {
        final sh = MediaQuery.sizeOf(context).height;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
              horizontal: sh * (40.0 / 1080.0),
              vertical: sh * (18.0 / 1080.0)),
          decoration: BoxDecoration(
            color: focused ? AppTheme.primary : Colors.white24,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: focused ? AppTheme.primary : AppTheme.textLow,
              width: focused ? 0 : 1,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_rounded,
                  size: sh * (20.0 / 1080.0), color: AppTheme.textHigh),
              SizedBox(width: sh * (8.0 / 1080.0)),
              Text(
                'Scarica',
                style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: sh * (20.0 / 1080.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
