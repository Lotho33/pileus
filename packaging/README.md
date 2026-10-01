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
| `io.github.lotho33.Pileus.yml` | tarball source auto-filled per release (see below) — the **libmpv module is still a stub**, see its header |
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

### Flathub — one-time remaining work (not per-release)

1. Fill in the **libmpv** module (the freedesktop runtime ships ffmpeg but
   not mpv; `media_kit` needs `libmpv.so`) — a real meson-based build of
   mpv from its own source release, with a pinned version + sha256 you
   compute yourself (`sha256sum` the tarball you download — don't trust a
   hash from anywhere else). The public `io.mpv.Mpv` Flathub manifest is
   the reference pattern for the dependency list and build flags; adapt it
   rather than guessing. Test actual playback in the sandbox afterward —
   a wrong build flag here fails silently until you press play.
2. `appstreamcli validate io.github.lotho33.Pileus.metainfo.xml` and
   `desktop-file-validate io.github.lotho33.Pileus.desktop` — both should
   already be clean; re-check after any edit.
3. `flatpak-builder --user --install --force-clean build-dir io.github.lotho33.Pileus.yml`
   and smoke-test the installed app.
4. Real screenshots, referenced by a stable URL, in the metainfo.
5. First-time submission: a PR to Flathub following
   [docs.flathub.org's submission guide](https://docs.flathub.org/docs/for-app-authors/submission).
   Flathub prefers building from source; be ready to justify this
   prebuilt-tarball approach or provide an offline pub cache instead. Once
   accepted, Flathub hosts its own copy of the manifest in a repo it
   manages — `scripts/update-flatpak-manifest.sh` keeps *this* repo's copy
   current, but an actual Flathub update still needs the matching change
   pushed to *that* repo (see Flathub's own maintainer docs for the exact
   flow — it's a normal git push, not a file dropped here).
