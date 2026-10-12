/// How the player should treat a URL. [auto] guesses from the URL (HLS
/// unless the path ends in a progressive container extension) — right for
/// everything mycelium resolves. Offline downloads say [progressive]
/// explicitly (from DownloadInfo.container) instead of relying on the URL.
enum StreamFormat {
  auto,
  hls,

  /// A single file read with HTTP Range requests (MKV/MP4 download).
  progressive;

  /// From a DownloadInfo.container-style value ("mkv", "mp4", "m3u8"…).
  /// Empty → [auto] (older servers didn't send one).
  static StreamFormat fromContainer(String? container) {
    final c = (container ?? '').trim().toLowerCase();
    if (c.isEmpty) return StreamFormat.auto;
    if (c == 'hls' || c == 'm3u8') return StreamFormat.hls;
    return StreamFormat.progressive;
  }
}
