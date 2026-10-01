import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart'
    show CatalogItem, SearchFilter;
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/sdui/blocks/card_carousel_block_view.dart';
import '../../../shared/sdui/sdui_block.dart';
import '../../../shared/sdui/sdui_parser.dart';
import '../../../shared/utils/safe_focus.dart';
import '../../../shared/utils/back_dispatch.dart';
import '../../../shared/widgets/error_retry_view.dart';
import '../../../shared/widgets/on_screen_keyboard.dart';
import '../../../shared/widgets/open_catalog_item.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';
import '../data/media_repository.dart';

part 'search_screen/view.dart';
part 'search_screen/results.dart';
part 'search_screen/controls.dart';
part 'search_screen/filter_panel.dart';

// Ratios — 1920×1080 baseline
// Kept as an alias so the many existing call sites don't churn — it's the
// app accent (AppTheme.primary).
const Color _kFocusColor = AppTheme.primary;
const double _rSrHPad = 48 / 1920;
const double _rSrHeaderVPad = 52 / 1080;
const double _rSrBarH = 72 / 1080;

// Shortest query the full search will dispatch (unless a filter is active) —
// matches quick search's _kMinSearchLength. A 0-1 char query is broad noise
// that the next keystroke replaces anyway; the on-screen keyboard has no
// Invio key here, the debounced dispatch below is the only trigger.
const int _kMinSearchLength = 2;

class SearchScreen extends StatelessWidget {
  final String pluginId;
  final String pluginName;
  final String initialQuery;

  const SearchScreen({
    super.key,
    required this.pluginId,
    required this.pluginName,
    this.initialQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DiscoveryBloc>(),
      child: _SearchView(
          pluginId: pluginId,
          pluginName: pluginName,
          initialQuery: initialQuery),
    );
  }
}
