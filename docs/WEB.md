# Pileus Web / PWA

Status: **spike / proof of concept.** The web target compiles and runs the
full responsive UI (shared with the desktop build), but it needs two
server-side pieces before it's usable end to end, and playback is
minimal. See "What's missing" below.

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

1. **gRPC-Web endpoint on Mycelium at `/grpc`.**
   Browsers can't speak HTTP/2 gRPC. Mycelium must expose gRPC-Web either
   natively (`improbable-eng/grpc-web` / connect-go) or behind Envoy /
   `grpcwebproxy` on the same origin. Until then every catalog/auth call
   fails in the browser. This is the single biggest item and it's
   **backend work**.

2. **Custom HTTP headers on the stream.** `<video>` can't send them, so a
   header-authenticated stream URL won't load. The resolver/proxy is
   expected to return a directly-playable URL (token in query string, or
   proxied). This is **backend work**.

HLS playback for non-Safari browsers **is wired**: `web/hls.min.js` is
bundled (no CDN, PWA-offline-safe) and attached when
`video.canPlayType('application/vnd.apple.mpegurl')` is empty; a natively
playable URL uses `src` directly.

## Done since the initial spike

- `web_playback_screen.dart` migrated off `dart:html` to `package:web` +
  `dart:js_interop`; `flutter build web` and the `--wasm` dry-run both pass.
- hls.js bundled and attached for non-native HLS (see above).
- Branded PWA icons rasterised from `assets/branding/pileus_icon.svg`
  (`web/icons/`, `favicon.png`).

## Nice-to-have / follow-ups

- Custom `<video>` chrome (currently the browser's native controls) +
  track selection.
- CSP / headers for the hosting setup; `--base-href` if not served at `/`.
- No LAN auto-discovery on web by design — the app is served *by* the
  server, so the origin is the server.
