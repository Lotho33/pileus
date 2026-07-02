import 'dart:async';

import 'package:flutter/services.dart';

/// Tells a fresh, isolated key press apart from every event that belongs to
/// a key being *held* — so an action that must only fire on a deliberate
/// press (opening the side nav when Left is pressed on the first carousel
/// card) never fires while the user is just holding Left to scroll back to
/// that card.
///
/// Works whichever way the box reports a hold:
///  * KeyRepeatEvent stream — the repeats are flagged directly;
///  * a KeyDown cascade with a single trailing KeyUp — the first KeyDown is
///    fresh, every KeyDown after it (until the KeyUp) is a repeat.
///
/// A dropped KeyUp (some TV boxes only deliver it to the focused node, which
/// may have changed) self-corrects: the held flag clears on its own if no
/// event for the key arrives for [_releaseGrace], so the next press counts
/// as fresh again. That grace is a safety net, not a debounce — a genuine
/// single press is reported as fresh with zero delay.
class HeldKeyGate {
  bool _held = false;
  Timer? _release;

  // Comfortably longer than any real key-repeat interval, short enough that
  // a re-press after a missed KeyUp isn't swallowed for long.
  static const _releaseGrace = Duration(milliseconds: 220);

  /// Feed every KeyDown / KeyRepeat / KeyUp for the tracked key. Returns
  /// `true` if this event is a repeat of a still-held key (suppress the
  /// press-only action), `false` for a fresh isolated press.
  bool isRepeat(KeyEvent event) {
    if (event is KeyUpEvent) {
      _held = false;
      _release?.cancel();
      return true;
    }
    final repeat = _held || event is KeyRepeatEvent;
    _held = true;
    _release?.cancel();
    _release = Timer(_releaseGrace, () => _held = false);
    return repeat;
  }

  void dispose() => _release?.cancel();
}
