/// Configuration for the in-app "a newer release is available" check
/// (see [UpdateService]). This only *notifies* — the actual install is done
/// out of band (Obtainium on Android, flatpak / a systemd timer on Linux).
///
/// Point it at your Forgejo instance either by editing the two constants
/// below, or — cleaner for CI — by passing them at build time:
///
///   flutter build linux --release \
///     --dart-define=PILEUS_FORGEJO_URL=https://git.example.com \
///     --dart-define=PILEUS_FORGEJO_REPO=owner/pileus-player
class UpdateConfig {
  const UpdateConfig._();

  /// Master switch for the whole feature.
  static const bool enabled = true;

  /// Set by store build pipelines (`--dart-define=PILEUS_STORE_BUILD=true`).
  /// Play and Amazon auto-update installed apps and disallow UI that steers
  /// users to off-store distribution, so the whole update check is forced
  /// off in a store build regardless of the Forgejo defines below.
  static const bool storeBuild =
      bool.fromEnvironment('PILEUS_STORE_BUILD', defaultValue: false);

  /// Forgejo/Gitea instance base URL, no trailing slash — e.g.
  /// `https://git.example.com`. Leave blank to disable the check.
  static const String forgejoBaseUrl = String.fromEnvironment(
    'PILEUS_FORGEJO_URL',
    defaultValue: '',
  );

  /// `owner/repo` on that instance — e.g. `owner/pileus-player`.
  static const String repoSlug = String.fromEnvironment(
    'PILEUS_FORGEJO_REPO',
    defaultValue: '',
  );

  /// Also surface releases flagged as pre-release (beta builds). With a
  /// closed beta you almost certainly want this on.
  static const bool includePrereleases = true;

  /// Don't hit the API more than once per this window (persisted across
  /// launches). A manual "check now" bypasses it.
  static const Duration minCheckInterval = Duration(hours: 6);

  /// Network timeout for the releases API call.
  static const Duration requestTimeout = Duration(seconds: 8);

  static bool get isConfigured =>
      enabled &&
      !storeBuild &&
      forgejoBaseUrl.startsWith('http') &&
      repoSlug.contains('/');

  /// Fallback URL to show the user if a release has no `html_url`.
  static String get releasesPageUrl =>
      '$forgejoBaseUrl/$repoSlug/releases';
}
