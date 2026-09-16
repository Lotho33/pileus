import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/safe_focus.dart';
import '../../../../shared/widgets/pileus_spinner.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import '../../engine/player_engine.dart';
import '../../models/skip_interval.dart';
import 'player_seek_bar.dart';

part 'player_overlay/overlay_state.dart';
part 'player_overlay/buttons.dart';
part 'player_overlay/live_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Overlay VOD: top bar + centro play/skip/episodio + seekbar in basso
// ─────────────────────────────────────────────────────────────────────────────

class PlayerOverlay extends StatefulWidget {
  final PlayerEngine engine;
  final String? title;
  final int episodeIndex;
  final int episodeCount;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  // Forwarded to PlayerSeekBar — see its own onActivity doc.
  final VoidCallback? onActivity;
  // Non-null only while the Skip-intro button is actually on screen — wired
  // to Down off the seek bar so the button is reachable by D-pad while the
  // overlay controls hold focus (it lives in a sibling layer, not this
  // widget). See playback_screen.dart.
  final VoidCallback? onNavigateToSkip;
  final List<SkipInterval> skipIntervals;
  // Real content length from catalog metadata (PlaybackArgs.durationSeconds).
  // mpv's reported duration can legitimately be smaller than this while the
  // resolved HLS playlist is still being generated segment-by-segment on
  // the backend (no #EXT-X-ENDLIST yet) — the seek bar would otherwise look
  // like it's tracking a live stream that keeps "growing" instead of a
  // fixed-length VOD. 0 means unknown; falls back to mpv's value only.
  final int knownDurationSeconds;
  // True during initial resolve/first-frame wait and during any later
  // re-buffering — play/pause, ±10s skip and the seek bar all disable while
  // this is true (see playback_screen.dart's _isLoadingFor).
  final bool loading;
  // Free-form progress text from the plugin/backend's own ResolveStream
  // (PlaybackResolveProgress.message) — shown under the center controls
  // only while loading, with an icon derived from [statusKind]
  // ("loading"|"success"|"error"|"warning").
  final String? statusMessage;
  final String? statusKind;
  // mpv's cache-fill percentage (0-100). Shown in the same slot instead of
  // the resolve message once the stream is resolved and mpv is filling its
  // buffer, i.e. right before the first frame.
  final bool buffering;
  final double bufferingPercent;

  // True only while the overlay is actually on screen. When false the
  // position/duration StreamBuilders below stop subscribing — otherwise the
  // seek bar's Column (CustomPaint + two formatted-time Text widgets)
  // rebuilds on every position tick (~4-10/s) for the whole playback even
  // though the overlay is invisible: pure waste on a low-power box.
  final bool active;

  const PlayerOverlay({
    super.key,
    required this.engine,
    required this.onBack,
    required this.onOpenSettings,
    this.title,
    this.episodeIndex = -1,
    this.episodeCount = 0,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.onActivity,
    this.onNavigateToSkip,
    this.skipIntervals = const [],
    this.knownDurationSeconds = 0,
    this.loading = false,
    this.statusMessage,
    this.statusKind,
    this.buffering = false,
    this.bufferingPercent = 0,
    this.active = true,
  });

  @override
  State<PlayerOverlay> createState() => PlayerOverlayState();
}
