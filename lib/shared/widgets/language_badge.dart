// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

typedef LangBadge = ({String label, Color color});

/// At most this many badges on one card/episode — one per language, each
/// its own colour.
const kMaxLanguageBadges = 5;

/// Which language versions a catalog card can play, from the plugin's
/// `extra['lang']` (and `extra['subs']`) — so "only in English" is known
/// before opening the title, not discovered at Play.
///
/// lang: one value or several separated by commas (`ita,jap,chn` for a
/// title out in several languages); each of '' or 'both' (nothing worth
/// flagging), 'ita', 'eng', 'jap', 'chn', 'kor' (the original language of
/// donghua and Korean series). Unknown values are skipped, duplicates
/// dropped, the rest kept in order up to [kMaxLanguageBadges].
/// subs: 'ita' when Italian subtitles exist for the original version.
List<LangBadge> languageBadges(String lang, {String subs = ''}) {
  final out = <LangBadge>[];
  for (final part in lang.split(RegExp(r'[,;|/\s]+'))) {
    final b = languageBadge(part.trim().toLowerCase(), subs: subs);
    if (b == null || out.any((o) => o.label == b.label)) continue;
    out.add(b);
    if (out.length == kMaxLanguageBadges) break;
  }
  return out;
}

/// One language value (see [languageBadges]); null when there's nothing to
/// show.
LangBadge? languageBadge(String lang, {String subs = ''}) {
  final withSubs = subs == 'ita';
  return switch (lang) {
    'ita' => (label: 'ITA', color: const Color(0xFF38bdf8)),
    'jap' => (label: 'JAP', color: const Color(0xFFf97316)),
    'chn' => (label: 'CHN', color: const Color(0xFFef4444)),
    'kor' => (label: 'KOR', color: const Color(0xFF22c55e)),
    'eng' => (
        label: withSubs ? 'ENG · SUB ITA' : 'ENG',
        color: const Color(0xFFa78bfa)
      ),
    _ => null,
  };
}

/// The badges as small pills, sized for phone/desktop cards (the TV card
/// keeps its own screen-height-scaled pill). [direction]: vertical on a
/// card's corner (stacked under each other, clear of the left-hand pills),
/// horizontal in a text row.
class LanguageBadgePill extends StatelessWidget {
  final String lang;
  final String subs;
  final Axis direction;
  const LanguageBadgePill(
      {super.key,
      required this.lang,
      this.subs = '',
      this.direction = Axis.horizontal});

  @override
  Widget build(BuildContext context) {
    final badges = languageBadges(lang, subs: subs);
    if (badges.isEmpty) return const SizedBox.shrink();
    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: direction == Axis.vertical
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.center,
      spacing: 3,
      children: [for (final b in badges) _pill(b)],
    );
  }

  Widget _pill(LangBadge b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: b.color.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        b.label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
