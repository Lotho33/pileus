import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/clients/media_client.dart' show ResolveResponse;
import '../../../core/grpc/grpc_errors.dart';
import '../../../core/utils/perf_log.dart';
import '../../../features/media/data/media_repository.dart';
import 'playback_event.dart';
import 'playback_state.dart';

const _retryDelays = [
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 10)
];
const _resolveStreamTimeout = Duration(seconds: 30);

class PlaybackBloc extends Bloc<PlaybackEvent, PlaybackState> {
  final MediaRepository _repo;
  final void Function()? onSessionExpired;

  PlaybackBloc(this._repo, {this.onSessionExpired})
      : super(const PlaybackInitial()) {
    on<InitializeVideoEvent>(_onInitialize);
    on<SelectStreamEvent>(_onSelectStream);
  }

  Future<void> _onInitialize(
      InitializeVideoEvent event, Emitter<PlaybackState> emit) async {
    perf('bloc: InitializeVideoEvent → getStreams(${event.mediaId})');
    emit(const FetchingStreams());
    try {
      final response = await _repo.getStreams(event.pluginId, event.mediaId);
      perf('bloc: getStreams done (${response.sources.length} sources)');
      if (response.sources.isEmpty) {
        emit(const PlaybackFailed('Nessuna sorgente disponibile.'));
        return;
      }
      // Auto-select: preferred label match → else first source
      final source = event.preferredLabel.isNotEmpty
          ? (response.sources
                  .where(
                    (s) =>
                        s.label.toLowerCase() ==
                        event.preferredLabel.toLowerCase(),
                  )
                  .firstOrNull ??
              response.sources.first)
          : response.sources.first;
      add(SelectStreamEvent(pluginId: event.pluginId, streamId: source.id));
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        // Still emit a terminal state: if the session-expired handler
        // doesn't navigate away (null, or a race), the screen would
        // otherwise sit on FetchingStreams — an infinite spinner.
        emit(const PlaybackFailed('Sessione scaduta. Riprova ad accedere.'));
        return;
      }
      emit(PlaybackFailed(e.toString()));
    }
  }

  Future<void> _onSelectStream(
      SelectStreamEvent event, Emitter<PlaybackState> emit) async {
    perf('bloc: SelectStreamEvent → resolveStream(${event.streamId})');
    emit(const ResolvingMediaStream());
    Object? lastError;
    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      // The previous attempt's resolve or its catch block can straddle a
      // dispose (BlocProvider closes the bloc as soon as the player screen
      // is popped) — check before emitting, not only after the delay below,
      // otherwise a closed-bloc emit throws a StateError here.
      if (isClosed) return;
      if (attempt > 0) {
        emit(PlaybackRetrying(attempt: attempt, of: _retryDelays.length));
        await Future.delayed(_retryDelays[attempt - 1]);
        if (isClosed) return;
      }
      ResolveResponse? resolved;
      try {
        // Server-streaming: zero or more {progress} updates while the plugin
        // resolves the stream, then exactly one {result} that ends the
        // stream — or the RPC throws instead, if the resolve failed outright
        // (see mycelium-core MYCELIUM_HANDOFF.md). A {progress} with
        // status "error" is informational only (a stage failed but the
        // resolve may still continue via fallback) — it never ends this
        // loop by itself, only a thrown exception or the stream closing does.
        // `.timeout` resets on every event, so a plugin that keeps sending
        // {progress} stays alive; only a hang with zero events (server or
        // plugin stuck, no error ever thrown) trips it, feeding the retry
        // loop below instead of leaving the UI stuck on the spinner forever.
        await for (final streamEvent in _repo
            .resolveStream(event.pluginId, event.streamId)
            .timeout(_resolveStreamTimeout)) {
          if (isClosed) return;
          if (streamEvent.hasResult()) {
            resolved = streamEvent.result;
          } else if (streamEvent.hasProgress()) {
            perf('bloc: resolve progress "${streamEvent.progress.message}"'
                ' [${streamEvent.progress.status}]');
            emit(PlaybackResolveProgress(
              message: streamEvent.progress.message,
              status: streamEvent.progress.status,
            ));
          }
        }
      } catch (e) {
        if (isUnauthenticated(e)) {
          onSessionExpired?.call();
          emit(const PlaybackFailed('Sessione scaduta. Riprova ad accedere.'));
          return;
        }
        if (kDebugMode) {
          debugPrint('[player] resolveStream attempt $attempt failed: $e');
        }
        lastError = e;
        continue;
      }
      if (resolved == null || resolved.resolvedUrl.isEmpty) {
        // The resolve stream closed cleanly without a {result} — the server /
        // plugin had its say (including any internal fallback, see the
        // comment above) and produced nothing. Unlike a thrown RPC error,
        // replaying the identical request won't change that, so fail now
        // instead of burning the remaining 2+5+10 s retry budget behind a
        // spinner. A genuine transport drop mid-resolve throws instead and is
        // still retried by the catch above.
        perf('bloc: resolve closed with no result (attempt $attempt) '
            '→ PlaybackFailed');
        emit(const PlaybackFailed('Stream non disponibile: URL non risolto.'));
        return;
      }
      perf('bloc: PlaybackReady (resolve done, attempt $attempt) '
          'isLive=${resolved.isLive}');
      emit(PlaybackReady(
        resolvedUrl: resolved.resolvedUrl,
        httpHeaders: resolved.httpHeaders,
        extra: Map<String, String>.from(resolved.extra),
      ));
      return;
    }
    perf('bloc: PlaybackFailed $lastError');
    emit(PlaybackFailed(lastError.toString()));
  }
}
