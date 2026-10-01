import 'package:flutter/material.dart';

import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String text;
  const SettingsSectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppScale.space(context, 24),
          AppScale.space(context, 24),
          AppScale.space(context, 24),
          AppScale.space(context, 8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small accent mark — plain gray caption text alone read as an
          // afterthought next to the rest of the app's purple-accented
          // chrome (focus glow, active states); this ties section labels
          // into the same accent without adding much visual weight.
          Container(
            width: AppScale.space(context, 3),
            height: AppScale.space(context, 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: AppScale.space(context, 8)),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: AppTheme.textLow,
              fontSize: AppScale.caption(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
