// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../core/di/injection.dart';
import '../core/grpc/remote_server_connect.dart';
import '../core/grpc/server_address.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/data/server_connector.dart';

/// Mobile server discovery: manual IP entry with the system keyboard, plus a
/// "retry auto-detect" that re-runs the UDP broadcast scan — see
/// _retryAutoDiscovery's own doc comment.
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
    await _connectTo(parsed.host, httpPort: parsed.port);
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
    final found = await rediscoverLanServer();
    if (!mounted) return;
    if (found == null) {
      // Without this a failing scan left the buttons disabled behind a
      // spinner forever (_busy never reset).
      setState(() {
        _busy = false;
        _error = 'Nessun server Mycelium trovato sulla rete locale.';
      });
      return;
    }
    // On the port the UDP reply announced (a server moved off the default).
    await _connectTo(found.host, httpPort: found.httpPort);
  }

  /// [httpPort]: typed as "ip:port" in the manual address; the fixed
  /// ServerPorts.http otherwise (auto-discovery). See connectLanServer.
  Future<void> _connectTo(String host, {int? httpPort}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await connectLanServer(host, httpPort: httpPort);
      if (!mounted) return;
      getIt<AuthBloc>().add(const AppStartedEvent(splashFloor: false));
    } on ServerProbeException catch (e) {
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
                'Un IP sulla rete locale, o un dominio/https:// per un '
                'server remoto.',
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
