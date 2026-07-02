import 'package:equatable/equatable.dart';

abstract class PlaybackEvent extends Equatable {
  const PlaybackEvent();
  @override
  List<Object?> get props => [];
}

class InitializeVideoEvent extends PlaybackEvent {
  final String pluginId;
  final String mediaId;
  final String preferredLabel;
  const InitializeVideoEvent({
    required this.pluginId,
    required this.mediaId,
    this.preferredLabel = '',
  });
  @override
  List<Object?> get props => [pluginId, mediaId, preferredLabel];
}

class SelectStreamEvent extends PlaybackEvent {
  final String pluginId;
  final String streamId;
  const SelectStreamEvent({required this.pluginId, required this.streamId});
  @override
  List<Object?> get props => [pluginId, streamId];
}
