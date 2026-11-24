// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/grpc/clients/media_client.dart' show BrowseResponse;

/// Filler and recap episodes, from the plugin's `extra['filler']` on an
/// episode ("filler" / "recap"; "" or absent when canon or not known — most
/// plugins never say, and then nothing is shown).
///
/// Shown as a word in the episode's meta line, in [kEpisodeKindColor] — not
/// a badge, so it doesn't compete with the language ones.
String episodeKindLabel(String? filler) =>
    switch ((filler ?? '').trim().toLowerCase()) {
      'filler' => 'Filler',
      'recap' => 'Riassunto',
      _ => '',
    };

const kEpisodeKindColor = Color(0xFFFBBF24);

/// [parts] joined by [sep], with [kind] (an [episodeKindLabel], may be '')
/// in [kEpisodeKindColor] at [kindAt] (clamped; default: after the first
/// part, so "24 min · Filler · trama…"). Empty parts are skipped.
TextSpan episodeMetaSpan(
  List<String> parts, {
  String kind = '',
  int kindAt = 1,
  String sep = '  ·  ',
}) {
  final words = <(String, bool)>[
    for (final p in parts)
      if (p.isNotEmpty) (p, false)
  ];
  if (kind.isNotEmpty) {
    words.insert(kindAt.clamp(0, words.length), (kind, true));
  }
  return TextSpan(children: [
    for (var i = 0; i < words.length; i++) ...[
      if (i > 0) TextSpan(text: sep),
      TextSpan(
        text: words[i].$1,
        style: words[i].$2
            ? const TextStyle(
                color: kEpisodeKindColor, fontWeight: FontWeight.w600)
            : null,
      ),
    ],
  ]);
}

// What the episode lists loaded said, per plugin and episode id — so the
// player's "next episode" card can say it too without every launch path
// carrying it along. Capped; a miss just shows nothing.
final _kinds = <String, String>{};
const _kindsCap = 4000;

/// Remembers the filler/recap episodes of a browse answer.
void rememberEpisodeKinds(String pluginId, BrowseResponse res) {
  void put(String id, String? filler) {
    final label = episodeKindLabel(filler);
    final key = '$pluginId\u0000$id';
    if (label.isEmpty) {
      _kinds.remove(key);
      return;
    }
    _kinds.remove(key);
    _kinds[key] = label;
    if (_kinds.length > _kindsCap) _kinds.remove(_kinds.keys.first);
  }

  for (final e in res.episodes) {
    put(e.id, e.extra['filler']);
  }
  for (final i in res.items) {
    if (!i.isDir) put(i.id, i.extra['filler']);
  }
}

/// [episodeKindLabel] of an episode a browse answer listed, '' when unknown.
String episodeKindOf(String pluginId, String episodeId) =>
    _kinds['$pluginId\u0000$episodeId'] ?? '';
