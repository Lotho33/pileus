import 'dart:convert';

enum SkipType { op, ed, recap }

class SkipInterval {
  final SkipType type;
  final double start;
  final double end;

  const SkipInterval(
      {required this.type, required this.start, required this.end});

  String get label => switch (type) {
        SkipType.op => 'Salta sigla',
        SkipType.ed => 'Salta ending',
        SkipType.recap => 'Salta recap',
      };
}

/// Parses the `extra['skip_times']` JSON blob mycelium attaches to a resolved
/// stream (AniSkip/IntroDB markers) into typed intervals. Extracted from the
/// TV player (`playback_screen/view.dart`, the only place this used to be
/// read) so desktop/web can consume the same feed — the data was always
/// platform-agnostic, it just had no reader outside the TV screen.
/// Malformed/unrecognized entries are silently dropped rather than throwing:
/// same defensive stance as the original inline version.
List<SkipInterval> parseSkipTimes(String? skipJson) {
  if (skipJson == null || skipJson.isEmpty) return const [];
  try {
    final list = jsonDecode(skipJson) as List;
    return list
        .map((r) {
          final interval = r['interval'] as Map<String, dynamic>;
          final typeStr = (r['skipType'] as String?) ?? '';
          final type = switch (typeStr) {
            'op' => SkipType.op,
            'ed' => SkipType.ed,
            'recap' => SkipType.recap,
            _ => null,
          };
          if (type == null) return null;
          return SkipInterval(
            type: type,
            start: (interval['startTime'] as num).toDouble(),
            end: (interval['endTime'] as num).toDouble(),
          );
        })
        .whereType<SkipInterval>()
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Which (if any) of [intervals] covers [pos] right now — same "half-open,
/// 1s-early-exit" window as the TV player so a skip button doesn't flash on
/// for the last second of an interval only to immediately reappear for the
/// next tick.
SkipInterval? activeSkipInterval(List<SkipInterval> intervals, Duration pos) {
  final posF = pos.inMilliseconds / 1000.0;
  for (final interval in intervals) {
    if (posF >= interval.start && posF < interval.end - 1) return interval;
  }
  return null;
}
