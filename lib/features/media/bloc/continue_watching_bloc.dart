import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/watch_next.dart';
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

  // Every version of the row also goes to the Android TV home screen's
  // "Watch Next" (a no-op elsewhere; unchanged lists aren't resent).
  @override
  void onChange(Change<ContinueWatchingState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (next is ContinueWatchingLoaded) WatchNext.sync(next.items);
  }

  Future<void> _onLoad(
    LoadContinueWatchingEvent event,
    Emitter<ContinueWatchingState> emit,
  ) async {
    // First load of the session: the row as the last session left it, on
    // screen at once (see MediaRepository.cachedContinueWatching).
    final hadNothing = state is ContinueWatchingInitial;
    if (hadNothing) {
      final cached = _repo.cachedContinueWatching();
      if (cached != null) emit(ContinueWatchingLoaded(cached));
    }
    try {
      final items = await _repo.fetchContinueWatching();
      if (items != null) {
        emit(ContinueWatchingLoaded(items));
      } else if (state is ContinueWatchingInitial) {
        // Failed with nothing drawn yet — an empty row, as before. A row
        // already on screen (from disk or an earlier load) stays.
        emit(const ContinueWatchingLoaded([]));
      }
    } catch (_) {
      if (state is ContinueWatchingInitial) {
        emit(const ContinueWatchingLoaded([]));
      }
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
    final ok = await _repo.removeFromContinueWatching(
        providerID: event.providerID, playableID: event.playableID);
    // Refused (session over, profile locked) — put the item back where it
    // was (not at the end) rather than letting it silently disappear. A
    // server that just didn't answer is not a refusal: the repository
    // queues the removal and sends it once the server is back.
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
