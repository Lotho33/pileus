import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/grpc_errors.dart';
import '../../../core/utils/metrics.dart';
import '../data/media_repository.dart';
import 'details_event.dart';
import 'details_state.dart';

class _RereadForLogoMeta extends DetailsEvent {
  final LoadDetailsEvent load;
  const _RereadForLogoMeta(this.load);
}

class DetailsBloc extends Bloc<DetailsEvent, DetailsState> {
  final MediaRepository _repo;
  final void Function()? onSessionExpired;
  final void Function()? onProfileLocked;

  /// The screen draws the title's logo (desktop/web): when the first answer
  /// has it not measured yet, read the details once more shortly after, or
  /// a dark logo would stay without its halo for as long as the page is
  /// open. Off where no logo is drawn: a re-emit would rebuild for nothing.
  final bool refreshLogoMeta;

  @visibleForTesting
  static Duration logoMetaRetryDelay = const Duration(seconds: 6);
  Timer? _logoMetaRetry;

  DetailsBloc(this._repo,
      {this.onSessionExpired,
      this.onProfileLocked,
      this.refreshLogoMeta = false})
      : super(const DetailsInitial()) {
    on<LoadDetailsEvent>(_onLoadDetails);
    on<_RereadForLogoMeta>(_onReread);
  }

  Future<void> _onLoadDetails(
      LoadDetailsEvent event, Emitter<DetailsState> emit) async {
    _logoMetaRetry?.cancel();
    emit(const DetailsLoading());
    final sw = Stopwatch()..start();
    try {
      final response = await _repo.getDetails(
        event.pluginId,
        event.mediaId,
        urgent: true,
      );
      Metrics.record(Metrics.details, sw.elapsedMilliseconds);
      emit(DetailsLoaded(response));
      if (refreshLogoMeta && detailsLogoPending(response)) {
        _logoMetaRetry = Timer(logoMetaRetryDelay, () {
          if (!isClosed) add(_RereadForLogoMeta(event));
        });
      }
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      if (isProfileLocked(e)) {
        onProfileLocked?.call();
        return;
      }
      emit(DetailsError(e.toString()));
    }
  }

  Future<void> _onReread(
      _RereadForLogoMeta event, Emitter<DetailsState> emit) async {
    try {
      final response = await _repo.getDetails(
        event.load.pluginId,
        event.load.mediaId,
        urgent: true,
        fresh: true,
      );
      if (state is DetailsLoaded && !detailsLogoPending(response)) {
        emit(DetailsLoaded(response));
      }
    } catch (_) {
      // Best effort: the page already shows everything but the halo.
    }
  }

  @override
  Future<void> close() {
    _logoMetaRetry?.cancel();
    return super.close();
  }
}
