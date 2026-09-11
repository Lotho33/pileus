# Releasing Pileus

Builds are published as **GitHub releases** on `github.com/Lotho33/pileus`:
the **Android APKs (per ABI)** are produced automatically by
`.github/workflows/release.yml` on every `vX.Y.Z` tag. Android TV / Fire TV
is the shipping target.

> Migration note: `release.yml` (this pipeline) and `ci.yml` are on GitHub
> Actions, and there's a single `main` branch now (no more `dev` — the repo
> is entirely public, the old private-dev/public-main split doesn't protect
> anything anymore). `store.yml` / `linux.yml` / `web.yml` / `windows.yml`
> are **still on Forgejo** (`.forgejo/workflows/`), pending a follow-up
> port — the Forgejo repo stays around for those until then.

The **Linux x64** tarball (`linux.yml`) and the **web / PWA** bundle
(`web.yml`) are separate **manual** conveniences — `workflow_dispatch` only,
run by hand with the tag as input, each attaching one tarball to the
existing release. Both build the responsive `-t lib/main_desktop.dart` /
`-t lib/main_web.dart` UI (not the D-pad TV shell). Neither is part of the
tag pipeline. The web bundle is a **spike** and needs a gRPC-Web endpoint on
Mycelium — see `docs/WEB.md`.

## Cutting a release

Use the helper: `scripts/release.sh <X.Y.Z>` bumps `version:` in
`pubspec.yaml`, commits, tags `vX.Y.Z`, and pushes branch + tag to the
`origin` remote (the script refuses to run unless you are on `main`).

Manually, the equivalent is:

1. Bump `version:` in `pubspec.yaml` (e.g. `1.4.0+0` — the `+build` is
   overwritten by CI with the pipeline run number, so only the `1.4.0` part
   matters here).
2. Commit, then tag and push:

   ```sh
   git tag v1.4.0
   git push origin main --tags
   ```

3. The `release` workflow builds and attaches the APKs to the `v1.4.0`
   GitHub release. Mark it **pre-release** there for beta builds — the
   in-app check and Obtainium both still pick it up.

Per-release effort after the one-time setup: ~1 minute.

## Store build (Play Store / Amazon Appstore)

Separate from the beta channel above. Run **`store` workflow** by hand
(Actions → store → Run) with the tag as input. It builds the **`tv` flavor**
(`applicationId com.lotho33.pileus`) and produces, from the tagged commit:

- a **signed AAB** (`flutter build appbundle --flavor tv`) — upload to the Play Console
- **signed per-ABI APKs** (`--split-per-abi`, arm/arm64) — upload to the
  Amazon Developer console
- an obfuscation-symbols tarball + R8 `mapping.txt` — upload to the Play
  Console for readable crash/ANR stacks

Differences from `release.yml` baked into `store.yml`:

- `--dart-define=PILEUS_STORE_BUILD=true` — the in-app update check and the
  Obtainium/sideload dialog are compiled out (`UpdateConfig.storeBuild`), and
  no personal GitHub/Mycelium host is embedded (`PILEUS_GITHUB_REPO` /
  `PILEUS_MYCELIUM_HOST` are **not** passed)
- `-PpileusRequireSigning=true` — the build fails if signing isn't
  configured, instead of falling back to debug keys
- `--obfuscate --split-debug-info`

Artifacts are pushed to the repo's **private Forgejo generic package
registry** (`<forgejo>/<owner>/-/packages/generic/pileus-store/<version>`),
not to the public release. Download from there and upload to the two
consoles by hand.

Console-side work that is **not** automatable, tracked outside the public
repo: privacy policy URL, Play Data Safety + IARC rating, Play App Signing
enrolment, the Foreground Service declaration, TV screenshots / reviewer
notes, and a reachable demo Mycelium server for review.

### Mobile flavor

The phone/tablet app is the same repo, `--flavor mobile -t lib/main_mobile.dart`
(`applicationId com.lotho33.pileus.mobile`), a **separate store listing**. The
`store` workflow builds it alongside `tv` (see store.yml).

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
  bad strip only surfaces at runtime) — a `--flavor mobile` build must pass
  a real playback + gRPC + subtitle-SVG smoke test on a device before it
  ships. Neither flag affects the `tv` builds.

Result: arm64 mobile release APK ≈ **23.5 MB** (vs ~36 MB unoptimised).

## One-time setup

### CI runner

`release.yml` and `ci.yml` run on GitHub-hosted `ubuntu-latest` — nothing to
register, free on this public repo. (`store.yml` / `linux.yml` / `web.yml` /
`windows.yml`, still on Forgejo, keep needing a self-hosted runner there
until ported — see the migration note above.)

### Repo secrets  (GitHub → Settings → Secrets and variables → Actions)

| Secret | What |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 pileus-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `pileus`) |
| `ANDROID_KEY_PASSWORD` | key password |

No `RELEASE_TOKEN` needed on GitHub — the builtin `GITHUB_TOKEN` (with
`contents: write`, already set in the workflow) covers creating the release
and uploading the APK assets.

### Repo variables  (Settings → Actions → Variables)

| Variable | What |
|---|---|
| `PILEUS_MYCELIUM_HOST` | default Mycelium host baked into release builds via `--dart-define` (for TVs where `mycelium.local` won't resolve). Read by both `release.yml` and `linux.yml`. Leave unset for store builds. |

> Both `release.yml` and `store.yml` now **fail** (`exit 1`) if
> `ANDROID_KEYSTORE_BASE64` is unset — they never publish a debug-signed
> artifact. A local `flutter run --release` without a keystore still works.

Generate the keystore once and **back it up** — losing it means you can
never update an already-installed APK:

```sh
keytool -genkey -v -keystore pileus-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias pileus
```

Local signed builds: copy `android/key.properties.example` →
`android/key.properties`, put the `.jks` at `android/app/release.jks`.

## Keeping devices updated

### In-app notice (sideload distribution only)

Sideload release builds are compiled with
`--dart-define=PILEUS_GITHUB_REPO=<owner/repo>` (injected by CI from
`github.repository`). On the home screen the app then checks
`api.github.com`'s releases endpoint (rate-limited to once per 6 h) and
shows a one-shot dialog when a newer version is out. It only *notifies* — no
download, no install. `pileus` is a public repo, so this needs no token.

**Store builds must omit this define** (Play and Amazon auto-update, and the
dialog otherwise points users off-store). With it unset,
`UpdateConfig.isConfigured` is false and the check is a silent no-op.

To try it in a dev build (desktop, dev only):

```sh
flutter run -d linux --dart-define=PILEUS_GITHUB_REPO=Lotho33/pileus
```

### Android — Obtainium

Install [Obtainium](https://github.com/ImranR98/Obtainium) on each beta
phone, **Add App**, source type **GitHub**, URL =
`https://github.com/Lotho33/pileus`. It tracks the APK assets and installs
new releases (enable background updates for near-silent updating). Pick the
ABI that matches the device (`arm64-v8a` for essentially all modern Android
TV boxes). Public repo, so no PAT to configure in Obtainium either.

### Linux — systemd timer  (desktop only, out of scope for the TV product)

Copy `packaging/linux/` onto the device and adjust paths:

```sh
sudo cp packaging/linux/pileus-update.sh /usr/local/bin/
sudo cp packaging/linux/pileus-update.{service,timer} /etc/systemd/system/
sudo systemctl enable --now pileus-update.timer
```

The script polls the releases API hourly, and unpacks the newest tarball
over the install dir when the tag changes.
