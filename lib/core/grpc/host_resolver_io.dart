import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/server_config.dart';

/// Native (`dart:io`) implementation of the platform-specific bits of
/// [resolveGrpcHost] — see `host_resolver.dart` for the shared logic and
/// `host_resolver_stub.dart` for the web no-ops.

/// `MYCELIUM_HOST` env var (dev convenience). The compile-time
/// `PILEUS_MYCELIUM_HOST` define is read in `host_resolver.dart` (works on
/// both platforms).
String? runtimeEnvHost() {
  final v = Platform.environment['MYCELIUM_HOST'];
  return (v != null && v.isNotEmpty) ? v : null;
}

bool get isAndroidPlatform => Platform.isAndroid;

/// TCP reachability probe of [host]:[port] within [timeout].
Future<bool> canReach(String host, int port, Duration timeout) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// UDP broadcast discovery — mirrors mycelium's responder
/// (internal/api/discovery.go). Returns the source IP of the first
/// `{"name":"Mycelium"}` reply, or null on timeout / any socket error.
Future<String?> discoverViaBroadcast({
  Duration timeout = const Duration(milliseconds: 1400),
}) async {
  const discoveryPort = ServerPorts.discoveryUdp;
  const magic = 'MYCELIUM_DISCOVER_V1';
  RawDatagramSocket? sock;
  try {
    sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sock.broadcastEnabled = true;
    final done = Completer<String?>();
    final payload = utf8.encode(magic);

    sock.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = sock?.receive();
      if (dg == null) return;
      try {
        final info = jsonDecode(utf8.decode(dg.data));
        if (info is Map && info['name'] == 'Mycelium' && !done.isCompleted) {
          done.complete(dg.address.address);
        }
      } catch (_) {
        // not our reply — ignore
      }
    });

    final targets = <InternetAddress>[InternetAddress('255.255.255.255')];
    try {
      for (final ni in await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false)) {
        for (final a in ni.addresses) {
          final p = a.address.split('.');
          if (p.length == 4) {
            targets.add(InternetAddress('${p[0]}.${p[1]}.${p[2]}.255'));
          }
        }
      }
    } catch (_) {}

    void blast() {
      for (final t in targets) {
        try {
          sock?.send(payload, t, discoveryPort);
        } catch (_) {}
      }
    }

    blast();
    Timer(const Duration(milliseconds: 450), blast);
    Timer(const Duration(milliseconds: 950), blast);

    return await done.future.timeout(timeout, onTimeout: () => null);
  } catch (_) {
    return null;
  } finally {
    sock?.close();
  }
}
