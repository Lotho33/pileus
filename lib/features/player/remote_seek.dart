/// ←/→ on the remote while the TV player's controls are hidden — the scheme
/// the Vega OS player (pileus-vega PlayerScreen) uses, and the one most TV
/// players have: a press seeks 10 s at once; held, the target moves on
/// 10 s per step, 30 s per step after [heldAfter] of them, and is shown as a
/// preview; the seek itself happens once, on release.
///
/// Pure state: the screen feeds it key events and the playhead, reads
/// [target] for the preview, and seeks to what [release] returns.
class RemoteSeek {
  static const step = Duration(seconds: 10);
  static const heldStep = Duration(seconds: 30);
  static const heldAfter = 6;

  /// Remotes repeat a held key 10-20 times a second; steps go at most this
  /// often (Vega's row stepping uses the same pace).
  static const minRepeatGap = Duration(milliseconds: 100);

  int _dir = 0;
  int _count = 0;
  Duration? _target;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Where the playhead will go, while a key is held; null otherwise.
  Duration? get target => _target;
  bool get active => _target != null;

  /// A key down (or repeat) in direction [dir] (+1 / -1). [position] is the
  /// playhead, [duration] the stream length (zero when unknown). Returns
  /// whether the target moved (a repeat inside [minRepeatGap] doesn't).
  bool press(int dir, Duration position, Duration duration, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final same = _target != null && _dir == dir;
    if (same && t.difference(_last) < minRepeatGap) return false;
    _last = t;
    final base = same ? _target! : position;
    _count = same ? _count + 1 : 1;
    _dir = dir;
    final delta = _count > heldAfter ? heldStep : step;
    var next = dir > 0 ? base + delta : base - delta;
    if (next.isNegative) next = Duration.zero;
    if (duration > Duration.zero) {
      final last = duration - const Duration(seconds: 1);
      if (next > last) next = last.isNegative ? Duration.zero : last;
    }
    _target = next;
    return true;
  }

  /// The key went up: the position to seek to (null when nothing was held).
  Duration? release() {
    final t = _target;
    _dir = 0;
    _count = 0;
    _target = null;
    return t;
  }
}
