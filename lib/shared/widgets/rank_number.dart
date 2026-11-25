// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// How wide the number beside a ranked card is, as a fraction of the card's
/// width; the card then covers the number's last [kRankOverlap] of that.
const double kRankNumberWidth = 0.92;
const double kRankOverlap = 0.22;

/// A two-digit rank ("10") is half again as wide as a wide digit in DM Sans:
/// its card gets a wider number space, so it stands as tall as the others
/// without squeezing its digits together. It is always the row's last.
const double kRankNumberWidthWide = 1.45;

/// The number's space for [rank], as a fraction of the card's width.
double rankNumberWidth(int rank) =>
    rank >= 10 ? kRankNumberWidthWide : kRankNumberWidth;

/// How tall the digits stand, as a fraction of the card's height.
const double _kDigitHeight = 0.74;

/// The share of a number's own width that may slip under the card.
const double _kUnderCard = 0.25;

/// The big number beside a card in a Top 10 row: the app's own font, filled
/// with the background and outlined in the accent — plain stroked text,
/// cheap on modest hardware (no shader, blur or shadow). Its baseline sits
/// on the card's bottom edge. It is placed on the part of [width] the card
/// leaves visible ([visibleWidth]) and slips under the card by at most a
/// quarter of its own width, so a narrow "1" stays whole and a wide "7"
/// keeps its stroke; a number still too wide for that is scaled down to
/// fit (a two-digit one has a wider space: [rankNumberWidth]).
class RankNumber extends StatelessWidget {
  final int rank;
  final double width;
  final double height;
  final double visibleWidth;
  const RankNumber(
      {super.key,
      required this.rank,
      required this.width,
      required this.height,
      required this.visibleWidth});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size(width, height),
          painter: _RankPainter('$rank', visibleWidth),
        ),
      );
}

class _RankPainter extends CustomPainter {
  final String text;
  final double visible;
  _RankPainter(this.text, this.visible);

  // Digits' cap height is ~0.7 of the font size in DM Sans.
  static const _capRatio = 0.72;

  TextPainter _layout(double fontSize, Paint? stroke) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -fontSize * 0.03,
            color: stroke == null ? AppTheme.bg : null,
            foreground: stroke,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    var fontSize = size.height * _kDigitHeight / _capRatio;
    // Widest a number can be: whole in the visible part but for the share
    // allowed under the card, and never past the number's own box.
    final maxW = (visible / (1 - _kUnderCard)).clamp(0.0, size.width);
    final probe = _layout(fontSize, null);
    if (probe.width > maxW) fontSize *= maxW / probe.width;
    final fill = _layout(fontSize, null);
    final stroke = _layout(
        fontSize,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (fontSize * 0.018).clamp(1.5, 8.0)
          ..color = AppTheme.primary.withValues(alpha: 0.9));
    final baseline =
        fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final right = (visible + fill.width * _kUnderCard).clamp(0.0, size.width);
    final at = Offset(right - fill.width, size.height - baseline);
    fill.paint(canvas, at);
    stroke.paint(canvas, at);
    probe.dispose();
    fill.dispose();
    stroke.dispose();
  }

  @override
  bool shouldRepaint(_RankPainter old) =>
      old.text != text || old.visible != visible;
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
    final numW = cardWidth * rankNumberWidth(rank);
    return SizedBox(
      width: rankedSlotWidth(cardWidth, rank: rank),
      height: slotHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: RankNumber(
                rank: rank,
                width: numW,
                height: cardHeight,
                visibleWidth: numW - cardWidth * kRankOverlap),
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

double rankedSlotWidth(double cardWidth, {int rank = 1}) =>
    cardWidth * (1 + rankNumberWidth(rank) - kRankOverlap);
