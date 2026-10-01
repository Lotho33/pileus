import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config/server_config.dart';
import '../core/di/injection.dart';
import '../core/grpc/host_resolver.dart';
import '../core/grpc/remote_server_connect.dart';
import '../core/grpc/server_address.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/data/auth_repository.dart';
import 'desktop_splash_screen.dart' show DesktopAuthCard;

class _DiscoveryError implements Exception {
  final String message;
  _DiscoveryError(this.message);
}

/// Desktop server discovery: manual host entry + "retry auto-detect" (which
/// re-runs the UDP broadcast scan — see _retryAutoDiscovery's doc
/// comment). Probe logic mirrors the mobile screen (HTTP /pileus/info + a
/// gRPC TCP reachability check); only the presentation is a centred card.
class DesktopDiscoveryScreen extends StatefulWidget {
  const DesktopDiscoveryScreen({super.key});

  @override
  State<DesktopDiscoveryScreen> createState() => _DesktopDiscoveryScreenState();
}

class _DesktopDiscoveryScreenState extends State<DesktopDiscoveryScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    final parsed = parseServerAddressInput(input);
    // Remote server mode (see server_address.dart) — a mycelium
    // published on the public internet (http(s):// URL, a domain, or a
    // public IP) instead of a LAN address. Only the manual field ever
    // reaches this — _retryAutoDiscovery below only ever produces a LAN
    // host.
    if (parsed.remote) {
      await _connectRemote(parsed);
      return;
    }
    await _connectTo(parsed.host);
  }

  Future<void> _connectRemote(ParsedServerAddress parsed) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await connectToRemoteServer(parsed);
    if (!mounted) return;
    if (result.ok) {
      getIt<AuthBloc>().add(const AppStartedEvent(splashFloor: false));
    } else {
      setState(() => _error = result.error);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// "Riprova rilevamento automatico" used to just re-dispatch
  /// `AppStartedEvent`, which only re-checks the *already-saved* session —
  /// it never actually re-ran the UDP broadcast scan at all (that only
  /// ever happens once, in `configureDependencies()` at cold app start —
  /// see `resolveGrpcHost()`'s own doc comment). From this screen (already
  /// past that first failed attempt) it was a silent no-op: nothing on the
  /// network was re-probed, so the outcome couldn't change and the screen
  /// just sat there (reported as "doesn't work"). This now
  /// actually re-runs the same broadcast+TCP-candidate race, then validates
  /// whatever it comes back with exactly like a manually typed host would.
  Future<void> _retryAutoDiscovery() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final host = await resolveGrpcHost();
    await _connectTo(host);
  }

  Future<void> _connectTo(String host) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.http('$host:${ServerPorts.http}', '/pileus/info'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        throw _DiscoveryError('Il server a "$host" ha risposto HTTP '
            '${res.statusCode} su :${ServerPorts.http}.');
      }
      Map<String, dynamic> info;
      try {
        info = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw _DiscoveryError(
            'Risposta non valida da "$host:${ServerPorts.http}".');
      }
      if (info['name'] != 'Mycelium') {
        throw _DiscoveryError(
            '"$host:${ServerPorts.http}" non è un server Mycelium.');
      }
      final fpRaw = info['grpc_tls_fingerprint'] as String?;
      final tlsFingerprint = (fpRaw != null && fpRaw.isNotEmpty) ? fpRaw : null;
      // grpc_port: the server's real gRPC port — it used to
      // always be reported as the fixed default regardless of what mycelium
      // actually listened on. Missing (older server) falls back to it.
      final rawGrpcPort = (info['grpc_port'] as num?)?.toInt();
      final grpcPort =
          (rawGrpcPort != null && rawGrpcPort > 0) ? rawGrpcPort : ServerPorts.grpc;

      try {
        final sock = await Socket.connect(host, grpcPort,
            timeout: const Duration(seconds: 4));
        sock.destroy();
      } catch (_) {
        throw _DiscoveryError(
            'Il server risponde su :${ServerPorts.http} ma non su '
            ':$grpcPort (gRPC). Apri/pubblica quella porta e '
            'assicurati che Mycelium sia in ascolto su 0.0.0.0.');
      }
      await getIt<AuthRepository>()
          .saveHostInfo(host, tlsFingerprint, grpcPort: rawGrpcPort);
      await rebuildGrpcClients(host,
          tlsFingerprint: tlsFingerprint, grpcPort: rawGrpcPort);
      if (!mounted) return;
      getIt<AuthBloc>().add(const AppStartedEvent(splashFloor: false));
    } on _DiscoveryError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Nessun server Mycelium raggiungibile a "$host".');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopAuthCard(
      title: 'Connetti al server',
      subtitle: 'Un IP sulla rete locale, o un dominio/https:// per un '
          'server remoto.',
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) {
            if (!_busy) _connect();
          },
          decoration: InputDecoration(
            hintText: '192.168.1.x o https://demo.tuodominio.it',
            errorText: _error,
            prefixIcon: const Icon(Icons.dns_outlined),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Connetti'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _busy ? null : _retryAutoDiscovery,
          child: const Text('Riprova rilevamento automatico'),
        ),
      ],
    );
  }
}
