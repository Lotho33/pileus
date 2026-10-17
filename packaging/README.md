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
| `io.github.lotho33.Pileus.yml` | tarball source auto-filled per release (see below) — **libmpv built from source and verified** (libass → ffmpeg → libdisplay-info/libXpresent/libplacebo → mpv → pileus, in that dependency order); smoke-tested with `flatpak-builder --run`, `media_kit_libs_linux registered.` confirms libmpv.so.2 actually resolves and loads in the sandbox |
| `pileus-update.{sh,service,timer}` | systemd auto-update units for a tarball install (unrelated to Flatpak) |

### Per-release: point the manifest at the new tarball

After `scripts/release.sh` (which also dispatches the `linux.yml` build —
see its own header) finishes and the tarball is attached to the GitHub
Release:

```sh
scripts/update-flatpak-manifest.sh <X.Y.Z>
```

Rewrites the manifest's `url`/`sha256` and the metainfo's `<release>` tag,
and runs `flatpak-builder` for you if it's installed. Commit the diff.

**Then, a second manual step** (unavoidable chicken-and-egg with the step
above): the `pileus` module's three small `type: file` sources
(`.desktop`/metainfo/icon) are fetched from this repo's own `main` branch
pinned to a commit, so the manifest builds from upstream sources only.
`metainfo.xml`'s content just changed (new `<release>` tag) by the step
above, so its sha256 changed too — but the new commit containing that
change doesn't exist on GitHub until *after* you push. So: push first,
then re-pin:

```sh
commit=$(git rev-parse HEAD)
for f in io.github.lotho33.Pileus.desktop io.github.lotho33.Pileus.metainfo.xml icon-256.png; do
  sha256sum "packaging/linux/$f"
done
```

and update the three `url`/`sha256` pairs in the `pileus` module by hand
(the commit hash is the same for all three; `.desktop`/icon rarely
actually change, only their hash *claim* needs touching when the commit
hash moves — but a stale one just fails the build loudly, so it's safe to
always refresh all three). Commit+push that as a tiny follow-up. A future
cleanup worth doing: have `linux.yml` copy these three files into the
release tarball itself alongside the binary, so this whole manual step
goes away — same single already-fetched archive source as the binary.

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
