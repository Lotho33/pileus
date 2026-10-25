import 'package:flutter/material.dart';

import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../tv_focusable.dart';

/// The one look of a settings row on the TV: a card with the label, what
/// it's set to on the right ([trailing]), an optional control under it
/// ([below], e.g. a value bar) and the explanation inside the card
/// ([caption]) — so a switch, a value you step through and a bar all read
/// as the same kind of thing. Focus = purple wash + border only: no scale —
/// a scaled card re-rasterises on every focus step, and with a dozen of
/// them scrolling on a TV box that was visible lag.
class SettingsCard extends StatelessWidget {
  final bool focused;
  final String label;
  final String? caption;
  final Widget? trailing;
  final Widget? below;

  const SettingsCard({
    super.key,
    required this.focused,
    required this.label,
    this.caption,
    this.trailing,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppScale.focusDuration,
      curve: AppScale.focusCurve,
      margin: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 16),
          vertical: AppScale.space(context, 4)),
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 24),
          vertical: AppScale.space(context, 16)),
      decoration: BoxDecoration(
        color: focused
            ? AppTheme.primary.withValues(alpha: 0.18)
            : AppTheme.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AppTheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: focused ? Colors.white : AppTheme.textMid,
                    fontSize: AppScale.label(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: AppScale.space(context, 16)),
                trailing!,
              ],
            ],
          ),
          if (below != null) ...[
            SizedBox(height: AppScale.space(context, 12)),
            below!,
          ],
          if (caption != null && caption!.isNotEmpty) ...[
            SizedBox(height: AppScale.space(context, 8)),
            Text(
              caption!,
              style: TextStyle(
                color: focused ? AppTheme.textMid : AppTheme.textLow,
                fontSize: AppScale.caption(context),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A setting changed with Left/Right (and OK, when [onActivate] is set):
/// the value on the right, a bar under the label when [fraction] is given,
/// "‹ value ›" otherwise. Up/Down are left to the list.
class SettingsStepperRow extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;

  /// 0..1 — draws the bar. Null for a list of choices.
  final double? fraction;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback? onActivate;

  const SettingsStepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onLeft,
    required this.onRight,
    this.caption,
    this.fraction,
    this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onLeft: onLeft,
      onRight: onRight,
      onActivate: onActivate,
      // No Scrollable.ensureVisible here: focus traversal already scrolls
      // the row into view, and a second animated scroll to the centre
      // fought it on every step (stutter going down the list).
      builder: (context, focused) {
        final valueStyle = TextStyle(
          color: focused ? Colors.white : AppTheme.textMid,
          fontSize: AppScale.label(context),
          fontWeight: FontWeight.w600,
        );
        return SettingsCard(
          focused: focused,
          label: label,
          caption: caption,
          trailing: Text(fraction == null ? '‹  $value  ›' : value,
              style: valueStyle),
          below: fraction == null
              ? null
              : SettingsValueBar(fraction: fraction!, focused: focused),
        );
      },
    );
  }
}

/// The thin bar of a [SettingsStepperRow].
class SettingsValueBar extends StatelessWidget {
  final double fraction;
  final bool focused;

  const SettingsValueBar(
      {super.key, required this.fraction, required this.focused});

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, cc) => Stack(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 4,
            width: cc.maxWidth * f,
            decoration: BoxDecoration(
              color: focused ? AppTheme.primary : Colors.white70,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
