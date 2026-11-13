// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

/// A metadata line ("★ 7.8   ·   2024   ·   Drama") with every "★" drawn
/// as an icon. DM Sans has no U+2605, so as plain text the web build
/// (CanvasKit) fetches Noto Sans Symbols 2 from fonts.gstatic.com just for
/// that glyph: ~370 KB on the first hero, and a missing-glyph box when the
/// server has no internet.
class MetaLine extends StatelessWidget {
  final String text;
  final TextStyle style;

  const MetaLine(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    if (!text.contains('★')) return Text(text, style: style);
    final parts = text.split('★');
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.star_rounded,
                  size: (style.fontSize ?? 14) * 1.1, color: style.color),
            ),
          if (parts[i].isNotEmpty) TextSpan(text: parts[i]),
        ],
      ]),
      style: style,
    );
  }
}
