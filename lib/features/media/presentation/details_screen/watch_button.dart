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

  @override
  void initState() {
    super.initState();
    if (!widget.isAudio) _loadSources();
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
    final cwPoster =
        widget.fanartUrl.isNotEmpty ? widget.fanartUrl : widget.posterUrl;
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

    // Streams non ancora caricati
    if (!_sourcesLoaded) {
      return SizedBox(
        height: 56,
        child: Center(
            child: PileusSpinner(
                size: AppScale.spinnerS(context), color: AppTheme.textLow)),
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
      return TvFocusable(
        autofocus: true,
        onActivate: onActivate,
        builder: (context, focused) =>
            _buildSingleButton(focused, 'Guarda', Icons.play_arrow_rounded),
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
          children: [
            for (int i = 0; i < _sources.length; i++)
              PopupPlayButton(
                label:
                    _sources[i].label.isNotEmpty ? _sources[i].label : 'Guarda',
                autofocus: i == 0,
                onTap: () => _play(context, _sources[i]),
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
