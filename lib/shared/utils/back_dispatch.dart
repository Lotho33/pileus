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
library;

import 'package:flutter/foundation.dart';

DateTime? _lastAt;

/// ~1 physical press. The two Android paths land within a few ms of each
/// other; this is generous enough to also absorb the "double KeyDownEvent"
/// quirk while staying under a deliberate rapid double-press.
const Duration _window = Duration(milliseconds: 300);

bool _dedupApplies() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool consumeBackEvent() {
  if (!_dedupApplies()) return true;
  final now = DateTime.now();
  final last = _lastAt;
  if (last != null && now.difference(last) < _window) return false;
  _lastAt = now;
  return true;
}
