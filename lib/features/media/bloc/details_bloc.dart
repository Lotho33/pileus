import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/grpc_errors.dart';
import '../data/media_repository.dart';
import 'details_event.dart';
import 'details_state.dart';

class DetailsBloc extends Bloc<DetailsEvent, DetailsState> {
  final MediaRepository _repo;
  final void Function()? onSessionExpired;

  DetailsBloc(this._repo, {this.onSessionExpired}) : super(const DetailsInitial()) {
    on<LoadDetailsEvent>(_onLoadDetails);
  }

  Future<void> _onLoadDetails(LoadDetailsEvent event, Emitter<DetailsState> emit) async {
    emit(const DetailsLoading());
    try {
      final response = await _repo.getDetails(event.pluginId, event.mediaId);
      emit(DetailsLoaded(response));
    } catch (e) {
      if (isUnauthenticated(e)) { onSessionExpired?.call(); return; }
      emit(DetailsError(e.toString()));
    }
  }
}
