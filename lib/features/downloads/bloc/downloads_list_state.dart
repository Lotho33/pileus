import 'package:equatable/equatable.dart';

import '../../../core/grpc/clients/media_client.dart' show DownloadInfo;

sealed class DownloadsListState extends Equatable {
  const DownloadsListState();
  @override
  List<Object?> get props => [];
}

class DownloadsListLoading extends DownloadsListState {
  const DownloadsListLoading();
}

/// UNAVAILABLE — "download non attivi sul server" (contract), distinct from
/// a plain transient error so the page can show a calmer, non-retry message.
class DownloadsListInactive extends DownloadsListState {
  const DownloadsListInactive();
}

class DownloadsListError extends DownloadsListState {
  final String message;
  const DownloadsListError(this.message);
  @override
  List<Object?> get props => [message];
}

class DownloadsListLoaded extends DownloadsListState {
  final List<DownloadInfo> downloads;
  final int serverFreeBytes;
  final int quotaBytes;
  final int usedBytes;
  const DownloadsListLoaded({
    required this.downloads,
    required this.serverFreeBytes,
    required this.quotaBytes,
    required this.usedBytes,
  });
  @override
  List<Object?> get props => [
        downloads.map((d) => '${d.downloadId}:${d.status}:${d.progress}').toList(),
        serverFreeBytes,
        quotaBytes,
        usedBytes,
      ];
}
