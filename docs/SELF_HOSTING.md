# Self-hosting

Pileus is only a **client**. It needs a **Mycelium** server that you run
yourself; there is no hosted/public instance and no built-in content.

> The Mycelium server is a separate project and is **not public yet**. This
> page describes what the client expects from it so the contract is clear;
> it will link to the server's own setup guide once that is available.

## What the client needs from the server

On the LAN (or reachable over VPN), same network as the device:

| Port | Proto | Used for |
|---|---|---|
| `50051` | TCP (gRPC / HTTP-2) | `AuthService`, `MediaPipeline`, `PluginService` |
| `8000` | TCP (HTTP) | `/pileus/info` (capabilities + TLS fingerprint), image proxy `/img`, `/plugin-icon/<id>`, HLS segment proxy |
| `51900` | UDP | discovery — the server answers `MYCELIUM_DISCOVER_V1` broadcasts |

For the **web** target the server must additionally expose a **gRPC-Web**
endpoint at `<origin>/grpc` and serve the built `build/web/` bundle from the
same origin. See [`WEB.md`](WEB.md).

## First run

1. **Discovery** — automatic (UDP broadcast + parallel TCP probe), or type
   the server IP manually.
2. **Pairing** — enter a short-lived **pairing code** generated from the
   Mycelium admin dashboard (not a password).
3. **Profile** — pick or create one. Profiles are server-wide and follow you
   across every paired device.

## Backend plugins

The publicly supported content sources are **Jellyfin** and **Plex**, added
as Mycelium plugins. The client is plugin-agnostic: catalog rows, search
filters, per-plugin settings and icons all come from the server
(`GetPluginSettings`, `GetSearchFilters`, `GET /plugin-icon/<id>`), so no
plugin is named or bundled in the app binary.

## TLS

If the server terminates TLS with a self-signed certificate, the client
pins its SHA-256 fingerprint on first contact (trust-on-first-use, from
`/pileus/info`). A plain-HTTP server on the LAN is the common case and is
allowed by the Android network security config.
