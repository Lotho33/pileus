// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../../core/theme/app_scale.dart';
import '../tv_back_button.dart';

/// Header for full-screen Settings pages — replaces the stock Material
/// AppBar (fixed 56dp height, default title style, and a back button that
/// isn't wired into the D-pad focus chain) with the same back-button +
/// title idiom already used for pushed screens elsewhere in the app (see
/// _BackButton/_BrowseContent in browse_screen.dart): sh-ratio sized, and —
/// unlike the AppBar's arrow — actually reachable and operable with a
/// plain D-pad remote that has no dedicated back key.
class SettingsHeader extends StatelessWidget {
  final String title;
  final FocusNode focusNode;
  final VoidCallback onBack;
  final VoidCallback? onFocusDown;
  final bool autofocus;

  const SettingsHeader({
    super.key,
    required this.title,
    required this.focusNode,
    required this.onBack,
    this.onFocusDown,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppScale.space(context, 24),
          AppScale.space(context, 20),
          AppScale.space(context, 24),
          AppScale.space(context, 12)),
      child: Row(
        children: [
          TvBackButton(
              focusNode: focusNode,
              onTap: onBack,
              onFocusDown: onFocusDown,
              autofocus: autofocus),
          SizedBox(width: AppScale.space(context, 14)),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: AppScale.title(context),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
