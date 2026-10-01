import 'package:flutter/widgets.dart';

/// Height for a 2-line caption at [size], honouring the active text scale so
/// row/grid height math stays exact (no debug overflow stripes).
double captionBoxHeight(BuildContext context, double size, {int lines = 2}) =>
    MediaQuery.textScalerOf(context).scale(size) * 1.3 * lines + 6;

/// Width breakpoints for the responsive (desktop / web) UI. One layout that
/// adapts by window width and input, rather than separate desktop/web forks.
///
///  * [compact]  < 640    — phone-ish; single column
///  * [medium]   640–1000  — small window / tablet; icon-only rail
///  * [expanded] 1000–1500 — laptop; labelled rail
///  * [large]    1500–1920 — desktop 1080p-class
///  * [xlarge]   ≥ 1920    — QHD / 4K-at-100%; bigger art + type so the UI
///                           doesn't read tiny on a physically large panel
enum Breakpoint { compact, medium, expanded, large, xlarge }

/// Content is never stretched edge-to-edge past this — only a genuine 4K+
/// panel gets side gutters; a maximised QHD window (≈2320px of content) is
/// under this and fills out completely, so the carousel paging chevrons sit
/// at the true right edge rather than floating inboard.
const double kMaxContentWidth = 2560;

Breakpoint breakpointOf(double width) {
  if (width < 640) return Breakpoint.compact;
  if (width < 1000) return Breakpoint.medium;
  if (width < 1500) return Breakpoint.expanded;
  if (width < 1920) return Breakpoint.large;
  return Breakpoint.xlarge;
}

extension BreakpointX on Breakpoint {
  bool get isCompact => this == Breakpoint.compact;
  bool get atLeastExpanded => index >= Breakpoint.expanded.index;
  bool get atLeastLarge => index >= Breakpoint.large.index;

  /// Nominal poster-card width for horizontal rows at this size.
  double get cardWidth => switch (this) {
        Breakpoint.compact => 118,
        Breakpoint.medium => 142,
        Breakpoint.expanded => 176,
        Breakpoint.large => 208,
        Breakpoint.xlarge => 236,
      };

  /// Outer horizontal padding for rows / page content.
  double get gutter => switch (this) {
        Breakpoint.compact => 16,
        Breakpoint.medium => 28,
        Breakpoint.expanded => 44,
        Breakpoint.large => 64,
        Breakpoint.xlarge => 88,
      };

  /// Row-header font size.
  double get rowTitleSize => switch (this) {
        Breakpoint.compact => 16,
        Breakpoint.medium => 17,
        Breakpoint.expanded => 18,
        Breakpoint.large => 20,
        Breakpoint.xlarge => 22,
      };

  /// Card caption font size.
  double get cardTitleSize => atLeastLarge ? 15 : 13.5;

  /// Hero headline (fallback when there's no logo image).
  double get heroTitleSize => switch (this) {
        Breakpoint.compact => 30,
        Breakpoint.medium => 36,
        Breakpoint.expanded => 42,
        Breakpoint.large => 50,
        Breakpoint.xlarge => 58,
      };

  double get railLabelSize => atLeastLarge ? 14.5 : 13.5;
}

/// Rebuilds its subtree with the current [Breakpoint] whenever the window
/// crosses a threshold.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, Breakpoint, BoxConstraints) builder;
  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => builder(context, breakpointOf(c.maxWidth), c),
    );
  }
}
