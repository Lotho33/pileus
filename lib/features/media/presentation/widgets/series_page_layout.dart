import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/grpc/clients/media_client.dart';
import '../../../../core/grpc/grpc_errors.dart';
import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_sizing.dart';
import '../../data/media_repository.dart';
import '../../../../shared/utils/safe_focus.dart';
import '../../../../shared/widgets/pileus_spinner.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import 'details_common.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

part 'series_page_layout/page.dart';
part 'series_page_layout/season_pill.dart';
part 'series_page_layout/episode_tile_row.dart';
part 'series_page_layout/panels.dart';
part 'series_page_layout/episode_popup.dart';
part 'series_page_layout/related_carousel.dart';
part 'series_page_layout/related_popup.dart';

// Series/anime detail page and its related-items ecosystem — extracted
// from details_screen.dart, the single largest piece of that file
// (~2,200 of its ~4,300 lines), per the design audit's file-size
// recommendation (§08). AnimeMetaRow and SeriesRelatedCarouselFooter are
// public because _MovieLayout and _AnimeMovieLayout (still in
// details_screen.dart) use them too; everything else here is only ever
// reached through AnimeLayout/SeriesLayout below.

// double-typed on both ends on purpose — see _EpisodeTileRowState.build()'s
// use of this for why plain math.max(double, double) isn't a safe
// substitute (its generic return type gets inferred as num through a
// nested .clamp() context, not double).
double _dmax(double a, double b) => a > b ? a : b;

class AnimeLayout extends StatelessWidget {
  final String pluginId;
  final CatalogItem item;
  final List<SeasonInfo> seasons;
  final SeriesDetails? series;
  const AnimeLayout(
      {super.key,
      required this.pluginId,
      required this.item,
      required this.seasons,
      required this.series});

  @override
  Widget build(BuildContext context) => _SeriesPageLayout(
        pluginId: pluginId,
        item: item,
        seasons: seasons,
        series: series,
        isAnime: true,
      );
}

// ── Series layout ─────────────────────────────────────────────────────────────

class SeriesLayout extends StatelessWidget {
  final String pluginId;
  final CatalogItem item;
  final List<SeasonInfo> seasons;
  final SeriesDetails? series;
  const SeriesLayout(
      {super.key,
      required this.pluginId,
      required this.item,
      required this.seasons,
      required this.series});

  @override
  Widget build(BuildContext context) => _SeriesPageLayout(
        pluginId: pluginId,
        item: item,
        seasons: seasons,
        series: series,
        isAnime: false,
      );
}

// ── Unified series page layout ────────────────────────────────────────────────
//
// Structure (single CustomScrollView, everything scrolls together):
//
//   [← Indietro]
//   ┌────────────┬──────────────────────────────────────────┐
//   │  Poster    │  Title                                   │
//   │  stagione  │  rating · year · genres                  │
//   │  (2:3)     │  plot                                    │
//   │            │                                          │
//   │            │  [S1] [S2] [S3]  ← season pills         │
//   │            │──────────────────────────────────────────│
//   │            │  1  Episode title          plot...  ›   │
//   │            │  2  ...                                  │
//   └────────────┴──────────────────────────────────────────┘
//   CORRELATI  [card][card]...
//   SIMILI     [card][card]...
