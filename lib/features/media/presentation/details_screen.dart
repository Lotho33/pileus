import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_sizing.dart';
import '../../../core/utils/media_type.dart';
import '../../../shared/sdui/sport_theme.dart'
    show sportAccentColor, isLiveNow, liveStartTimeLabel;
import '../../../shared/widgets/error_retry_view.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/details_bloc.dart';
import '../bloc/details_event.dart';
import '../bloc/details_state.dart';
import '../data/continue_watching_item.dart';
import '../data/media_repository.dart';
import '../../player/episode_poster.dart';
import 'widgets/details_common.dart';
import 'widgets/series_page_layout.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

part 'details_screen/movie_layout.dart';
part 'details_screen/live_event_layout.dart';
part 'details_screen/anime_movie_layout.dart';
part 'details_screen/misc_layouts.dart';
part 'details_screen/watch_button.dart';

// ── Layout ratios — baseline 1920×1080 ────────────────────────────────────────
// Used inside LayoutBuilder: multiply by bc.maxWidth or bc.maxHeight.
// Horizontal padding used to be its own local _rDetHPad (48/1920) —
// consolidated onto AppScale.catalogHPadRatio (56/1920), the same source
// home_screen.dart and card_carousel_block_view.dart already share, so all
// three full-bleed catalog/details screens agree on one safe-margin value
// instead of three independently-tunable numbers.
// detailsVPadRatio/detailsPosterWRatio/detailsGapRatio (used by _MovieLayout
// and _AnimeMovieLayout below) now live in widgets/details_common.dart,
// shared with series_page_layout.dart's _SeriesPageLayout instead of
// duplicated privately in both.
class DetailsScreen extends StatelessWidget {
  final String pluginId;
  final String mediaId;

  const DetailsScreen({
    super.key,
    required this.pluginId,
    required this.mediaId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DetailsBloc>()
        ..add(LoadDetailsEvent(pluginId: pluginId, mediaId: mediaId)),
      child: _DetailsView(pluginId: pluginId, mediaId: mediaId),
    );
  }
}

class _DetailsView extends StatelessWidget {
  final String pluginId;
  final String mediaId;
  const _DetailsView({required this.pluginId, required this.mediaId});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
        canRequestFocus: false,
        onEsc: () => context.pop(),
        builder: (context, _) => Scaffold(
              backgroundColor: AppTheme.bg,
              body: BlocBuilder<DetailsBloc, DetailsState>(
                builder: (context, state) {
                  // A plain cut from the loading bridge straight to the final
                  // layout (a completely different widget tree — single column vs.
                  // two-column, depending on media_type) read as a hard flash on
                  // top of whatever position jump was already happening. The
                  // crossfade doesn't fix a wrong position by itself, but it's the
                  // difference between "that snapped" and "that resolved".
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: AppScale.fadeCurve,
                    switchOutCurve: AppScale.fadeCurve,
                    child: _buildForState(context, state),
                  );
                },
              ),
            )); // Scaffold + Focus
  }

  Widget _buildForState(BuildContext context, DetailsState state) {
    if (state is DetailsLoading || state is DetailsInitial) {
      // Deliberately a plain neutral background (the Scaffold's own
      // AppTheme.bg), not the item's fanart/poster — that used to give a
      // continuous-background impression, but the loading state's own
      // background rarely matches the final layout's (which varies by
      // media_type, unknown until GetDetails answers), so the "continuity"
      // just meant an extra, mismatched-looking backdrop flashing in and
      // back out for however long the request takes.
      return KeyedSubtree(
        key: const ValueKey('loading'),
        child: Center(
            child: PileusSpinner(
                size: AppScale.spinnerL(context), color: AppTheme.textHigh)),
      );
    }
    if (state is DetailsError) {
      return KeyedSubtree(
        key: const ValueKey('error'),
        child: ErrorRetryView(
          title: 'Impossibile caricare il contenuto',
          detail: state.message,
          onRetry: () => context
              .read<DetailsBloc>()
              .add(LoadDetailsEvent(pluginId: pluginId, mediaId: mediaId)),
          onSecondary: () => context.pop(),
          secondaryLabel: 'Indietro',
        ),
      );
    }
    if (state is DetailsLoaded) {
      return _DetailsContent(
        key: ValueKey('loaded_${state.response.item.id}'),
        pluginId: pluginId,
        response: state.response,
      );
    }
    return const SizedBox.shrink();
  }
}

bool _isAnime(CatalogItem item) =>
    (item.extra['anilist_id'] ?? '').isNotEmpty ||
    (item.extra['mal_id'] ?? '').isNotEmpty;

class _DetailsContent extends StatelessWidget {
  final String pluginId;
  final DetailsResponse response;

  const _DetailsContent(
      {super.key, required this.pluginId, required this.response});

  @override
  Widget build(BuildContext context) {
    final item = response.item;
    final kind = mediaKindOf(item.mediaType);

    if (kind == MediaKind.live) {
      if (item.isDir) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.pushReplacement(
            '/browse/$pluginId/${Uri.encodeComponent(item.id)}',
            extra: item.title,
          );
        });
        return Center(
            child: PileusSpinner(
                size: AppScale.spinnerL(context), color: AppTheme.textHigh));
      }
      return _LiveEventLayout(pluginId: pluginId, response: response);
    }

    if (kind == MediaKind.music) {
      return _MusicLayout(pluginId: pluginId, response: response);
    }

    if (kind == MediaKind.vodClip) {
      return _VodClipLayout(pluginId: pluginId, response: response);
    }

    // Resolved once here instead of each layout independently calling
    // response.hasMovie()/hasSeries() — single source of truth for the
    // rest of this dispatch.
    final movie = response.hasMovie() ? response.movie : null;
    final series = response.hasSeries() ? response.series : null;

    // Anime film (format=MOVIE/SPECIAL): no episode list
    if (_isAnime(item) && !item.isDir) {
      return _AnimeMovieLayout(
          pluginId: pluginId, item: item, series: series, movie: movie);
    }

    final seasons = series?.seasons ?? <SeasonInfo>[];

    // Defensive: a plugin can mark an item as a directory without actually
    // populating GetDetails().series.seasons (incomplete/buggy plugin) — the
    // series/anime layouts below never load anything in that case and show
    // a permanent "no episodes" dead end. Fall back to plain directory
    // browsing instead — same route open_catalog_item.dart already uses for
    // a generic non-series isDir item — rather than stranding the user.
    if (item.isDir && seasons.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.pushReplacement(
          '/browse/$pluginId/${Uri.encodeComponent(item.id)}',
          extra: item.title,
        );
      });
      return Center(
          child: PileusSpinner(
              size: AppScale.spinnerL(context), color: AppTheme.textHigh));
    }

    // Anime serie: two-column with inline episode list
    if (_isAnime(item)) {
      return AnimeLayout(
          pluginId: pluginId, item: item, seasons: seasons, series: series);
    }

    // TV series: two-column with inline episode list
    if (item.isDir) {
      return SeriesLayout(
          pluginId: pluginId, item: item, seasons: seasons, series: series);
    }

    // Plain movie
    return _MovieLayout(pluginId: pluginId, item: item, movie: movie);
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

// Parses "url|norm_w|norm_h|dark" encoded logo string. Returns the URL part.
// Also handles legacy "url|w|h" (3-part) format.
String logoUrlOnly(String encoded) {
  final parts = encoded.split('|');
  // 4-part: url|norm_w|norm_h|dark  — url is everything before the last 3 pipes
  if (parts.length >= 4) {
    return parts.sublist(0, parts.length - 3).join('|');
  }
  // 3-part legacy: url|w|h
  if (parts.length == 3) {
    return parts.sublist(0, parts.length - 2).join('|');
  }
  return encoded;
}

// Returns true if the logo was flagged dark (field 4 == "1").
bool logoDark(String encoded) {
  final parts = encoded.split('|');
  if (parts.length >= 4) return parts.last == '1';
  return false;
}

// Computes render size for a logo using server-side normalized dimensions.
// norm_w/norm_h come from mycelium.image.analyze_logo (800px wide, cap 200h).
// maxH/maxW are Flutter-side caps (screen-relative). Falls back to 3:1 if dims unknown.
({double w, double h}) logoRenderSize(
  String encoded, {
  required double targetW,
  required double maxH,
  required double maxW,
}) {
  double srcW = 0, srcH = 0;
  final parts = encoded.split('|');
  // 4-part: url|norm_w|norm_h|dark
  if (parts.length >= 4) {
    srcW = double.tryParse(parts[parts.length - 3]) ?? 0;
    srcH = double.tryParse(parts[parts.length - 2]) ?? 0;
  } else if (parts.length == 3) {
    // legacy 3-part: url|w|h
    srcW = double.tryParse(parts[parts.length - 2]) ?? 0;
    srcH = double.tryParse(parts[parts.length - 1]) ?? 0;
  }

  double rw, rh;
  if (srcW > 0 && srcH > 0) {
    rw = targetW;
    rh = targetW * srcH / srcW;
  } else {
    rw = targetW;
    rh = targetW / 3.0;
  }

  // Cap: se troppo alto (logo quasi quadrato) scala giù da maxH.
  if (rh > maxH) {
    rw = rw * maxH / rh;
    rh = maxH;
  }
  // Cap larghezza (non dovrebbe servire ma per sicurezza).
  if (rw > maxW) {
    rh = rh * maxW / rw;
    rw = maxW;
  }
  // Floor: loghi ultra-wide non diventano filini.
  final minH = maxH * 0.30;
  if (rh < minH) {
    rh = minH;
  }

  return (w: rw, h: rh);
}
