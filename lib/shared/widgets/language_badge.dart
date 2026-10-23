import 'package:flutter/material.dart';

/// Which language version a catalog card can play, from the plugin's
/// `extra['lang']` (and `extra['subs']`) — so "only in English" is known
/// before opening the title, not discovered at Play.
///
/// lang: '' or 'both' (nothing worth flagging), 'ita', 'eng', 'jap'.
/// subs: 'ita' when Italian subtitles exist for the original version.
/// Null when there's nothing to show.
({String label, Color color})? languageBadge(String lang, {String subs = ''}) {
  final withSubs = subs == 'ita';
  return switch (lang) {
    'ita' => (label: 'ITA', color: const Color(0xFF38bdf8)),
    'jap' => (label: 'JAP', color: const Color(0xFFf97316)),
    'eng' => (
        label: withSubs ? 'ENG · SUB ITA' : 'ENG',
        color: const Color(0xFFa78bfa)
      ),
    _ => null,
  };
}

/// The badge as a small pill, sized for phone/desktop cards (the TV card
/// keeps its own screen-height-scaled pill).
class LanguageBadgePill extends StatelessWidget {
  final String lang;
  final String subs;
  const LanguageBadgePill({super.key, required this.lang, this.subs = ''});

  @override
  Widget build(BuildContext context) {
    final b = languageBadge(lang, subs: subs);
    if (b == null) return const SizedBox.shrink();
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
