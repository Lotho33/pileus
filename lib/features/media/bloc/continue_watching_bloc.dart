import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/continue_watching_item.dart';
import '../data/media_repository.dart';
import 'continue_watching_event.dart';
import 'continue_watching_state.dart';

class ContinueWatchingBloc
    extends Bloc<ContinueWatchingEvent, ContinueWatchingState> {
  final MediaRepository _repo;

  ContinueWatchingBloc(this._repo) : super(const ContinueWatchingInitial()) {
    on<LoadContinueWatchingEvent>(_onLoad);
    on<RemoveContinueWatchingEvent>(_onRemove);
  }

  Future<void> _onLoad(
    LoadContinueWatchingEvent event,
    Emitter<ContinueWatchingState> emit,
  ) async {
    try {
      final items = await _repo.getContinueWatching();
      emit(ContinueWatchingLoaded(items));
    } catch (_) {
      emit(const ContinueWatchingLoaded([]));
    }
  }

  Future<void> _onRemove(
    RemoveContinueWatchingEvent event,
    Emitter<ContinueWatchingState> emit,
  ) async {
    // Optimistic update: remove immediately from the visible list.
    final before = state;
    ContinueWatchingItem? removedItem;
    int removedIndex = -1;
    if (before is ContinueWatchingLoaded) {
      removedIndex = before.items.indexWhere(
        (i) =>
            i.providerID == event.providerID &&
            i.playableID == event.playableID,
      );
      if (removedIndex >= 0) removedItem = before.items[removedIndex];
      final updated = [
        for (final i in before.items)
          if (!(i.providerID == event.providerID &&
              i.playableID == event.playableID))
            i
      ];
      emit(ContinueWatchingLoaded(updated));
    }
    final ok = await _repo.deleteProgress(
        providerID: event.providerID, playableID: event.playableID);
    // The delete never reached the server — put the item back where it was
    // (not at the end) rather than letting it silently disappear from
    // "continue watching" with no way for the user to know why.
    if (!ok && removedItem != null) {
      final current = state;
      if (current is ContinueWatchingLoaded) {
        final restored = [...current.items];
        restored.insert(removedIndex.clamp(0, restored.length), removedItem);
        emit(ContinueWatchingLoaded(restored));
      }
    }
  }
}
