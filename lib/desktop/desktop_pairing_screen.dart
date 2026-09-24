import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/bloc/auth_state.dart';
import '../features/auth/friendly_error.dart';
import 'desktop_splash_screen.dart' show DesktopAuthCard;

/// Desktop device pairing: the short-lived code from the Mycelium admin
/// dashboard.
class DesktopPairingScreen extends StatefulWidget {
  const DesktopPairingScreen({super.key});

  @override
  State<DesktopPairingScreen> createState() => _DesktopPairingScreenState();
}

class _DesktopPairingScreenState extends State<DesktopPairingScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    getIt<AuthBloc>().add(AuthenticateDeviceEvent(code));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      bloc: getIt<AuthBloc>(),
      listener: (context, state) {
        if (state is AuthError) {
          setState(() {
            _busy = false;
            _error = friendlyPairingErrorMessage(state.message);
          });
        }
      },
      child: DesktopAuthCard(
        title: 'Abbina il dispositivo',
        subtitle:
            'Genera un codice di abbinamento dalla dashboard admin di Mycelium '
            'e inseriscilo qui.',
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) {
              if (!_busy) _submit();
            },
            decoration: InputDecoration(
              hintText: 'Codice di abbinamento',
              errorText: _error,
              prefixIcon: const Icon(Icons.vpn_key_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Conferma'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => getIt<AuthBloc>().add(const ChangeServerEvent()),
            child: const Text('Cambia server'),
          ),
        ],
      ),
    );
  }
}
