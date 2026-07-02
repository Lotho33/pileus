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

## [1.2.3] — 2026-09-09

- Baseline for the public release. Android TV / Fire TV client for a
  self-hosted Mycelium backend, with mobile / desktop / web targets sharing
  the same core.

[Unreleased]: https://github.com/lotho33/pileus-player/compare/v1.2.3...HEAD
[1.2.3]: https://github.com/lotho33/pileus-player/releases/tag/v1.2.3
