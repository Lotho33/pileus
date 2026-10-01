# Build / run / package — per target

`flutter analyze` (0 issues) and `flutter test` must pass before a merge —
CI enforces both (`.github/workflows/ci.yml`).

## Matrix

| Target | Run (dev) | Package | CI workflow |
|---|---|---|---|
| **Android TV / Fire TV** | `flutter run --flavor tv` | `flutter build apk --release --flavor tv --split-per-abi --target-platform android-arm,android-arm64` | `release.yml` (on tag `vX.Y.Z`) · `store.yml` (signed AAB, manual) |
| **Mobile** | `flutter run --flavor mobile -t lib/main_mobile.dart` | `flutter build appbundle --release --flavor mobile -t lib/main_mobile.dart` | `store.yml` (alongside `tv`) |
| **Desktop — Linux** | `flutter run -d linux -t lib/main_desktop.dart` | `flutter build linux --release -t lib/main_desktop.dart` | `linux.yml` (manual, attaches a tarball to the release) |
| **Desktop — Windows** | `flutter run -d windows -t lib/main_desktop.dart` | `flutter build windows --release -t lib/main_desktop.dart` | `windows.yml` (manual, GitHub-hosted runner) |
| **Web** | `flutter run -d chrome -t lib/main_web.dart` | `flutter build web --release -t lib/main_web.dart --base-href /` | `release.yml` builds and attaches the web tarball on every tag |
| **TV web** (Tizen/webOS) | `flutter run -d chrome -t lib/main_web_tv.dart` | `flutter build web --release -t lib/main_web_tv.dart --base-href /` | manual packaging, see [`TIZEN_WEBOS.md`](TIZEN_WEBOS.md) |

## Android build flags (`tv` and `mobile` flavors)

Off by default (a mis-strip only shows at runtime), **on in CI** for every
Android channel:

| Gradle flag | Effect |
|---|---|
| `-PpileusExcludeMpv=true` | strips `libmpv.so` + helpers (~12 MB/ABI) — Android always uses ExoPlayer, `_MpvPlayerEngine` throws if constructed |
| `-PpileusR8=true` | R8 code shrink + `shrinkResources` (`android/app/proguard-rules.pro`) |
| `-PpileusRequireSigning=true` | the build fails instead of falling back to debug signing if `android/key.properties` is missing (store pipeline) |

Dart obfuscation (`--obfuscate --split-debug-info`) is on in every CI
workflow; symbols + R8's `mapping.txt` are archived with the release for
de-obfuscating crashes.

## Build-time `--dart-define`s

| Define | Use |
|---|---|
| `PILEUS_GITHUB_REPO` | `owner/repo` on github.com for the in-app "update available" check |
| `PILEUS_MYCELIUM_HOST` | a default Mycelium host baked into the binary (useful for a TV with no other way to find the server on first launch) |
| `PILEUS_STORE_BUILD=true` | disables the update check entirely — the build the store pipeline produces |

At runtime, the `MYCELIUM_HOST` environment variable is read as an
override on native platforms.

> Store builds (`store.yml`) always pass `PILEUS_STORE_BUILD=true` and omit
> `PILEUS_GITHUB_REPO`/`PILEUS_MYCELIUM_HOST` — the binary never contacts
> or bakes in any particular host or repo.

## Further reading

- Release process (tags, signing, store builds): [`../RELEASE.md`](../RELEASE.md)
- Web target specifics: [`WEB.md`](WEB.md)
- Samsung Tizen / LG webOS packaging: [`TIZEN_WEBOS.md`](TIZEN_WEBOS.md)
- Shared core architecture: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Self-hosting the backend: [`SELF_HOSTING.md`](SELF_HOSTING.md)
