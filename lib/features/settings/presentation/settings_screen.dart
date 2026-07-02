import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_event.dart';
import '../../../features/media/data/media_repository.dart';
import '../../../shared/widgets/ambient_glow_background.dart';
import '../../../shared/widgets/settings/dialog_action_button.dart';
import '../../../shared/widgets/settings/settings_header.dart';
import '../../../shared/widgets/settings/settings_nav_row.dart';
import '../../../shared/widgets/settings/settings_section_header.dart';
import '../../../shared/widgets/tv_focusable.dart';

/// Impostazioni hub — the single home for app-wide actions. "Cambia server"
/// and "Esci dall'app" live here now (the side nav no longer carries an
/// exit action) alongside the per-area drill-downs.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backFn = FocusNode();
  final _profileFn = FocusNode();
  final _serverFn = FocusNode();
  final _prefsFn = FocusNode();
  final _pluginsFn = FocusNode();
  final _clearCacheFn = FocusNode();
  final _exitFn = FocusNode();
  bool _clearingCache = false;

  @override
  void dispose() {
    _backFn.dispose();
    _profileFn.dispose();
    _serverFn.dispose();
    _prefsFn.dispose();
    _pluginsFn.dispose();
    _clearCacheFn.dispose();
    _exitFn.dispose();
    super.dispose();
  }

  Future<void> _clearCache() async {
    if (_clearingCache) return;
    setState(() => _clearingCache = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await getIt<MediaRepository>().clearCatalogCache();
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Cache svuotata — i cataloghi si aggiorneranno al prossimo caricamento.'),
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Impossibile svuotare la cache: $e')));
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => context.pop(),
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: AmbientGlowBackground(
            child: Column(
          children: [
            SettingsHeader(
              title: 'Impostazioni',
              focusNode: _backFn,
              onBack: () => context.pop(),
              onFocusDown: () => _profileFn.requestFocus(),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                    horizontal: AppScale.screenHPad(context),
                    vertical: AppScale.space(context, 12)),
                children: [
                  const SettingsSectionHeader('Account'),
                  SettingsNavRow(
                    icon: Icons.person_rounded,
                    label: 'Profilo',
                    subtitle: 'Nome, avatar',
                    focusNode: _profileFn,
                    autofocus: true,
                    onFocusUp: () => _backFn.requestFocus(),
                    onFocusDown: () => _serverFn.requestFocus(),
                    onTap: () => context.push('/settings/profile'),
                  ),
                  const SettingsSectionHeader('Connessione'),
                  SettingsNavRow(
                    icon: Icons.dns_rounded,
                    label: 'Cambia server',
                    subtitle:
                        'Torna alla ricerca del server — richiede un nuovo abbinamento',
                    focusNode: _serverFn,
                    onFocusUp: () => _profileFn.requestFocus(),
                    onFocusDown: () => _prefsFn.requestFocus(),
                    onTap: () => _showChangeServerDialog(context),
                  ),
                  const SettingsSectionHeader('App'),
                  SettingsNavRow(
                    icon: Icons.tune_rounded,
                    label: 'Preferenze',
                    subtitle: 'Sottotitoli',
                    focusNode: _prefsFn,
                    onFocusUp: () => _serverFn.requestFocus(),
                    onFocusDown: () => _pluginsFn.requestFocus(),
                    onTap: () => context.push('/settings/preferences'),
                  ),
                  SettingsNavRow(
                    icon: Icons.extension_rounded,
                    label: 'Plugin',
                    subtitle: 'Configurazione per singolo plugin',
                    focusNode: _pluginsFn,
                    onFocusUp: () => _prefsFn.requestFocus(),
                    onFocusDown: () => _clearCacheFn.requestFocus(),
                    onTap: () => context.push('/settings/plugins'),
                  ),
                  SettingsNavRow(
                    icon: Icons.delete_sweep_rounded,
                    label: 'Svuota cache catalogo',
                    subtitle: _clearingCache
                        ? 'Svuotamento in corso…'
                        : 'Rimuove i cataloghi in cache — utile se compaiono contenuti vecchi',
                    focusNode: _clearCacheFn,
                    onFocusUp: () => _pluginsFn.requestFocus(),
                    onFocusDown: () => _exitFn.requestFocus(),
                    onTap: _clearCache,
                  ),
                  SizedBox(height: AppScale.space(context, 10)),
                  SettingsNavRow(
                    icon: Icons.logout_rounded,
                    label: 'Esci dall\'app',
                    subtitle: 'Chiude Pileus',
                    focusNode: _exitFn,
                    onFocusUp: () => _clearCacheFn.requestFocus(),
                    onTap: () => _showExitDialog(context),
                  ),
                ],
              ),
            ),
          ],
        )),
      ),
    );
  }
}

// Wipes the cached host + TLS pin + device pairing (AuthBloc.forgetServer)
// and drops back to server discovery — navigation is handled by the
// app-wide listener in main.dart, not here.
Future<void> _showChangeServerDialog(BuildContext context) async {
  final authBloc = context.read<AuthBloc>();
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(dialogCtx).pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Cambiare server?'),
        content: const Text(
          'Tornerai alla ricerca del server. Dovrai abbinare di nuovo questo '
          'dispositivo al nuovo server.',
          style: TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            autofocus: true,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          DialogActionButton(
            label: 'Cambia server',
            primary: true,
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              authBloc.add(const ChangeServerEvent());
            },
          ),
        ],
      ),
    ),
  );
}

// Closes the app. SystemNavigator.pop() is the platform-correct way — on
// Android it finishes the Activity (what Back at the root does), on desktop
// it closes the window.
Future<void> _showExitDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(dialogCtx).pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Uscire dall\'app?'),
        content: const Text(
          'Pileus verrà chiuso.',
          style: TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            autofocus: true,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          DialogActionButton(
            label: 'Esci',
            primary: true,
            primaryColor: Colors.red[700],
            onPressed: () => SystemNavigator.pop(),
          ),
        ],
      ),
    ),
  );
}
