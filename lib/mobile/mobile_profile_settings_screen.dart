import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/bloc/auth_state.dart';
import '../features/settings/bloc/profile_management_cubit.dart';
import '../features/settings/bloc/profile_management_state.dart';
import '../shared/widgets/default_avatars.dart';
import 'mobile_router.dart';
import '../shared/widgets/text_prompt_dialog.dart';

class MobileProfileSettingsScreen extends StatelessWidget {
  const MobileProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activeId = switch (context.read<AuthBloc>().state) {
      AuthenticatedState(:final activeProfileId) => activeProfileId,
      _ => '',
    };
    return BlocProvider(
      create: (_) => getIt<ProfileManagementCubit>()..load(activeId),
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: const Text('Profilo'),
      ),
      body: BlocConsumer<ProfileManagementCubit, ProfileMgmtState>(
        listener: (context, state) {
          if (state is ProfileMgmtDeleted) mobileRouter.go('/profiles');
          if (state is ProfileMgmtError) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is ProfileMgmtLoading || state is ProfileMgmtInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is! ProfileMgmtLoaded) {
            return const Center(
              child: Text('Profilo non disponibile',
                  style: TextStyle(color: AppTheme.textMid)),
            );
          }
          final cubit = context.read<ProfileManagementCubit>();
          final p = state.profile;
          return ListView(
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: SizedBox(
                  width: 44,
                  height: 44,
                  child: ClipOval(
                    child: isDefaultAvatarUrl(p.avatarUrl)
                        ? DefaultAvatarView(
                            index: defaultAvatarIndex(p.avatarUrl), size: 44)
                        : const ColoredBox(color: AppTheme.surface2),
                  ),
                ),
                title: Text(p.profileName,
                    style: const TextStyle(color: AppTheme.textHigh)),
                subtitle: const Text('Tocca per rinominare',
                    style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
                onTap: () => _rename(context, cubit, p.profileName),
              ),
              ListTile(
                leading:
                    const Icon(Icons.face_outlined, color: AppTheme.textMid),
                title: const Text('Avatar',
                    style: TextStyle(color: AppTheme.textHigh)),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textLow),
                onTap: () => _pickAvatar(context, cubit),
              ),
              const Divider(color: AppTheme.border),
              SwitchListTile(
                value: state.isDefault,
                onChanged: (v) {
                  if (v && state.otherDefaultName != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Predefinito già assegnato a "${state.otherDefaultName}".')));
                    return;
                  }
                  cubit.setDefault(v);
                },
                title: const Text('Profilo predefinito',
                    style: TextStyle(color: AppTheme.textHigh)),
                subtitle: const Text('Saltato il selettore all\'avvio',
                    style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined,
                    color: AppTheme.textMid),
                title: const Text('Cambia profilo',
                    style: TextStyle(color: AppTheme.textHigh)),
                onTap: () => getIt<AuthBloc>().add(const SwitchProfileEvent()),
              ),
              const Divider(color: AppTheme.border),
              ListTile(
                enabled: !state.isOnlyProfile,
                leading:
                    const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                title: const Text('Elimina profilo',
                    style: TextStyle(color: Color(0xFFFF6B6B))),
                subtitle: state.isOnlyProfile
                    ? const Text('Non puoi eliminare l\'unico profilo',
                        style: TextStyle(color: AppTheme.textLow, fontSize: 12))
                    : null,
                onTap: () => _confirmDelete(context, cubit),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _rename(BuildContext context, ProfileManagementCubit cubit,
      String current) async {
    final name = await showTextPrompt(
      context,
      title: 'Rinomina profilo',
      initial: current,
      confirmLabel: 'Salva',
    );
    if (name != null && name.isNotEmpty && name != current) {
      cubit.rename(name);
    }
  }

  Future<void> _pickAvatar(
      BuildContext context, ProfileManagementCubit cubit) async {
    final idx = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Scegli avatar'),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (var i = 0; i < kDefaultAvatars.length; i++)
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(i),
                  child: ClipOval(child: DefaultAvatarView(index: i, size: 60)),
                ),
            ],
          ),
        ),
      ),
    );
    if (idx != null) cubit.updateAvatarUrl(defaultAvatarUrlFor(idx));
  }

  Future<void> _confirmDelete(
      BuildContext context, ProfileManagementCubit cubit) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminare il profilo?'),
        content: const Text('L\'operazione non è reversibile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (yes == true) cubit.delete();
  }
}
