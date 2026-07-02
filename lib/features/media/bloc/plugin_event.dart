import 'package:equatable/equatable.dart';

abstract class PluginEvent extends Equatable {
  const PluginEvent();
  @override
  List<Object?> get props => [];
}

class LoadPluginsEvent extends PluginEvent {
  const LoadPluginsEvent();
}

/// Silent re-fetch — keeps the current list on screen while refreshing, only
/// emits if something actually changed (no PluginLoading flash). Used both
/// internally by the poll timer and externally, e.g. by home_screen.dart
/// after returning from Impostazioni > Plugin: PluginBloc is a fresh
/// instance per screen (see injection.dart), so a reorder committed by the
/// Settings screen's own instance never reaches home's — this event forces
/// home's instance to catch up.
class RefreshPluginsEvent extends PluginEvent {
  /// When true the reloaded list is always emitted, even if
  /// PluginBloc._statusChanged sees no difference — used after a local
  /// change that _statusChanged doesn't inspect (a hidden/re-ordered
  /// catalog leaves plugin count and status metadata untouched).
  final bool force;
  const RefreshPluginsEvent({this.force = false});

  @override
  List<Object?> get props => [force];
}


class LoadPluginSettingsEvent extends PluginEvent {
  final String pluginId;
  final String profileId;
  const LoadPluginSettingsEvent(this.pluginId, this.profileId);
  @override
  List<Object?> get props => [pluginId, profileId];
}

class SavePluginSettingEvent extends PluginEvent {
  final String pluginId;
  final String profileId;
  final String key;
  final String value;
  const SavePluginSettingEvent(
      this.pluginId, this.profileId, this.key, this.value);
  @override
  List<Object?> get props => [pluginId, profileId, key, value];
}

class ReorderPluginEvent extends PluginEvent {
  final int fromIndex;
  final int toIndex;
  const ReorderPluginEvent(this.fromIndex, this.toIndex);
  @override
  List<Object?> get props => [fromIndex, toIndex];
}
