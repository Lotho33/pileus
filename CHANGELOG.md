# Changelog

All notable changes to Pileus are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
