import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';

/// Mobile settings landing — a plain touch list. The leaf screens
/// (Preferenze, Profilo, Plugin) are mobile-native (see mobile_router.dart);
/// account actions are wired straight to [AuthBloc].
class MobileSettingsScreen extends StatelessWidget {
  const MobileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: const Text('Impostazioni'),
      ),
      body: ListView(
        children: [
          _row(context, Icons.tune, 'Preferenze',
              () => context.push('/settings/preferences')),
          _row(context, Icons.person_outline, 'Profilo',
              () => context.push('/settings/profile')),
          _row(context, Icons.extension_outlined, 'Plugin',
              () => context.push('/settings/plugins')),
          const Divider(color: AppTheme.border),
          // "Cambia profilo" and "Esci" live on the home profile button
          // (top-right avatar) — not duplicated here.
          _row(context, Icons.dns_outlined, 'Cambia server', () {
            _confirm(context, 'Cambiare server?',
                'Dovrai rifare discovery e abbinamento.', () {
              getIt<AuthBloc>().add(const ChangeServerEvent());
            });
          }),
        ],
      ),
    );
  }

  Widget _row(
      BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final c = danger ? const Color(0xFFFF6B6B) : AppTheme.textHigh;
    return ListTile(
      leading: Icon(icon, color: danger ? c : AppTheme.textMid),
      title: Text(label, style: TextStyle(color: c)),
      trailing: danger
          ? null
          : const Icon(Icons.chevron_right, color: AppTheme.textLow),
      onTap: onTap,
    );
  }

  void _confirm(
      BuildContext context, String title, String body, VoidCallback onYes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onYes();
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }
}
