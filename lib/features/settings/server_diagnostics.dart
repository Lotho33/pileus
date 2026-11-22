import 'dart:io' show NetworkInterface, InternetAddressType;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config.dart';
import '../../core/db/models/device_session.dart';
import '../../core/di/injection.dart';
import '../../core/grpc/host_resolver.dart' show myceliumHttpBase;
import '../auth/data/server_connector.dart' show parseServerInfo;

/// What Impostazioni › Server shows: where this device connects and how the
/// server answers right now — so a tester can read out (or photograph) the
/// address, ports and version instead of guessing.
class ServerDiagnostics {
  final String host;
  final bool remote;
  final String? vpnHost;
  final String httpBase;
  final int grpcPort;
  final String? tlsFingerprint;
  final String deviceId;
  final List<String> deviceIps;
  final String appVersion;

  /// From GET /pileus/info now; null when it didn't answer ([error] says why).
  final String? serverVersion;
  final int? latencyMs;
  final String? error;

  const ServerDiagnostics({
    required this.host,
    required this.remote,
    required this.httpBase,
    required this.grpcPort,
    required this.deviceId,
    required this.deviceIps,
    required this.appVersion,
    this.vpnHost,
    this.tlsFingerprint,
    this.serverVersion,
    this.latencyMs,
    this.error,
  });

  bool get reachable => error == null;

  /// Label/value pairs, in display order.
  List<(String, String)> get rows => [
        (
          'Stato',
          reachable ? 'Raggiungibile ($latencyMs ms)' : 'Non risponde: $error'
        ),
        ('Server', host.isEmpty ? '—' : host),
        ('Collegamento', remote ? 'Remoto (Internet)' : 'Rete locale'),
        ('Indirizzo web', httpBase.isEmpty ? '—' : httpBase),
        if (!remote) ('Porta gRPC', '$grpcPort'),
        (
          'Cifratura',
          tlsFingerprint == null
              ? 'No'
              : 'TLS · ${shortFingerprint(tlsFingerprint!)}'
        ),
        if (vpnHost != null && vpnHost!.isNotEmpty) ('Indirizzo VPN', vpnHost!),
        if (serverVersion != null) ('Versione Mycelium', serverVersion!),
        if (deviceIps.isNotEmpty)
          ('IP di questo dispositivo', deviceIps.join(', ')),
        if (deviceId.isNotEmpty) ('ID dispositivo', deviceId),
        if (appVersion.isNotEmpty) ('Versione Pileus', appVersion),
      ];
}

/// "F2:80:B8:51…5E:CD": enough to compare with the dashboard at a glance.
String shortFingerprint(String fp) {
  final hex = fp.replaceAll(':', '').toUpperCase();
  if (hex.length < 12) return hex;
  String pairs(String s) => [
        for (var i = 0; i + 1 < s.length; i += 2) s.substring(i, i + 2)
      ].join(':');
  return '${pairs(hex.substring(0, 8))}…${pairs(hex.substring(hex.length - 4))}';
}

/// Reads the saved session and asks the server for /pileus/info, timed.
Future<ServerDiagnostics> loadServerDiagnostics({
  http.Client? client,
  Future<List<String>> Function()? localIps,
  Future<String> Function()? appVersion,
  Duration timeout = const Duration(seconds: 5),
}) async {
  DeviceSession? session;
  try {
    session = DeviceSession.readFrom(getIt<SharedPreferences>());
  } catch (_) {}
  final base = myceliumHttpBase() ?? '';

  String? version;
  int? latency;
  String? error;
  if (base.isEmpty) {
    error = 'nessun server salvato';
  } else {
    final c = client ?? http.Client();
    final sw = Stopwatch()..start();
    try {
      final res = await c.get(Uri.parse('$base/pileus/info')).timeout(timeout);
      sw.stop();
      if (res.statusCode != 200) {
        error = 'HTTP ${res.statusCode}';
      } else if (parseServerInfo(res.body) == null) {
        error = 'non è un server Mycelium';
      } else {
        latency = sw.elapsedMilliseconds;
        version = _versionOf(res.body);
      }
    } catch (_) {
      error = 'nessuna risposta';
    } finally {
      if (client == null) c.close();
    }
  }

  return ServerDiagnostics(
    host: session?.grpcHost ?? '',
    remote: session?.remote ?? false,
    vpnHost: session?.vpnHost,
    httpBase: base,
    grpcPort: (session?.grpcPort != null && session!.grpcPort! > 0)
        ? session.grpcPort!
        : ServerPorts.grpc,
    tlsFingerprint: (session?.tlsFingerprint?.isNotEmpty ?? false)
        ? session!.tlsFingerprint
        : null,
    deviceId: session?.deviceId ?? '',
    deviceIps: await (localIps ?? _localIps)().catchError((_) => <String>[]),
    appVersion: await (appVersion ?? _appVersion)().catchError((_) => ''),
    serverVersion: version,
    latencyMs: latency,
    error: error,
  );
}

String? _versionOf(String body) {
  final m = RegExp(r'"version"\s*:\s*"([^"]*)"').firstMatch(body);
  final v = m?.group(1);
  return (v == null || v.isEmpty) ? null : v;
}

Future<List<String>> _localIps() async {
  if (kIsWeb) return const [];
  return [
    for (final i in await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false))
      for (final a in i.addresses) a.address,
  ];
}

Future<String> _appVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}
