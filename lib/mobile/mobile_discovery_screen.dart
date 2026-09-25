import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config/server_config.dart';
import '../core/di/injection.dart';
import '../core/grpc/host_resolver.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/data/auth_repository.dart';

class _DiscoveryError implements Exception {
  final String message;
  _DiscoveryError(this.message);
}

/// Mobile server discovery: manual IP entry with the system keyboard, plus a
/// "retry auto-detect" that re-runs the UDP broadcast/mDNS scan (see
/// _retryAutoDiscovery's doc comment — it didn't actually do this until
/// 2026-09-25).
class MobileDiscoveryScreen extends StatefulWidget {
  const MobileDiscoveryScreen({super.key});

  @override
  State<MobileDiscoveryScreen> createState() => _MobileDiscoveryScreenState();
}

class _MobileDiscoveryScreenState extends State<MobileDiscoveryScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _ctrl.text.trim();
    if (host.isEmpty) return;
    await _connectTo(host);
  }

  /// "Riprova rilevamento automatico" used to just re-dispatch
  /// `AppStartedEvent`, which only re-checks the *already-saved* session —
  /// it never actually re-ran the UDP/mDNS broadcast scan at all (that only
  /// ever happens once, in `configureDependencies()` at cold app start —
  /// see `resolveGrpcHost()`'s own doc comment). From this screen (already
  /// past that first failed attempt) it was a silent no-op: nothing on the
  /// network was re-probed, so the outcome couldn't change and the screen
  /// just sat there (2026-09-25 — reported as "doesn't work"). This now
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
      // 1. HTTP side (/pileus/info on :8000) — also carries the gRPC TLS
      //    pinning fingerprint (trust-on-first-use; the gRPC cert is
      //    self-signed, so a matching SHA-256 IS the trust check).
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

      // 2. gRPC side (:50051) — pairing and every catalog call go here, and
      //    it's often bound/published separately from :8000. Fail loudly
      //    now instead of hanging on the pairing screen later. A plain TCP
      //    connect is enough here even when the port speaks TLS.
      try {
        final sock = await Socket.connect(host, ServerPorts.grpc,
            timeout: const Duration(seconds: 4));
        sock.destroy();
      } catch (_) {
        throw _DiscoveryError(
            'Il server risponde su :${ServerPorts.http} ma non su '
            ':${ServerPorts.grpc} (gRPC). Apri/pubblica quella porta e '
            'assicurati che Mycelium sia in ascolto su 0.0.0.0.');
      }
      await getIt<AuthRepository>().saveHostInfo(host, tlsFingerprint);
      await rebuildGrpcClients(host, tlsFingerprint: tlsFingerprint);
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
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: const Text('Connetti al server'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Indirizzo IP del tuo server Mycelium sulla rete locale.',
                style: TextStyle(color: AppTheme.textMid),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) {
                  if (!_busy) _connect();
                },
                decoration: InputDecoration(
                  hintText: '192.168.1.x',
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
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Connetti'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _retryAutoDiscovery,
                child: const Text('Riprova rilevamento automatico'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
