import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/models/local_profile.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ambient_glow_background.dart';
import '../../../shared/widgets/default_avatars.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/settings/dialog_action_button.dart';
import '../../../shared/widgets/settings/settings_header.dart';
import '../../../shared/widgets/settings/settings_nav_row.dart';
import '../../../shared/widgets/settings/settings_section_header.dart';
import '../../../shared/widgets/settings/settings_text_dialog.dart';
import '../../../shared/widgets/settings/settings_toggle_row.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/presentation/widgets/profile_pin_dialog.dart';
import '../bloc/profile_management_cubit.dart';
import '../bloc/profile_management_state.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activeProfileId = switch (context.read<AuthBloc>().state) {
      AuthenticatedState(:final activeProfileId) => activeProfileId,
      _ => '',
    };
    return BlocProvider(
      create: (_) => getIt<ProfileManagementCubit>()..load(activeProfileId),
      child: const _ProfileSettingsBody(),
    );
  }
}

class _ProfileSettingsBody extends StatefulWidget {
  const _ProfileSettingsBody();

  @override
  State<_ProfileSettingsBody> createState() => _ProfileSettingsBodyState();
}

class _ProfileSettingsBodyState extends State<_ProfileSettingsBody> {
  final _backFn = FocusNode();
  final _nameFn = FocusNode();
  final _avatarFn = FocusNode();
  final _defaultFn = FocusNode();
  final _pinFn = FocusNode();
  final _removePinFn = FocusNode();
  final _forgetDeviceFn = FocusNode();
  final _logoutFn = FocusNode();
  final _deleteFn = FocusNode();
  // Guards the explicit initial-focus request in the BlocConsumer listener
  // below — fires once, the first time data is actually ready, not on
  // every later ProfileMgmtLoaded re-emission (a rename, a PIN change...),
  // which would otherwise yank focus back to "Nome" out from under
  // whatever the user has since navigated to.
  bool _initialFocusRequested = false;

  @override
  void dispose() {
    _backFn.dispose();
    _nameFn.dispose();
    _avatarFn.dispose();
    _defaultFn.dispose();
    _pinFn.dispose();
    _removePinFn.dispose();
    _forgetDeviceFn.dispose();
    _logoutFn.dispose();
    _deleteFn.dispose();
    super.dispose();
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
              title: 'Profilo',
              focusNode: _backFn,
              onBack: () => context.pop(),
              onFocusDown: () => _nameFn.requestFocus(),
            ),
            Expanded(
              child: BlocConsumer<ProfileManagementCubit, ProfileMgmtState>(
                listener: (context, state) {
                  // PileusLoadingSwitcher holds its spinner up for a 260ms
                  // minimum even once the real (near-instant, usually
                  // cached) data is ready — the "Nome" row's own
                  // autofocus: true, declared on a widget that doesn't
                  // mount until that delay (plus the switcher's 220ms
                  // crossfade) elapses, unreliably loses the race to
                  // actually land focus. Requesting it explicitly, once,
                  // the moment the data is actually ready sidesteps that
                  // entirely instead of depending on autofocus timing.
                  if (state is ProfileMgmtLoaded && !_initialFocusRequested) {
                    _initialFocusRequested = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _nameFn.requestFocus();
                    });
                  }
                  if (state is ProfileMgmtDeleted) {
                    // Going straight to /profiles left AuthBloc in
                    // AuthenticatedState, so ProfileSelectionScreen (which
                    // only renders once it sees ProfileSelectionRequired /
                    // has a profile list) sat on its spinner forever. Route
                    // through the bloc instead: SwitchProfileEvent reloads
                    // the local profiles (now minus the deleted one) and
                    // emits ProfileSelectionRequired, which main.dart's
                    // app-wide listener turns into the /profiles navigation.
                    context.read<AuthBloc>().add(const SwitchProfileEvent());
                  }
                  if (state is ProfileMgmtError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.red[900]),
                    );
                  }
                },
                builder: (context, state) {
                  return PileusLoadingSwitcher(
                    isLoading: state is! ProfileMgmtLoaded,
                    spinnerSize: AppScale.spinnerL(context),
                    child: state is ProfileMgmtLoaded
                        ? _buildForm(context, state)
                        : const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _buildForm(BuildContext context, ProfileMgmtLoaded state) {
    final profile = state.profile;
    final cubit = context.read<ProfileManagementCubit>();
    return ListView(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.screenHPad(context),
          vertical: AppScale.space(context, 12)),
      children: [
        const SettingsSectionHeader('Dati profilo'),
        SettingsNavRow(
          icon: Icons.badge_rounded,
          label: 'Nome',
          subtitle: profile.profileName,
          focusNode: _nameFn,
          autofocus: true,
          onFocusUp: () => _backFn.requestFocus(),
          onFocusDown: () => _avatarFn.requestFocus(),
          onTap: () async {
            final newName = await showSettingsTextInputDialog(
              context,
              title: 'Rinomina profilo',
              initialValue: profile.profileName,
            );
            if (newName != null) await cubit.rename(newName);
          },
        ),
        SettingsNavRow(
          icon: Icons.image_rounded,
          label: 'Avatar',
          subtitle: isDefaultAvatarUrl(profile.avatarUrl)
              ? 'Predefinito'
              : (profile.avatarUrl.isNotEmpty ? 'Personalizzato' : 'Nessuno'),
          focusNode: _avatarFn,
          onFocusUp: () => _nameFn.requestFocus(),
          onFocusDown: () => _defaultFn.requestFocus(),
          onTap: () =>
              _showAvatarPickerDialog(context, cubit, profile.avatarUrl),
        ),
        const SettingsSectionHeader('Avvio'),
        SettingsToggleRow(
          label: 'Profilo predefinito',
          value: state.isDefault,
          focusNode: _defaultFn,
          onFocusUp: () => _avatarFn.requestFocus(),
          onFocusDown: () => _pinFn.requestFocus(),
          onChanged: (v) {
            if (!v) {
              cubit.setDefault(false);
              return;
            }
            if (state.otherDefaultName != null) {
              _showDefaultBlockedDialog(context, state.otherDefaultName!);
            } else {
              _showSetDefaultDialog(context, cubit);
            }
          },
        ),
        const SettingsSectionHeader('Sicurezza'),
        SettingsNavRow(
          icon: Icons.pin_rounded,
          label: profile.pinProtected ? 'Cambia PIN' : 'Imposta PIN',
          subtitle: profile.pinProtected ? 'Attivo' : 'Non impostato',
          focusNode: _pinFn,
          onFocusUp: () => _defaultFn.requestFocus(),
          onFocusDown: () => (profile.pinProtected
                  ? _removePinFn
                  : (profile.deviceTrusted ? _forgetDeviceFn : _logoutFn))
              .requestFocus(),
          onTap: () => _managePin(context, cubit, profile),
        ),
        if (profile.pinProtected)
          SettingsNavRow(
            icon: Icons.lock_open_rounded,
            label: 'Rimuovi PIN',
            focusNode: _removePinFn,
            onFocusUp: () => _pinFn.requestFocus(),
            onFocusDown: () =>
                (profile.deviceTrusted ? _forgetDeviceFn : _logoutFn)
                    .requestFocus(),
            onTap: () => _removePin(context, cubit, profile),
          ),
        if (profile.deviceTrusted)
          SettingsNavRow(
            icon: Icons.phonelink_erase_rounded,
            label: 'Dimentica questo dispositivo',
            subtitle: 'Richiederà di nuovo il PIN qui',
            focusNode: _forgetDeviceFn,
            onFocusUp: () =>
                (profile.pinProtected ? _removePinFn : _pinFn).requestFocus(),
            onFocusDown: () => _logoutFn.requestFocus(),
            onTap: () => _confirmForgetDevice(context, cubit),
          ),
        const SettingsSectionHeader('Sessione'),
        SettingsNavRow(
          icon: Icons.switch_account_rounded,
          label: 'Cambia profilo',
          subtitle: 'Torna alla schermata dei profili',
          focusNode: _logoutFn,
          onFocusUp: () => (profile.deviceTrusted
                  ? _forgetDeviceFn
                  : (profile.pinProtected ? _removePinFn : _pinFn))
              .requestFocus(),
          onFocusDown: () => _deleteFn.requestFocus(),
          onTap: () => _showLogoutDialog(context),
        ),
        const SettingsSectionHeader('Zona pericolosa'),
        SettingsNavRow(
          icon: Icons.delete_forever_rounded,
          label: 'Elimina profilo',
          subtitle: state.isOnlyProfile
              ? 'Non puoi eliminare l\'unico profilo del dispositivo'
              : null,
          enabled: !state.isOnlyProfile,
          focusNode: _deleteFn,
          onFocusUp: () => _logoutFn.requestFocus(),
          onTap: state.isOnlyProfile
              ? null
              : () => _showDeleteDialog(context, cubit),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── PIN management ─────────────────────────────────────────────────────────

Future<void> _managePin(BuildContext context, ProfileManagementCubit cubit,
    LocalProfile profile) async {
  final response = await showPinSetupDialog(context,
      profileId: profile.profileId, hasExistingPin: profile.pinProtected);
  if (response == null) return;
  await cubit.refresh();
  if (response.pinProtected && context.mounted) {
    // Setting/changing the PIN just revoked every device's trust for this
    // profile — this one included (see AuthRepository.setProfilePin's doc)
    // — so immediately offer to unlock again instead of leaving the
    // profile looking locked in its own settings screen.
    final unlocked = await showProfileUnlockDialog(context,
        profileId: profile.profileId, profileName: profile.profileName);
    if (unlocked) await cubit.refresh();
  }
}

Future<void> _removePin(BuildContext context, ProfileManagementCubit cubit,
    LocalProfile profile) async {
  final removed =
      await showPinRemoveDialog(context, profileId: profile.profileId);
  if (removed) await cubit.refresh();
}

Future<void> _confirmForgetDevice(
    BuildContext context, ProfileManagementCubit cubit) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(dialogCtx).pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Dimenticare questo dispositivo?'),
        content: const Text(
          'La prossima volta dovrai inserire di nuovo il PIN per usare '
          'questo profilo su questo dispositivo.',
          style: TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            autofocus: true,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          DialogActionButton(
            label: 'Dimentica',
            primary: true,
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              cubit.forgetDevice();
            },
          ),
        ],
      ),
    ),
  );
}

// Avatars are picked from the bundled default set (see default_avatars.dart)
// instead of a pasted image URL — there's no comfortable way to type a URL
// on a remote, and a self-hosted app shouldn't need external image hosting
// just to set a profile picture.
Future<void> _showAvatarPickerDialog(BuildContext context,
    ProfileManagementCubit cubit, String currentAvatarUrl) async {
  final initialIndex = isDefaultAvatarUrl(currentAvatarUrl)
      ? defaultAvatarIndex(currentAvatarUrl)
      : 0;
  final index = await showDialog<int>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _AvatarPickerDialog(initialIndex: initialIndex),
  );
  if (index != null) await cubit.updateAvatarUrl(defaultAvatarUrlFor(index));
}

class _AvatarPickerDialog extends StatefulWidget {
  final int initialIndex;
  const _AvatarPickerDialog({required this.initialIndex});

  @override
  State<_AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<_AvatarPickerDialog> {
  // Owned by the State, not disposed after `await showDialog` — the old
  // shape disposed this FocusNode a frame before the exit transition
  // finished, so a focus handoff still in flight against it
  // (onDownFromLastRow) hit a disposed node. gridKey + cancelFn thread the
  // Down/Up connection both ways between the grid and the "Annulla" button.
  final _gridKey = GlobalKey<_AvatarPickerGridState>();
  final _cancelFn = FocusNode();

  @override
  void dispose() {
    _cancelFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(context).pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Scegli avatar'),
        content: _AvatarPickerGrid(
          key: _gridKey,
          initialIndex: widget.initialIndex,
          onSelected: (index) => Navigator.of(context).pop(index),
          onDownFromLastRow: () => _cancelFn.requestFocus(),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            focusNode: _cancelFn,
            onUp: () => _gridKey.currentState?.focusCurrent(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _AvatarPickerGrid extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onDownFromLastRow;
  const _AvatarPickerGrid({
    super.key,
    required this.initialIndex,
    required this.onSelected,
    this.onDownFromLastRow,
  });

  @override
  State<_AvatarPickerGrid> createState() => _AvatarPickerGridState();
}

class _AvatarPickerGridState extends State<_AvatarPickerGrid> {
  static const _columns = 5;
  late final _nodes = List.generate(kDefaultAvatars.length, (_) => FocusNode());
  late int _focused = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[_focused].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Re-focuses wherever the grid was left — the "Annulla" button below
  /// calls this on Up so leaving it lands back where the user actually was
  /// instead of always resetting to the first tile.
  void focusCurrent() {
    if (_focused >= 0 && _focused < _nodes.length) {
      _nodes[_focused].requestFocus();
    }
  }

  void _moveFocus(int delta) {
    final next = (_focused + delta).clamp(0, kDefaultAvatars.length - 1);
    if (next == _focused) return;
    setState(() => _focused = next);
    _nodes[next].requestFocus();
  }

  void _moveDown() {
    final next = _focused + _columns;
    if (next >= kDefaultAvatars.length) {
      widget.onDownFromLastRow?.call();
      return;
    }
    setState(() => _focused = next);
    _nodes[next].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tileSize = AppScale.space(context, 84);
    final gap = AppScale.space(context, 12);
    return SizedBox(
      width: _columns * tileSize + (_columns - 1) * gap,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < kDefaultAvatars.length; i++)
            TvFocusable(
              focusNode: _nodes[i],
              onActivate: () => widget.onSelected(i),
              onLeft: () => _moveFocus(-1),
              onRight: () => _moveFocus(1),
              onUp: () => _moveFocus(-_columns),
              onDown: _moveDown,
              builder: (context, isFocused) => Container(
                width: tileSize,
                height: tileSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isFocused ? AppTheme.primary : Colors.transparent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: DefaultAvatarView(index: i, size: tileSize - 6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Shown when the user turns the "Profilo predefinito" toggle ON while
// another profile already holds it — the default is a single slot, so this
// blocks the change and points at the profile to clear first.
Future<void> _showDefaultBlockedDialog(
    BuildContext context, String otherName) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(dialogCtx).pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Predefinito già assegnato'),
        content: Text(
          '«$otherName» è già impostato come profilo predefinito. '
          'Per usare questo profilo, disattiva prima il predefinito '
          'dalle impostazioni di «$otherName».',
          style: const TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          DialogActionButton(
            label: 'Ho capito',
            autofocus: true,
            primary: true,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
        ],
      ),
    ),
  );
}

// Confirmation shown when turning the "Profilo predefinito" toggle ON and
// the slot is free.
Future<void> _showSetDefaultDialog(
    BuildContext context, ProfileManagementCubit cubit) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(dialogCtx).pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Impostare come predefinito?'),
        content: const Text(
          'All\'avvio l\'app entrerà direttamente con questo profilo, '
          'saltando la schermata di selezione.',
          style: TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          DialogActionButton(
            label: 'Imposta',
            primary: true,
            // Unlike the destructive dialogs in this file (Elimina, Cambia
            // profilo), where defaulting focus to "Annulla" is the safety-
            // conscious choice, this one only confirms what the user just
            // asked for by flipping the switch — landing on "Annulla" here
            // instead meant a D-pad user pressing Select right away (the
            // natural reflex right after toggling something on) silently
            // cancelled it, and the switch just snapped back off with no
            // visible error: reported as "the default-profile toggle
            // doesn't work".
            autofocus: true,
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              cubit.setDefault(true);
            },
          ),
        ],
      ),
    ),
  );
}

// Dispatches AuthBloc.SwitchProfileEvent — goes back to the profile picker
// without unpairing the device (no admin PIN re-entry). LogoutEvent (the
// heavier "forget this device" action, forces /pairing) exists in the bloc
// but deliberately has no UI entry point on this per-profile screen — a
// profile row is the wrong place for a device-wide action. Navigation back
// to /profiles is handled by the app-wide listener in main.dart, not here.
Future<void> _showLogoutDialog(BuildContext context) async {
  final authBloc = context.read<AuthBloc>();
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(dialogCtx).pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Cambiare profilo?'),
        content: const Text(
          'Tornerai alla schermata di selezione dei profili.',
          style: TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            autofocus: true,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          DialogActionButton(
            label: 'Cambia profilo',
            primary: true,
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              authBloc.add(const SwitchProfileEvent());
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _showDeleteDialog(
  BuildContext context,
  ProfileManagementCubit cubit,
) async {
  String? error;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) {
        return TvFocusable(
          canRequestFocus: false,
          onEsc: () => Navigator.of(dialogCtx).pop(),
          builder: (context, _) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Eliminare questo profilo?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Questa azione non può essere annullata.',
                  style: TextStyle(color: AppTheme.textMid),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: AppScale.caption(dialogCtx))),
                ],
              ],
            ),
            actions: [
              DialogActionButton(
                label: 'Annulla',
                autofocus: true,
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
              DialogActionButton(
                label: 'Elimina',
                primary: true,
                primaryColor: Colors.red[700],
                onPressed: () async {
                  final ok = await cubit.delete();
                  if (!ok) {
                    setDialogState(
                        () => error = 'Errore durante l\'eliminazione');
                    return;
                  }
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
