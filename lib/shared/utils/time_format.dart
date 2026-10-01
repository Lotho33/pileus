/// Relative "last seen" label from a Unix timestamp (seconds) — used for
/// PluginInfo.last_ok_unix (0 = never confirmed reachable) wherever a
/// plugin's heartbeat/reachability is shown (home_screen.dart's side-nav
/// badge, plugin_settings_screen.dart's per-plugin status).
String lastSeenLabel(int lastOkUnixSeconds) {
  if (lastOkUnixSeconds <= 0) return 'mai';
  final delta = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastOkUnixSeconds * 1000));
  if (delta.inMinutes < 1) return 'pochi secondi fa';
  if (delta.inHours < 1) return '${delta.inMinutes}m fa';
  if (delta.inDays < 1) return '${delta.inHours}h fa';
  return '${delta.inDays}g fa';
}
