import 'package:equatable/equatable.dart';

import '../data/continue_watching_item.dart';

abstract class ContinueWatchingState extends Equatable {
  const ContinueWatchingState();
  @override
  List<Object?> get props => [];
}

class ContinueWatchingInitial extends ContinueWatchingState {
  const ContinueWatchingInitial();
}

class ContinueWatchingLoaded extends ContinueWatchingState {
  final List<ContinueWatchingItem> items;
  const ContinueWatchingLoaded(this.items);
  @override
  List<Object?> get props => [items];
}
