import 'package:fixnum/fixnum.dart' show Int64;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/clients/media_client.dart'
    show CreateDownloadRequest, CreateDownloadItem, CreateDownloadsRequest;
import '../../../core/grpc/grpc_errors.dart';
import '../../media/data/media_repository.dart';
import '../download_format.dart' show DownloadScheduleKind;
import 'download_options_state.dart';

/// Display metadata for one item to download — mirrors CreateDownloadRequest/
/// CreateDownloadItem's own display fields (contract: "così il list funziona
/// offline"). One of these per episode in a season/next-N batch; a movie/
/// single episode is just a batch of one. [streamId] is still needed per
/// item (each episode's own GetStreams-resolved source), but the quality/
/// audio/subtitle choice itself is made ONCE from the first episode's
/// GetDownloadOptions and applies to every item as criteria — see
/// confirmBatch's doc.
class DownloadTarget {
  final String mediaId;
  final String parentId;
  final String title;
  final String seriesTitle;
  final String poster;
  final int seasonNumber;
  final int episodeNumber;
  final String streamId;

  const DownloadTarget({
    required this.mediaId,
    required this.streamId,
    this.parentId = '',
    this.title = '',
    this.seriesTitle = '',
    this.poster = '',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
  });
}

/// One candidate episode for a season/next-N batch, offered alongside the
/// single-episode choice in the options sheet — NOT yet resolved to a
/// stream (that only happens once the user actually picks this group, via
/// its own GetStreams call; resolving every episode of a season up front
/// just to show the choice would be a lot of unnecessary RPCs for a picker
/// the user might not even use). See DownloadBatchGroup.
class DownloadBatchCandidate {
  final String mediaId;
  final String parentId;
  final String title;
  final String seriesTitle;
  final String poster;
  final int seasonNumber;
  final int episodeNumber;

  const DownloadBatchCandidate({
    required this.mediaId,
    this.parentId = '',
    this.title = '',
    this.seriesTitle = '',
    this.poster = '',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
  });
}

/// "Scarica la stagione" / "Scarica i prossimi N episodi" — one row in the
/// options sheet's batch picker. [candidates] includes the very episode the
/// sheet was already opened for (matched by mediaId when resolving, so that
/// one doesn't need a second GetStreams call).
class DownloadBatchGroup {
  final String label;
  final List<DownloadBatchCandidate> candidates;
  const DownloadBatchGroup({required this.label, required this.candidates});
}

/// Drives the download-options bottom sheet/dialog — one instance per sheet
/// open, thrown away when it closes. Fetches GetDownloadOptions once, then
/// only mutates local selection state (variant/audio/subtitles/schedule)
/// until the user confirms, at which point it fires one or more
/// CreateDownload calls.
class DownloadOptionsCubit extends Cubit<DownloadOptionsState> {
  final MediaRepository _repo;
  final String pluginId;

  DownloadOptionsCubit(this._repo, {required this.pluginId})
      : super(const DownloadOptionsLoading());

  Future<void> load(String streamId) async {
    emit(const DownloadOptionsLoading());
    try {
      final resp = await _repo.getDownloadOptions(pluginId, streamId);
      if (isClosed) return;
      if (!resp.available || resp.variants.isEmpty) {
        emit(DownloadOptionsUnavailable(resp.unavailableReason.isNotEmpty
            ? resp.unavailableReason
            : 'Non scaricabile'));
        return;
      }
      emit(DownloadOptionsReady(
        response: resp,
        selectedVariantId: resp.variants.first.id,
        // Only the tracks flagged as the source's default come pre-selected
        // — matches CreateDownloadRequest.audio_ids' own doc ("empty = the
        // source's default audio") so an untouched sheet submits exactly
        // what an empty selection would have meant anyway.
        selectedAudioIds: {
          for (final a in resp.audio)
            if (a.isDefault) a.id
        },
        selectedSubtitleIds: const {},
        scheduleKind: DownloadScheduleKind.now,
        // Contract: "Spuntala di default quando quality_below_usual=true".
        upgradeIfBetter: resp.qualityBelowUsual,
      ));
    } catch (e) {
      if (isClosed) return;
      if (isUnauthenticated(e) || isProfileLocked(e)) {
        // The screen holding this sheet already reacts to these globally
        // (AuthBloc) — nothing useful to show locally beyond closing.
        emit(DownloadOptionsError(grpcMessage(e)));
        return;
      }
      emit(DownloadOptionsError(grpcMessage(e)));
    }
  }

  void selectVariant(String variantId) {
    final s = state;
    if (s is! DownloadOptionsReady) return;
    emit(s.copyWith(selectedVariantId: variantId));
  }

  void toggleAudio(String trackId) {
    final s = state;
    if (s is! DownloadOptionsReady) return;
    final next = Set<String>.of(s.selectedAudioIds);
    if (!next.add(trackId)) next.remove(trackId);
    emit(s.copyWith(selectedAudioIds: next));
  }

  void toggleSubtitle(String trackId) {
    final s = state;
    if (s is! DownloadOptionsReady) return;
    final next = Set<String>.of(s.selectedSubtitleIds);
    if (!next.add(trackId)) next.remove(trackId);
    emit(s.copyWith(selectedSubtitleIds: next));
  }

  void setScheduleNow() {
    final s = state;
    if (s is! DownloadOptionsReady) return;
    emit(s.copyWith(
        scheduleKind: DownloadScheduleKind.now, clearScheduledAt: true));
  }

  void setSchedulePreferredWindow() {
    final s = state;
    if (s is! DownloadOptionsReady) return;
    emit(s.copyWith(
        scheduleKind: DownloadScheduleKind.preferredWindow,
        clearScheduledAt: true));
  }

  void setScheduleAt(DateTime when) {
    final s = state;
    if (s is! DownloadOptionsReady) return;
    emit(s.copyWith(
        scheduleKind: DownloadScheduleKind.specificTime, scheduledAt: when));
  }

  void toggleUpgradeIfBetter() {
    final s = state;
    if (s is! DownloadOptionsReady) return;
    emit(s.copyWith(upgradeIfBetter: !s.upgradeIfBetter));
  }

  Int64 _notBefore(DownloadOptionsReady s) =>
      s.scheduleKind == DownloadScheduleKind.specificTime &&
              s.scheduledAt != null
          ? Int64(s.scheduledAt!.millisecondsSinceEpoch ~/ 1000)
          : Int64.ZERO;

  bool _usePreferredHours(DownloadOptionsReady s) =>
      s.scheduleKind == DownloadScheduleKind.preferredWindow;

  /// Single movie/episode — the common case, one CreateDownload call.
  Future<void> confirmSingle(DownloadTarget target) async {
    final s = state;
    if (s is! DownloadOptionsReady) return;
    emit(const DownloadOptionsSubmitting(done: 0, total: 1));
    try {
      final info = await _repo.createDownload(CreateDownloadRequest(
        pluginId: pluginId,
        streamId: target.streamId,
        variantId: s.selectedVariantId,
        audioIds: s.selectedAudioIds.toList(),
        subtitleIds: s.selectedSubtitleIds.toList(),
        notBefore: _notBefore(s),
        usePreferredHours: _usePreferredHours(s),
        mediaId: target.mediaId,
        parentId: target.parentId,
        title: target.title,
        seriesTitle: target.seriesTitle,
        poster: target.poster,
        seasonNumber: target.seasonNumber,
        episodeNumber: target.episodeNumber,
        upgradeIfBetter: s.upgradeIfBetter,
      ));
      if (isClosed) return;
      emit(DownloadOptionsSubmitted([info]));
    } catch (e) {
      if (isClosed) return;
      emit(DownloadOptionsSubmitFailed(grpcMessage(e)));
    }
  }

  /// Season / "next N episodes": ONE CreateDownloads call for every target
  /// (contract: "sostituisce il ciclo di CreateDownload") — the quality/
  /// audio/subtitle choice made from the first episode's options is sent
  /// once at the request level and applies to every item as criteria, not
  /// per-item. No subscription: this queues exactly the given targets, never
  /// "future episodes too" (contract: "Nessun abbonamento").
  Future<void> confirmBatch(List<DownloadTarget> targets) async {
    final s = state;
    if (s is! DownloadOptionsReady || targets.isEmpty) return;
    emit(DownloadOptionsSubmitting(done: 0, total: targets.length));
    try {
      final resp = await _repo.createDownloads(CreateDownloadsRequest(
        pluginId: pluginId,
        items: [
          for (final t in targets)
            CreateDownloadItem(
              streamId: t.streamId,
              mediaId: t.mediaId,
              parentId: t.parentId,
              title: t.title,
              seriesTitle: t.seriesTitle,
              poster: t.poster,
              seasonNumber: t.seasonNumber,
              episodeNumber: t.episodeNumber,
            ),
        ],
        variantId: s.selectedVariantId,
        audioIds: s.selectedAudioIds.toList(),
        subtitleIds: s.selectedSubtitleIds.toList(),
        notBefore: _notBefore(s),
        usePreferredHours: _usePreferredHours(s),
        upgradeIfBetter: s.upgradeIfBetter,
      ));
      if (isClosed) return;
      emit(DownloadOptionsSubmitted(resp.downloads,
          serverEstimatedTotalBytes: resp.estimatedTotalBytes.toInt()));
    } catch (e) {
      if (isClosed) return;
      emit(DownloadOptionsSubmitFailed(grpcMessage(e)));
    }
  }
}
