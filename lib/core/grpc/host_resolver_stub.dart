// Web no-ops for the platform-specific bits of resolveGrpcHost. On the web
// build none of these run: resolveGrpcHost returns the page origin's host
// directly (the app is served *by* mycelium), so the LAN probe / UDP
// discovery are never reached — they exist only to keep host_resolver.dart
// compiling without dart:io.

String? runtimeEnvHost() => null;

bool get isAndroidPlatform => false;

Future<bool> canReach(String host, int port, Duration timeout) async => false;

Future<String?> discoverViaBroadcast({
  Duration timeout = const Duration(milliseconds: 1400),
}) async =>
    null;
