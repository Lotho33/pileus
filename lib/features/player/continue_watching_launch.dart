import '../media/data/continue_watching_item.dart';

/// The `/player` route `extra` for resuming a Continue Watching entry —
/// one definition for every resume entry point (home card on TV and mobile,
/// the details "Riprendi" button), so a field added for one platform can't
/// silently be missing on another again.
///
/// [posterFallback] is used when the stored row has no poster of its own.
Map<String, dynamic> continueWatchingPlayerExtra(
  ContinueWatchingItem item, {
  String posterFallback = '',
}) =>
    <String, dynamic>{
      // playableID is the stream id of the source that was playing (it
      // carries the language — see source_continuity.dart). Passed as
      // streamId so the player resolves that exact source directly instead
      // of re-running GetStreams on it as if it were a bare media id: a
      // plugin whose ids carry a language/variant suffix can double-suffix it
      // and fail, and a bare-id resolve would pick the default language.
      'streamId': item.playableID,
      // A "roll-forward" row (the next episode, written when the previous one
      // was finished) is stored at ~31 s purely to clear mycelium's
      // `progress_time >= 30` filter — not a real resume point. Recognise it
      // (no known duration + tiny progress) and start from the top instead.
      'seekTo': (item.totalTime <= 0 && item.progressTime <= 35)
          ? 0
          : item.progressTime.toInt(),
      'poster': item.poster.isNotEmpty ? item.poster : posterFallback,
      'parentId': item.parentID,
      if (item.title.isNotEmpty) 'title': item.title,
      // Re-sent on resume so a re-watch keeps refreshing these (the backend's
      // UpsertProgress never lets a blank value overwrite a stored one, so
      // this is purely "keep it fresh", never lossy).
      'showTitle': item.showTitle,
      'plot': item.plot,
      'rating': item.rating,
      if (item.genres.isNotEmpty) 'genres': item.genres,
      if (item.year > 0) 'year': item.year,
      'durationSeconds': item.durationSeconds,
      // The player rebuilds the prev/next episode list itself after playback
      // starts (it may walk several season directories — not worth blocking
      // the tap on); it just needs to know which plugin to ask.
      if (item.parentID.isNotEmpty) 'pluginId': item.providerID,
    };
