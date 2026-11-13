// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../../../core/grpc/clients/media_client.dart' show MyListItem;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/open_trailer.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import '../../my_list.dart';

// Secondary actions of a TV details page — "Scarica", "La mia lista",
// "Trailer" — shared by the film layouts (details_screen.dart's
// _WatchButton) and the series page (series_page_layout).

/// The look of a secondary action next to the play button(s) ("Scarica",
/// "La mia lista").
Widget detailsSecondaryChip(
    BuildContext context, bool focused, IconData icon, String label) {
  final sh = MediaQuery.sizeOf(context).height;
  // A secondary action next to "Guarda"/the language buttons, not a second
  // one of equal weight: unfocused it's a plain ghost outline (no fill,
  // dimmer icon/text); focused it gets the same primary-color treatment as
  // every other focusable here, just scaled down, so it doesn't lose
  // visibility as a D-pad target.
  return AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    padding: EdgeInsets.symmetric(
        horizontal: sh * (20.0 / 1080.0), vertical: sh * (10.0 / 1080.0)),
    decoration: BoxDecoration(
      color: focused ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: focused ? AppTheme.primary : AppTheme.textLow,
        width: focused ? 0 : 1,
      ),
      boxShadow: focused
          ? [
              BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1)
            ]
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: sh * (14.0 / 1080.0),
            color: focused ? AppTheme.textHigh : AppTheme.textMid),
        SizedBox(width: sh * (6.0 / 1080.0)),
        Text(
          label,
          style: TextStyle(
            color: focused ? AppTheme.textHigh : AppTheme.textMid,
            fontSize: sh * (14.0 / 1080.0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// "La mia lista" toggle on a TV details page (film and series). Without
/// explicit [onLeft]/[onRight] the default D-pad traversal moves on.
class TvMyListChip extends StatelessWidget {
  final MyListItem item;
  final FocusNode? focusNode;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  const TvMyListChip(
      {super.key,
      required this.item,
      this.focusNode,
      this.onLeft,
      this.onRight});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MyList.instance,
      builder: (context, _) {
        final list = MyList.instance;
        if (!list.supported) return const SizedBox.shrink();
        final saved = list.contains(item.pluginId, item.mediaId);
        return TvFocusable(
          focusNode: focusNode,
          onLeft: onLeft,
          onRight: onRight,
          onActivate: () => toggleMyListWithFeedback(
              ScaffoldMessenger.of(context), item),
          builder: (context, focused) => detailsSecondaryChip(
              context,
              focused,
              saved ? Icons.check_rounded : Icons.add_rounded,
              'La mia lista'),
        );
      },
    );
  }
}

/// "Trailer" on a TV details page — hands the link to the YouTube app (see
/// open_trailer.dart).
class TvTrailerChip extends StatelessWidget {
  final String url;
  final FocusNode? focusNode;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  const TvTrailerChip(
      {super.key,
      required this.url,
      this.focusNode,
      this.onLeft,
      this.onRight});

  @override
  Widget build(BuildContext context) => TvFocusable(
        focusNode: focusNode,
        onLeft: onLeft,
        onRight: onRight,
        onActivate: () =>
            openTrailerWithFeedback(ScaffoldMessenger.of(context), url),
        builder: (context, focused) => detailsSecondaryChip(
            context, focused, Icons.movie_outlined, 'Trailer'),
      );
}
