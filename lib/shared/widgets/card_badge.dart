// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The label of a card's `badge` ("new" / "new_episode"); '' for anything
/// else — an unknown value shows nothing.
String cardBadgeLabel(String badge) => switch (badge.trim()) {
      'new' => 'Novità',
      'new_episode' => 'Nuovo episodio',
      _ => '',
    };

/// A strip at the bottom centre of a card — the top corners already hold
/// the type (Film/OVA…) and language pills.
class CardBadgeRibbon extends StatelessWidget {
  final String label;
  final double fontSize;
  const CardBadgeRibbon({super.key, required this.label, this.fontSize = 11});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.8, vertical: fontSize * 0.3),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(fontSize * 0.4)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.1),
        ),
      );
}

/// [CardBadgeRibbon] placed for a card's Stack, or nothing when [badge]
/// has no label.
List<Widget> cardBadgeOverlay(String badge, {double fontSize = 11}) {
  final label = cardBadgeLabel(badge);
  if (label.isEmpty) return const [];
  return [
    Positioned(
      left: 4,
      right: 4,
      bottom: 0,
      child: Center(child: CardBadgeRibbon(label: label, fontSize: fontSize)),
    ),
  ];
}
