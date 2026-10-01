import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/grpc/clients/media_client.dart';
import 'live_event_popup.dart';

/// Tap routing for a catalog item, shared by every horizontal carousel
/// (home screen catalog rows, search results) — previously duplicated
/// identically in home_screen.dart's `_CatalogSection._handleTap` and
/// fixed_carousel.dart's `_tapHandler`.
///
/// Not shared with browse_screen.dart: that screen routes playable items
/// straight to `/player/...` instead of `/details/...` — a genuinely
/// different navigation policy, not a duplicate of this one.
void openCatalogItem(BuildContext ctx, String pluginId, CatalogItem item) {
  final mt = item.mediaType;
  if (mt == 'live') {
    showLiveEventPopup(ctx, pluginId, item);
  } else if (mt == 'series' || mt == 'movie' || mt == 'episode') {
    // extra: item — the catalog item is already fully loaded and its
    // fanart/poster already decoded/cached from wherever the user tapped
    // it (a hero background, a card). DetailsScreen uses this as a preview
    // so the same image renders continuously instead of the screen going
    // blank behind a spinner until GetDetails round-trips.
    ctx.push('/details/$pluginId/${Uri.encodeComponent(item.id)}', extra: item);
  } else if (item.isDir) {
    ctx.push('/browse/$pluginId/${Uri.encodeComponent(item.id)}',
        extra: item.title);
  } else {
    // extra: item — the catalog item is already fully loaded and its
    // fanart/poster already decoded/cached from wherever the user tapped
    // it (a hero background, a card). DetailsScreen uses this as a preview
    // so the same image renders continuously instead of the screen going
    // blank behind a spinner until GetDetails round-trips.
    ctx.push('/details/$pluginId/${Uri.encodeComponent(item.id)}', extra: item);
  }
}
