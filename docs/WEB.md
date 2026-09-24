# Pileus Web / PWA

Status: **client-side ready, one known server-dependent gap left.** The web
target compiles and runs the full responsive UI (shared with the desktop
build); the gRPC-Web transport that used to be the single biggest blocker
here is implemented client-side (see "Done since the initial spike") and a
web build has shipped successfully alongside every release since v1.2.6 —
but that only proves the client compiles and serves, not that a given
Mycelium deployment actually exposes gRPC-Web at `/grpc` (that's server
config, verify it against your own instance). The one gap that's still
open on **either** side is custom HTTP headers on the `<video>` stream — see
"What's missing" below.

## Build & run

```sh
# dev
flutter run  -d chrome        -t lib/main_web.dart

# production bundle  -> build/web/
flutter build web             -t lib/main_web.dart --release --base-href /
```

Serve `build/web/` from the same origin as (or a reverse proxy in front of)
Mycelium — the app talks gRPC-Web to `<origin>/grpc` and hits
`<origin>/pileus/info`, `<origin>/plugin-icon/<id>`, `<origin>/img` for
REST/assets. `flutter_service_worker.js` is emitted for offline-shell / PWA
install.

## How it fits together

| Piece | Web |
|---|---|
| UI | `lib/web/` + the shared `lib/desktop/` screens (responsive, point-and-click) |
| Entry point | `lib/main_web.dart` → `PileusWebApp` → `webRouter` |
| Transport | **gRPC-Web** — `lib/core/grpc/grpc_channel_web.dart` builds `GrpcWebClientChannel.xhr(<origin>/grpc)` (selected automatically via the `dart.library.html` conditional export in `grpc_channel.dart`) |
| Host resolution | `lib/core/grpc/host_resolver.dart` returns the page origin's host; the `dart:io` LAN probe / UDP discovery live behind `host_resolver_io.dart` / `host_resolver_stub.dart` so web links only the stub |
| Discovery screen | `lib/web/web_discovery_screen.dart` — auto-confirms the origin via `/pileus/info`, with a manual host override |
| Pairing / profiles / splash / settings | reused from `lib/desktop/` unchanged |
| Player | `lib/web/web_playback_screen.dart` — a plain HTML5 `<video>` in an `HtmlElementView` |

`PlaybackBloc` (stream fetch + `ResolveStream`) is reused as-is — it's pure
gRPC, no engine.

## What's missing (blocks "usable")

1. **Custom HTTP headers on the stream.** `<video>`/hls.js can't send them,
   so a header-authenticated stream URL won't load — `web_playback_screen.dart`
   assigns the resolved URL straight to `_video.src`/`hls.loadSource(url)`
   with no token-in-query-string or similar workaround yet. The
   resolver/proxy needs to return a directly-playable URL instead. This is
   **backend work** (possibly with a small client-side follow-up once the
   URL shape is known).

Previously listed here as blocker #1 — **resolved client-side, verify your
server**: a gRPC-Web endpoint on Mycelium at `/grpc`. Browsers can't speak
HTTP/2 gRPC natively; `lib/core/grpc/grpc_channel_web.dart` builds a
`GrpcWebClientChannel.xhr('<origin>/grpc/')` (with a documented workaround
for a `grpc` package 5.1.0 quirk where the method path bypasses that
prefix — Mycelium needs to route `/mycelium.*` at the origin root, or
rewrite). The client is ready; whether *your* Mycelium deployment actually
exposes that endpoint is a server-side question this doc can't answer.

HLS playback for non-Safari browsers **is wired**: `web/hls.min.js` is
bundled (no CDN, PWA-offline-safe) and attached when
`video.canPlayType('application/vnd.apple.mpegurl')` is empty; a natively
playable URL uses `src` directly.

## Done since the initial spike

- `web_playback_screen.dart` migrated off `dart:html` to `package:web` +
  `dart:js_interop`; `flutter build web` and the `--wasm` dry-run both pass
  (dry-run only — no CI pipeline actually builds with `--wasm` yet, so it's
  wasm-*ready*, not wasm-*shipped*).
- hls.js bundled and attached for non-native HLS (see above).
- Branded PWA icons rasterised from `assets/branding/pileus_icon.svg`
  (`web/icons/`, `favicon.png`).
- gRPC-Web client transport implemented (see above) — every release since
  v1.2.6 has published a web build via CI.
- Black poster/backdrop images on web (a CORS issue when a page skipped the
  `/img` proxy) fixed in v1.3.5 — `posterSrc()`/`backdropSrc()` now always
  route through the proxy on web regardless of what the caller asks for.

## Nice-to-have / follow-ups

- Custom `<video>` chrome (currently the browser's native controls) +
  track selection.
- CSP / headers for the hosting setup; `--base-href` if not served at `/`.
- No LAN auto-discovery on web by design — the app is served *by* the
  server, so the origin is the server.
