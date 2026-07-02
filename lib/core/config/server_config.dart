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
}
