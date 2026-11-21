import 'dart:async';

import 'player_tuning.dart';

/// How often every player saves its watch progress while playing.
const kProgressHeartbeatInterval = Duration(seconds: 15);

/// The periodic progress save shared by the four players.
///
/// Live never runs it — see PlaybackProgress's class doc ("Why every
/// screen's 15s heartbeat still skips live streams"). While the app can't
/// be seen it stops (a wasted round-trip every 15s otherwise), with one last
/// save the moment it goes to the background; it restarts on return.
///
/// [onSave] is the screen's own guarded save (each one skips mid
/// episode-switch on its own).
class ProgressHeartbeat {
  ProgressHeartbeat({
    required this.isLive,
    required this.onSave,
    this.interval = kProgressHeartbeatInterval,
  });

  final bool isLive;
  final void Function() onSave;
  final Duration interval;

  Timer? _timer;

  bool get isRunning => _timer != null;

  /// Starts the periodic save (no-op for live, or when already running).
  void start() {
    if (isLive || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => onSave());
  }

  /// The app went to the background (true) or came back (false).
  void setBackgrounded(bool backgrounded) {
    if (!backgrounded) {
      start();
      return;
    }
    final t = _timer;
    if (t == null) return;
    t.cancel();
    _timer = null;
    _saveSafely();
  }

  /// The screen is going away: stop, and one final save — catches everything
  /// since the last tick (e.g. backing out 8 s after it).
  void close() {
    _timer?.cancel();
    _timer = null;
    _saveSafely();
  }

  void _saveSafely() {
    if (isLive) return;
    try {
      onSave();
    } catch (_) {}
  }
}

/// The short window a playback error gets to recover on its own before the
/// player shows it (see [kErrorGraceDuration]) — shared by the four players.
class ErrorGrace {
  ErrorGrace({this.duration = kErrorGraceDuration});

  final Duration duration;
  Timer? _timer;

  bool get isActive => _timer?.isActive ?? false;

  /// (Re)starts the window; [onExpired] runs if nothing [cancel]s it first.
  void arm(void Function() onExpired) {
    _timer?.cancel();
    _timer = Timer(duration, onExpired);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
