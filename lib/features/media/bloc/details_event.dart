import 'package:equatable/equatable.dart';

abstract class DetailsEvent extends Equatable {
  const DetailsEvent();
  @override
  List<Object?> get props => [];
}

class LoadDetailsEvent extends DetailsEvent {
  final String pluginId;
  final String mediaId;
  const LoadDetailsEvent({required this.pluginId, required this.mediaId});
  @override
  List<Object?> get props => [pluginId, mediaId];
}
