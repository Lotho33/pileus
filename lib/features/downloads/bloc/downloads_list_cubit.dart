import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/clients/media_client.dart' show DownloadInfo;
import '../../../core/grpc/grpc_errors.dart';
import '../../media/data/media_repository.dart';
import '../data/downloads_local_index.dart';
import 'downloads_list_state.dart';

/// Drives the "Download" page: one ListDownloads on start, then a poll every
/// [pollInterval] (contract: "aggiornato ogni 2-3 s mentre la pagina è
/// aperta") for as long as this cubit is alive — the page starts it in
/// initState and closes it in dispose, same lifecycle as every other
/// screen-scoped Cubit in the app.
class DownloadsListCubit extends Cubit<DownloadsListState> {
  final MediaRepository _repo;
  final Duration pollInterval;
  // Nullable: the ack queue / quality-changed detection are meaningful only
  // once a platform actually fetches files to the device (Phase 2, not
  // built yet) — TV, which never does, can use this cubit with none.
  final DownloadsLocalIndex? localIndex;
  Timer? _timer;

  DownloadsListCubit(
    this._repo, {
    this.pollInterval = const Duration(seconds: 3),
    this.localIndex,
  }) : super(const DownloadsListLoading());

  void start() {
    _refresh();
    // Best-effort, fire-and-forget — a failed ack just stays pending and
    // gets retried the next time this runs (contract: "riprova al prossimo
    // avvio online"). Ideally this also runs once at app startup, not only
    // when the user happens to open this page; tracked as a Phase 2 wiring
    // task alongside the rest of the local-download bookkeeping.
    localIndex?.syncPendingAcks(_repo);
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _refresh());
  }

  /// True when this device already has a copy of [info] AND the server's
  /// current quality_label no longer matches what was saved when this
  /// device fetched it — the downloads page offers "Scarica di nuovo in
  /// qualità migliore" for this (contract point 5).
  bool hasQualityUpgrade(DownloadInfo info) =>
      localIndex?.hasQualityChanged(info.downloadId, info.qualityLabel) ??
      false;

  Future<void> _refresh() async {
    try {
      final resp = await _repo.listDownloads();
      if (isClosed) return;
      emit(DownloadsListLoaded(
        downloads: resp.downloads,
        serverFreeBytes: resp.serverFreeBytes.toInt(),
        quotaBytes: resp.quotaBytes.toInt(),
        usedBytes: resp.usedBytes.toInt(),
      ));
    } catch (e) {
      if (isClosed) return;
      if (isUnavailable(e)) {
        emit(const DownloadsListInactive());
        return;
      }
      // A poll tick that fails transiently (Wi-Fi blip) shouldn't blank out
      // an already-loaded list — only the very first load (still in
      // DownloadsListLoading) surfaces the error state.
      if (state is DownloadsListLoading) {
        emit(DownloadsListError(grpcMessage(e)));
      }
    }
  }

  Future<void> cancelDownload(String downloadId) async {
    await _repo.cancelDownload(downloadId);
    await _refresh();
  }

  Future<void> deleteDownload(String downloadId) async {
    await _repo.deleteDownload(downloadId);
    await _refresh();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
