# Changelog

All notable changes to Pileus are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases before the first public release existed only as bare `vX.Y.Z` tags in
the private history and are not itemised here.

## [Unreleased]

### Added
- Public open-source release: `LICENSE` (GPL-3.0-only), `CONTRIBUTING.md`,
  `SECURITY.md`, issue / PR templates, `analyze` + `test` CI gate.

### Changed
- Repository hygiene pass: internal tooling and store-readiness notes removed
  from version control; iOS / macOS scaffold (unused) dropped; release script
  parameterised (no hard-coded instance URL).
- Large widget files split into `part` / `part of` folders for readability.
- Shared watch-progress logic extracted to `lib/shared/player/`.

### Fixed
- Web target compiles again (`media_kit` `NativePlayer` reference behind
  `kIsWeb` was still type-checked for the web build).

## [1.3.8] — 2026-09-22

### Fixed
- Further mobile player and Android TV source-handling fixes, including a
  fix for RPC responses that landed in cache but weren't reflected on
  screen for several seconds (the "needs a second tap" symptom reported on
  search / series / episode screens).

## [1.3.7] — 2026-09-21

### Fixed
- Assorted plugin-loading fixes.

## [1.3.6] — 2026-09-21

### Fixed
- Web app polish pass following the first web build.

## [1.3.5] — 2026-09-18

### Fixed
- Black poster/backdrop images on web: the real cause was CORS on the
  upstream plugin URL when a detail page skipped the `/img` proxy —
  `posterSrc()`/`backdropSrc()` now always route through the proxy on web.

## [1.3.4] — 2026-09-18

### Added
- Mobile player: "previous episode", next-episode prefetch at ~80%
  watched, and always-fresh metadata on every episode change.

### Fixed
- A `LateInitializationError` crash on the desktop/web (mpv) backend during
  load.
- AniSkip intro/outro markers that could fail to reach the client even when
  computed successfully server-side.
- Continue Watching poster not updating after progress, and a double-tap
  on mobile that could cancel the action it just triggered.

## [1.3.3] — 2026-09-17

### Added
- Continue Watching card on mobile, with the next episode playable
  directly from it.

### Fixed
- Mitigation for a loading-time freeze and for Android TV Surface issues.

## [1.3.2] — 2026-09-16

### Added
- Mobile player: next-episode navigation, seek gesture, Continue Watching
  without a minimum-progress threshold, and audio-track selection.

## [1.3.0] / [1.3.1] — 2026-09-14

### Fixed
- Further web and mobile player fixes.

## [1.2.8] / [1.2.9] — 2026-09-14

### Fixed
- Android and web fixes, guided by additional diagnostics.

## [1.2.6] / [1.2.7] — 2026-09-13

### Added
- First buildable web target.

### Fixed
- First round of fixes for an Android TV live-playback stall.

## [1.2.5] — 2026-09-11

### Changed
- CI consolidated onto a single public branch (`main`); the release
  pipeline now also builds the mobile flavor, not just `tv`.

## [1.2.3] — 2026-09-09

- Baseline for the public release. Android TV / Fire TV client for a
  self-hosted Mycelium backend, with mobile / desktop / web targets sharing
  the same core.

[Unreleased]: https://github.com/Lotho33/pileus/compare/v1.3.8...HEAD
[1.3.8]: https://github.com/Lotho33/pileus/releases/tag/v1.3.8
[1.3.7]: https://github.com/Lotho33/pileus/releases/tag/v1.3.7
[1.3.6]: https://github.com/Lotho33/pileus/releases/tag/v1.3.6
[1.3.5]: https://github.com/Lotho33/pileus/releases/tag/v1.3.5
[1.3.4]: https://github.com/Lotho33/pileus/releases/tag/v1.3.4
[1.3.3]: https://github.com/Lotho33/pileus/releases/tag/v1.3.3
[1.3.2]: https://github.com/Lotho33/pileus/releases/tag/v1.3.2
[1.3.1]: https://github.com/Lotho33/pileus/releases/tag/v1.3.1
[1.3.0]: https://github.com/Lotho33/pileus/releases/tag/v1.3.0
[1.2.9]: https://github.com/Lotho33/pileus/releases/tag/v1.2.9
[1.2.8]: https://github.com/Lotho33/pileus/releases/tag/v1.2.8
[1.2.7]: https://github.com/Lotho33/pileus/releases/tag/v1.2.7
[1.2.6]: https://github.com/Lotho33/pileus/releases/tag/v1.2.6
[1.2.5]: https://github.com/Lotho33/pileus/releases/tag/v1.2.5
[1.2.3]: https://github.com/Lotho33/pileus/releases/tag/v1.2.3
