import '../../core/grpc/clients/media_client.dart' show DownloadInfo;

/// The downloads page's unit: a movie, or a series with its downloaded
/// episodes in season/episode order — so ten episodes of one show are one
/// card that opens on them, not ten loose rows.
class DownloadGroup {
  final String key;
  final bool isSeries;
  final String pluginId;
  final String parentId;
  final String title;
  final String poster;
  final List<DownloadInfo> items;

  const DownloadGroup({
    required this.key,
    required this.isSeries,
    required this.pluginId,
    required this.parentId,
    required this.title,
    required this.poster,
    required this.items,
  });

  int get readyCount => items.where((i) => i.status == 'completed').length;

  int get totalBytes => items.fold(
      0,
      (n, i) =>
          n + (i.fileBytes > 0 ? i.fileBytes : i.estimatedBytes).toInt());

  bool get anyInProgress => items.any((i) => const {
        'queued',
        'scheduled',
        'running',
        'paused',
      }.contains(i.status));

  /// Season numbers present, in order (0 = unknown season).
  List<int> get seasons =>
      (items.map((i) => i.seasonNumber).toSet().toList()..sort());
}

String downloadGroupKey(DownloadInfo d) => d.parentId.isNotEmpty
    ? 's\u0000${d.pluginId}\u0000${d.parentId}'
    : 'm\u0000${d.pluginId}\u0000${d.mediaId.isNotEmpty ? d.mediaId : d.downloadId}';

/// Groups [downloads] keeping the first-seen order of the groups (the
/// server lists newest first, so the show downloaded last comes first).
List<DownloadGroup> groupDownloads(List<DownloadInfo> downloads) {
  final order = <String>[];
  final byKey = <String, List<DownloadInfo>>{};
  for (final d in downloads) {
    final k = downloadGroupKey(d);
    if (!byKey.containsKey(k)) order.add(k);
    byKey.putIfAbsent(k, () => []).add(d);
  }
  return [
    for (final k in order)
      () {
        final items = byKey[k]!
          ..sort((a, b) {
            final s = a.seasonNumber.compareTo(b.seasonNumber);
            return s != 0 ? s : a.episodeNumber.compareTo(b.episodeNumber);
          });
        final first = items.first;
        final series = first.parentId.isNotEmpty;
        return DownloadGroup(
          key: k,
          isSeries: series,
          pluginId: first.pluginId,
          parentId: first.parentId,
          title: series && first.seriesTitle.isNotEmpty
              ? first.seriesTitle
              : first.title,
          poster: first.poster,
          items: items,
        );
      }()
  ];
}

/// "S1 · E3 — Titolo" for an episode row inside its series.
String episodeRowLabel(DownloadInfo d) {
  final num = d.episodeNumber > 0
      ? (d.seasonNumber > 0
          ? 'S${d.seasonNumber} · E${d.episodeNumber}'
          : 'E${d.episodeNumber}')
      : '';
  if (num.isEmpty) return d.title;
  return d.title.isEmpty ? num : '$num — ${d.title}';
}
