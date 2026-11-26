// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// How wide the number beside a ranked card is, as a fraction of the card's
/// width; the card then covers [kRankOverlap] of it — like the big charts of
/// the streaming services, a wide number runs under its poster.
const double kRankNumberWidth = 1.0;
const double kRankOverlap = 0.2;

/// "10" keeps the same space as the others and may run further under its
/// card, by this share of the part the card covers; every number is drawn
/// at the size "10" fits at.
const double _kTwoDigitsUnderCard = 0.2;

/// How tall the digits stand at most, as a fraction of the card's height
/// (the width "10" needs usually keeps them shorter).
const double _kDigitHeight = 0.62;

/// How far from the card a narrow number ("1") ends, as a share of the
/// visible part: room for the focused card growing over it.
const double _kClearOfCard = 0.1;

/// The big number beside a card in a Top 10 row: the app's own font at its
/// own proportions, filled with the background and outlined in the accent —
/// plain stroked text, cheap on modest hardware (no shader, blur or
/// shadow). It stands about half as tall as the card, centred on the
/// card's middle. A wide number starts at the left of [width] and runs under
/// the card as far as it must; a narrow one ("1") stays whole in the part
/// the card leaves visible ([visibleWidth]). All ten stand equally tall:
/// sized so "10", its digits pulled close to read as one number, fits.
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

  // Between two digits, as a share of the font size: laid out one by one
  // (letter spacing is drawn differently from one platform to another).
  // Negative: DM Sans' "1" has wide side bearings; pulled in, "10" reads as
  // one number rather than "1 0".
  static const _digitGap = -0.10;

  TextPainter _digit(String d, double fontSize, Paint? stroke) => TextPainter(
        text: TextSpan(
          text: d,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: stroke == null ? AppTheme.bg : null,
            foreground: stroke,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  // The width of [s] at [fontSize].
  double _width(String s, double fontSize) {
    var w = 0.0;
    for (var i = 0; i < s.length; i++) {
      final p = _digit(s[i], fontSize, null);
      w += p.width + (i > 0 ? fontSize * _digitGap : 0);
      p.dispose();
    }
    return w;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var fontSize = size.height * _kDigitHeight / _capRatio;
    // A number never goes past its own box.
    final room = size.width +
        (text.length > 1 ? (size.width - visible) * _kTwoDigitsUnderCard : 0);
    // Every number at the size "10" fits in its room: 1 to 10 stand
    // equally tall.
    final roomTen = size.width + (size.width - visible) * _kTwoDigitsUnderCard;
    final ten = _width('10', fontSize);
    if (ten > roomTen) fontSize *= roomTen / ten;
    final w = _width(text, fontSize);
    // Wide: from the left edge, under the card as needed. Narrow: whole in
    // the visible part, clear of the card.
    final right =
        (w > visible * (1 - _kClearOfCard) ? w : visible * (1 - _kClearOfCard))
            .clamp(0.0, room);
    // The digits' middle on the card's middle.
    final baselineY = (size.height + fontSize * _capRatio) / 2;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (fontSize * 0.025).clamp(1.5, 9.0)
      ..color = AppTheme.primary.withValues(alpha: 0.9);
    var x = right - w;
    for (var i = 0; i < text.length; i++) {
      final fill = _digit(text[i], fontSize, null);
      final stroke = _digit(text[i], fontSize, strokePaint);
      final baseline =
          fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final at = Offset(x, baselineY - baseline);
      fill.paint(canvas, at);
      stroke.paint(canvas, at);
      x += fill.width + fontSize * _digitGap;
      fill.dispose();
      stroke.dispose();
    }
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

double rankedSlotWidth(double cardWidth) =>
    cardWidth * (1 + kRankNumberWidth - kRankOverlap);
