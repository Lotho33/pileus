import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_config.dart';

/// Result of a successful update check. Only constructed when the feature is
/// configured and the API answered — a null return from [UpdateService.check]
/// means "couldn't tell" (disabled, offline, rate-limited, parse error), and
/// callers should treat that as "no update", never as an error to surface.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  final String releaseUrl;
  final bool isPrerelease;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.isPrerelease,
    this.publishedAt,
  });

  bool get updateAvailable =>
      compareVersions(latestVersion, currentVersion) > 0;
}

class UpdateService {
  final SharedPreferences _prefs;
  final http.Client _client;

  UpdateService(this._prefs, {http.Client? client})
      : _client = client ?? http.Client();

  /// Release the HTTP client. Wired to the get_it registration's `dispose:`
  /// so a `getIt.reset()` (the startup-error retry path) doesn't leak it.
  void dispose() => _client.close();

  static const _kLastCheckKey = 'update.lastCheckUnix';
  static const _kDismissedKey = 'update.dismissedVersion';

  /// The version the user explicitly dismissed ("Ignora questa versione").
  String? get dismissedVersion => _prefs.getString(_kDismissedKey);

  Future<void> dismiss(String version) =>
      _prefs.setString(_kDismissedKey, version);

  Future<void> clearDismissed() => _prefs.remove(_kDismissedKey);

  bool _rateLimited() {
    final last = _prefs.getInt(_kLastCheckKey);
    if (last == null) return false;
    final elapsed = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(last * 1000));
    return elapsed < UpdateConfig.minCheckInterval;
  }

  /// Returns update metadata, or null when it can't be determined.
  /// [force] skips the rate limit (use for a manual "check now").
  Future<UpdateInfo?> check({bool force = false}) async {
    if (!UpdateConfig.isConfigured) return null;
    if (!force && _rateLimited()) return null;

    try {
      final current = (await PackageInfo.fromPlatform()).version.trim();

      // The list endpoint (newest first) covers both stable and beta
      // (pre-release) — /releases/latest silently skips pre-releases.
      final uri = Uri.parse(
        '${UpdateConfig.forgejoBaseUrl}'
        '/api/v1/repos/${UpdateConfig.repoSlug}/releases?limit=10&page=1',
      );
      final resp = await _client.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(UpdateConfig.requestTimeout);

      // Record the attempt regardless of outcome so a flaky server doesn't
      // get hammered on every launch.
      await _prefs.setInt(
          _kLastCheckKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);

      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) return null;

      Map<String, dynamic>? picked;
      for (final e in decoded) {
        if (e is! Map<String, dynamic>) continue;
        if (e['draft'] == true) continue;
        if (e['prerelease'] == true && !UpdateConfig.includePrereleases) {
          continue;
        }
        picked = e;
        break; // list is newest-first
      }
      if (picked == null) return null;

      final tag = (picked['tag_name'] as String? ?? '').trim();
      if (tag.isEmpty) return null;

      return UpdateInfo(
        currentVersion: current,
        latestVersion: _stripLeadingV(tag),
        releaseName: (picked['name'] as String?)?.trim().isNotEmpty == true
            ? (picked['name'] as String).trim()
            : tag,
        releaseNotes: (picked['body'] as String? ?? '').trim(),
        releaseUrl: (picked['html_url'] as String?)?.trim().isNotEmpty == true
            ? (picked['html_url'] as String).trim()
            : UpdateConfig.releasesPageUrl,
        isPrerelease: picked['prerelease'] == true,
        publishedAt: DateTime.tryParse(picked['published_at'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}

String _stripLeadingV(String s) =>
    (s.startsWith('v') || s.startsWith('V')) ? s.substring(1) : s;

/// Compares two dotted version strings. Returns >0 if [a] is newer than [b],
/// <0 if older, 0 if equal. Tolerant of a leading `v`, of a `+build`
/// suffix (ignored), of missing components (treated as 0) and of a
/// `-prerelease` tail (any prerelease sorts *before* the same release
/// without one — `1.4.0-beta.2 < 1.4.0`).
int compareVersions(String a, String b) {
  ({List<int> nums, String pre}) parse(String raw) {
    var s = _stripLeadingV(raw.trim());
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    String pre = '';
    final dash = s.indexOf('-');
    if (dash >= 0) {
      pre = s.substring(dash + 1);
      s = s.substring(0, dash);
    }
    final nums = s
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    return (nums: nums, pre: pre);
  }

  final pa = parse(a);
  final pb = parse(b);
  final len = pa.nums.length > pb.nums.length ? pa.nums.length : pb.nums.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.nums.length ? pa.nums[i] : 0;
    final y = i < pb.nums.length ? pb.nums[i] : 0;
    if (x != y) return x > y ? 1 : -1;
  }
  // Same numeric core: no prerelease beats a prerelease.
  if (pa.pre.isEmpty && pb.pre.isEmpty) return 0;
  if (pa.pre.isEmpty) return 1;
  if (pb.pre.isEmpty) return -1;
  return _comparePrerelease(pa.pre, pb.pre);
}

// SemVer §11: split on '.', compare identifier by identifier. Two numeric
// identifiers compare numerically (so `beta.10 > beta.2`, which a plain
// string compare gets backwards); a numeric identifier is lower than an
// alphanumeric one; alphanumeric identifiers compare in ASCII order; and
// the shorter list loses when it's a prefix of the longer.
int _comparePrerelease(String a, String b) {
  final ai = a.split('.');
  final bi = b.split('.');
  final len = ai.length > bi.length ? ai.length : bi.length;
  for (var i = 0; i < len; i++) {
    if (i >= ai.length) return -1;
    if (i >= bi.length) return 1;
    final an = int.tryParse(ai[i]);
    final bn = int.tryParse(bi[i]);
    if (an != null && bn != null) {
      if (an != bn) return an > bn ? 1 : -1;
    } else if (an != null) {
      return -1; // numeric < alphanumeric
    } else if (bn != null) {
      return 1;
    } else {
      final c = ai[i].compareTo(bi[i]);
      if (c != 0) return c > 0 ? 1 : -1;
    }
  }
  return 0;
}
