import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config/server_config.dart';
import '../core/di/injection.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/data/auth_repository.dart';
import '../desktop/desktop_splash_screen.dart' show DesktopAuthCard;

/// Web server discovery. The page is normally served *by* mycelium, so the
/// origin already is the server — this screen mostly just confirms it via
/// `/pileus/info` and moves on, with a manual host override for the case
/// where the app is hosted somewhere else (behind a gRPC-Web proxy).
class WebDiscoveryScreen extends StatefulWidget {
  const WebDiscoveryScreen({super.key});

  @override
  State<WebDiscoveryScreen> createState() => _WebDiscoveryScreenState();
}

class _WebDiscoveryScreenState extends State<WebDiscoveryScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Try the page origin automatically first.
    _ctrl.text = Uri.base.host;
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect(auto: true));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _connect({bool auto = false}) async {
    final host = _ctrl.text.trim();
    if (host.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On web the transport is gRPC-Web against the current origin's
      // `/grpc`; the reachability check is just the HTTP info endpoint.
      final base = host == Uri.base.host
          ? '${Uri.base.scheme}://${Uri.base.host}'
              '${Uri.base.hasPort ? ":${Uri.base.port}" : ""}'
          : 'http://$host:${ServerPorts.http}';
      final res = await http
          .get(Uri.parse('$base/pileus/info'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode} da $base/pileus/info';
      }
      final info = jsonDecode(res.body) as Map<String, dynamic>;
      if (info['name'] != 'Mycelium') throw 'Non è un server Mycelium.';

      await getIt<AuthRepository>().saveHostInfo(host, null);
      await rebuildGrpcClients(host, tlsFingerprint: null);
      if (!mounted) return;
      getIt<AuthBloc>().add(const AppStartedEvent(splashFloor: false));
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            auto ? 'Inserisci l\'indirizzo del server.' : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopAuthCard(
      title: 'Connetti al server',
      subtitle:
          'Di norma questa pagina è servita da Mycelium stesso. Modifica solo '
          'se stai usando un proxy gRPC-Web separato.',
      children: [
        TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) {
            if (!_busy) _connect();
          },
          decoration: InputDecoration(
            hintText: 'host del server',
            errorText: _error,
            prefixIcon: const Icon(Icons.dns_outlined),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : () => _connect(),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Connetti'),
        ),
      ],
    );
  }
}
