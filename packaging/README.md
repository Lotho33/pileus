# packaging/

Platform packaging for the desktop targets. The Android APK/AAB pipeline
lives in `.forgejo/workflows/{release,store}.yml`; see `../RELEASE.md`.

## windows/

`pileus.iss` — Inno Setup 6 script. Turns `build/windows/x64/runner/Release/`
into `pileus-<version>-windows-x64-setup.exe`.

```
flutter build windows --release -t lib/main_desktop.dart
iscc packaging\windows\pileus.iss /DAppVersion=1.2.3
```

Driven in CI by `.forgejo/workflows/windows.yml`, which also produces a
portable `.zip`. That workflow needs a **self-hosted Windows runner**
(label `windows`) with git + flutter + Inno Setup on PATH — none is
registered yet, so it is unvalidated.

## linux/

Desktop integration + Flatpak:

| File | State |
|---|---|
| `io.github.lotho33.Pileus.desktop` | ready |
| `io.github.lotho33.Pileus.metainfo.xml` | ready except **screenshots** (need real images at `docs/screenshots/`) |
| `io.github.lotho33.Pileus.yml` | **template** — see its header; not buildable as-is |
| `pileus-update.{sh,service,timer}` | existing systemd auto-update units (unrelated to Flatpak) |

### Flatpak / Flathub — remaining work

1. Rasterise `assets/branding/pileus_icon.svg` → `icon-256.png` (and the
   hicolor sizes) next to the manifest.
2. Fill the manifest placeholders: the released tarball URL + sha256, and a
   real **libmpv** module (the freedesktop runtime ships ffmpeg but not
   mpv; `media_kit` needs `libmpv.so`). Test playback in the sandbox.
3. `appstreamcli validate io.github.lotho33.Pileus.metainfo.xml` and
   `desktop-file-validate io.github.lotho33.Pileus.desktop` — both clean.
4. `flatpak-builder --user --install --force-clean build-dir io.github.lotho33.Pileus.yml`
   and smoke-test.
5. Optionally have `.forgejo/workflows/linux.yml` also emit a `.flatpak`
   bundle for direct download.
6. Only then: a source-built manifest + PR to `flathub/flathub`
   (Flathub prefers building from source; be ready to justify a prebuilt
   bundle or provide an offline pub cache).
