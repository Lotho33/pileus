# Self-hosting

Pileus is only a **client**. It needs a **Mycelium** server that you run
yourself — see [Lotho33/mycelium](https://github.com/Lotho33/mycelium) for
the server and its own setup guide. There is no hosted/public instance and
Pileus ships with no content of its own.

## What the client needs from the server

On the LAN, same network as the device:

| Port | Proto | Used for |
|---|---|---|
| `50051` | TCP (gRPC / HTTP-2) | `AuthService`, `MediaPipeline`, `PluginService` |
| `8000` | TCP (HTTP) | `/pileus/info` (capabilities + TLS fingerprint), image proxy `/img`, `/plugin-icon/<id>`, HLS segment proxy |
| `51900` | UDP | discovery — the server answers `MYCELIUM_DISCOVER_V1` broadcasts |

A server published on the public internet (a domain or `https://` address)
works too — see "Remote servers" below; it needs none of the LAN-only ports
or discovery, just a single HTTPS port reachable from the client.

For the **web** target the server must additionally expose a **gRPC-Web**
endpoint at `<origin>/grpc` and serve the built `build/web/` bundle from the
same origin. See [`WEB.md`](WEB.md).

## First run

1. **Discovery** — automatic on the LAN (UDP broadcast + a TCP probe), or
   type the address manually: an IP for a LAN server, or a domain/`https://`
   URL for a remote one.
2. **Pairing** — enter a short-lived **pairing code** generated from the
   Mycelium admin dashboard (not a password).
3. **Profile** — pick or create one. Profiles are server-wide and follow you
   across every paired device.

## Remote servers

Typing a domain name, a public IP, or an explicit `http(s)://` address into
the manual server field (instead of a private-range LAN IP) switches the
client into remote mode: the REST API and the gRPC channel both connect
over a single HTTPS port (443 by default, or an explicit `:port` in the
address) with standard system CA certificate validation — no certificate
pinning, since a publicly reachable server is expected to have a real
CA-issued certificate. See `lib/core/grpc/server_address.dart` for the
exact rules.

## Plugins

The client is plugin-agnostic: catalog rows, search filters, per-plugin
settings and icons all come from the server (`GetPluginSettings`,
`GetSearchFilters`, `GET /plugin-icon/<id>`), so no plugin is named or
bundled in the app binary. What a given Mycelium instance can browse and
play is entirely defined by the plugins its operator installed.

## TLS

**LAN server**: if it terminates TLS with a self-signed certificate, the
client pins its SHA-256 fingerprint on first contact (trust-on-first-use,
from `/pileus/info`). A plain-HTTP server on the LAN is the common case and
is allowed by the Android network security config.

**Remote server**: standard CA validation, no pinning — see "Remote
servers" above.
