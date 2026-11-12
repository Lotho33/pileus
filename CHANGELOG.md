# Changelog

All notable changes to Pileus are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Away from home over Tailscale: when the mycelium server has "Accesso da
  fuori casa" on, Pileus learns its tailnet address at every start
  (`GetServerInfo`) and tries it alongside the LAN addresses, so a native
  device with the Tailscale app on keeps working outside the home network.
  Older servers are unaffected.

## [1.5.3]

### Fixed
- Device pairing could silently re-enroll as a brand new device instead of
  reconnecting as the one already paired — a fresh device_id was minted on
  every `authorizeDevice` call instead of being generated once per
  installation and reused. Logging out of an expired session also used to
  wipe it, compounding the same issue. Fixed; the server's own
  UNAUTHENTICATED message is now logged before a session is dropped, so an
  unexpected sign-out is diagnosable instead of silent.
- Desktop/web (`media_kit`/libmpv backend): a stream that resolved near-
  instantly could crash the whole process on playback start — a native call
  fired before the player's handle had finished initializing. Fixed with
  the same guard already used elsewhere in the same engine.
- "Change server" is now reachable from every pre-login screen on every
  platform (device pairing, profile selection, server discovery) — some had
  no way back to manual server entry once auto-discovery locked onto a
  server on the LAN, with nothing to do but reinstall.

## [1.5.2] — Public release

Initial public release. Pileus is a Flutter client for a self-hosted
[Mycelium](https://github.com/Lotho33/mycelium) media-server backend —
Android TV/Fire TV, mobile, desktop (Linux/Windows) and web, one shared
codebase.

### Added
- Android TV / Fire TV app: D-pad navigation, on-screen keyboard, device
  pairing, server-wide profiles with optional PIN protection, server-driven
  catalog UI, search with server-provided filters, Continue Watching,
  offline downloads, intro/outro skip markers.
- Mobile app (phone/tablet), desktop app (Linux/Windows), and a web build —
  sharing the same core (gRPC transport, repositories, BLoC state, player
  engine) behind a platform-appropriate presentation layer.
- Dual player backend: ExoPlayer on Android, libmpv (`media_kit`) on
  desktop/web, behind one neutral `PlayerEngine` facade.
- LAN server discovery (UDP broadcast + manual entry) and a remote-server
  mode (an explicit domain or `https://` address, standard CA-validated
  TLS) for a Mycelium instance reached over the public internet.
- In-app "update available" notice for sideload installs (off by default in
  store builds).
