# Contributing to Pileus

Thanks for your interest. Pileus is a Flutter client (Android TV / Fire TV
first, with mobile / desktop / web targets sharing the same core) for a
self-hosted **Mycelium** streaming backend.

## Ground rules

- **License.** Pileus is GPL-3.0-only (see `LICENSE`). By submitting a
  contribution you agree to license it under the same terms.
- **Scope.** This repo is a *bring-your-own-server client*. The publicly
  supported backend plugins are Jellyfin and Plex. Please don't send patches
  that hard-code, bundle, or specifically target other content sources.
- **Be civil.** Assume good faith, keep discussion technical.

## Development setup

The project is built and tested inside a Flutter devcontainer; you don't
need Flutter on the host.

```bash
flutter pub get
flutter analyze          # must be clean
flutter test             # must pass
```

Entry points, one per target:

| Target          | Entry point            | Notes                                  |
|-----------------|------------------------|----------------------------------------|
| Android TV / Fire TV | `lib/main.dart`   | primary target, D-pad navigation       |
| Mobile          | `lib/main_mobile.dart` | touch UI                              |
| Desktop (Linux / Windows) | `lib/main_desktop.dart` | `media_kit` player backend  |
| Web (PWA spike) | `lib/main_web.dart`    | reuses the desktop UI; needs a gRPC-Web endpoint on the server |

Run e.g. `flutter run -t lib/main_desktop.dart -d linux`.

A Mycelium server reachable on the LAN (or via VPN) is required for anything
past the pairing screen — gRPC `:50051`, HTTP `:8000`, discovery `:51900/udp`
(centralised in `lib/core/config/server_config.dart`).

## Pull requests

1. Branch from `dev` (not `main`).
2. Keep the change focused; unrelated cleanups go in their own PR.
3. `flutter analyze` **and** `flutter test` must pass — CI enforces both
   (`.github/workflows/ci.yml`).
4. Match the surrounding code: the codebase uses `flutter_lints` plus a few
   extra `prefer_const_*` rules (`analysis_options.yaml`), 2-space indent,
   trailing commas, and short `// ──` section banners in large files.
5. Large widget files are split with `part` / `part of` under a same-named
   folder — follow that pattern rather than growing a single file past
   ~1.5k lines.
6. Describe *what changed and why* in the PR body. Screenshots for UI
   changes (TV, mobile, desktop as relevant).

## Reporting bugs

Use the issue templates. For anything security-sensitive, see
[`SECURITY.md`](SECURITY.md) — do **not** open a public issue.
