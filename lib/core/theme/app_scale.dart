import 'package:flutter/material.dart';

/// The app's actual responsive scale — every ratio here already existed,
/// duplicated, across home_screen.dart (_PluginNavItem/_NavAction),
/// browse_screen.dart (_BackButton/title) and the Settings module before
/// this file existed. `AppTheme.dark()`'s `textTheme` looks like a type
/// scale but nothing in the app reads it (screens hand-roll `sh * ratio`
/// literals instead, which is where the numbers actually come from) — this
/// is the real one. Every screen the app builds next should pull its sizes
/// from here instead of inventing a fresh `sh * (x / 1080.0)` literal, so
/// the drift that produced the original Settings audit doesn't recur.
///
/// The convention itself: every size is proportional to screen HEIGHT
/// (`sh`), calibrated against a 1080p baseline (hence `/ 1080.0`), because
/// Android TV panels are always 16:9 — anchoring to height keeps text/icons
/// visually the same relative size at any resolution (720p, 1080p, 4K)
/// without the compounding-scale bug that ambient text scalers cause (see
/// main.dart's MediaQuery override, which deliberately does NOT apply on
/// top of this for the same reason).
abstract final class AppScale {
  static double sh(BuildContext context) => MediaQuery.sizeOf(context).height;

  // ── Type scale ────────────────────────────────────────────────────────
  // Page/screen title — matches browse_screen.dart's header and the
  // "Pileus" wordmark in home_screen.dart's side nav.
  static double title(BuildContext context) => sh(context) * 0.030;

  // Primary row/button label — matches _PluginNavItem/_NavAction. Bumped
  // again (+15%) on top of the original +15% pass at the user's request —
  // the side menu specifically read as too small even after the first bump.
  static double label(BuildContext context) => sh(context) * 0.0265;

  // Secondary text: row subtitles, section headers, badges, dialog error
  // text. Clamped so it never balloons on a very tall panel — and given a
  // low floor only as a guard for a genuinely tiny desktop window, NOT as a
  // readability floor: on an Android TV whose logical canvas comes back
  // half-size (devicePixelRatio 2.0 on a 1080p panel → sh ≈ 540) a 16px
  // floor made this text ~1.5× bigger than the layout box reserved for it
  // (every surrounding size is a plain sh-ratio with no floor), which is
  // what produced the clipped/overlapping text on TV. 11px keeps a sub-400
  // desktop window from collapsing to unreadable without decoupling this
  // from the proportional scale on every real TV.
  static double caption(BuildContext context) =>
      (sh(context) * (21.0 / 1080.0)).clamp(11.0, 30.0);

  // ── Icon scale ────────────────────────────────────────────────────────
  static double iconL(BuildContext context) =>
      sh(context) * (42.5 / 1080.0); // leading row icon
  static double iconM(BuildContext context) =>
      sh(context) * (28.0 / 1080.0); // trailing/back icon
  static double iconS(BuildContext context) =>
      sh(context) * (23.0 / 1080.0); // inline small icon
  static double iconXL(BuildContext context) =>
      sh(context) * (52.0 / 1080.0); // full-screen status icon (auth flow)

  // ── Spinner scale ─────────────────────────────────────────────────────
  static double spinnerS(BuildContext context) =>
      sh(context) * (24.0 / 1080.0); // inline/button spinner
  static double spinnerL(BuildContext context) =>
      sh(context) * (48.0 / 1080.0); // full-screen loading spinner

  // ── Spacing ───────────────────────────────────────────────────────────
  // Any padding/margin/gap value: pass the px you'd want at 1080p, get
  // back the scaled equivalent — e.g. `AppScale.space(context, 16)`.
  static double space(BuildContext context, double px1080) =>
      sh(context) * (px1080 / 1080.0);

  // ── Focus treatment ───────────────────────────────────────────────────
  // Google's TV focus-scale guidance is 1.025x-1.1x; which end of that
  // range to use depends on how much a scaled-up element risks overlapping
  // its neighbors. Full-width rows (Settings) sit close together — a card
  // in a carousel has room to spare.
  static const double focusScaleRow = 1.02;
  static const double focusScaleCard = 1.07;
  static const double focusScaleIcon =
      1.06; // small standalone icon buttons (back button, etc)

  // Every call site pairs an `AnimatedScale` (the scale-up) with an
  // `AnimatedContainer` (border/color) to animate the same focus change —
  // but each one picked its own duration, and near-none of the
  // `AnimatedContainer`s specified a `curve` at all, silently defaulting to
  // `Curves.linear` while the `AnimatedScale` next to it eased. Same
  // transition, two different speed profiles — reads as the border/scale
  // visibly stepping out of sync (2026-09 audit). 150ms/easeOutCubic was
  // already the most common value across call sites; this is just the one
  // place that value now lives, instead of each site re-guessing it.
  static const Duration focusDuration = Duration(milliseconds: 150);
  static const Curve focusCurve = Curves.easeOutCubic;

  // `AnimatedSwitcher.switchInCurve`/`switchOutCurve` both default to
  // `Curves.linear` — every crossfade in the app (details/plugin state,
  // quick-search results, home hero art, season poster) left that default,
  // which at these short durations (140-260ms) reads as a hard cut rather
  // than a dissolve. One curve for all of them, same reasoning as
  // `focusCurve` above.
  static const Curve fadeCurve = Curves.easeOut;

  // Focus glow — now always empty. A blurred BoxShadow forces a Gaussian-blur
  // shader compile the first time each focusable draws it (a multi-hundred-ms
  // raster hitch on a weak Amlogic GPU the first time you navigate onto each
  // kind of control), and repaints that blur layer for the whole focus-scale
  // animation after that. Every call site already carries a solid primary
  // border + a scale-up as its focus cue — the standard Android TV
  // treatment — so the glow was pure cost. Kept as a function (rather than
  // deleting ~20 call sites) so re-enabling it later is a one-line change.
  static List<BoxShadow> focusGlow(Color color,
          {double alpha = 0.35, double blur = 16}) =>
      const [];

  // ── Screen-edge safe area ─────────────────────────────────────────────
  // Extra outer padding for edge-to-edge scrollable content (the Settings
  // screens' ListViews, which have no side padding of their own — only
  // SettingsNavRow's own ~16px margin). Combined with that margin this
  // reaches Google's cited ~48dp/5% TV safe-margin total. Needed for two
  // reasons: overscan on real hardware, and because AnimatedScale paints
  // outside its row's original layout box on focus — without this, a row
  // focused right at the screen edge scales its glow/border past the
  // physical boundary and gets hard-clipped there, which reads as a
  // broken/cut-off animation instead of a highlight.
  static double screenHPad(BuildContext context) => space(context, 32);

  // ── Full-bleed catalog screens' own safe margin ─────────────────────────
  // home_screen.dart and card_carousel_block_view.dart each carried an
  // identical private `_rHPad = 56 / 1920` / `_rCardGap = 20 / 1920` —
  // duplicated, not derived from one another, so a future change to either
  // could silently desync the home hero's own edge padding from the
  // carousel row underneath it. Consolidated here as the single source.
  //
  // Deliberately width-based (unlike screenHPad above, which is
  // height-based) rather than converted to it: at 1920×1080 this is 56px,
  // noticeably more generous than screenHPad's 32px — TV panels are always
  // 16:9 so the two bases stay proportional either way, but forcing this
  // onto screenHPad's smaller value would have shrunk an already-adequate
  // margin, not improved it.
  static double catalogHPadRatio(double screenWidth) =>
      screenWidth * (56.0 / 1920.0);
  static double catalogGapRatio(double screenWidth) =>
      screenWidth * (20.0 / 1920.0);

  // ── Details/episode/series content scale ──────────────────────────────
  // The 3 screens with a heavy free-text layout (movie/series details,
  // episode detail, series page) each hand-rolled their own
  // `(sh/1080*1.15).clamp(...)` instead of a plain AppScale ratio, because
  // that text also has to fit a fixed-pixel-budget column/footer — which
  // floors it far more aggressively than any other screen's proportional
  // sizing needs. `hasFooter` (whether the related/similar-content footer
  // is showing) frees up more room to size into when it isn't; `floor`/
  // `ceiling` stay per-caller since each was tuned against that screen's
  // own known overflow point, not picked at random.
  //
  // Divides by the ambient textScaler for the same reason every other size
  // on this scale doesn't need to: without it, main.dart's ~1.35×
  // desktop/web readability boost is applied *again* on top of fonts sized
  // by this already-inflated `s`, doubling up and overflowing the
  // fixed-pixel budget the floor above was tuned against (2026-09 audit —
  // only details_screen.dart was doing this division before the 3 call
  // sites were consolidated here; the other two were exposed to exactly
  // that double-scaling on desktop/web).
  static double contentScale(
    BuildContext context, {
    required bool hasFooter,
    double floor = 0.55,
    double ceiling = 2.4,
  }) {
    final ts = MediaQuery.textScalerOf(context).scale(1.0);
    return (sh(context) / 1080.0 * 1.15).clamp(floor, ceiling) *
        (hasFooter ? 1.0 : 1.12) /
        (ts > 1.0 ? ts : 1.0);
  }
}
