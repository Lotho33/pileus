import 'package:equatable/equatable.dart';

abstract class PlaybackState extends Equatable {
  const PlaybackState();
  @override
  List<Object?> get props => [];
}

class PlaybackInitial extends PlaybackState {
  const PlaybackInitial();
}

class FetchingStreams extends PlaybackState {
  const FetchingStreams();
}

class ResolvingMediaStream extends PlaybackState {
  const ResolvingMediaStream();
}

/// Intermediate update from the ResolveStream RPC while a stage of the
/// resolve is in progress (e.g. "falling back to the extractor…"). `status`
/// is "loading"|"success"|"error"|"warning" — the UI must only use it to
/// pick an icon/animation, never branch logic on `message`'s text. An
/// unrecognized status must be treated like "loading" (safe default).
class PlaybackResolveProgress extends PlaybackState {
  final String message;
  final String status;
  const PlaybackResolveProgress({required this.message, required this.status});
  @override
  List<Object?> get props => [message, status];
}

class PlaybackReady extends PlaybackState {
  final String resolvedUrl;
  final Map<String, String> httpHeaders;
  final Map<String, String> extra;
  const PlaybackReady({
    required this.resolvedUrl,
    required this.httpHeaders,
    this.extra = const {},
  });
  @override
  List<Object?> get props => [resolvedUrl, httpHeaders, extra];
}

class PlaybackRetrying extends PlaybackState {
  final int attempt;
  final int of;
  const PlaybackRetrying({required this.attempt, required this.of});
  @override
  List<Object?> get props => [attempt, of];
}

class PlaybackFailed extends PlaybackState {
  final String errorMessage;
  const PlaybackFailed(this.errorMessage);
  @override
  List<Object?> get props => [errorMessage];
}
