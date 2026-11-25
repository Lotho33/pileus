// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// How wide the number beside a ranked card is, as a fraction of the card's
/// width; the card then covers [kRankOverlap] of it — like the big charts of
/// the streaming services, the digits run well under the next poster.
const double kRankNumberWidth = 1.0;
const double kRankOverlap = 0.4;

/// A two-digit rank ("10"): a little more room, so the "0" isn't all hidden.
/// It is always the row's last.
const double kRankNumberWidthWide = 1.15;

/// The number's space for [rank], as a fraction of the card's width.
double rankNumberWidth(int rank) =>
    rank >= 10 ? kRankNumberWidthWide : kRankNumberWidth;

/// How tall the digits stand, as a fraction of the card's height.
const double _kDigitHeight = 0.94;

/// How far from the card a narrow number ("1") ends, as a share of the
/// visible part: room for the focused card growing over it.
const double _kClearOfCard = 0.1;

/// DM Sans' digits are wide: drawn condensed to this share of their width,
/// they stand as tall as the card without a wide row (a chart's look).
const double _kCondense = 0.74;

/// The big number beside a card in a Top 10 row: the app's own font,
/// condensed, filled with the background and outlined in the accent — plain
/// stroked text, cheap on modest hardware (no shader, blur or shadow). Its
/// baseline sits on the card's bottom edge and it stands about as tall as
/// the card. A wide number starts at the left of [width] and runs under the
/// card as far as it must; a narrow one ("1") stays whole in the part the
/// card leaves visible ([visibleWidth]). A number wider than [width] is
/// scaled down to fit.
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
            // Two digits nearly touch, as in the charts.
            letterSpacing: -fontSize * (text.length > 1 ? 0.07 : 0.02),
            color: stroke == null ? AppTheme.bg : null,
            foreground: stroke,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    var fontSize = size.height * _kDigitHeight / _capRatio;
    // On screen (condensed) a number never goes past its own box.
    final probe = _layout(fontSize, null);
    final probeW = probe.width * _kCondense;
    if (probeW > size.width) fontSize *= size.width / probeW;
    final fill = _layout(fontSize, null);
    final stroke = _layout(
        fontSize,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (fontSize * 0.02).clamp(1.5, 9.0)
          ..color = AppTheme.primary.withValues(alpha: 0.9));
    final w = fill.width * _kCondense;
    final baseline =
        fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    // Wide: from the left edge, under the card as needed. Narrow: whole in
    // the visible part, clear of the card.
    final right =
        (w > visible * (1 - _kClearOfCard) ? w : visible * (1 - _kClearOfCard))
            .clamp(0.0, size.width);
    canvas
      ..save()
      ..translate(right - w, size.height - baseline)
      ..scale(_kCondense, 1);
    fill.paint(canvas, Offset.zero);
    stroke.paint(canvas, Offset.zero);
    canvas.restore();
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
