import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/clients/media_client.dart' show DownloadInfo;
import 'package:pileus/features/downloads/download_groups.dart';

DownloadInfo _ep(String id, String show, int s, int e) => DownloadInfo(
    downloadId: id,
    pluginId: 'example.series',
    mediaId: 'm$id',
    parentId: show,
    seriesTitle: 'Serie $show',
    title: 'Ep $e',
    seasonNumber: s,
    episodeNumber: e);

void main() {
  test('episodes of one series become one group, in season/episode order',
      () {
    final groups = groupDownloads([
      _ep('3', 'a', 2, 1),
      DownloadInfo(downloadId: 'f', pluginId: 'example.movie', mediaId: 'film', title: 'Film'),
      _ep('1', 'a', 1, 2),
      _ep('2', 'a', 1, 1),
      _ep('9', 'b', 1, 1),
    ]);
    expect(groups.map((g) => g.title), ['Serie a', 'Film', 'Serie b']);
    final a = groups.first;
    expect(a.isSeries, isTrue);
    expect(a.items.map((i) => i.downloadId), ['2', '1', '3']);
    expect(a.seasons, [1, 2]);
    expect(groups[1].isSeries, isFalse);
  });

  test('episode label', () {
    expect(episodeRowLabel(_ep('1', 'a', 1, 3)), 'S1 · E3 — Ep 3');
    expect(episodeRowLabel(DownloadInfo(title: 'Speciale')), 'Speciale');
  });
}
