import 'package:flutter/widgets.dart';

import 'di/injection.dart' show getIt;
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

  void attach() {
    if (_refs++ == 0) WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (_refs > 0 && --_refs == 0) {
      WidgetsBinding.instance.removeObserver(this);
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
        _pausePoll();
      case AppLifecycleState.resumed:
        _resumePoll();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
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
