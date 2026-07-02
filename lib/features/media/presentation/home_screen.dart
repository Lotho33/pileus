import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'details_screen.dart' show logoUrlOnly, logoDark, logoRenderSize;

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart' hide ContinueWatchingItem;
import '../../../core/grpc/grpc_errors.dart';
import '../../../core/perf_profile.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/update/update_prompt.dart';
import '../../../core/utils/image_sizing.dart';
import '../data/media_repository.dart';
import '../../../shared/sdui/sdui_block.dart';
import '../../../shared/sdui/sdui_block_view.dart';
import '../../../shared/sdui/sdui_parser.dart';
import '../../../shared/sdui/sport_theme.dart';
import '../../../shared/utils/back_dispatch.dart';
import '../../../shared/utils/held_key_gate.dart';
import 'widgets/home_hero_background.dart';
import 'widgets/plugin_nav.dart';
import 'widgets/quick_search_area.dart';
import '../../../shared/utils/safe_focus.dart';
import 'widgets/details_common.dart';
import '../../../shared/widgets/error_retry_view.dart';
import '../../../shared/widgets/open_catalog_item.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/settings/plugin_reorder_dialog.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/continue_watching_bloc.dart';
import '../bloc/continue_watching_event.dart';
import '../bloc/continue_watching_state.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';
import '../bloc/plugin_bloc.dart';
import '../bloc/plugin_event.dart';
import '../bloc/plugin_state.dart';
import '../data/continue_watching_item.dart';

part 'home_screen/home_view.dart';
part 'home_screen/plugin_page.dart';
part 'home_screen/shell.dart';
part 'home_screen/carousel.dart';
part 'home_screen/meta_zone.dart';
part 'home_screen/sections.dart';
part 'home_screen/continue_watching.dart';
part 'home_screen/popups.dart';

// ── constants ──────────────────────────────────────────────────────────────────

const int _kVisibleCards = 7; // cards visible at once in the poster carousel
// Must match card_carousel_block_view.dart's own copy — used here only to
// reserve the correct vertical space above a featured row (see
// carouselTop in _StandardHomeShellState.build()), before that widget
// itself is built.
const int _kVisibleCardsFeatured = 5;
// _kQuickSearchVisibleCards/_kMinSearchLength moved to
// widgets/quick_search_area.dart with the widget that used them.

// All ratios target a 1920×1080 (16:9 TV) baseline.
// Horizontal padding/card-gap used to be duplicated here as _rHPad/_rCardGap
// and again in card_carousel_block_view.dart — both now pull from
// AppScale.catalogHPadRatio/catalogGapRatio, the single source.
// Use inside LayoutBuilder:
//   final hPad    = AppScale.catalogHPadRatio(w);
//   final cardGap = AppScale.catalogGapRatio(w);   etc.

// Absolute — only used where LayoutBuilder is unavailable (nav panel width).
// _kHPad and _sideNavW are now computed at runtime from screen size (see
// AppScale.catalogHPadRatio above). Kept as fallback references for any
// legacy direct usage.
const double _sideNavRatio = 460.0 / 1920.0;

// Plugin display name / icon come from the server (manifest `name:` /
// `icon:`); `pluginLabel()` in widgets/plugin_nav.dart is the shared
// helper. No per-plugin table here.

// ── FSM ────────────────────────────────────────────────────────────────────────

enum _HomeFsm { loading, browsing, heroFocused, navOpen }

// ── HomeScreen ─────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // PluginBloc/ContinueWatchingBloc are lazy singletons (see
    // injection.dart) that AuthBloc's splash-time fast path (the "skip
    // straight to remembered profile" branch of _onAppStarted) may have
    // already dispatched into and warmed up before this screen ever
    // mounted — BlocProvider.value reuses that same instance instead of
    // recreating it (which would re-dispatch from zero and throw away the
    // head start). The still-initial-state guard below covers every other
    // path to /home (explicit profile picker, new profile creation), where
    // nothing has loaded yet.
    final pluginBloc = getIt<PluginBloc>();
    if (pluginBloc.state is PluginInitial) {
      pluginBloc.add(const LoadPluginsEvent());
    }
    final continueWatchingBloc = getIt<ContinueWatchingBloc>();
    if (continueWatchingBloc.state is ContinueWatchingInitial) {
      continueWatchingBloc.add(const LoadContinueWatchingEvent());
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: pluginBloc),
        BlocProvider.value(value: continueWatchingBloc),
      ],
      child: const _HomeView(),
    );
  }
}
