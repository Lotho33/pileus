import 'dart:async';

import 'package:flutter/widgets.dart';

import 'di/injection.dart' show getIt, reconnectGrpcChannel;
import 'utils/metrics.dart';
import '../features/media/bloc/plugin_bloc.dart';
import '../features/media/bloc/plugin_event.dart';

/// One process-wide [WidgetsBindingObserver] that sheds background work when
/// the OS backgrounds the app.
///
/// Every UI shell (TV / mobile / desktop / web) calls [attach] from its root
/// `State.initState` and [detach] from `dispose`. attach/detach are
/// ref-counted so a hot-reload or an overlapping shell can't leave it
/// double-registered or prematurely torn down.
///
/// What it does today:
/// - Brackets [PluginBloc]'s 30 s status poll — on a weak TV box each poll
///   while backgrounded is a wasted gRPC round-trip + JSON decode.
/// - Exposes [state] (a [ValueListenable]) so other widgets — the shared
///   playback heartbeat — can pause their own timers without each registering
///   a separate observer.
/// - Drops the gRPC connection after the device slept or the app sat in the
///   background (see ReconnectableChannel for why it can't be trusted then).
///   Sleep is spotted by a wall-clock jump between ticks of [_wakeTick]:
///   Dart timers run on the monotonic clock, which stops during suspend, so
///   a 5 s tick that sees minutes pass on the wall clock means we slept.
///   That covers desktop Linux, where a system suspend never produces a
///   lifecycle event at all.
///
/// Note: on Android the ExoPlayer engine already pauses decoding natively
/// (`handleLifecycle: true`); the libmpv engine (desktop/web) does not, so
/// the playback screens gate their heartbeat and keep-awake on [state].
class AppLifecycleReactor with WidgetsBindingObserver {
  AppLifecycleReactor._();
  static final AppLifecycleReactor instance = AppLifecycleReactor._();

  /// Last lifecycle state seen. Starts optimistic (`resumed`) — the first
  /// real callback corrects it.
  final ValueNotifier<AppLifecycleState> state =
      ValueNotifier<AppLifecycleState>(AppLifecycleState.resumed);

  /// true while the app is not in the foreground (`paused` or `hidden`).
  bool get isBackgrounded =>
      state.value == AppLifecycleState.paused ||
      state.value == AppLifecycleState.hidden;

  int _refs = 0;
  bool _pollPaused = false;
  Timer? _wakeTimer;
  DateTime _lastTick = DateTime.now();
  DateTime? _backgroundedAt;

  static const _wakeTick = Duration(seconds: 5);
  // Slack over the tick before a gap counts as sleep — a busy UI isolate
  // can delay a timer a little, never by this much.
  static const _sleepGap = Duration(seconds: 20);
  // Below this a trip to the background (a notification, an input switch)
  // can't have cost us the connection; not worth a new handshake.
  static const _backgroundGap = Duration(seconds: 15);

  void attach() {
    if (_refs++ == 0) {
      WidgetsBinding.instance.addObserver(this);
      _lastTick = DateTime.now();
      _wakeTimer = Timer.periodic(_wakeTick, (_) => _onWakeTick());
    }
  }

  void detach() {
    if (_refs > 0 && --_refs == 0) {
      WidgetsBinding.instance.removeObserver(this);
      _wakeTimer?.cancel();
      _wakeTimer = null;
      // Never leave the poll stranded paused if the shell goes away.
      _resumePoll();
      state.value = AppLifecycleState.resumed;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state.value = state;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
        _pausePoll();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        // Before _resumePoll: its catch-up refresh should already go out
        // on the fresh connection.
        if (since != null &&
            DateTime.now().difference(since) > _backgroundGap) {
          Metrics.wakeBegin();
          reconnectGrpcChannel('resumed');
        }
        _resumePoll();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onWakeTick() {
    final now = DateTime.now();
    final gap = now.difference(_lastTick);
    _lastTick = now;
    if (gap > _wakeTick + _sleepGap) {
      Metrics.wakeBegin();
      reconnectGrpcChannel('woke after ${gap.inSeconds}s');
      // Lifecycle never fires for a system suspend on desktop, so nothing
      // else would refresh what went stale while we slept.
      if (!isBackgrounded && getIt.isRegistered<PluginBloc>()) {
        final bloc = getIt<PluginBloc>();
        if (!bloc.isClosed) bloc.add(const RefreshPluginsEvent());
      }
    }
  }

  void _pausePoll() {
    if (_pollPaused || !getIt.isRegistered<PluginBloc>()) return;
    getIt<PluginBloc>().pausePolling();
    _pollPaused = true;
  }

  void _resumePoll() {
    if (!_pollPaused) return;
    _pollPaused = false;
    if (!getIt.isRegistered<PluginBloc>()) return;
    final bloc = getIt<PluginBloc>();
    bloc.resumePolling();
    // Catch up immediately on the poll(s) skipped while backgrounded instead
    // of waiting out a fresh 30 s interval.
    if (!bloc.isClosed) bloc.add(const RefreshPluginsEvent());
  }
}
