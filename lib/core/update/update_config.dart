/// Configuration for the in-app "a newer release is available" check
/// (see [UpdateService]). This only *notifies* — the actual install is done
/// out of band (Obtainium on Android, flatpak / a systemd timer on Linux).
///
/// Points at a `owner/repo` on github.com — the API host is fixed
/// (`api.github.com`), unlike a self-hosted Forgejo instance there is no
/// separate base URL to configure. Set it by passing it at build time:
///
///   flutter build linux --release \
///     --dart-define=PILEUS_GITHUB_REPO=Lotho33/pileus
class UpdateConfig {
  const UpdateConfig._();

  /// Master switch for the whole feature.
  static const bool enabled = true;

  /// Set by store build pipelines (`--dart-define=PILEUS_STORE_BUILD=true`).
  /// Play and Amazon auto-update installed apps and disallow UI that steers
  /// users to off-store distribution, so the whole update check is forced
  /// off in a store build regardless of the repo slug below.
  static const bool storeBuild =
      bool.fromEnvironment('PILEUS_STORE_BUILD', defaultValue: false);

  /// `owner/repo` on github.com — e.g. `Lotho33/pileus`. Leave blank to
  /// disable the check.
  static const String repoSlug = String.fromEnvironment(
    'PILEUS_GITHUB_REPO',
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
      enabled && !storeBuild && repoSlug.contains('/');

  /// Fallback URL to show the user if a release has no `html_url`.
  static String get releasesPageUrl => 'https://github.com/$repoSlug/releases';
}
