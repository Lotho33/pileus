import 'package:equatable/equatable.dart';

import '../../../core/grpc/clients/media_client.dart';

abstract class PluginState extends Equatable {
  const PluginState();
  @override
  List<Object?> get props => [];
}

class PluginInitial extends PluginState {
  const PluginInitial();
}

class PluginLoading extends PluginState {
  const PluginLoading();
}

class PluginsLoaded extends PluginState {
  final List<PluginInfo> plugins;
  const PluginsLoaded(this.plugins);
  @override
  List<Object?> get props => [plugins];
}

class PluginError extends PluginState {
  final String message;
  // Best-effort — see grpc_errors.dart:looksLikeCertificateMismatch. Lets the
  // UI show "the server's certificate changed" instead of the generic
  // "server unreachable" message, which was misleading for this specific
  // case (the server IS reachable, the pinned TLS fingerprint just no longer
  // matches after e.g. a mycelium reinstall/reset).
  final bool certMismatch;
  const PluginError(this.message, {this.certMismatch = false});
  @override
  List<Object?> get props => [message, certMismatch];
}

// Settings states — these are emitted alongside PluginsLoaded (per-plugin flow).

class PluginSettingsLoading extends PluginState {
  final String pluginId;
  const PluginSettingsLoading(this.pluginId);
  @override
  List<Object?> get props => [pluginId];
}

class PluginSettingsLoaded extends PluginState {
  final String pluginId;
  final List<PluginSettingField> fields;
  const PluginSettingsLoaded(this.pluginId, this.fields);
  @override
  List<Object?> get props => [pluginId, fields];
}

class PluginSettingsSaved extends PluginState {
  final String pluginId;
  const PluginSettingsSaved(this.pluginId);
  @override
  List<Object?> get props => [pluginId];
}

class PluginSettingsError extends PluginState {
  final String pluginId;
  final String message;
  const PluginSettingsError(this.pluginId, this.message);
  @override
  List<Object?> get props => [pluginId, message];
}
