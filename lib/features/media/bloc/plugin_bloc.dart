import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/clients/media_client.dart';
import '../../../core/grpc/grpc_errors.dart';
import '../data/media_repository.dart';
import 'plugin_event.dart';
import 'plugin_state.dart';

EventTransformer<E> _sequential<E>() {
  return (events, mapper) => events.asyncExpand(mapper);
}

class PluginBloc extends Bloc<PluginEvent, PluginState> {
  final MediaRepository _repo;
  final void Function()? onSessionExpired;
  Timer? _pollTimer;

  static const _pollInterval = Duration(seconds: 30);

  PluginBloc(this._repo, {this.onSessionExpired})
      : super(const PluginInitial()) {
    on<LoadPluginsEvent>(_onLoad);
    on<RefreshPluginsEvent>(_onRefresh);
    on<LoadPluginSettingsEvent>(_onLoadSettings);
    // Same concurrency hazard as ReorderPluginEvent below: _onSaveSetting
    // emits twice (saved, then reloaded from a second network round-trip),
    // so two Save presses on different fields close together can interleave
    // their final emits — whichever save's reload lands last "wins" the
    // displayed state, not whichever the user pressed last.
    on<SavePluginSettingEvent>(_onSaveSetting, transformer: _sequential());
    // flutter_bloc's default transformer runs handlers concurrently. A D-pad
    // "move" during reorder fires one ReorderPluginEvent per arrow press, and
    // fast repeated presses (normal on a remote) would otherwise overlap:
    // each handler snapshots `state` independently before the previous
    // handler's save+emit lands, so the persisted order ends up decided by
    // which write *finishes* last rather than the last move the user made —
    // exactly the "sticks sometimes, looks random" symptom. Processing them
    // one at a time (each waits for the previous to fully complete) fixes it.
    on<ReorderPluginEvent>(_onReorder, transformer: _sequential());
  }

  // Full load — emits PluginLoading first (shown on first open).
  Future<void> _onLoad(
      LoadPluginsEvent event, Emitter<PluginState> emit) async {
    emit(const PluginLoading());
    try {
      final plugins = await _repo.listPlugins();
      emit(PluginsLoaded(plugins));
      _startPolling();
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      emit(PluginError(e.toString(), certMismatch: looksLikeCertificateMismatch(e)));
    }
  }

  // Silent refresh — keeps current list visible while fetching.
  Future<void> _onRefresh(
      RefreshPluginsEvent event, Emitter<PluginState> emit) async {
    try {
      final plugins = await _repo.listPlugins();
      // Only emit if state changed — avoids unnecessary rebuilds.
      final current = state;
      if (current is PluginsLoaded && !event.force) {
        final changed = plugins.length != current.plugins.length ||
            _statusChanged(current.plugins, plugins);
        if (changed) emit(PluginsLoaded(plugins));
      } else {
        emit(PluginsLoaded(plugins));
      }
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      // Otherwise silent — don't replace a working list with an error on a background poll.
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!isClosed && _pollPauseDepth == 0) add(const RefreshPluginsEvent());
    });
  }

  // The 30s plugin-status poll is only useful while the plugin list is on
  // screen (home / Impostazioni plugin). During playback — a movie is 90+
  // minutes — each poll is a wasted gRPC round-trip + JSON decode that can
  // show up as a micro-stutter on a weak box. PlaybackScreen brackets its
  // lifetime with pause/resume; a depth counter so nested/overlapping
  // callers can't resume it early.
  int _pollPauseDepth = 0;
  void pausePolling() => _pollPauseDepth++;
  void resumePolling() {
    if (_pollPauseDepth > 0) _pollPauseDepth--;
  }

  Future<void> _onReorder(
      ReorderPluginEvent event, Emitter<PluginState> emit) async {
    final current = state;
    if (current is! PluginsLoaded) return;
    final list = List<PluginInfo>.from(current.plugins);
    final PluginInfo item = list.removeAt(event.fromIndex);
    list.insert(event.toIndex, item);
    try {
      await _repo.savePluginOrder(list.map((p) => p.pluginId).toList());
      emit(PluginsLoaded(list));
    } catch (_) {
      // Save failed — leave the previously-emitted (still-saved) order in
      // place rather than showing a reorder that didn't actually persist.
      // Same "don't break a working list over a background write" rationale
      // as _onRefresh above.
    }
  }

  bool _statusChanged(List a, List b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      // pluginId first — catches reordering even when two plugins happen to
      // share identical status metadata (rare, but silently missing a
      // reorder made in another PluginBloc instance would be worse).
      if (a[i].pluginId != b[i].pluginId ||
          a[i].statusLabel != b[i].statusLabel ||
          a[i].statusDetail != b[i].statusDetail ||
          a[i].needsConfig != b[i].needsConfig ||
          a[i].isReady != b[i].isReady) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadSettings(
      LoadPluginSettingsEvent event, Emitter<PluginState> emit) async {
    emit(PluginSettingsLoading(event.pluginId));
    try {
      final fields =
          await _repo.getPluginSettings(event.pluginId, event.profileId);
      emit(PluginSettingsLoaded(event.pluginId, fields));
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      emit(PluginSettingsError(event.pluginId, e.toString()));
    }
  }

  Future<void> _onSaveSetting(
      SavePluginSettingEvent event, Emitter<PluginState> emit) async {
    try {
      await _repo.savePluginSetting(
          event.pluginId, event.profileId, event.key, event.value);
      emit(PluginSettingsSaved(event.pluginId));
      final fields =
          await _repo.getPluginSettings(event.pluginId, event.profileId);
      emit(PluginSettingsLoaded(event.pluginId, fields));
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      emit(PluginSettingsError(event.pluginId, e.toString()));
    }
  }
}
