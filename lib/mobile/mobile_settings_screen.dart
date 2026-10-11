import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../shared/utils/tap_guard.dart';

/// Mobile settings landing — a plain touch list. The leaf screens
/// (Preferenze, Profilo, Plugin) are mobile-native (see mobile_router.dart);
/// account actions are wired straight to [AuthBloc].
// Published from docs/PRIVACY.md (GitHub Pages, see docs/index.md) — keep in
// sync with the URL given in the Play Console listing.
const _privacyUrl = 'https://lotho33.github.io/pileus/PRIVACY.html';

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
              () => context.pushGuarded('/settings/preferences')),
          _row(context, Icons.person_outline, 'Profilo',
              () => context.pushGuarded('/settings/profile')),
          _row(context, Icons.extension_outlined, 'Plugin',
              () => context.pushGuarded('/settings/plugins')),
          _row(context, Icons.download_outlined, 'Download',
              () => context.pushGuarded('/downloads')),
          const Divider(color: AppTheme.border),
          // "Cambia profilo" and "Esci" live on the home profile button
          // (top-right avatar) — not duplicated here.
          _row(context, Icons.dns_outlined, 'Cambia server', () {
            _confirm(context, 'Cambiare server?',
                'Dovrai rifare discovery e abbinamento.', () {
              getIt<AuthBloc>().add(const ChangeServerEvent());
            });
          }),
          const Divider(color: AppTheme.border),
          _row(context, Icons.info_outline, 'Informazioni',
              () => _showAbout(context)),
        ],
      ),
    );
  }

  /// Version + privacy policy + Flutter's own open-source licenses page
  /// (showAboutDialog's "Licenze" button) — the in-app place Play's user
  /// data policy expects the privacy policy to be reachable from.
  Future<void> _showAbout(BuildContext context) async {
    if (!TapGuard.acquire()) return; // double tap — see tap_guard.dart
    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (${info.buildNumber})';
    } catch (_) {}
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'Pileus',
      applicationVersion: version,
      applicationLegalese: 'Client per server Mycelium.',
      children: const [
        SizedBox(height: 16),
        Text(
          'Pileus non raccoglie dati personali e non usa analytics né '
          'pubblicità: comunica solo con il server Mycelium che hai scelto.',
        ),
        SizedBox(height: 10),
        Text('Informativa privacy:'),
        SelectableText(_privacyUrl),
      ],
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
    if (!TapGuard.acquire()) return; // double tap — see tap_guard.dart
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => popIfCurrent(ctx),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              if (!popIfCurrent(ctx)) return;
              onYes();
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }
}
