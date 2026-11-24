// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// How wide the number beside a ranked card is, as a fraction of the card's
/// width; the card then covers the number's last [kRankOverlap] of that.
const double kRankNumberWidth = 0.82;
const double kRankOverlap = 0.3;

/// The big number beside a card in a Top 10 row: the app's own font, filled
/// with the background and outlined in the accent — plain stroked text,
/// cheap on modest hardware (no shader, blur or shadow). Its baseline sits
/// on the card's bottom edge and its digits stand about as tall as the card;
/// a number too wide for [width] ("10") is scaled down to fit.
class RankNumber extends StatelessWidget {
  final int rank;
  final double width;
  final double height;
  const RankNumber(
      {super.key,
      required this.rank,
      required this.width,
      required this.height});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size(width, height),
          painter: _RankPainter('$rank'),
        ),
      );
}

class _RankPainter extends CustomPainter {
  final String text;
  _RankPainter(this.text);

  // Digits' cap height is ~0.7 of the font size in DM Sans.
  static const _capRatio = 0.72;

  TextPainter _layout(double fontSize, Paint? stroke) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -fontSize * 0.06,
            color: stroke == null ? AppTheme.bg : null,
            foreground: stroke,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    var fontSize = size.height * 0.98 / _capRatio;
    final probe = _layout(fontSize, null);
    if (probe.width > size.width) fontSize *= size.width / probe.width;
    final fill = _layout(fontSize, null);
    final stroke = _layout(
        fontSize,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (fontSize * 0.018).clamp(1.5, 8.0)
          ..color = AppTheme.primary.withValues(alpha: 0.9));
    final baseline =
        fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final at = Offset(size.width - fill.width, size.height - baseline);
    fill.paint(canvas, at);
    stroke.paint(canvas, at);
    probe.dispose();
    fill.dispose();
    stroke.dispose();
  }

  @override
  bool shouldRepaint(_RankPainter old) => old.text != text;
}

/// A card of a ranked row with its number: [cardWidth] + the number's
/// width less the overlap. Use [rankedSlotWidth] to size the slot.
/// [cardHeight] is the picture's height (the number's); [slotHeight] the
/// whole card's, when the row doesn't already give one (a plain Row).
class RankedCardSlot extends StatelessWidget {
  final int rank;
  final double cardWidth;
  final double cardHeight;
  final double? slotHeight;
  final Widget card;
  const RankedCardSlot({
    super.key,
    required this.rank,
    required this.cardWidth,
    required this.cardHeight,
    required this.card,
    this.slotHeight,
  });

  @override
  Widget build(BuildContext context) {
    final numW = cardWidth * kRankNumberWidth;
    return SizedBox(
      width: rankedSlotWidth(cardWidth),
      height: slotHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: RankNumber(rank: rank, width: numW, height: cardHeight),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: cardWidth,
            child: card,
          ),
        ],
      ),
    );
  }
}

double rankedSlotWidth(double cardWidth) =>
    cardWidth * (1 + kRankNumberWidth - kRankOverlap);
