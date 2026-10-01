/// Fixed ports mycelium-core listens on. Collected here so a change — or a
/// future "configurable port" setting — touches one file instead of the
/// five call sites that used to hard-code these literals (the two gRPC
/// channel factories, the auth interceptor's `x-http-host`, the discovery
/// screen probe, and the UDP host resolver).
abstract final class ServerPorts {
  /// gRPC service (ClientChannel / gRPC-Web).
  static const int grpc = 50051;

  /// HTTP side: `/pileus/info`, the image proxy, segment proxy. Sent to the
  /// server as the `x-http-host` metadata so it can build proxy URLs.
  static const int http = 8000;

  /// UDP broadcast the server answers during LAN discovery.
  static const int discoveryUdp = 51900;

  /// Default HTTPS port for a *remote* mycelium — a server
  /// published on the public internet (e.g. a demo instance store
  /// reviewers connect to) rather than found on the LAN. See
  /// server_address.dart: remote mode connects both the REST API and the
  /// native gRPC channel to this single port (or whatever explicit
  /// ":port" the person typed), unlike LAN mode's separate fixed
  /// :8000/:50051.
  static const int remoteHttps = 443;
}
