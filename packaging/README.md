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
| `io.github.lotho33.Pileus.metainfo.xml` | ready except **screenshots** (need real images, published somewhere stable and referenced by URL — Flathub requires the image reachable at review time) |
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
pinned to a commit — Flathub's guidelines ask that these stay "integrated
in the upstream project" rather than duplicated into the submission PR.
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

### Flathub — one-time remaining work (not per-release)

1. ~~Fill in the **libmpv** module~~ — done (2026-10-03). Trimmed down from
   the public `io.mpv.Mpv` manifest to just what libmpv-the-library needs
   (not the CLI player, scripting, OCR, VapourSynth, DVD/Blu-ray, etc.):
   `libass` → `ffmpeg` (decode-only, no external encoder libs) →
   `libdisplay-info`/`libXpresent` (mpv's DRM/X11-vsync deps) →
   `libplacebo` (mpv 0.41+ made this a hard requirement, not optional) →
   `mpv` (`-Dlibmpv=true -Dcplayer=false`). Module order matters to
   flatpak-builder (strictly sequential) — libass/libdisplay-info/
   libXpresent/libplacebo must all precede whatever needs them.
   Also fixed a real bug in the **pileus** module itself found during this
   same pass: it was installing the binary to `/app/bin`, `data/` to
   `/app/share/pileus`, `lib/*.so` to `/app/lib/pileus` — three separate
   locations. Flutter's Linux embedder resolves `data/`/`lib/` as siblings
   of the executable's own directory, so that layout would have shipped an
   app that fails to find its own assets at launch. Fixed by keeping the
   whole bundle intact under `/app/lib/pileus/` with a thin exec wrapper
   at `/app/bin/pileus` (same pattern as how bundled Electron apps are
   usually packaged for Flatpak).
2. `appstreamcli validate io.github.lotho33.Pileus.metainfo.xml` and
   `desktop-file-validate io.github.lotho33.Pileus.desktop` — both clean
   except the screenshot URL (see #4) and a harmless multi-category hint;
   re-check after any edit.
3. ~~`flatpak-builder --user --install --force-clean build-dir io.github.lotho33.Pileus.yml`
   and smoke-test the installed app~~ — done. Built clean, and
   `flatpak-builder --run build-dir io.github.lotho33.Pileus.yml pileus`
   actually launches: GTK comes up, and the log shows
   `package:media_kit_libs_linux registered.` with no missing-library
   error — confirms `libmpv.so.2` genuinely resolves and loads in the
   sandbox, not just that the build compiles.
4. Real screenshots, referenced by a stable URL, in the metainfo — still
   open.
5. First-time submission: a PR to Flathub following
   [docs.flathub.org's submission guide](https://docs.flathub.org/docs/for-app-authors/submission).
   Flathub prefers building from source; be ready to justify this
   prebuilt-tarball approach for the `pileus` module itself (the libmpv
   stack now genuinely builds from source, same as Flathub expects — only
   the Flutter/Dart app binary is fetched prebuilt, since rebuilding
   Flutter itself inside the sandbox needs a whole separate offline-pub-
   cache setup, see the `flutpak` tool if that becomes a hard blocker in
   review). Once accepted, Flathub hosts its own copy of the manifest in a
   repo it manages — `scripts/update-flatpak-manifest.sh` keeps *this*
   repo's copy current, but an actual Flathub update still needs the
   matching change pushed to *that* repo (see Flathub's own maintainer
   docs for the exact flow — it's a normal git push, not a file dropped
   here).
