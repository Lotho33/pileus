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
/// the type (Film/OVA…) and language pills. [top]: at the top centre
/// instead, for the landscape cards whose bottom holds the title and the
/// progress bar (Continua a guardare).
class CardBadgeRibbon extends StatelessWidget {
  final String label;
  final double fontSize;
  final bool top;
  const CardBadgeRibbon(
      {super.key, required this.label, this.fontSize = 11, this.top = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.8, vertical: fontSize * 0.3),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: top
              ? BorderRadius.vertical(bottom: Radius.circular(fontSize * 0.4))
              : BorderRadius.vertical(top: Radius.circular(fontSize * 0.4)),
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
/// has no label. Never takes a tap meant for the card.
List<Widget> cardBadgeOverlay(String badge,
    {double fontSize = 11, bool top = false}) {
  final label = cardBadgeLabel(badge);
  if (label.isEmpty) return const [];
  return [
    Positioned(
      left: 4,
      right: 4,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      child: IgnorePointer(
        child: Center(
            child: CardBadgeRibbon(label: label, fontSize: fontSize, top: top)),
      ),
    ),
  ];
}
