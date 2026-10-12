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

/// Shared between the home screen and its [QuickSearchArea].
///
/// - [requestOpen]: the *only* deliberate way to open search. Focus landing
///   inside the panel without it — Flutter restoring the home route's focus
///   history after a pushed route (player, details) pops, when the card it
///   would restore was rebuilt meanwhile (Continue Watching reloads after
///   playback) — is bounced straight back out instead of opening search
///   with focus stranded on its invisible focus proxy.
/// - [isOpen] / [close]: lets the home's root Back (PopScope) close search
///   instead of showing "Premi di nuovo per uscire". One Back press reaches
///   the app as both a key event and a platform popRoute (see
///   back_dispatch.dart); when the popRoute wins, search's own Back handler
///   only sees the echo — without this it never closed.
class QuickSearchController {
  bool _openRequested = false;
  bool _isOpen = false;
  VoidCallback? _close;

  bool get isOpen => _isOpen;

  /// Opens search by focusing [barFocusNode] (the area's entry proxy).
  void requestOpen(FocusNode barFocusNode) {
    _openRequested = true;
    barFocusNode.requestFocus();
    // Only valid for this one focus move: if focus didn't actually enter
    // (excluded, nav open…), a later stray restore must not inherit it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequested = false);
  }

  /// Closes search if open; true when it was.
  bool close() {
    if (!_isOpen || _close == null) return false;
    _close!();
    return true;
  }

  bool _takeOpenRequest() {
    final r = _openRequested;
    _openRequested = false;
    return r;
  }
}

class QuickSearchArea extends StatefulWidget {
  final String pluginId;
  final String pluginName;
  final FocusNode barFocusNode;
  final VoidCallback onDismiss;
  final QuickSearchController controller;

  const QuickSearchArea({
    super.key,
    required this.pluginId,
    required this.pluginName,
    required this.barFocusNode,
    required this.controller,
    required this.onDismiss,
  });

  @override
  State<QuickSearchArea> createState() => _QuickSearchAreaState();
}
