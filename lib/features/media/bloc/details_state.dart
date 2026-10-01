import 'package:equatable/equatable.dart';

import '../../../core/grpc/clients/media_client.dart';

abstract class DetailsState extends Equatable {
  const DetailsState();
  @override
  List<Object?> get props => [];
}

class DetailsInitial extends DetailsState {
  const DetailsInitial();
}

class DetailsLoading extends DetailsState {
  const DetailsLoading();
}

class DetailsLoaded extends DetailsState {
  final DetailsResponse response;
  const DetailsLoaded(this.response);
  @override
  List<Object?> get props => [response];
}

class DetailsError extends DetailsState {
  final String message;
  const DetailsError(this.message);
  @override
  List<Object?> get props => [message];
}
