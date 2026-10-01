# Pileus

**Pileus** is a Flutter client for a self-hosted [Mycelium](https://github.com/Lotho33/mycelium)
media-server backend. One codebase, five targets:

| Target | Entry point | Notes |
|---|---|---|
| **Android TV / Fire TV** | `lib/main.dart` | primary target — D-pad/remote navigation |
| **Mobile** (phone / tablet) | `lib/main_mobile.dart` | touch UI |
| **Desktop** (Linux / Windows) | `lib/main_desktop.dart` | `media_kit` player backend |
| **Web** | `lib/main_web.dart` | desktop-styled UI, gRPC-Web — see [`docs/WEB.md`](docs/WEB.md) |
| **TV web** (Samsung Tizen / LG webOS) | `lib/main_web_tv.dart` | D-pad UI packaged as a smart-TV app — see [`docs/TIZEN_WEBOS.md`](docs/TIZEN_WEBOS.md) |

The core (DI, gRPC/proto, repositories, BLoC, player engine, server-driven
UI) is shared; only the presentation layer differs per target.

### What Pileus is not

- **Not a content service.** Pileus ships with no content sources of its
  own. What it can browse and play is entirely defined by the Mycelium
  server (and its plugins) you point it at.
- **Not standalone.** It needs a Mycelium server to talk to — see
  [Lotho33/mycelium](https://github.com/Lotho33/mycelium) for the backend.

> **Language:** the interface is Italian-only for now. Localization
> (`intl` + `.arb` files) is a future milestone; no string is externalized
> yet.

Architecture overview in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md);
build/run/package matrix per target in [`docs/BUILD.md`](docs/BUILD.md).

---

## Requirements

- A device for whichever target you're building: an Android TV/Fire TV box,
  a phone/tablet, a Linux/Windows desktop, or a browser.
- A **Mycelium** server you run yourself, reachable either on the LAN or
  remotely over HTTPS:
  - gRPC `:50051/tcp`
  - HTTP `:8000/tcp` (`/pileus/info`, image proxy `/img`, segment proxy)
  - LAN discovery `:51900/udp` (skipped entirely for a remote/HTTPS server)

Ports are centralised in `lib/core/config/server_config.dart`
(`ServerPorts`).

---

## First launch

1. **Server discovery** — automatic on the LAN (UDP broadcast + a TCP probe
   of a few candidate hosts), or manual: type an IP (LAN) or a domain/
   `https://` URL (remote server, standard CA-validated TLS — see
   `lib/core/grpc/server_address.dart`). The resolved host is saved for
   next launch.
2. **Device pairing** — a short-lived pairing code generated from the
   Mycelium admin dashboard (not a password).
3. **Profile** — pick or create one. Profiles are server-wide: they follow
   the person across every paired device.
4. **Home** — catalog rows driven by the server's plugins, search,
   Continue Watching.

The session JWT lives **in memory only** — every cold start re-resolves
and re-authenticates before mounting any protected screen (see
`lib/core/router/app_router.dart`'s guard).

---

## Architecture

### Module map (`lib/`)

```
core/      config · db · di · grpc · router · theme · update · utils
features/  auth · media · player · settings
           (each: bloc|cubit / data (repository) / presentation)
shared/    sdui · widgets · utils · presentation
```

### State & dependency injection

`flutter_bloc` + `get_it` (`lib/core/di/injection.dart`). `AuthBloc` is a
singleton shared across every screen; `PluginBloc`/`ContinueWatchingBloc`
are lazy singletons reset on logout; everything else is a factory.

### Transport (gRPC + proto)

Services: `AuthService`, `MediaPipeline`, `PluginService`
(`proto/auth.proto`, `proto/media.proto`). `AuthInterceptor` injects the
JWT, profile id and the host mycelium needs to build proxy URLs. The gRPC
channel's TLS: a LAN server's self-signed certificate is pinned by
SHA-256 fingerprint on first contact; a remote server (an explicit domain
or `https://` address) uses standard system CA validation instead — see
`lib/core/grpc/server_address.dart`.

### Server-driven UI

`lib/shared/sdui/` turns the server's catalog definitions into card
carousels, with forward-compatible handling of unrecognized layout hints
(never crash on a value this client doesn't know yet).

### Player — dual backend

A neutral facade (`lib/features/player/engine/player_engine.dart`) — every
screen talks only to `PlayerEngine`, never to a backend type directly.

| Platform | Backend |
|---|---|
| **Android** (TV + mobile) | ExoPlayer via `better_player_plus` |
| **Desktop** (Linux / Windows) | libmpv via `media_kit` |
| **Web** | HTML5 `<video>` (+ hls.js for non-native HLS) |

### Performance profile

- `lib/core/perf_profile.dart` — a "low-power UI" mode that sheds blur/
  shader work on weak hardware.
- `lib/core/device_profile.dart` — native detection of TV vs. phone/tablet
  and weak-hardware hints on Android.
- Image cache sizing and network-image downscaling in
  `lib/core/utils/image_sizing.dart`.

---

## Playback flow

```
discovery → pairing → profile
  → GetCatalog → GetDetails → GetStreams
  → ResolveStream (server-streaming: progress… → resolved_url + headers)
  → PlayerEngine.open()
```

---

## Android permissions

The full, minimal set the Android TV/mobile builds request, and why:

| Permission | Why |
|---|---|
| `INTERNET` | every call to your Mycelium server — gRPC, HTTP, LAN discovery |
| `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE` | LAN server discovery (UDP broadcast) and basic connectivity awareness |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | keeps video/audio playing when the app is backgrounded, with the standard Android media-playback notification |
| `WAKE_LOCK` | keeps the screen/CPU awake during active playback |

No storage, camera, microphone, contacts, location, or SMS permission is
requested. `android/app/src/main/AndroidManifest.xml` explicitly strips
`RECEIVE_BOOT_COMPLETED`, which a transitive player dependency declares but
Pileus has no use for (no scheduled work or alarm needs to survive a
reboot). See [`docs/PRIVACY.md`](docs/PRIVACY.md) for the privacy policy.

---

## Development

```bash
flutter pub get
flutter analyze   # must be clean
flutter test      # must pass
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development/PR
workflow.

## Release

See [RELEASE.md](RELEASE.md).

## License

**GPL-3.0-only** — see [LICENSE](LICENSE). `pubspec.yaml` has
`publish_to: 'none'` (this isn't a pub package).

The bundled font (DM Sans, `assets/fonts/DMSans/`) is under the SIL Open
Font License 1.1 — see `assets/fonts/DMSans/OFL.txt`.
