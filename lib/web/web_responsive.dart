import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../shared/responsive.dart';

/// Picks the mobile-flavor screen at `Breakpoint.compact` width (< 640,
/// the same threshold the desktop-responsive layout already uses for
/// "phone-ish" — see shared/responsive.dart) **or on a touch-first device**,
/// and the desktop-flavor one otherwise.
///
/// Without this, web always renders `lib/desktop/` regardless of viewport —
/// on a phone/PWA width that means a permanently-visible nav rail eating
/// horizontal space (asymmetric, cramped). `lib/mobile/`
/// is already built, dart:io-free, and — the part that makes this a route-
/// level switch rather than a wrapper widget — already navigates via the
/// same go_router path shapes (`/player/:pluginId/:mediaId`, `/details/...`)
/// that `web_router.dart` resolves regardless of which shell pushed to them.
///
/// Width alone sent every tablet (iPad ≥ 768 px, Android tablets in Chrome)
/// to the desktop shell, whose item options live on right-click and whose
/// affordances assume hover — unreachable with a finger. The native Android
/// build already runs the mobile flavor on tablets, so a touch-first browser
/// gets the same. Detected by the *primary* pointer (`pointer: coarse`), not
/// the user agent: iPadOS Safari reports itself as a Mac by default, and a
/// touchscreen laptop (primary pointer = trackpad) keeps the desktop shell.
Widget webResponsive(
  BuildContext context, {
  required WidgetBuilder mobile,
  required WidgetBuilder desktop,
}) {
  final compact = breakpointOf(MediaQuery.sizeOf(context).width).isCompact;
  return compact || _touchPrimary ? mobile(context) : desktop(context);
}

/// Read once: switching shell mid-session (e.g. attaching an iPad trackpad)
/// would throw away the whole navigation state for no real gain.
final bool _touchPrimary = () {
  try {
    return web.window.matchMedia('(pointer: coarse)').matches;
  } catch (_) {
    return false;
  }
}();
