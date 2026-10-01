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
import '../shared/widgets/native_pin_dialogs.dart';
import '../shared/widgets/text_prompt_dialog.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Mobile profile picker: tap an avatar to enter, "+" to create one (system
/// keyboard dialog).
class MobileProfilesScreen extends StatefulWidget {
  const MobileProfilesScreen({super.key});

  @override
  State<MobileProfilesScreen> createState() => _MobileProfilesScreenState();
}

class _MobileProfilesScreenState extends State<MobileProfilesScreen> {
  List<LocalProfile> _profiles = const [];
  // Dedupes _maybeOpenPinDialog between initState and the BlocListener below
  // — see initState's doc for why both exist.
  String? _handledPinProfileId;

  @override
  void initState() {
    super.initState();
    // BlocListener's `listener` only fires for emissions AFTER this screen
    // starts listening, never the one already current when it mounted —
    // and that's exactly the common case for openPinForProfileId: the app-
    // level listener (mobile_app.dart) is what reacted to it and navigated
    // here in the first place. Reading the bloc's current state directly
    // is what actually catches it.
    final s = getIt<AuthBloc>().state;
    if (s is ProfileSelectionRequired) {
      _profiles = s.profiles;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeOpenPinDialog(s);
      });
    }
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

  // Same as _selectProfile in profile_selection_screen.dart (TV) — a
  // pinProtected && !unlocked profile gets the PIN dialog first.
  Future<void> _select(LocalProfile profile) async {
    if (profile.pinProtected && !profile.unlocked) {
      final unlocked = await showNativePinUnlockDialog(context,
          profileId: profile.profileId, profileName: profile.profileName);
      if (!unlocked || !mounted) return;
    }
    getIt<AuthBloc>().add(SelectProfileEvent(profile.profileId));
  }

  // Runs once per emitted state, unlike a builder — the auto-open case: see
  // profile_selection_screen.dart's _maybeOpenPinDialog for the full
  // rationale (a remembered default that couldn't auto-enter, or a mid-
  // session ProfileLockedEvent bounce).
  Future<void> _maybeOpenPinDialog(ProfileSelectionRequired state) async {
    final pinFor = state.openPinForProfileId;
    if (pinFor == null || pinFor == _handledPinProfileId) return;
    _handledPinProfileId = pinFor;
    final profile =
        state.profiles.where((p) => p.profileId == pinFor).firstOrNull;
    if (profile == null) return;
    final unlocked = await showNativePinUnlockDialog(context,
        profileId: profile.profileId, profileName: profile.profileName);
    if (unlocked && mounted) {
      getIt<AuthBloc>().add(SelectProfileEvent(profile.profileId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      bloc: getIt<AuthBloc>(),
      listener: (context, state) {
        if (state is ProfileSelectionRequired) {
          setState(() => _profiles = state.profiles);
          _maybeOpenPinDialog(state);
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
                  onTap: () => _select(p),
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
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isDefaultAvatarUrl(profile.avatarUrl)
                        ? DefaultAvatarView(
                            index: defaultAvatarIndex(profile.avatarUrl),
                            size: 96,
                          )
                        : profile.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                // Web-only, no-op on every other platform — see image_sizing.dart's
                                // "ImageRenderMethodForWeb.HttpGet" section for why every
                                // CachedNetworkImage call site in the app sets this.
                                imageRenderMethodForWeb:
                                    ImageRenderMethodForWeb.HttpGet,
                                imageUrl: profile.avatarUrl,
                                memCacheWidth: 256,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const ColoredBox(
                                    color: AppTheme.surface2),
                              )
                            : const ColoredBox(color: AppTheme.surface2),
                  ),
                  if (profile.pinProtected && !profile.unlocked)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                        ),
                        child: const Icon(Icons.lock,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ],
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
