# Contributing

Thanks for your interest in Pileus.

## Scope

Pileus is a **client** — Android TV/Fire TV, mobile, desktop and web
builds that talk to a self-hosted [Mycelium](https://github.com/Lotho33/mycelium)
server. It has no content sources of its own and is deliberately agnostic
about what plugins a Mycelium instance runs.

Please don't open PRs or issues that add, request, or discuss specific
third-party content services. Anything that knows about a specific site or
service belongs in a Mycelium plugin, not in this repo.

## Development

```bash
flutter pub get
flutter analyze          # must be clean
flutter test             # must pass
```

Entry points, one per target:

| Target | Entry point | Notes |
|---|---|---|
| Android TV / Fire TV | `lib/main.dart` | primary target, D-pad navigation |
| Mobile | `lib/main_mobile.dart` | touch UI |
| Desktop (Linux / Windows) | `lib/main_desktop.dart` | `media_kit` player backend |
| Web | `lib/main_web.dart` | desktop-styled UI, gRPC-Web |
| TV web (Samsung Tizen / LG webOS) | `lib/main_web_tv.dart` | D-pad UI over gRPC-Web, see `docs/TIZEN_WEBOS.md` |

Run e.g. `flutter run -t lib/main_desktop.dart -d linux`.

A Mycelium server reachable on the LAN (or a remote one over HTTPS) is
required for anything past the pairing screen — gRPC `:50051`, HTTP
`:8000`, LAN discovery `:51900/udp` (all centralised in
`lib/core/config/server_config.dart`).

## Pull requests

1. Branch from `main`.
2. Keep changes focused; unrelated cleanups go in their own PR.
3. `flutter analyze` **and** `flutter test` must pass — CI enforces both
   (`.github/workflows/ci.yml`).
4. Match the surrounding code: `flutter_lints` plus a few extra
   `prefer_const_*` rules (`analysis_options.yaml`), 2-space indent,
   trailing commas.
5. Large widget files are split with `part`/`part of` under a same-named
   folder — follow that pattern rather than growing a single file past a
   couple thousand lines.
6. Describe *what changed and why* in the PR body. Screenshots for UI
   changes (TV, mobile, desktop as relevant).

## Commit messages

Short imperative summary; body explaining *why* when it isn't obvious.

## Reporting bugs

Use the issue templates. For anything security-sensitive, see
[SECURITY.md](SECURITY.md) — do **not** open a public issue.

## License

Pileus is GPL-3.0-only (see `LICENSE`). By contributing you agree your work
is licensed under the same terms.
