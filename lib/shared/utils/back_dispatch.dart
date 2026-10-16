/// One physical Back/Esc press on Android TV reaches the app on **two
/// independent paths**:
///
///  1. a key event — `LogicalKeyboardKey.goBack` (some boxes even emit it
///     twice for a single press), handled by the focus tree
///     (`TvFocusable.onEsc`, the raw `Focus.onKeyEvent` handlers);
///  2. the platform channel — `Activity.onBackPressed()` → `System.popRoute`,
///     handled by GoRouter's `BackButtonDispatcher` (and any `PopScope`).
///
/// Both fire for the same press, so a screen that pops its route on (1) also
/// gets popped again by (2) — "Back acts like it was pressed twice". Linux
/// desktop only ever has the Esc key, which is why it never doubled there.
///
/// [consumeBackEvent] is the single gate every "go back / close / pop"
/// handler funnels through: the first call in a short window wins and
/// returns `true` (act on it); anything else inside the window is the same
/// press echoing on the other path and returns `false` (swallow, do
/// nothing). Handlers that do something *other* than navigate back on Esc
/// (e.g. the home screen opening its side nav) deliberately do NOT call
/// this — they're not a back-navigation and must stay independent of the
/// platform pop that drives app-exit from the root route.
///
/// The dedup window is **Android-only**. That two-path echo (plus the
/// "double KeyDownEvent" box quirk) is what it exists for; everywhere else
/// there is a single path — the Esc key on desktop, one key event on web —
/// so a rapid Esc-Esc is two *deliberate* presses and the window must not
/// eat the second one.
///
/// TV web (webOS/Tizen remote Back, bridged to `GoBack` in web/index.html)
/// rebuilds the Android pair on purpose — key path first, then a router pop
/// (main.dart) — because the TV screens rely on it (e.g. Back on a card
/// that only moves focus still reaches the home's exit-confirm). There the
/// dedup is scoped to that one press instead of a time window:
/// [beginWebBackPress]/[endWebBackPress].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

DateTime? _lastAt;

/// ~1 physical press. The two Android paths land within a few ms of each
/// other; this is generous enough to also absorb the "double KeyDownEvent"
/// quirk while staying under a deliberate rapid double-press.
const Duration _window = Duration(milliseconds: 300);

bool _dedupApplies() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool _webPressActive = false;
bool _webPressConsumed = false;

/// TV web: a remote Back press starts (before the focus tree sees it).
void beginWebBackPress() {
  _webPressActive = true;
  _webPressConsumed = false;
}

/// TV web: the key path is done with the press. Returns whether a handler
/// already acted on it via [consumeBackEvent] — if not, the caller does the
/// router pop Android's platform path would have done.
bool endWebBackPress() {
  _webPressActive = false;
  return _webPressConsumed;
}

bool consumeBackEvent() {
  if (_webPressActive) {
    if (_webPressConsumed) return false;
    _webPressConsumed = true;
    return true;
  }
  if (!_dedupApplies()) return true;
  final now = DateTime.now();
  final last = _lastAt;
  if (last != null && now.difference(last) < _window) return false;
  _lastAt = now;
  return true;
}

/// TV web safety net: a Back handler that navigated without going through
/// [consumeBackEvent] (a bare `Navigator.pop`) still counts as having acted
/// on the press, so the follow-up router pop never closes a second screen.
class BackPressNavObserver extends NavigatorObserver {
  void _mark() {
    if (_webPressActive) _webPressConsumed = true;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _mark();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _mark();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _mark();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _mark();
}
