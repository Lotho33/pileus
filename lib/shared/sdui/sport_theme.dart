import 'package:flutter/material.dart';

/// Whether a catalog/details item's `extra['is_live']` flag says it's on air
/// *right now* — as opposed to e.g. a scheduled sport event that hasn't
/// started yet. Shared by the home hero, the details live-event layout, the
/// live event popup and the mobile live sheet so all four agree on what
/// counts as "IN DIRETTA".
bool isLiveNow(Map<String, String> extra) => extra['is_live'] == '1';

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Best-effort "HH:MM" start time for a live/scheduled event, read from
/// whichever `extra` key the plugin populated. Mycelium's CatalogItem has no
/// typed time field for this (the SDK's LiveDetails.stream_start is
/// GetDetails-only), so this defensively checks several key names other
/// plugins/paths might use. Returns null if none of them parse.
String? liveStartTimeLabel(Map<String, String> extra) {
  const keys = [
    'stream_start',
    'streamStart',
    'start_time',
    'start',
    'start_at',
    'starts_at',
    'start_unix',
    'event_time',
    'kickoff',
    'time',
    'begin',
    'scheduled',
  ];
  for (final k in keys) {
    final raw = extra[k];
    if (raw == null || raw.trim().isEmpty) continue;
    final v = raw.trim();
    // Unix epoch (seconds or milliseconds).
    final n = int.tryParse(v);
    if (n != null && n > 1000000000) {
      final ms = n > 100000000000 ? n : n * 1000;
      return _hhmm(
          DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal());
    }
    // Already a HH:MM (possibly inside a longer string).
    final m = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(v);
    if (m != null) return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
    // ISO-8601 / RFC-3339.
    final dt = DateTime.tryParse(v);
    if (dt != null) return _hhmm(dt.toLocal());
  }
  return null;
}

/// Sport-category accent color and icon, shared by the home hero, the live
/// carousel cards and the live event popup — one mapping so the accent
/// strip / gradient / chip read as one consistent visual language.
Color sportAccentColor(String cat) {
  switch (cat) {
    case 'football':
      return const Color(0xFF2E7D32);
    case 'basketball':
      return const Color(0xFFE65100);
    case 'tennis':
      return const Color(0xFF558B2F);
    case 'baseball':
      return const Color(0xFF1565C0);
    case 'hockey':
    case 'ice-hockey':
      return const Color(0xFF0277BD);
    case 'rugby':
    case 'rugby-league':
    case 'rugby-union':
      return const Color(0xFF4E342E);
    case 'motor-sports':
      return const Color(0xFFB71C1C);
    case 'american-football':
      return const Color(0xFF4527A0);
    case 'cycling':
      return const Color(0xFF00695C);
    case 'golf':
      return const Color(0xFF33691E);
    case 'boxing':
    case 'fight':
    case 'mma':
      return const Color(0xFF880E4F);
    case 'cricket':
      return const Color(0xFF1A237E);
    case 'volleyball':
      return const Color(0xFF006064);
    case 'darts':
      return const Color(0xFF37474F);
    case 'afl':
      return const Color(0xFF4E342E);
    default:
      return const Color(0xFF1A237E);
  }
}

/// Material icon per sport category. Replaces an emoji-based version: the
/// Linux desktop build ships no colour-emoji font (Android's system font
/// has them), so the emoji rendered as tofu there. Material Icons are part
/// of every Flutter build and tree-shaken, so this costs nothing extra and
/// renders identically on both platforms.
IconData sportIcon(String cat) {
  switch (cat) {
    case 'football':
      return Icons.sports_soccer;
    case 'basketball':
      return Icons.sports_basketball;
    case 'tennis':
      return Icons.sports_tennis;
    case 'baseball':
      return Icons.sports_baseball;
    case 'hockey':
    case 'ice-hockey':
      return Icons.sports_hockey;
    case 'rugby':
    case 'rugby-league':
    case 'rugby-union':
    case 'afl':
      return Icons.sports_rugby;
    case 'motor-sports':
      return Icons.sports_motorsports;
    case 'american-football':
      return Icons.sports_football;
    case 'cycling':
      return Icons.directions_bike;
    case 'golf':
      return Icons.sports_golf;
    case 'boxing':
    case 'fight':
    case 'mma':
      return Icons.sports_mma;
    case 'cricket':
      return Icons.sports_cricket;
    case 'volleyball':
      return Icons.sports_volleyball;
    case 'darts':
      return Icons.my_location;
    default:
      return Icons.sports;
  }
}
