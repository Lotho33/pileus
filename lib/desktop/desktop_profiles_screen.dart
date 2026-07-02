import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/db/models/local_profile.dart';
import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/bloc/auth_state.dart';
import '../shared/widgets/text_prompt_dialog.dart';
import '../shared/widgets/default_avatars.dart';

/// Desktop profile picker: a centred, hover-highlighted avatar wall — the
/// large-screen take on the mobile grid.
class DesktopProfilesScreen extends StatefulWidget {
  const DesktopProfilesScreen({super.key});

  @override
  State<DesktopProfilesScreen> createState() => _DesktopProfilesScreenState();
}

class _DesktopProfilesScreenState extends State<DesktopProfilesScreen> {
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
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chi sta guardando?',
                  style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 40),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 28,
                    runSpacing: 28,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const double _kTile = 152;

class _ProfileTile extends StatefulWidget {
  final LocalProfile profile;
  final VoidCallback onTap;
  const _ProfileTile({required this.profile, required this.onTap});

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: _kTile,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _hover ? 1.04 : 1,
                duration: const Duration(milliseconds: 130),
                child: SizedBox(
                  width: _kTile,
                  height: _kTile,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: isDefaultAvatarUrl(p.avatarUrl)
                            ? DefaultAvatarView(
                                index: defaultAvatarIndex(p.avatarUrl),
                                size: _kTile)
                            : p.avatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: p.avatarUrl,
                                    memCacheWidth: 320,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const ColoredBox(
                                            color: AppTheme.surface2),
                                  )
                                : const ColoredBox(color: AppTheme.surface2),
                      ),
                      // Border drawn on top so it never eats into the avatar.
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _hover
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.profileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hover ? AppTheme.textHigh : AppTheme.textMid,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatefulWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  State<_AddTile> createState() => _AddTileState();
}

class _AddTileState extends State<_AddTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _kTile,
              height: _kTile,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hover ? AppTheme.primary : AppTheme.border,
                  width: _hover ? 2.5 : 1,
                ),
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppTheme.textMid, size: 44),
            ),
            const SizedBox(height: 12),
            const Text('Aggiungi',
                style: TextStyle(color: AppTheme.textMid, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
