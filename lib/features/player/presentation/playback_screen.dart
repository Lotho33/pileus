import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/app_lifecycle.dart';
import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart'
    show DetailsResponse, ProgressResponse;
import '../../../core/perf_profile.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/perf_log.dart';
import '../../../features/media/bloc/plugin_bloc.dart';
import '../../../features/media/data/media_repository.dart';
import '../../../features/settings/data/settings_repository.dart';
import '../../../shared/utils/back_dispatch.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/playback_bloc.dart';
import '../bloc/playback_event.dart';
import '../bloc/playback_state.dart';
import '../bloc/player_ui_cubit.dart';
import '../bloc/player_ui_state.dart';
import '../engine/player_engine.dart';
import '../episode_poster.dart';
import '../episode_prefetch.dart';
import '../models/playback_args.dart';
import '../models/skip_interval.dart';
import '../player_tuning.dart';
import '../playback_episode_cache.dart';
import '../profile_lease_conflict.dart';
import '../resume_seek.dart';
import 'widgets/player_audio_artwork.dart';
import 'widgets/player_overlay.dart';
import 'widgets/player_settings_panel.dart';
import 'widgets/skip_intro_button.dart';

part 'playback_screen/view.dart';
part 'playback_screen/next_episode_banner.dart';
part 'playback_screen/error_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point — risolve PlaybackArgs dall'extra di GoRouter
// ─────────────────────────────────────────────────────────────────────────────

class PlaybackScreen extends StatelessWidget {
  final String pluginId;
  final String mediaId;

  const PlaybackScreen(
      {super.key, required this.pluginId, required this.mediaId});

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final args =
        PlaybackArgs.fromExtra(extra, pluginId: pluginId, mediaId: mediaId);

    return BlocProvider(
      create: (_) {
        perfReset('PLAY $pluginId / $mediaId'
            ' (live=${args.isLive}, seekTo=${args.seekTo}s)');
        final bloc = getIt<PlaybackBloc>();
        final startPositionSec =
            resolveStartPositionSec(isLive: args.isLive, seekTo: args.seekTo);
        if (args.directUrl != null && args.directUrl!.isNotEmpty) {
          bloc.add(UseDirectUrlEvent(
              url: args.directUrl!, httpHeaders: args.directUrlHeaders));
        } else if (args.directStreamId != null &&
            args.directStreamId!.isNotEmpty) {
          bloc.add(SelectStreamEvent(
              pluginId: pluginId,
              streamId: args.directStreamId!,
              startPositionSec: startPositionSec));
        } else {
          bloc.add(InitializeVideoEvent(
            pluginId: pluginId,
            mediaId: mediaId,
            preferredLabel: args.sourceLabel,
            startPositionSec: startPositionSec,
          ));
        }
        return bloc;
      },
      child: _PlaybackView(pluginId: pluginId, mediaId: mediaId, args: args),
    );
  }
}
