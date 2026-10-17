# packaging/

Platform packaging for the desktop and TV-web targets. The Android APK/AAB
pipeline lives in `.github/workflows/{release,store}.yml`; see
`../RELEASE.md`. Samsung Tizen / LG webOS packaging lives in `tizen/` and
`webos/`; see `../docs/TIZEN_WEBOS.md`.

## windows/

`pileus.iss` — Inno Setup 6 script. Turns `build/windows/x64/runner/Release/`
into `pileus-<version>-windows-x64-setup.exe`.

```
flutter build windows --release -t lib/main_desktop.dart
iscc packaging\windows\pileus.iss /DAppVersion=1.2.3
```

Driven in CI by `.github/workflows/windows.yml` (GitHub-hosted
`windows-latest` runner), which also produces a portable `.zip`.

## linux/

Desktop integration + Flatpak:

| File | State |
|---|---|
| `io.github.lotho33.Pileus.desktop` | ready |
| `io.github.lotho33.Pileus.metainfo.xml` | ready except **screenshots** (real images referenced by a stable URL — app stores read them from there) |
| `icon-256.png` | ready — rasterised from `web/icons/Icon-512.png` |
| `io.github.lotho33.Pileus.yml` | tarball source swapped in per release by `flatpak.yml` (see below) — **libmpv built from source and verified** (libass → ffmpeg → libdisplay-info/libXpresent/libplacebo → mpv → pileus, in that dependency order); smoke-tested with `flatpak-builder --run`, `media_kit_libs_linux registered.` confirms libmpv.so.2 actually resolves and loads in the sandbox |
| `pileus-update.{sh,service,timer}` | systemd auto-update units for a tarball install (unrelated to Flatpak) |

### Self-hosted Flatpak repo

Published at **https://lotho33.github.io/pileus/flatpak/** — install
instructions for users in `docs/LINUX.md`. Per release, nothing to do by
hand: `scripts/release.sh` dispatches `linux.yml`, which chains
`.github/workflows/flatpak.yml`:

1. downloads the tag's `pileus-<ver>-linux-x64.tar.gz` and swaps it into
   the manifest as a local `path:` source (plus the metainfo `<release>`);
2. builds with `flatpak-builder` (libmpv modules cached between runs) into
   an OSTree repo on branch `stable`, GPG-signed;
3. attaches `pileus-<ver>-linux-x64.flatpak` (single-file bundle) and
   `flatpak-repo.tar.gz` to the GitHub Release;
4. runs `pages.yml`, which deploys `docs/` (Jekyll, as before) plus the
   newest `flatpak-repo.tar.gz` under `/flatpak/repo/` and the files in
   `linux/flatpak/` (`pileus.flatpakrepo`, the `.flatpakref`, the public
   key). Pages source must be set to "GitHub Actions".

The repo keeps only the latest build; clients update without the older
commit.

**Signing key**: RSA 4096, fingerprint
`AD5C6DA0755AEEFA6A69E1B8BCFBA0FFC89C0C4B`, private half in the
`FLATPAK_GPG_PRIVATE_KEY` secret (and backed up outside GitHub). The public
half is `linux/flatpak/pileus-flatpak.gpg` and the base64 `GPGKey=` line of
both `.flatpak*` files — replacing the key means every installed client
has to re-add the remote.

Local build (no publishing): `scripts/update-flatpak-manifest.sh <X.Y.Z>`
points the manifest at a released tarball, then
`flatpak-builder --user --install --force-clean build-dir
linux/io.github.lotho33.Pileus.yml`.

### Not on Flathub

Since May 2026 Flathub's policy rejects apps and submissions made with
generative AI (code, manifest, metadata, the PR itself), with repeat
violations risking a permanent ban — Pileus is developed with an AI
assistant, so it doesn't qualify. The one submission (flathub/flathub#10492,
2026-10-03) was auto-closed and labelled "AI Slop". Don't resubmit.

The manifest stays: it builds and runs (below), and is the base for a
self-hosted Flatpak distribution instead.

### Flatpak build notes

1. The **libmpv** module is trimmed down from the public `io.mpv.Mpv`
   manifest to just what libmpv-the-library needs (not the CLI player,
   scripting, OCR, VapourSynth, DVD/Blu-ray, etc.): `libass` → `ffmpeg`
   (decode-only, no external encoder libs) → `libdisplay-info`/
   `libXpresent` (mpv's DRM/X11-vsync deps) → `libplacebo` (mpv 0.41+ made
   this a hard requirement) → `mpv` (`-Dlibmpv=true -Dcplayer=false`).
   Module order matters to flatpak-builder (strictly sequential).
   The **pileus** module keeps the whole Flutter bundle intact under
   `/app/lib/pileus/` with a thin exec wrapper at `/app/bin/pileus`:
   Flutter's Linux embedder resolves `data/`/`lib/` as siblings of the
   executable, so splitting them across `/app/bin`, `/app/share`, `/app/lib`
   ships an app that can't find its own assets.
2. `appstreamcli validate io.github.lotho33.Pileus.metainfo.xml` and
   `desktop-file-validate io.github.lotho33.Pileus.desktop` — clean except
   the screenshot URL and a harmless multi-category hint.
3. Verified (2026-10-03): `flatpak-builder --user --install --force-clean
   build-dir io.github.lotho33.Pileus.yml` builds clean, and
   `flatpak-builder --run build-dir io.github.lotho33.Pileus.yml pileus`
   launches with `package:media_kit_libs_linux registered.` — libmpv.so.2
   resolves and loads in the sandbox.
