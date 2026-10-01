import 'package:equatable/equatable.dart';

import '../../../core/grpc/clients/media_client.dart'
    show DownloadOptionsResponse, DownloadInfo, DownloadVariant;
import '../download_format.dart';

sealed class DownloadOptionsState extends Equatable {
  const DownloadOptionsState();
  @override
  List<Object?> get props => [];
}

class DownloadOptionsLoading extends DownloadOptionsState {
  const DownloadOptionsLoading();
}

/// GetDownloadOptions answered `available: false` — not an error, just
/// nothing to configure. [reason] is unavailable_reason, shown verbatim.
class DownloadOptionsUnavailable extends DownloadOptionsState {
  final String reason;
  const DownloadOptionsUnavailable(this.reason);
  @override
  List<Object?> get props => [reason];
}

/// A genuine RPC failure fetching the options themselves (as opposed to a
/// normal `available: false` response) — network/auth/server error, shown
/// with a retry affordance.
class DownloadOptionsError extends DownloadOptionsState {
  final String message;
  const DownloadOptionsError(this.message);
  @override
  List<Object?> get props => [message];
}

/// The picker itself: options loaded, user is choosing quality/audio/
/// subtitles/schedule. [response.variants] is never empty here (that case
/// would mean available=true with nothing to pick, treated the same as
/// [DownloadOptionsUnavailable] by the cubit before this state is ever
/// reached).
class DownloadOptionsReady extends DownloadOptionsState {
  final DownloadOptionsResponse response;
  final String selectedVariantId;
  final Set<String> selectedAudioIds;
  final Set<String> selectedSubtitleIds;
  final DownloadScheduleKind scheduleKind;
  // Only meaningful when scheduleKind == specificTime.
  final DateTime? scheduledAt;
  // CreateDownload(s)Request.upgrade_if_better — defaults to true when the
  // server already flagged quality_below_usual (contract: "Spuntala di
  // default quando quality_below_usual=true"), false otherwise.
  final bool upgradeIfBetter;

  const DownloadOptionsReady({
    required this.response,
    required this.selectedVariantId,
    required this.selectedAudioIds,
    required this.selectedSubtitleIds,
    required this.scheduleKind,
    this.scheduledAt,
    this.upgradeIfBetter = false,
  });

  DownloadOptionsReady copyWith({
    String? selectedVariantId,
    Set<String>? selectedAudioIds,
    Set<String>? selectedSubtitleIds,
    DownloadScheduleKind? scheduleKind,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    bool? upgradeIfBetter,
  }) =>
      DownloadOptionsReady(
        response: response,
        selectedVariantId: selectedVariantId ?? this.selectedVariantId,
        selectedAudioIds: selectedAudioIds ?? this.selectedAudioIds,
        selectedSubtitleIds: selectedSubtitleIds ?? this.selectedSubtitleIds,
        scheduleKind: scheduleKind ?? this.scheduleKind,
        scheduledAt:
            clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
        upgradeIfBetter: upgradeIfBetter ?? this.upgradeIfBetter,
      );

  /// The variant the user has selected — falls back to the first (best) one
  /// if selectedVariantId is '' or no longer matches (defensive; the cubit
  /// always keeps this in sync with response.variants).
  DownloadVariant? get selectedVariant =>
      response.variants.where((v) => v.id == selectedVariantId).firstOrNull ??
      (response.variants.isNotEmpty ? response.variants.first : null);

  int get totalBytes => totalEstimatedBytes(
        variant: selectedVariant,
        selectedAudio:
            response.audio.where((a) => selectedAudioIds.contains(a.id)),
      );

  /// Whether the chosen total fits what the server says it can still use —
  /// the sheet shows the total in red when this is false (contract: "totale
  /// in rosso se non ci sta").
  bool get fitsServerSpace => totalBytes <= response.serverFreeBytes.toInt();

  /// Client-side pre-confirm estimate for a season/next-N batch — the real
  /// CreateDownloadsResponse.estimated_total_bytes doesn't exist until that
  /// RPC actually runs, so the sheet shows "this episode's weight × N"
  /// beforehand instead (contract: "Prima di confermare mostra
  /// estimated_total_bytes, o stimalo come peso del primo episodio × N").
  int estimateBatchBytes(int itemCount) => totalBytes * itemCount;

  @override
  List<Object?> get props => [
        response.available,
        response.variants.length,
        selectedVariantId,
        selectedAudioIds,
        selectedSubtitleIds,
        scheduleKind,
        scheduledAt,
        upgradeIfBetter,
      ];
}

/// One or more CreateDownload calls in flight (a single item, or a season/
/// next-N-episodes batch — [total] is 1 for the single-item case).
class DownloadOptionsSubmitting extends DownloadOptionsState {
  final int done;
  final int total;
  const DownloadOptionsSubmitting({required this.done, required this.total});
  @override
  List<Object?> get props => [done, total];
}

/// Every item in the batch was queued successfully.
class DownloadOptionsSubmitted extends DownloadOptionsState {
  final List<DownloadInfo> created;
  // The server's own total for a CreateDownloads batch (null for a single
  // CreateDownload, which has no such field).
  final int? serverEstimatedTotalBytes;
  const DownloadOptionsSubmitted(this.created, {this.serverEstimatedTotalBytes});
  @override
  List<Object?> get props =>
      [created.map((d) => d.downloadId).toList(), serverEstimatedTotalBytes];
}

/// CreateDownload came back FAILED_PRECONDITION (quota/disk margin/not
/// downloadable) — [message] is the server's own text, shown as-is, no
/// retry (see grpc_errors.dart's isFailedPrecondition doc). [created] holds
/// whatever earlier items in a batch already succeeded before this one
/// failed, so the caller can still surface those instead of losing them.
class DownloadOptionsSubmitFailed extends DownloadOptionsState {
  final String message;
  final List<DownloadInfo> created;
  const DownloadOptionsSubmitFailed(this.message, {this.created = const []});
  @override
  List<Object?> get props => [message, created.map((d) => d.downloadId).toList()];
}
