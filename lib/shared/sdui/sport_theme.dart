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
  for (final k in _startKeys) {
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
  final fromPlot = liveStartAt(extra);
  return fromPlot == null ? null : _hhmm(fromPlot);
}

// The keys a plugin may put an event's start in — see liveStartTimeLabel.
const _startKeys = [
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

// "Inizio: 25/10 12:00" (local time) or "Inizio: 25/10 12:00 UTC" — the
// line the sport plugins write at the top of the plot.
final _plotStart = RegExp(
    r'^\s*Inizio:\s*(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2})(\s*UTC)?',
    caseSensitive: false,
    multiLine: true);

/// When a live/scheduled event starts, as a full date and time — from a
/// start key ([liveStartTimeLabel]'s list: Unix seconds/ms or ISO-8601), else
/// from the plot's "Inizio: dd/mm hh:mm" line. Null when neither says.
DateTime? liveStartAt(Map<String, String> extra, {DateTime? now}) {
  for (final k in _startKeys) {
    final v = (extra[k] ?? '').trim();
    if (v.isEmpty) continue;
    final n = int.tryParse(v);
    if (n != null && n > 1000000000) {
      final ms = n > 100000000000 ? n : n * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    final dt = DateTime.tryParse(v);
    if (dt != null) return dt.toLocal();
  }
  final m = _plotStart.firstMatch(extra['plot'] ?? '');
  if (m == null) return null;
  final today = now ?? DateTime.now();
  final day = int.parse(m.group(1)!), month = int.parse(m.group(2)!);
  final hour = int.parse(m.group(3)!), minute = int.parse(m.group(4)!);
  final utc = m.group(5) != null;
  DateTime at(int year) => utc
      ? DateTime.utc(year, month, day, hour, minute).toLocal()
      : DateTime(year, month, day, hour, minute);
  // No year in the line: the one that puts it nearest to today (a match on
  // 2 January seen on 30 December is next year's).
  var d = at(today.year);
  if (d.difference(today).inDays > 180) d = at(today.year - 1);
  if (today.difference(d).inDays > 180) d = at(today.year + 1);
  return d;
}

const _weekdays = [
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

/// "Tra 25 min", "Oggi alle 20:45", "Domani alle 15:00", "Sabato alle
/// 18:00", "02/11 alle 21:00" — when an event that isn't on air yet starts.
/// Past its start: "Doveva iniziare alle 12:00" (not on air yet).
String liveWhenLabel(DateTime start, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final hm = _hhmm(start);
  final mins = start.difference(n).inMinutes;
  if (mins < 0) return 'Doveva iniziare alle $hm';
  if (mins < 60) return mins <= 1 ? 'Sta per iniziare' : 'Tra $mins min';
  final days = DateTime(start.year, start.month, start.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  if (days == 0) return 'Oggi alle $hm';
  if (days == 1) return 'Domani alle $hm';
  if (days < 7) return '${_weekdays[start.weekday - 1]} alle $hm';
  return '${start.day.toString().padLeft(2, '0')}/'
      '${start.month.toString().padLeft(2, '0')} alle $hm';
}

const _weekdaysShort = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

/// The short form for a card badge: "Oggi 20:45", "Domani 15:00",
/// "Sab 18:00", "02/11 21:00" — by day, so it can't go stale between two
/// refreshes the way "Tra 25 min" would. Past its start: "In attesa".
String liveWhenShort(DateTime start, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (start.isBefore(n)) return 'In attesa';
  final hm = _hhmm(start);
  final days = DateTime(start.year, start.month, start.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  if (days == 0) return 'Oggi $hm';
  if (days == 1) return 'Domani $hm';
  if (days < 7) return '${_weekdaysShort[start.weekday - 1]} $hm';
  return '${start.day.toString().padLeft(2, '0')}/'
      '${start.month.toString().padLeft(2, '0')} $hm';
}

/// The plot of a live item without the lines the status line already shows:
/// "Inizio: …" (when the start is shown as a label) and a bare
/// "IN DIRETTA" (the red pill). "IN DIRETTA · 63' (1-0)" stays — the minute
/// and score are news.
String livePlotWithoutStatus(String plot, {required bool startShown}) {
  final lines = plot.split('\n').where((l) {
    final t = l.trim();
    if (t.isEmpty) return false;
    if (t.toUpperCase() == 'IN DIRETTA') return false;
    if (startShown && _plotStart.hasMatch(t)) return false;
    return true;
  });
  return lines.join('\n');
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
