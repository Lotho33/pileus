import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../core/theme/app_theme.dart';
import '../core/utils/image_sizing.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/media/bloc/details_bloc.dart';
import '../features/media/bloc/details_event.dart';
import '../features/media/bloc/details_state.dart';
import '../features/media/data/continue_watching_item.dart';
import '../features/media/data/media_repository.dart';
import '../features/player/resolve_and_play.dart';
import '../shared/widgets/error_retry_view.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

class MobileDetailsScreen extends StatelessWidget {
  final String pluginId;
  final String mediaId;
  final CatalogItem? preview;

  const MobileDetailsScreen({
    super.key,
    required this.pluginId,
    required this.mediaId,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DetailsBloc(
        getIt<MediaRepository>(),
        onSessionExpired: () =>
            getIt<AuthBloc>().add(const SessionExpiredEvent()),
      )..add(LoadDetailsEvent(pluginId: pluginId, mediaId: mediaId)),
      child: _View(pluginId: pluginId, mediaId: mediaId, preview: preview),
    );
  }
}

class _View extends StatelessWidget {
  final String pluginId;
  final String mediaId;
  final CatalogItem? preview;
  const _View({required this.pluginId, required this.mediaId, this.preview});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: BlocBuilder<DetailsBloc, DetailsState>(
        builder: (context, s) {
          if (s is DetailsError) {
            return _Error(
              message: s.message,
              onRetry: () => context.read<DetailsBloc>().add(
                  LoadDetailsEvent(pluginId: pluginId, mediaId: mediaId)),
            );
          }
          final res = s is DetailsLoaded ? s.response : null;
          final item = res?.item ?? preview;
          if (item == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _Body(
            pluginId: pluginId,
            item: item,
            details: res,
            loading: s is DetailsLoading || s is DetailsInitial,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String pluginId;
  final CatalogItem item;
  final DetailsResponse? details;
  final bool loading;

  const _Body({
    required this.pluginId,
    required this.item,
    required this.details,
    required this.loading,
  });

  bool get _isSeries =>
      item.mediaType == 'series' || (details?.hasSeries() ?? false);

  String get _plot {
    final d = details;
    if (d == null) return '';
    if (d.hasSeries()) return d.series.plot;
    if (d.hasMovie()) return d.movie.plot;
    if (d.hasEpisode()) return d.episode.plot;
    return '';
  }

  List<String> get _genres {
    final d = details;
    if (d == null) return const [];
    if (d.hasSeries()) return d.series.genres;
    if (d.hasMovie()) return d.movie.genres;
    return const [];
  }

  String get _fanart {
    final d = details;
    final fromDetails = d == null
        ? ''
        : d.hasSeries()
            ? d.series.fanartUrl
            : d.hasMovie()
                ? d.movie.fanartUrl
                : '';
    return fromDetails.isNotEmpty ? fromDetails : item.bannerUrl;
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final seasons =
        details?.hasSeries() == true ? details!.series.seasons : <SeasonInfo>[];
    const overlap = 50.0;
    final noImage = _fanart.isEmpty;
    // No backdrop → the header shrinks to just the (safe-area-inset) back
    // button, and the poster + title flow in the content below instead of
    // straddling the header — so nothing overlaps the floating back button.
    final headerH =
        noImage ? topInset + 56.0 : (size.height * 0.28).clamp(200.0, 320.0);

    final backButton = SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
      ),
    );

    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 104,
        height: 156,
        child: item.posterUrl.isNotEmpty
            ? CachedNetworkImage(
                // Web-only, no-op on every other platform — see image_sizing.dart's
                // "ImageRenderMethodForWeb.HttpGet" section for why every
                // CachedNetworkImage call site in the app sets this.
                imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                imageUrl:
                    posterSrc(item.posterUrl, cacheWidthFor(context, 104)),
                memCacheWidth: cacheWidthFor(context, 104),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: AppTheme.surface2),
              )
            : const ColoredBox(color: AppTheme.surface2),
      ),
    );

    final titleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textHigh,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (item.rating > 0) '★ ${item.rating.toStringAsFixed(1)}',
            if (item.year > 0) '${item.year}',
            if (_isSeries && seasons.isNotEmpty) '${seasons.length} stagioni',
          ].join('  ·  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.textMid, fontSize: 13),
        ),
      ],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (noImage)
            SizedBox(
              height: headerH,
              width: double.infinity,
              child: ColoredBox(color: AppTheme.bg, child: backButton),
            )
          else
            // Backdrop with the poster protruding past its bottom edge
            // (Clip.none) — no negative padding, nothing a scroll view clips.
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: headerH,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        // Web-only, no-op on every other platform — see image_sizing.dart's
                        // "ImageRenderMethodForWeb.HttpGet" section for why every
                        // CachedNetworkImage call site in the app sets this.
                        imageRenderMethodForWeb:
                            ImageRenderMethodForWeb.HttpGet,
                        imageUrl: backdropSrc(
                            _fanart, backdropCacheWidth(context),
                            proxy: true),
                        memCacheWidth: backdropCacheWidth(context),
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.3),
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: AppTheme.surface),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.55, 1.0],
                            colors: [
                              Color(0x22000000),
                              Color(0x66000000),
                              AppTheme.bg
                            ],
                          ),
                        ),
                      ),
                      backButton,
                    ],
                  ),
                ),
                Positioned(left: 16, bottom: -overlap, child: poster),
                Positioned(
                  left: 16 + 104 + 14,
                  right: 16,
                  bottom: 12,
                  child: titleCol,
                ),
              ],
            ),
          if (noImage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  poster,
                  const SizedBox(width: 14),
                  Expanded(child: titleCol),
                ],
              ),
            ),
          Padding(
            padding:
                EdgeInsets.fromLTRB(16, noImage ? 16 : overlap + 14, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_genres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final g in _genres.take(4))
                          Chip(
                            label:
                                Text(g, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppTheme.surface,
                            side: const BorderSide(color: AppTheme.border),
                          ),
                      ],
                    ),
                  ),
                _PlayButton(
                  pluginId: pluginId,
                  item: item,
                  details: details,
                  isSeries: _isSeries,
                ),
                const SizedBox(height: 16),
                if (loading && _plot.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_plot.isNotEmpty)
                  Text(
                    _plot,
                    style: const TextStyle(
                        color: AppTheme.textMid, fontSize: 14, height: 1.45),
                  ),
                if (_isSeries && seasons.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Seasons(
                    seasons: seasons,
                    pluginId: pluginId,
                    onPlayEpisode: (season, eps, i) {
                      resolveAndPlay(
                        context,
                        pluginId,
                        eps[i].id,
                        extra: <String, dynamic>{
                          'title': eps[i].title,
                          'showTitle': item.title,
                          'poster': eps[i].thumbnailUrl.isNotEmpty
                              ? eps[i].thumbnailUrl
                              : item.posterUrl,
                          'seriesPoster': item.posterUrl,
                          'parentId': season.directoryId,
                          'episodeList': eps.map((e) => e.id).toList(),
                          'episodeTitles': eps.map((e) => e.title).toList(),
                          'episodeThumbs':
                              eps.map((e) => e.thumbnailUrl).toList(),
                          'episodeIndex': i,
                          // Same as _play() above: without these, auto-advance
                          // across a season boundary silently no-ops.
                          'allSeasonIds':
                              seasons.map((s) => s.directoryId).toList(),
                          'allSeasonLabels':
                              seasons.map((s) => s.label).toList(),
                          'seasonIndex': seasons.indexOf(season),
                          // Series-level metadata for the continue-watching
                          // card + its hero — always the series' own plot,
                          // never the episode's (see _plot getter above,
                          // already series-preferring via hasSeries()).
                          'plot': _plot,
                          'rating': item.rating,
                          'year': (details?.hasSeries() == true &&
                                  details!.series.year > 0)
                              ? details!.series.year
                              : item.year,
                          'genres': _genres,
                        },
                      );
                    },
                  ),
                ],
                _RelatedRow(pluginId: pluginId, details: details),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The main "play" CTA — checks for an existing Continue Watching entry for
/// this series/movie and, if found, resumes it directly instead of always
/// defaulting to season 1 episode 1 (series) or restarting from 0 (movie).
/// Best-effort: any failure of the CW lookup silently falls back to the
/// original "play from start" behaviour.
class _PlayButton extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  final DetailsResponse? details;
  final bool isSeries;

  const _PlayButton({
    required this.pluginId,
    required this.item,
    required this.details,
    required this.isSeries,
  });

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  ContinueWatchingItem? _resume;

  @override
  void initState() {
    super.initState();
    _checkResume();
  }

  Future<void> _checkResume() async {
    try {
      final repo = getIt<MediaRepository>();
      final items = widget.isSeries
          ? await repo.getContinueWatching(
              pluginId: widget.pluginId, parentId: widget.item.id)
          : await repo.getContinueWatching(pluginId: widget.pluginId);
      if (!mounted) return;
      final match = widget.isSeries
          ? items.firstOrNull
          : items
              .where((i) =>
                  i.parentID.isEmpty && i.playableID == widget.item.id)
              .firstOrNull;
      // A "next episode" row parked at ~31s just to clear mycelium's
      // progress_time>=30 filter (see PlaybackProgress.maybeClear) isn't a
      // real resume point — same guard the home Continue Watching card uses.
      final isRealProgress = match != null &&
          !(match.totalTime <= 0 && match.progressTime <= 35);
      if (isRealProgress && mounted) setState(() => _resume = match);
    } catch (_) {
      // best-effort — falls back to the default "play from start" button
    }
  }

  Future<void> _play(BuildContext context) async {
    final resume = _resume;
    if (resume != null) {
      // Same minimal push as the home Continue Watching card's _resume() —
      // playableID is an already-resolved stream id, passed as streamId so
      // the player calls ResolveStream directly instead of re-running
      // GetStreams on a stream id.
      context.push(
        '/player/${widget.pluginId}/${Uri.encodeComponent(resume.playableID)}',
        extra: <String, dynamic>{
          'streamId': resume.playableID,
          'title': resume.title,
          'showTitle': resume.showTitle,
          'poster':
              resume.poster.isNotEmpty ? resume.poster : widget.item.posterUrl,
          'parentId': resume.parentID,
          'seekTo': resume.progressTime.toInt(),
        },
      );
      return;
    }
    if (widget.isSeries) {
      final seasons = widget.details?.hasSeries() == true
          ? widget.details!.series.seasons
          : const <SeasonInfo>[];
      if (seasons.isNotEmpty) {
        final season = seasons.firstWhere((s) => s.episodeCount > 0,
            orElse: () => seasons.first);
        final browse = await getIt<MediaRepository>()
            .browse(widget.pluginId, season.directoryId, '');
        if (!context.mounted) return;
        if (browse.episodes.isNotEmpty) {
          final eps = browse.episodes;
          final series =
              widget.details?.hasSeries() == true ? widget.details!.series : null;
          await resolveAndPlay(
            context,
            widget.pluginId,
            eps.first.id,
            extra: <String, dynamic>{
              'title': eps.first.title,
              'showTitle': widget.item.title,
              'poster': eps.first.thumbnailUrl.isNotEmpty
                  ? eps.first.thumbnailUrl
                  : widget.item.posterUrl,
              'seriesPoster': widget.item.posterUrl,
              'parentId': season.directoryId,
              'episodeList': eps.map((e) => e.id).toList(),
              'episodeTitles': eps.map((e) => e.title).toList(),
              'episodeThumbs': eps.map((e) => e.thumbnailUrl).toList(),
              'episodeIndex': 0,
              'allSeasonIds': seasons.map((s) => s.directoryId).toList(),
              'allSeasonLabels': seasons.map((s) => s.label).toList(),
              'seasonIndex': seasons.indexOf(season),
              // Series-level metadata for the continue-watching card + its
              // hero — always the series' own plot, never the episode's.
              'plot': series?.plot ?? '',
              'rating': widget.item.rating,
              'year': (series?.year ?? 0) > 0 ? series!.year : widget.item.year,
              'genres': series?.genres.toList() ?? const <String>[],
            },
          );
          return;
        }
      }
    }
    await resolveAndPlay(
      context,
      widget.pluginId,
      widget.item.id,
      extra: <String, dynamic>{
        'title': widget.item.title,
        'poster': widget.item.posterUrl,
        'mediaType': widget.item.mediaType,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final resume = _resume;
    return FilledButton.icon(
      onPressed: () => _play(context),
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(
        resume != null
            ? 'Riprendi «${resume.title}»'
            : (widget.isSeries ? 'Riproduci 1ª puntata' : 'Riproduci'),
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
      ),
    );
  }
}

class _Seasons extends StatefulWidget {
  final List<SeasonInfo> seasons;
  final String pluginId;
  final void Function(SeasonInfo season, List<EpisodeInfo> eps, int index)
      onPlayEpisode;

  const _Seasons({
    required this.seasons,
    required this.pluginId,
    required this.onPlayEpisode,
  });

  @override
  State<_Seasons> createState() => _SeasonsState();
}

class _SeasonsState extends State<_Seasons> {
  static const _pageSize = 12;
  int _sel = 0;
  int _shown = _pageSize;
  final _cache = <String, List<EpisodeInfo>>{};
  bool _busy = false;
  ScrollPosition? _scrollPos;

  @override
  void initState() {
    super.initState();
    _load(widget.seasons.first);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reveal more episodes as the page scrolls down instead of a "Mostra
    // altri" button; the window cap still avoids building a huge season at
    // once inside this SingleChildScrollView.
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _scrollPos) {
      _scrollPos?.removeListener(_onScroll);
      _scrollPos = pos;
      _scrollPos?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollPos?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => _maybeGrow();

  /// Reveal another batch when scrolled near the bottom, or immediately when
  /// the page is too short to scroll at all (few episodes / no backdrop) —
  /// there's no "load more" button any more.
  void _maybeGrow() {
    if (!mounted) return;
    final eps = _cache[widget.seasons[_sel].directoryId] ?? const [];
    if (_shown >= eps.length) return;
    final pos = _scrollPos;
    final notScrollable =
        pos == null || !pos.hasContentDimensions || pos.maxScrollExtent <= 4;
    final nearBottom = pos != null &&
        pos.hasContentDimensions &&
        pos.pixels >= pos.maxScrollExtent - 700;
    if (notScrollable || nearBottom) {
      setState(() => _shown = (_shown + _pageSize).clamp(0, eps.length));
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeGrow());
    }
  }

  Future<void> _load(SeasonInfo s) async {
    if (_cache.containsKey(s.directoryId)) return;
    setState(() => _busy = true);
    try {
      final b = await getIt<MediaRepository>()
          .browse(widget.pluginId, s.directoryId, '');
      _cache[s.directoryId] = b.episodes;
    } catch (_) {
      _cache[s.directoryId] = const [];
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeGrow());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final season = widget.seasons[_sel];
    final eps = _cache[season.directoryId] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.seasons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = widget.seasons[i];
              final selected = i == _sel;
              return ChoiceChip(
                label:
                    Text(s.label.isNotEmpty ? s.label : 'Stagione ${s.number}'),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _sel = i;
                    _shown = _pageSize;
                  });
                  _load(s);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (_busy && eps.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          for (var i = 0; i < eps.length && i < _shown; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 92,
                    height: 52,
                    child: eps[i].thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            // Web-only, no-op on every other platform — see image_sizing.dart's
                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                            // CachedNetworkImage call site in the app sets this.
                            imageRenderMethodForWeb:
                                ImageRenderMethodForWeb.HttpGet,
                            imageUrl: posterSrc(
                                eps[i].thumbnailUrl, cacheWidthFor(context, 92),
                                proxy: true),
                            memCacheWidth: cacheWidthFor(context, 92),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: AppTheme.surface2),
                          )
                        : const ColoredBox(color: AppTheme.surface2),
                  ),
                ),
                title: Text(
                  '${eps[i].episodeNumber}. ${eps[i].title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppTheme.textHigh, fontSize: 14),
                ),
                subtitle: eps[i].duration > 0
                    ? Text('${eps[i].duration} min',
                        style: const TextStyle(
                            color: AppTheme.textLow, fontSize: 12))
                    : null,
                onTap: () => widget.onPlayEpisode(season, eps, i),
              ),
            ),
          if (eps.length > _shown)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// "Correlati" / "Simili" — decoded from `details.item.extra['related' |
/// 'similar']` (JSON arrays of `{id, title, poster, rel}`). Tap → open that
/// title's details page.
class _RelatedRow extends StatelessWidget {
  final String pluginId;
  final DetailsResponse? details;
  const _RelatedRow({required this.pluginId, required this.details});

  List<Map<String, dynamic>> _decode(String raw) {
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = details?.item.extra;
    if (ex == null) return const SizedBox.shrink();
    final related = _decode(ex['related'] ?? '');
    final similar = _decode(ex['similar'] ?? '');
    if (related.isEmpty && similar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (related.isNotEmpty) _section(context, 'Correlati', related),
        if (similar.isNotEmpty) _section(context, 'Simili', similar),
      ],
    );
  }

  Widget _section(
      BuildContext context, String title, List<Map<String, dynamic>> items) {
    const cardW = 116.0;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            height: cardW * 3 / 2 + 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final e = items[i];
                final id = (e['id'] as String?) ?? '';
                final t = (e['title'] as String?) ?? '';
                final poster = (e['poster'] as String?) ?? '';
                final rel = _relLabel((e['rel'] as String?) ?? '');
                return SizedBox(
                  width: cardW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: AppTheme.surface,
                        clipBehavior: Clip.antiAlias,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: id.isEmpty
                              ? null
                              : () => context.push(
                                  '/details/$pluginId/${Uri.encodeComponent(id)}'),
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 2 / 3,
                                child: poster.isNotEmpty
                                    ? CachedNetworkImage(
                                        // Web-only, no-op on every other platform — see image_sizing.dart's
                                        // "ImageRenderMethodForWeb.HttpGet" section for why every
                                        // CachedNetworkImage call site in the app sets this.
                                        imageRenderMethodForWeb:
                                            ImageRenderMethodForWeb.HttpGet,
                                        imageUrl: posterSrc(poster,
                                            cacheWidthFor(context, cardW),
                                            proxy: true),
                                        memCacheWidth:
                                            cacheWidthFor(context, cardW),
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const ColoredBox(
                                                color: AppTheme.surface2),
                                      )
                                    : const ColoredBox(
                                        color: AppTheme.surface2),
                              ),
                              if (rel.isNotEmpty)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(rel,
                                        style: const TextStyle(
                                            color: AppTheme.textHigh,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(t,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textMid, fontSize: 12.5)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _relLabel(String r) => switch (r) {
        'SEQUEL' => 'Sequel',
        'PREQUEL' => 'Prequel',
        'SIDE_STORY' => 'Side story',
        'SPIN_OFF' => 'Spin-off',
        _ => '',
      };
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: AppTheme.bg),
      body: ErrorRetryView(
        title: 'Impossibile caricare il contenuto',
        detail: message,
        onRetry: onRetry,
      ),
    );
  }
}
