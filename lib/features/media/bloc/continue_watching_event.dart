import 'package:equatable/equatable.dart';

abstract class ContinueWatchingEvent extends Equatable {
  const ContinueWatchingEvent();
  @override
  List<Object?> get props => [];
}

class LoadContinueWatchingEvent extends ContinueWatchingEvent {
  const LoadContinueWatchingEvent();
}

class RemoveContinueWatchingEvent extends ContinueWatchingEvent {
  final String providerID;
  final String playableID;
  const RemoveContinueWatchingEvent(this.providerID, this.playableID);
  @override
  List<Object?> get props => [providerID, playableID];
}
