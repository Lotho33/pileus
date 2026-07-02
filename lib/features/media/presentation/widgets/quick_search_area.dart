import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/grpc/clients/media_client.dart' show CatalogItem;
import '../../../../core/perf_profile.dart';
import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/sdui/blocks/card_carousel_block_view.dart';
import '../../../../shared/sdui/sdui_block.dart';
import '../../../../shared/sdui/sdui_parser.dart';
import '../../../../shared/utils/back_dispatch.dart';
import '../../../../shared/utils/safe_focus.dart';
import '../../../../shared/widgets/on_screen_keyboard.dart';
import '../../../../shared/widgets/open_catalog_item.dart';
import '../../../../shared/widgets/pileus_spinner.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import '../../bloc/discovery_bloc.dart';
import '../../bloc/discovery_event.dart';
import '../../bloc/discovery_state.dart';

part 'quick_search_area/area_state.dart';
part 'quick_search_area/search_bar.dart';
part 'quick_search_area/see_all_button.dart';


// ── quick search ─────────────────────────────────────────────────────────
// Reached by pressing up from the first catalog row (see
// onNavigateUpFromCarousel in home_screen.dart's _PluginPageBody) — scoped
// to whichever plugin is currently active in home, same as the old nav
// sub-panel's "Cerca in {plugin}" action it replaces. Expands in place (no
// route push): bar widens, a Netflix-style on-screen keyboard appears
// below it, and results stream in live as poster+title cards (same
// CardCarouselBlockView used by every other catalog row) — "cerca
// meglio"/filters is one explicit action away, opening the existing full
// SearchScreen pre-filled with whatever's already been typed.
//
// Extracted from home_screen.dart — third piece split out per the design
// audit's file-size recommendation (§08), after HomeHeroBackground and
// PluginNav.

// Fixed slot count for the preview row — keeps card size constant
// regardless of result count.
const int _kQuickSearchVisibleCards = 4;
// Shortest query quick search will actually dispatch to the backend — a
// single letter is broad enough to be mostly noise and gets replaced
// almost immediately by the next keystroke anyway.
const int _kMinSearchLength = 2;

class QuickSearchArea extends StatefulWidget {
  final String pluginId;
  final String pluginName;
  final FocusNode barFocusNode;
  final VoidCallback onDismiss;

  const QuickSearchArea({
    super.key,
    required this.pluginId,
    required this.pluginName,
    required this.barFocusNode,
    required this.onDismiss,
  });

  @override
  State<QuickSearchArea> createState() => _QuickSearchAreaState();
}

