import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart';
import '../../../core/theme/app_scale.dart';
import '../../../shared/widgets/error_retry_view.dart';
import '../../../shared/widgets/live_event_popup.dart';
import '../../../shared/widgets/media_catalog_card.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';

// Ratios — 1920×1080 baseline
const double _rBrHPad = 48 / 1920;
const double _rBrVPad = 28 / 1080;
const double _rBrCardW = 200 / 1920; // ~5 cards visible @ 1920
const double _rBrCardGap = 20 / 1920;
const double _rBrTileH = 72 / 1080;

class BrowseScreen extends StatelessWidget {
  final String pluginId;
  final String parentId;
  final String title;

  const BrowseScreen({
    super.key,
    required this.pluginId,
    required this.parentId,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DiscoveryBloc>()
        ..add(LoadBrowseEvent(pluginId: pluginId, parentId: parentId)),
      child: _BrowseView(pluginId: pluginId, parentId: parentId, title: title),
    );
  }
}

class _BrowseView extends StatelessWidget {
  final String pluginId;
  final String parentId;
  final String title;
  const _BrowseView(
      {required this.pluginId, required this.parentId, required this.title});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
        canRequestFocus: false,
        onEsc: () => context.pop(),
        builder: (context, _) => Scaffold(
              backgroundColor: Colors.black,
              body: BlocBuilder<DiscoveryBloc, DiscoveryState>(
                builder: (context, state) {
                  if (state is DiscoveryLoading || state is DiscoveryInitial) {
                    return Center(
                        child: PileusSpinner(
                            size: AppScale.spinnerL(context),
                            color: Colors.white));
                  }
                  if (state is DiscoveryError) {
                    return ErrorRetryView(
                      message: 'Impossibile caricare il contenuto.',
                      detail: state.errorCode,
                      onRetry: () => context.read<DiscoveryBloc>().add(
                          LoadBrowseEvent(
                              pluginId: pluginId, parentId: parentId)),
                      onSecondary: () => context.pop(),
                      secondaryLabel: 'Indietro',
                    );
                  }
                  if (state is DiscoveryLoaded) {
                    if (state.items.isEmpty) {
                      return const ErrorRetryView(
                        title: 'Niente da mostrare',
                        message: 'Questa sezione è vuota.',
                        icon: Icons.inbox_outlined,
                        autofocus: false,
                      );
                    }
                    return _BrowseContent(
                        pluginId: pluginId, title: title, items: state.items);
                  }
                  return Center(
                      child: PileusSpinner(
                          size: AppScale.spinnerL(context),
                          color: Colors.white));
                },
              ),
            )); // Scaffold + TvFocusable
  }
}

bool _isEpisodeList(List<CatalogItem> items) {
  if (items.isEmpty) return false;
  final first = items.first;
  return !first.isDir &&
      (first.episodeNumber > 0 ||
          (first.extra['anilist_id'] ?? '').isNotEmpty ||
          (first.extra['mal_id'] ?? '').isNotEmpty);
}

class _BrowseContent extends StatelessWidget {
  final String pluginId;
  final String title;
  final List<CatalogItem> items;

  const _BrowseContent({
    required this.pluginId,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final hPad = w * _rBrHPad;
        final vPad = h * _rBrVPad;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 0),
              child: Row(
                children: [
                  // Autofocus only when the list/grid below is empty and
                  // won't autofocus its own first item — otherwise nothing
                  // in the screen ever claims focus and the D-pad is dead.
                  _BackButton(
                      onTap: () => context.pop(), autofocus: items.isEmpty),
                  SizedBox(width: w * 0.010),
                  if (title.isNotEmpty)
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: h * 0.026,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: h * 0.014),
            Expanded(
              child: _isEpisodeList(items)
                  ? _EpisodeListView(
                      pluginId: pluginId,
                      showTitle: title,
                      items: items,
                      hPad: hPad,
                      tileH: h * _rBrTileH)
                  : _PosterGridView(
                      pluginId: pluginId,
                      items: items,
                      hPad: hPad,
                      cardW: w * _rBrCardW,
                      cardGap: w * _rBrCardGap),
            ),
          ],
        );
      },
    );
  }
}

// ── back button ───────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool autofocus;
  const _BackButton({required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onActivate: onTap,
      onEsc: onTap,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: focused
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          color: Colors.white.withValues(alpha: focused ? 1.0 : 0.7),
          size: 24,
        ),
      ),
    );
  }
}

// ── Episode list (anime) ──────────────────────────────────────────────────────

class _EpisodeListView extends StatelessWidget {
  final String pluginId;
  final String showTitle;
  final List<CatalogItem> items;
  final double hPad;
  final double tileH;

  const _EpisodeListView({
    required this.pluginId,
    required this.showTitle,
    required this.items,
    required this.hPad,
    required this.tileH,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
        itemCount: items.length,
        itemBuilder: (context, i) {
          return _EpisodeTile(
            pluginId: pluginId,
            showTitle: showTitle,
            item: items[i],
            tileH: tileH,
            autofocus: i == 0,
          );
        },
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final String pluginId;
  final String showTitle;
  final CatalogItem item;
  final double tileH;
  final bool autofocus;

  const _EpisodeTile({
    required this.pluginId,
    required this.showTitle,
    required this.item,
    required this.tileH,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final epNum = item.episodeNumber > 0 ? item.episodeNumber : null;

    void navigate() {
      final isAnime = (item.extra['anilist_id'] ?? '').isNotEmpty ||
          (item.extra['mal_id'] ?? '').isNotEmpty;
      if (isAnime) {
        context.push(
          '/episode/$pluginId/${Uri.encodeComponent(item.id)}',
          extra: {'showTitle': showTitle},
        );
      } else if (item.isDir) {
        context.push(
          '/browse/$pluginId/${Uri.encodeComponent(item.id)}',
          extra: item.title,
        );
      } else if (item.mediaType == 'live') {
        showLiveEventPopup(context, pluginId, item);
      } else {
        // Carry the card metadata through so the continue-watching entry
        // this play creates is complete from the first save (title, poster,
        // rating, year, genres, plot) instead of a bare row that only fills
        // in later, if a detail lookup happens to succeed. _saveProgress /
        // the backend's keep-if-empty upsert do the rest.
        final genreList = (item.extra['genres'] ?? '')
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList();
        context.push(
          '/player/$pluginId/${Uri.encodeComponent(item.id)}',
          extra: <String, dynamic>{
            if (item.title.isNotEmpty) 'title': item.title,
            if (showTitle.isNotEmpty) 'showTitle': showTitle,
            if (item.posterUrl.isNotEmpty) 'poster': item.posterUrl,
            if (item.rating > 0) 'rating': item.rating,
            if (item.year > 0) 'year': item.year,
            if (genreList.isNotEmpty) 'genres': genreList,
            if ((item.extra['plot'] ?? '').isNotEmpty)
              'plot': item.extra['plot'],
          },
        );
      }
    }

    return TvFocusable(
      autofocus: autofocus,
      onActivate: navigate,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: EdgeInsets.only(bottom: tileH * 0.07),
        padding: EdgeInsets.symmetric(
            horizontal: tileH * 0.26, vertical: tileH * 0.22),
        decoration: BoxDecoration(
          color: focused
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused ? Colors.white54 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: tileH * 0.80,
              child: Text(
                epNum != null ? '$epNum' : '—',
                style: TextStyle(
                  color: focused ? Colors.white : Colors.white38,
                  fontSize: tileH * 0.36,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            SizedBox(width: tileH * 0.20),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: focused ? Colors.white : Colors.white70,
                  fontSize: tileH * 0.24,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: tileH * 0.16),
            Icon(
              Icons.chevron_right_rounded,
              color: focused ? Colors.white : Colors.white24,
              size: tileH * 0.38,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Poster grid (generic) ─────────────────────────────────────────────────────

class _PosterGridView extends StatelessWidget {
  final String pluginId;
  final List<CatalogItem> items;
  final double hPad;
  final double cardW;
  final double cardGap;

  const _PosterGridView({
    required this.pluginId,
    required this.items,
    required this.hPad,
    required this.cardW,
    required this.cardGap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth - hPad * 2;
        final cols = (avail / (cardW + cardGap)).floor().clamp(2, 10);
        // Actual cell size the grid will render, not the nominal ratio used
        // above just to pick the column count — keeps the card in sync with
        // the real cell regardless of screen resolution.
        final actualCardW = (avail - cardGap * (cols - 1)) / cols;
        final actualCardH = actualCardW * 3 / 2;

        return FocusTraversalGroup(
          child: GridView.builder(
            // Top padding isn't decorative here: MediaCatalogCard grows 8%
            // on focus (AnimatedScale, centered), and the scrollable clips
            // hard at its own edge (Clip.hardEdge, the default) — with zero
            // top padding, focusing a card in row 0 clipped its glow/border
            // against that edge instead of scaling cleanly. Same class of
            // bug already fixed for the shared SDUI carousel's reserved
            // scale buffer.
            padding: EdgeInsets.fromLTRB(hPad, actualCardH * 0.08, hPad, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: cardGap,
              crossAxisSpacing: cardGap,
              childAspectRatio: 2 / 3,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return MediaCatalogCard(
                title: item.title,
                posterUrl: item.posterUrl,
                width: actualCardW,
                height: actualCardH,
                onTap: () {
                  if (item.isDir) {
                    context.push(
                      '/browse/$pluginId/${Uri.encodeComponent(item.id)}',
                      extra: item.title,
                    );
                  } else {
                    if (item.mediaType == 'live') {
                      showLiveEventPopup(context, pluginId, item);
                    } else {
                      context.push(
                          '/player/$pluginId/${Uri.encodeComponent(item.id)}');
                    }
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
