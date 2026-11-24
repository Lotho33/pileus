import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// "Stai ancora guardando?" — shared by the four playback screens.
///
/// Episodes that start by themselves (the next-episode countdown) keep a
/// screen nobody is watching streaming all night, and mycelium proxying it.
/// So at an episode boundary the player asks first when, since the last
/// key press, click or touch, [maxEpisodes] episodes have played back to
/// back or [maxIdle] has gone by. It never interrupts an episode or a film
/// midway.
///
/// Input is heard globally (HardwareKeyboard + the pointer router) while
/// [attach]ed, so each screen only reports its auto-advances.
class StillWatchingGuard {
  static const maxEpisodes = 3;
  static const maxIdle = Duration(minutes: 90);

  final DateTime Function() _now;
  StillWatchingGuard({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _lastInput = _now();
  }

  late DateTime _lastInput;
  // Episodes started since the last input, the one playing included.
  int _episodes = 1;
  bool _attached = false;

  /// A key, click, touch or scroll: someone is there.
  void noteInput() {
    _lastInput = _now();
    _episodes = 1;
  }

  /// The countdown is about to start the next episode by itself: true to
  /// ask first (pause and show the prompt) instead.
  bool get shouldAsk =>
      _episodes >= maxEpisodes || _now().difference(_lastInput) >= maxIdle;

  /// The next episode started by itself (not asked, or asked and answered).
  void noteAutoAdvance() => _episodes++;

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent) noteInput();
    return false; // only listening
  }

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent || e is PointerScrollEvent) noteInput();
  }

  void attach() {
    if (_attached) return;
    _attached = true;
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }
}

/// The prompt's text: with the series' name when known.
String stillWatchingMessage(String showTitle) => showTitle.trim().isEmpty
    ? 'Stai ancora guardando?'
    : 'Stai ancora guardando «${showTitle.trim()}»?';
