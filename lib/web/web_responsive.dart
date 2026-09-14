import 'package:flutter/widgets.dart';

import '../shared/responsive.dart';

/// Picks the mobile-flavor screen at `Breakpoint.compact` width (< 640,
/// the same threshold the desktop-responsive layout already uses for
/// "phone-ish" — see shared/responsive.dart) and the desktop-flavor one
/// otherwise.
///
/// Before this, web always rendered `lib/desktop/` regardless of viewport —
/// on a phone/PWA width that meant a permanently-visible nav rail eating
/// horizontal space (asymmetric, cramped — reported 2026-09-14). `lib/mobile/`
/// was already built, dart:io-free, and — the part that makes this a route-
/// level switch rather than a wrapper widget — already navigates via the
/// same go_router path shapes (`/player/:pluginId/:mediaId`, `/details/...`)
/// that `web_router.dart` resolves regardless of which shell pushed to them.
Widget webResponsive(
  BuildContext context, {
  required WidgetBuilder mobile,
  required WidgetBuilder desktop,
}) {
  final compact = breakpointOf(MediaQuery.sizeOf(context).width).isCompact;
  return compact ? mobile(context) : desktop(context);
}
