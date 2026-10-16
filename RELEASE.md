# Releasing Pileus

Builds are published as **GitHub releases** on `github.com/Lotho33/pileus`.
Every workflow runs on a GitHub-hosted runner — nothing to register, no
self-hosted infrastructure.

| Workflow | Trigger | Produces |
|---|---|---|
| `release.yml` | push of tag `vX.Y.Z` (or manual, with a tag input) | Android APKs (per-ABI, both flavors) + the web bundle, attached to the GitHub Release; **also** draft-uploads the TV store build to a new Amazon Appstore edit (see below) |
| `store.yml` | manual, tag input | signed AAB + signed per-ABI APKs for Play Store / Amazon Appstore, as a downloadable workflow artifact |
| `linux.yml` | manual, tag input | a Linux x64 tarball, attached to the GitHub Release |
| `windows.yml` | manual, tag input | a Windows installer + portable zip, attached to the GitHub Release |
| `ci.yml` | every push/PR to `main` | `flutter analyze` + `flutter test` |

Android TV / Fire TV is the shipping target; the web bundle also covers a
browser-based install (notably iOS, where a sideloaded native app isn't an
option without a developer account).

### Web build

Built and attached automatically alongside the APKs on every tag, as
`pileus-<version>-web.tar.gz`. Unpack it and serve `build/web`'s contents
from the same origin as Mycelium (or a reverse proxy in front of it); see
`docs/WEB.md` for current caveats before relying on it for anything beyond
browsing. To (re)build it for an existing tag without re-cutting a release:
Actions → release → Run workflow, with that tag as input (already-published
assets are replaced, not duplicated).

## Cutting a release

Use the helper: `scripts/release.sh <X.Y.Z>` bumps `version:` in
`pubspec.yaml`, commits, tags `vX.Y.Z`, pushes branch + tag to the
`origin` remote (it refuses to run unless you're on `main`), and — if `gh`
is on PATH — also dispatches `linux.yml` for that tag, so the desktop
Linux tarball gets built and attached without a separate manual step. Once
that run finishes, `scripts/update-flatpak-manifest.sh <X.Y.Z>` points the
Flatpak manifest (`packaging/linux/`) at the new tarball — see
`packaging/README.md` for the remaining one-time Flathub setup.

Manually, the equivalent is:

1. Bump `version:` in `pubspec.yaml` (e.g. `1.4.0+0` — the `+build` is
   overwritten by CI with the pipeline run number, so only the `1.4.0` part
   matters here).
2. Commit, then tag and push:

   ```sh
   git tag v1.4.0
   git push origin main --tags
   ```

3. The `release` workflow builds and attaches the APKs + web bundle to the
   `v1.4.0` GitHub release. Mark it **pre-release** there for a beta build —
   the in-app check and Obtainium both still pick it up.

## Store build (Play Store / Amazon Appstore)

Separate from the beta channel above. Run the **`store`** workflow by hand
(Actions → store → Run) with the tag as input. It builds **both** flavors
from the tagged commit:

- a **signed AAB** per flavor (`flutter build appbundle`) — upload the `tv`
  one to the Play Console
- **signed per-ABI APKs** (`--split-per-abi`, arm/arm64) per flavor — upload
  to the Amazon Developer console
- an obfuscation-symbols tarball + R8 `mapping.txt` per flavor — upload to
  the Play Console for readable crash/ANR stacks

Differences from `release.yml` baked into `store.yml`:

- `--dart-define=PILEUS_STORE_BUILD=true` — the in-app update check and the
  sideload dialog are compiled out (`UpdateConfig.storeBuild`), and no
  particular GitHub repo or Mycelium host is baked in
  (`PILEUS_GITHUB_REPO`/`PILEUS_MYCELIUM_HOST` are **not** passed)
- `-PpileusRequireSigning=true` — the build fails if signing isn't
  configured, instead of falling back to debug keys
- `--obfuscate --split-debug-info`

Artifacts are uploaded as a workflow run artifact (Actions tab → that run →
Artifacts), **not** attached to the public GitHub Release. Download from
there and upload to the two store consoles by hand.

Console-side work that isn't automatable: the privacy policy URL
(`docs/PRIVACY.md`, published wherever the store console needs a URL), Play
Data Safety + content rating questionnaire, Play App Signing enrolment, TV
screenshots, and reviewer notes (including a reachable demo Mycelium server
for the reviewer to connect to — see `docs/PRIVACY.md` and the admin
dashboard's own docs for setting up a reviewer-facing demo instance; its
address is never checked into this repo).

### Amazon Appstore auto-upload (`release.yml`)

Every `vX.Y.Z` tag also builds the TV flavor with `store.yml`'s own flags
(`PILEUS_STORE_BUILD=true`, signing required, R8 + `--obfuscate`, no
`libmpv.so`) and pushes the resulting per-ABI APKs to a **new** Amazon
Appstore edit via the
[App Submission API](https://developer.amazon.com/docs/app-submission-api/)
— see `scripts/amazon-upload-edit.sh` for the actual HTTP calls. This is the
`amazon-submit` job, independent of the sideload `android`/`web` jobs (a
failure here never blocks the GitHub Release).

**It uploads and submits the edit for review** (`--submit`, since
v1.6.8 — before that it stopped at a draft). Smoke-test the sideload APK of
the same tag on a Fire TV before the review finishes. If a previous version
is still under review, Amazon refuses any change: the job warns and uploads
nothing — re-run the tag (Actions → release → Run workflow, `force=tv`)
once the review is over. Runs only when the `tv` target changed (see
"Per-store publishing" below).

One-time setup, beyond the signing secrets this job also reuses:

1. Amazon Developer Console → *Settings → API Access* → create a security
   profile associated with the App Submission API → note its Client ID /
   Client Secret.
2. `scripts/set-amazon-secrets.sh` uploads both as repo secrets
   (`AMAZON_CLIENT_ID` / `AMAZON_CLIENT_SECRET`) — needs `gh` authenticated
   with admin access to the repo.
3. Add repo variable `AMAZON_APP_ID` (Settings → Secrets and variables →
   Actions → **Variables** tab, not Secrets — it's not sensitive, it's
   visible in the Console's own URLs) = this app's id, from the Console's
   *Additional information* panel for the Pileus TV listing.

Confidence note: the API call sequence in `amazon-upload-edit.sh` is written
against Amazon's current published docs, not against a live test run — its
own header comment explains why every call dumps Amazon's raw response on
failure. Sanity-check the first real run's Actions log before trusting it
unattended.

### Mobile flavor

The phone/tablet app is the same repo, `--flavor mobile -t
lib/main_mobile.dart` — a separate `applicationId`, hence a **separate
store listing**. The `store` workflow builds it alongside `tv`.

Size-optimised store build (matches the workflow):

```sh
flutter build appbundle --release --flavor mobile -t lib/main_mobile.dart \
  -PpileusRequireSigning=true -PpileusExcludeMpv=true -PpileusR8=true \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=PILEUS_STORE_BUILD=true --build-name=<X.Y.Z> --build-number=<n>
```

- `-PpileusExcludeMpv=true` drops `libmpv.so` (media_kit) from the APK — the
  Android player always uses ExoPlayer, `_MpvPlayerEngine` throws if
  constructed there. ~12 MB/ABI.
- `-PpileusR8=true` turns on R8 code shrink + `shrinkResources` (uses
  `android/app/proguard-rules.pro`). **Both flags are OFF by default** (a
  bad strip only surfaces at runtime) — a build with them on should pass a
  real playback + gRPC + subtitle smoke test on a device before it ships.

Result: arm64 mobile release APK ≈ 23.5 MB (vs ~36 MB unoptimised).

### Per-store publishing (`release.yml`)

Each store job runs only when the tag changed what that store ships —
`scripts/release-targets.py` diffs the tag against the previous one and,
for Dart, follows the import graph from each entry point (so a change under
`lib/mobile/` doesn't republish the TV apps; one in a shared bloc does):

| Target | Entry point | Store job |
|---|---|---|
| `tv` | `lib/main.dart` (+ `android/` minus `src/mobile`, `third_party/`) | `amazon-submit` + `play` (Android TV app, `com.lotho33.pileus`) |
| `mobile` | `lib/main_mobile.dart` (+ `android/` minus `src/tv`, `third_party/`) | `play` (`com.lotho33.pileus.mobile`) |
| `webos` | `lib/main_web_tv.dart` (+ `web/`, `packaging/webos/`) | `webos`: 1080p + 720p `.ipk` on the GitHub Release |

`pubspec.yaml`/`pubspec.lock`/`assets/` count for every target (the
`version:` bump alone doesn't). `scripts/release.sh` prints the same verdict
before tagging, also on `-n`. Force an unchanged target: Actions → release
→ Run workflow, tag + `force` (`tv,mobile,webos` or `all`).

**Play** (`play` job): builds the AAB of each changed flavor and sends it to
the **production** track with status completed — i.e. submitted for
review, published when Google approves. Needs secret
`PLAY_SERVICE_ACCOUNT_JSON` (below); without it the job only warns.

**LG webOS**: the Seller Lounge has no upload API. Download both `.ipk`
from the release and upload them by hand (File Ver. = the release version).

**versionCode** is `scripts/version-code.sh X.Y.Z` (MAJOR·10⁸ + MINOR·10⁶ +
PATCH·10⁴) in every workflow, not the run number — per-workflow run
counters drifted apart between Play (store.yml) and Amazon (release.yml).

## One-time setup

### Google Play API (`PLAY_SERVICE_ACCOUNT_JSON`)

1. Google Cloud Console → a project (any) → *APIs & Services* → enable
   **Google Play Android Developer API**.
2. *IAM & Admin → Service accounts* → create one → *Keys* → *Add key* →
   JSON → download it.
3. Play Console → *Users and permissions* → *Invite new users* → the
   service account's e-mail → app permissions for **both** Pileus apps
   (TV + mobile): *Release to production…*, *Manage testing tracks…*, *View
   app information*.
4. `gh secret set PLAY_SERVICE_ACCOUNT_JSON < downloaded-key.json`, then
   delete the downloaded file.


### Repo secrets (GitHub → Settings → Secrets and variables → Actions)

| Secret | What |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 pileus-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `pileus`) |
| `ANDROID_KEY_PASSWORD` | key password |
| `AMAZON_CLIENT_ID` | App Submission API client id (Console → Settings → API Access) — set via `scripts/set-amazon-secrets.sh`, not by hand |
| `AMAZON_CLIENT_SECRET` | App Submission API client secret — same script |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Developer API service-account key (JSON) — see "Google Play API" above |

No extra token needed — the builtin `GITHUB_TOKEN` (`contents: write`,
already set in each workflow) covers creating the release and uploading
assets.

### Repo variables (Settings → Actions → Variables)

| Variable | What |
|---|---|
| `PILEUS_MYCELIUM_HOST` | a default Mycelium host baked into beta builds via `--dart-define` (useful for a TV with no other way to find the server on first launch). Read by `release.yml` and `linux.yml`/`windows.yml`. Leave unset for store builds. |
| `AMAZON_APP_ID` | the TV listing's app id (Console → your app → Additional information) — read by `release.yml`'s `amazon-submit` job. Not sensitive (visible in Console URLs), hence a variable, not a secret. |

> `release.yml` and `store.yml` both **fail** (`exit 1`) if
> `ANDROID_KEYSTORE_BASE64` is unset — neither ever publishes a
> debug-signed artifact. A local `flutter run --release` without a
> keystore still works.

Generate the keystore once and **back it up** — losing it means you can
never update an already-installed APK:

```sh
keytool -genkey -v -keystore pileus-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias pileus
```

Local signed builds: copy `android/key.properties.example` →
`android/key.properties`, put the `.jks` at `android/app/release.jks`
(both git-ignored).

## Keeping devices updated

### In-app notice (sideload distribution only)

Sideload release builds are compiled with
`--dart-define=PILEUS_GITHUB_REPO=<owner/repo>` (injected by CI from
`github.repository`). On the home screen the app then checks
`api.github.com`'s releases endpoint (rate-limited to once per 6 h) and
shows a one-shot dialog when a newer version is out. It only *notifies* —
no download, no install.

**Store builds must omit this define** (Play and Amazon auto-update, and
the dialog otherwise points users off-store). With it unset,
`UpdateConfig.isConfigured` is false and the check is a silent no-op.

To try it in a dev build (desktop, dev only):

```sh
flutter run -d linux --dart-define=PILEUS_GITHUB_REPO=Lotho33/pileus
```

### Android — Obtainium

`release.yml` builds **both** flavors as separate `applicationId`s, so
[Obtainium](https://github.com/ImranR98/Obtainium) needs **two separate app
entries**, one per flavor.

For each, **Add App**, source type **GitHub**, URL =
`https://github.com/Lotho33/pileus` (same repo both times), then set an
**APK filter** (regex) so each entry picks its own asset:

| Entry | APK filter (regex) |
|---|---|
| TV | `pileus-.*-android-(?!.*mobile).*\.apk` |
| Mobile | `pileus-.*-mobile-android-.*\.apk` |

Pick the ABI that matches the device (`arm64-v8a` for essentially all
modern Android TV boxes and current phones). Enable background updates for
near-silent updating.

### Linux — systemd timer (desktop only)

Copy `packaging/linux/` onto the device and adjust paths:

```sh
sudo cp packaging/linux/pileus-update.sh /usr/local/bin/
sudo cp packaging/linux/pileus-update.{service,timer} /etc/systemd/system/
sudo systemctl enable --now pileus-update.timer
```

The script polls the GitHub releases API hourly and unpacks the newest
tarball over the install dir when the tag changes.
