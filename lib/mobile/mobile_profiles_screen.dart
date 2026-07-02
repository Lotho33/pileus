import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/db/models/local_profile.dart';
import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/bloc/auth_state.dart';
import '../shared/widgets/default_avatars.dart';
import '../shared/widgets/text_prompt_dialog.dart';

/// Mobile profile picker: tap an avatar to enter, "+" to create one (system
/// keyboard dialog).
class MobileProfilesScreen extends StatefulWidget {
  const MobileProfilesScreen({super.key});

  @override
  State<MobileProfilesScreen> createState() => _MobileProfilesScreenState();
}

class _MobileProfilesScreenState extends State<MobileProfilesScreen> {
  List<LocalProfile> _profiles = const [];

  @override
  void initState() {
    super.initState();
    final s = getIt<AuthBloc>().state;
    if (s is ProfileSelectionRequired) _profiles = s.profiles;
  }

  Future<void> _create() async {
    final name = await showTextPrompt(
      context,
      title: 'Nuovo profilo',
      hint: 'Nome',
      confirmLabel: 'Crea',
    );
    if (name != null && name.isNotEmpty) {
      getIt<AuthBloc>().add(CreateProfileEvent(name: name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      bloc: getIt<AuthBloc>(),
      listener: (context, state) {
        if (state is ProfileSelectionRequired) {
          setState(() => _profiles = state.profiles);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.bg,
          title: const Text('Chi sta guardando?'),
        ),
        body: SafeArea(
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(20),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            children: [
              for (final p in _profiles)
                _ProfileTile(
                  profile: p,
                  onTap: () => getIt<AuthBloc>()
                      .add(SelectProfileEvent(p.profileId)),
                ),
              _AddTile(onTap: _create),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final LocalProfile profile;
  final VoidCallback onTap;
  const _ProfileTile({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isDefaultAvatarUrl(profile.avatarUrl)
                    ? DefaultAvatarView(
                        index: defaultAvatarIndex(profile.avatarUrl),
                        size: 96,
                      )
                    : profile.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: profile.avatarUrl,
                            memCacheWidth: 256,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: AppTheme.surface2),
                          )
                        : const ColoredBox(color: AppTheme.surface2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.profileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textHigh),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(Icons.add_rounded,
                    color: AppTheme.textMid, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Aggiungi', style: TextStyle(color: AppTheme.textMid)),
        ],
      ),
    );
  }
}
