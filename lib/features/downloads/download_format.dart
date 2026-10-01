// Pure, engine/platform-agnostic helpers for the offline-downloads feature
// (server-side prepared download — see mycelium-core's
// docs/pileus-contract.md, "Offline downloads"). Kept dependency-free (no
// gRPC types beyond the generated messages themselves) so every one of these
// is a plain unit test, no bloc/widget harness needed.

import '../../core/grpc/clients/media_client.dart'
    show
        DownloadVariant,
        DownloadTrack,
        DownloadInfo,
        PluginInfo;

/// A plugin only shows the "Scarica" affordance when ListPlugins reports this
/// capability (contract: "Un plugin è scaricabile solo se ListPlugins
/// riporta la capacità 'download'").
bool pluginSupportsDownload(PluginInfo plugin) =>
    plugin.capabilities.contains('download');

/// Total estimated size for a chosen combination: the variant itself plus
/// every currently-selected audio track (subtitles are ≈0 per the contract,
/// so they're deliberately not summed here even though DownloadTrack has the
/// field for them too — keeps this function's contract exactly the one the
/// spec describes: "peso totale ... variante + ogni audio scelto").
int totalEstimatedBytes({
  required DownloadVariant? variant,
  required Iterable<DownloadTrack> selectedAudio,
}) {
  var total = variant?.estimatedBytes.toInt() ?? 0;
  for (final a in selectedAudio) {
    total += a.estimatedBytes.toInt();
  }
  return total;
}

/// "1.4 GB" / "340 MB" / "512 KB" / "0 B" — binary (1024) units, one decimal
/// past the first, matching how every other size in the app is already
/// shown (server_free_bytes, quota, etc. all go through this too).
String formatBytes(num bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final decimals = unitIndex == 0 ? 0 : (value < 10 ? 1 : 0);
  return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
}

/// A variant's own size label — "fino a ~1.2 GB" when the server only
/// declared a peak bitrate (bandwidth_is_peak: the real file could be
/// smaller), otherwise a plain "1.2 GB".
String formatVariantSize(DownloadVariant variant) {
  final size = formatBytes(variant.estimatedBytes.toInt());
  return variant.bandwidthIsPeak ? 'fino a ~$size' : size;
}

/// Estimated preparation time for [totalBytes] at [bytesPerSec] — '' when
/// the rate is unknown (0, per the contract), otherwise "~N min"/"~N s"/
/// "~N h Nmin".
String formatEtaLabel(int totalBytes, int bytesPerSec) {
  if (bytesPerSec <= 0 || totalBytes <= 0) return '';
  final totalSeconds = totalBytes / bytesPerSec;
  if (totalSeconds < 60) return '~${totalSeconds.ceil()} s';
  final totalMinutes = (totalSeconds / 60).ceil();
  if (totalMinutes < 60) return '~$totalMinutes min';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return minutes == 0 ? '~$hours h' : '~$hours h ${minutes}min';
}

/// "Il file resta sul server per N giorni" / "resta sul server finché non lo
/// elimini" (retention_days: 0 = never, per the contract).
String retentionLabel(int retentionDays) => retentionDays <= 0
    ? 'Il file resta sul server finché non lo elimini'
    : 'Il file resta sul server per $retentionDays giorn${retentionDays == 1 ? 'o' : 'i'}';

/// The "quality now vs usual" warning the options sheet shows underneath the
/// plugin's own notes when the best variant available right now is below
/// what this plugin has served before (contract: quality_below_usual +
/// usual_max_height). '' when there's nothing to warn about.
String qualityBelowUsualWarning({
  required bool qualityBelowUsual,
  required int usualMaxHeight,
  required int bestHeightNow,
}) {
  if (!qualityBelowUsual || usualMaxHeight <= 0) return '';
  final now = bestHeightNow > 0 ? '${bestHeightNow}p' : 'una qualità ridotta';
  return 'Ora il massimo è $now, di solito ${usualMaxHeight}p: '
      'conviene scaricare più tardi';
}

/// One of the three ways a download can be scheduled from the options sheet.
enum DownloadScheduleKind { now, preferredWindow, specificTime }

/// A leaf-level readable status for one [DownloadInfo] row on the downloads
/// page. Doesn't localize dates/times itself (that's a widget concern, needs
/// a BuildContext-free formatter the caller already has) — takes the already-
/// formatted pieces as parameters instead.
String downloadStatusLabel(
  DownloadInfo info, {
  required String Function(DateTime) formatTime,
}) {
  switch (info.status) {
    case 'queued':
      return 'In coda';
    case 'scheduled':
      final at = info.scheduledFor.toInt();
      if (at <= 0) return 'Programmato';
      final dt = DateTime.fromMillisecondsSinceEpoch(at * 1000);
      return 'Programmato alle ${formatTime(dt)}';
    case 'running':
      final pct = (info.progress.clamp(0.0, 1.0) * 100).round();
      return 'Preparazione $pct%';
    // Not an error — the server pauses its own downloads while someone is
    // actively watching something (to not compete for bandwidth/egress) and
    // resumes them by itself once that's over. No action, no retry.
    case 'paused':
      return 'In pausa — riprende quando nessuno guarda';
    case 'completed':
      return 'Pronto';
    case 'failed':
      return info.error.isNotEmpty ? info.error : 'Errore';
    case 'canceled':
      return 'Annullato';
    default:
      return info.status;
  }
}

/// "condiviso con un altro profilo" — DownloadInfo.shared: the same server
/// file also backs another profile's own download entry. Purely informative:
/// deleting *this* profile's entry never touches the other one (the server
/// keeps the file alive as long as any download still references it).
const String sharedIndicatorLabel = 'Condiviso con un altro profilo';

/// "cerco una qualità migliore (fascia)" — DownloadInfo.upgrade_pending:
/// the server will retry this download in [preferredHours] hoping for a
/// better rendition than what it already has (see CreateDownloadRequest.
/// upgrade_if_better / CreateDownloadsRequest.upgrade_if_better), then keep
/// whichever came out better. [preferredHours] may be empty (no known
/// window) — the label still reads fine without the parenthetical then.
String upgradePendingLabel(String preferredHours) => preferredHours.isEmpty
    ? 'Cerco una qualità migliore'
    : 'Cerco una qualità migliore ($preferredHours)';

/// Where GetDownloadOptions/CreateDownloadRequest's preferred_hours window
/// comes from — shown next to the "fascia consigliata" choice in the options
/// sheet. '' (unknown/other) falls back to a generic label rather than
/// hiding the source entirely.
String preferredHoursSourceLabel(String source) => switch (source) {
      'plugin' => 'consigliata dalla sorgente',
      'learned' => 'in queste ore la qualità di solito è migliore',
      _ => '',
    };
