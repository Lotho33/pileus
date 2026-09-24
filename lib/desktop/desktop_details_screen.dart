import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../shared/responsive.dart';
import '../shared/widgets/error_retry_view.dart';
import 'widgets/desktop_dialogs.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Desktop-native details page: a wide backdrop header with the poster and
/// actions overlaid, then (for a series) season chips + an episode grid, and
/// related / similar rows.
class DesktopDetailsScreen extends StatelessWidget {
  final String pluginId;
  final String mediaId;
  final CatalogItem? preview;

  const DesktopDetailsScreen({
    super.key,
    required this.pluginId,
    required this.mediaId,
    this.preview,
  });

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DetailsBloc(
        getIt<MediaRepository>(),
        onSessionExpired: () =>
            getIt<AuthBloc>().add(const SessionExpiredEvent()),
      )..add(LoadDetailsEvent(pluginId: pluginId, mediaId: mediaId)),
      // Esc goes back on desktop — there's no platform back / didPopRoute
      // there, so without this the only way off this pushed route is the
      // small header back button. autofocus gives CallbackShortcuts a focus
      // node so Esc works before the user tabs into the content.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _back(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppTheme.bg,
            body: BlocBuilder<DetailsBloc, DetailsState>(
              builder: (context, s) {
                if (s is DetailsError) {
                  return _Error(
                    message: s.message,
                    onRetry: () => context.read<DetailsBloc>().add(
                        LoadDetailsEvent(
                            pluginId: pluginId, mediaId: mediaId)),
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
          ),
        ),
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

  String get _logo {
    final d = details;
    if (d == null) return item.logoUrl;
    final l = d.hasSeries()
        ? d.series.logoUrl
        : d.hasMovie()
            ? d.movie.logoUrl
            : '';
    return l.isNotEmpty ? l : item.logoUrl;
  }

  String get _fanart {
    final d = details;
    final f = d == null
        ? ''
        : d.hasSeries()
            ? d.series.fanartUrl
            : d.hasMovie()
                ? d.movie.fanartUrl
                : '';
    return f.isNotEmpty ? f : item.bannerUrl;
  }

  List<SeasonInfo> get _seasons =>
      details?.hasSeries() == true ? details!.series.seasons : const [];

  Future<void> _play(BuildContext context) async {
    if (_isSeries && _seasons.isNotEmpty) {
      final season = _seasons.firstWhere((s) => s.episodeCount > 0,
          orElse: () => _seasons.first);
      final browse = await getIt<MediaRepository>()
          .browse(pluginId, season.directoryId, '');
      if (!context.mounted) return;
      if (browse.episodes.isNotEmpty) {
        _playEpisode(context, season, browse.episodes, 0);
        return;
      }
    }
    await resolveAndPlay(
      context,
      pluginId,
      item.id,
      extra: {
        'title': item.title,
        'poster': item.posterUrl,
        'mediaType': item.mediaType,
      },
      sourcePicker: showDesktopSourcePicker,
    );
  }

  void _playEpisode(
      BuildContext context, SeasonInfo season, List<EpisodeInfo> eps, int i) {
    resolveAndPlay(
      context,
      pluginId,
      eps[i].id,
      extra: {
        'title': eps[i].title,
        'showTitle': item.title,
        'poster': eps[i].thumbnailUrl.isNotEmpty
            ? eps[i].thumbnailUrl
            : item.posterUrl,
        'seriesPoster': item.posterUrl,
        'parentId': season.directoryId,
        'episodeList': eps.map((e) => e.id).toList(),
        'episodeTitles': eps.map((e) => e.title).toList(),
        'episodeThumbs': eps.map((e) => e.thumbnailUrl).toList(),
        'episodeIndex': i,
        // Without these, auto-advance/next-episode across a season boundary
        // silently no-ops — same fields mobile's equivalent call sites send.
        'allSeasonIds': _seasons.map((s) => s.directoryId).toList(),
        'allSeasonLabels': _seasons.map((s) => s.label).toList(),
        'seasonIndex': _seasons.indexOf(season),
        // Series-level metadata for the continue-watching card + its hero —
        // always the series' own plot, never the episode's (_plot already
        // prefers hasSeries() over hasEpisode()/hasMovie() above).
        'plot': _plot,
        'rating': item.rating,
        'year': (details?.hasSeries() == true && details!.series.year > 0)
            ? details!.series.year
            : item.year,
        'genres': _genres,
      },
      sourcePicker: showDesktopSourcePicker,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, bp, c) {
        final headerH = (c.maxHeight * 0.52).clamp(360.0, 620.0);
        final big = bp.atLeastLarge;
        // One left edge for the poster/metadata and the rows below it.
        final pad = bp.gutter;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                pluginId: pluginId,
                fanart: _fanart,
                logo: _logo,
                item: item,
                seasons: _seasons,
                isSeries: _isSeries,
                plot: _plot,
                genres: _genres,
                loading: loading,
                height: headerH,
                pad: pad,
                big: big,
                onPlay: () => _play(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isSeries && _seasons.isNotEmpty)
                          _DesktopSeasons(
                            seasons: _seasons,
                            pluginId: pluginId,
                            onPlay: (s, eps, i) =>
                                _playEpisode(context, s, eps, i),
                          ),
                        _RelatedRows(pluginId: pluginId, details: details),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String pluginId;
  final String fanart;
  final String logo;
  final CatalogItem item;
  final List<SeasonInfo> seasons;
  final bool isSeries;
  final String plot;
  final List<String> genres;
  final bool loading;
  final double height;
  final double pad;
  final bool big;
  final VoidCallback onPlay;

  const _Header({
    required this.pluginId,
    required this.fanart,
    required this.logo,
    required this.item,
    required this.seasons,
    required this.isSeries,
    required this.plot,
    required this.genres,
    required this.loading,
    required this.height,
    required this.pad,
    required this.big,
    required this.onPlay,
  });

  Widget _poster(BuildContext context, double w) {
    final h = w * 3 / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: w,
        height: h,
        child: item.posterUrl.isNotEmpty
            ? CachedNetworkImage(
                // Web-only, no-op on every other platform — see image_sizing.dart's
                // "ImageRenderMethodForWeb.HttpGet" section for why every
                // CachedNetworkImage call site in the app sets this.
                imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                imageUrl: posterSrc(item.posterUrl, cacheWidthFor(context, w)),
                memCacheWidth: cacheWidthFor(context, w),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: AppTheme.surface2),
              )
            : const ColoredBox(color: AppTheme.surface2),
      ),
    );
  }

  Widget _infoCol(BuildContext context) {
    final meta = <String>[
      if (item.rating > 0) '★ ${item.rating.toStringAsFixed(1)}',
      if (item.year > 0) '${item.year}',
      if (isSeries && seasons.isNotEmpty)
        '${seasons.length} stagion${seasons.length == 1 ? 'e' : 'i'}',
    ].join('   ·   ');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logo.isNotEmpty && !logo.endsWith('.svg'))
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: big ? 130 : 100, maxWidth: big ? 460 : 360),
              child: CachedNetworkImage(
                // Web-only, no-op on every other platform — see image_sizing.dart's
                // "ImageRenderMethodForWeb.HttpGet" section for why every
                // CachedNetworkImage call site in the app sets this.
                imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                imageUrl: logo,
                memCacheWidth: cacheWidthFor(context, 460),
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorWidget: (_, __, ___) => _Title(item.title, big: big),
              ),
            )
          else
            _Title(item.title, big: big),
          if (meta.isNotEmpty) ...[
            SizedBox(height: big ? 14 : 10),
            Text(meta,
                style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: big ? 15 : 13,
                    fontWeight: FontWeight.w600)),
          ],
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in genres.take(4))
                  Chip(
                    label: Text(g, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white10,
                    side: const BorderSide(color: AppTheme.border),
                  ),
              ],
            ),
          ],
          if (plot.isNotEmpty) ...[
            SizedBox(height: big ? 14 : 10),
            Text(plot,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: big ? 14 : 13,
                    height: 1.45)),
          ] else if (loading) ...[
            const SizedBox(height: 12),
            const SizedBox(width: 160, child: LinearProgressIndicator()),
          ],
          SizedBox(height: big ? 22 : 16),
          _PlayButton(
            pluginId: pluginId,
            item: item,
            isSeries: isSeries,
            big: big,
            onPlayDefault: onPlay,
          ),
        ],
      ),
    );
  }

  Widget _backBtn(BuildContext context) => IconButton.filledTonal(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
      );

  @override
  Widget build(BuildContext context) {
    final posterW = big ? 220.0 : 168.0;

    // No backdrop → don't fake one with a tall black band. Compact top: back
    // button, then poster + info near the top on the plain page ground.
    if (fanart.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backBtn(context),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _poster(context, posterW * 0.85),
                const SizedBox(width: 24),
                Expanded(child: _infoCol(context)),
              ],
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            // Web-only, no-op on every other platform — see image_sizing.dart's
            // "ImageRenderMethodForWeb.HttpGet" section for why every
            // CachedNetworkImage call site in the app sets this.
            imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
            imageUrl:
                backdropSrc(fanart, backdropCacheWidth(context), proxy: true),
            memCacheWidth: backdropCacheWidth(context),
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.25),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: AppTheme.surface),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.6, 1.0],
                colors: [
                  Color(0xF00D0D1A),
                  Color(0x800D0D1A),
                  Color(0x000D0D1A),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0.0, 0.5],
                colors: [AppTheme.bg, Colors.transparent],
              ),
            ),
          ),
          Positioned(top: 16, left: 16, child: _backBtn(context)),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, big ? 40 : 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _poster(context, posterW),
                  const SizedBox(width: 24),
                  Expanded(child: _infoCol(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The main "play" CTA — checks for an existing Continue Watching entry for
/// this series/movie and, if found, resumes it directly instead of
/// delegating to [onPlayDefault] (which always starts from season 1 episode
/// 1, or from 0 for a movie). Best-effort: any failure of the CW lookup
/// silently falls back to [onPlayDefault].
class _PlayButton extends StatefulWidget {
  final String pluginId;
  final CatalogItem item;
  final bool isSeries;
  final bool big;
  final VoidCallback onPlayDefault;

  const _PlayButton({
    required this.pluginId,
    required this.item,
    required this.isSeries,
    required this.big,
    required this.onPlayDefault,
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
      // best-effort — falls back to onPlayDefault
    }
  }

  void _play(BuildContext context) {
    final resume = _resume;
    if (resume == null) {
      widget.onPlayDefault();
      return;
    }
    // Same minimal push as the home Continue Watching card's resume — see
    // mobile_home_screen.dart's _CwCard._resume() for the identical pattern.
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
        backgroundColor: AppTheme.textHigh,
        foregroundColor: AppTheme.bg,
        padding: EdgeInsets.symmetric(
            horizontal: widget.big ? 28 : 22, vertical: widget.big ? 18 : 14),
        textStyle: TextStyle(
            fontSize: widget.big ? 15 : 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final bool big;
  const _Title(this.text, {required this.big});

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textHigh,
          fontSize: big ? 40 : 30,
          fontWeight: FontWeight.w800,
          height: 1.08,
        ),
      );
}

// ── Seasons + episodes ─────────────────────────────────────────────────────

class _DesktopSeasons extends StatefulWidget {
  final List<SeasonInfo> seasons;
  final String pluginId;
  final void Function(SeasonInfo season, List<EpisodeInfo> eps, int index)
      onPlay;

  const _DesktopSeasons({
    required this.seasons,
    required this.pluginId,
    required this.onPlay,
  });

  @override
  State<_DesktopSeasons> createState() => _DesktopSeasonsState();
}

class _DesktopSeasonsState extends State<_DesktopSeasons> {
  static const _pageSize = 24;
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
    // Grow the visible window as the page scrolls toward the bottom — no
    // "load more" button, and the cap keeps a 1000-episode season from
    // building every card at once.
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

  /// Reveal another batch if the page is scrolled near the bottom OR isn't
  /// scrollable at all yet (short page — e.g. a series with no backdrop and
  /// only a handful of episodes, where there is no scroll event to react
  /// to). Loops per frame until the list either fills past the viewport or
  /// every episode is shown.
  void _maybeGrow() {
    if (!mounted) return;
    final eps = _cache[widget.seasons[_sel].directoryId] ?? const [];
    if (_shown >= eps.length) return;
    final pos = _scrollPos;
    final notScrollable =
        pos == null || !pos.hasContentDimensions || pos.maxScrollExtent <= 4;
    final nearBottom = pos != null &&
        pos.hasContentDimensions &&
        pos.pixels >= pos.maxScrollExtent - 900;
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
    final shown = eps.take(_shown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 12),
          child: Text('Episodi',
              style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ),
        if (widget.seasons.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < widget.seasons.length; i++)
                  ChoiceChip(
                    label: Text(widget.seasons[i].label.isNotEmpty
                        ? widget.seasons[i].label
                        : 'Stagione ${widget.seasons[i].number}'),
                    selected: i == _sel,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _sel = i;
                        _shown = _pageSize;
                      });
                      _load(widget.seasons[i]);
                    },
                  ),
              ],
            ),
          ),
        if (_busy && eps.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (eps.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nessun episodio.',
                style: TextStyle(color: AppTheme.textMid)),
          )
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: 128,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: shown.length,
            itemBuilder: (_, i) => _EpisodeCard(
              ep: shown[i],
              index: i,
              onPlay: () => widget.onPlay(season, eps, i),
            ),
          ),
          if (eps.length > _shown)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  final EpisodeInfo ep;
  final int index;
  final VoidCallback onPlay;
  const _EpisodeCard(
      {required this.ep, required this.index, required this.onPlay});

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ep = widget.ep;
    final n = ep.episodeNumber > 0 ? ep.episodeNumber : widget.index + 1;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: Container(
          decoration: BoxDecoration(
            color: _hover ? Colors.white10 : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 176,
                  height: 99,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ep.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              // Web-only, no-op on every other platform — see image_sizing.dart's
                              // "ImageRenderMethodForWeb.HttpGet" section for why every
                              // CachedNetworkImage call site in the app sets this.
                              imageRenderMethodForWeb:
                                  ImageRenderMethodForWeb.HttpGet,
                              imageUrl: posterSrc(
                                  ep.thumbnailUrl, cacheWidthFor(context, 176),
                                  proxy: true),
                              memCacheWidth: cacheWidthFor(context, 176),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const ColoredBox(color: AppTheme.surface2),
                            )
                          : const ColoredBox(color: AppTheme.surface2),
                      if (_hover)
                        const ColoredBox(
                          color: Colors.black38,
                          child: Center(
                            child: Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 34),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$n. ${ep.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textHigh,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                    if (ep.plot.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(ep.plot,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textLow,
                              fontSize: 11.5,
                              height: 1.3)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Related / Similar ──────────────────────────────────────────────────────

class _RelatedRows extends StatelessWidget {
  final String pluginId;
  final DetailsResponse? details;
  const _RelatedRows({required this.pluginId, required this.details});

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
    const cardW = 150.0;
    const capSize = 13.0;
    final capH = captionBoxHeight(context, capSize);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: cardW * 3 / 2 + 8 + capH + 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final e = items[i];
                final id = (e['id'] as String?) ?? '';
                final t = (e['title'] as String?) ?? '';
                final poster = (e['poster'] as String?) ?? '';
                return Center(
                  child: _RelatedCard(
                    width: cardW,
                    title: t,
                    poster: poster,
                    captionHeight: capH,
                    captionSize: capSize,
                    onTap: id.isEmpty
                        ? null
                        : () => context.push(
                            '/details/$pluginId/${Uri.encodeComponent(id)}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedCard extends StatefulWidget {
  final double width;
  final String title;
  final String poster;
  final double captionHeight;
  final double captionSize;
  final VoidCallback? onTap;
  const _RelatedCard({
    required this.width,
    required this.title,
    required this.poster,
    required this.captionHeight,
    required this.captionSize,
    required this.onTap,
  });

  @override
  State<_RelatedCard> createState() => _RelatedCardState();
}

class _RelatedCardState extends State<_RelatedCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _hover ? 1.05 : 1,
                duration: const Duration(milliseconds: 130),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: widget.poster.isNotEmpty
                        ? CachedNetworkImage(
                            // Web-only, no-op on every other platform — see image_sizing.dart's
                            // "ImageRenderMethodForWeb.HttpGet" section for why every
                            // CachedNetworkImage call site in the app sets this.
                            imageRenderMethodForWeb:
                                ImageRenderMethodForWeb.HttpGet,
                            imageUrl: posterSrc(widget.poster,
                                cacheWidthFor(context, widget.width),
                                proxy: true),
                            memCacheWidth: cacheWidthFor(context, widget.width),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: AppTheme.surface2),
                          )
                        : const ColoredBox(color: AppTheme.surface2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: widget.captionHeight,
                child: Text(widget.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _hover ? AppTheme.textHigh : AppTheme.textMid,
                        fontSize: widget.captionSize,
                        height: 1.3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ErrorRetryView(
          title: 'Impossibile caricare il contenuto',
          detail: message,
          onRetry: onRetry,
        ),
        Positioned(
          top: 16,
          left: 16,
          child: IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
      ],
    );
  }
}
