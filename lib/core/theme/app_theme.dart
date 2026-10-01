import 'package:flutter/material.dart';

// Responsive type/spacing/focus scale lives in app_scale.dart, not here —
// ThemeData is built once at startup with no BuildContext, so it can't
// express the sh-ratio sizing every screen actually uses.
abstract final class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0D0D1A); // main scaffold background
  static const Color surface = Color(0xFF141428); // card / panel
  static const Color surface2 = Color(0xFF1A1A2E); // lighter card
  static const Color border = Color(0xFF2A2A4A); // subtle borders
  static const Color primary = Color(0xFF7C6AF7); // purple accent
  static const Color secondary = Color(0xFF4FC3F7); // cyan accent
  // Soft off-white rather than pure #FFFFFF — TV guidance flags pure white
  // as harsh at typical living-room brightness in a dim room; this is close
  // enough to be imperceptible as a color shift but avoids that.
  static const Color textHigh = Color(0xFFF2F2F0);
  static const Color textMid = Colors.white70;
  static const Color textLow = Colors.white38;

  // App-wide font, set once here (ThemeData.fontFamily) — every Text style
  // in this app leaves fontFamily unset, so it falls through
  // DefaultTextStyle to whatever ThemeData declares, which is what makes
  // this apply everywhere with one line instead of touching every call
  // site.
  static const String bodyFont = 'DMSans';

  // ── ThemeData ─────────────────────────────────────────────────────────────────
  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        fontFamily: bodyFont,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surface,
          onSurface: textHigh,
        ),
        cardColor: surface2,
        focusColor: primary,
        dividerColor: border,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: textHigh,
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: bg,
          hintStyle: TextStyle(color: textLow, fontSize: 18),
          labelStyle: TextStyle(color: textMid),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? primary : Colors.transparent),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          titleTextStyle: TextStyle(
              color: textHigh, fontSize: 22, fontWeight: FontWeight.w700),
        ),
      );
}
