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

/// Desktop profile picker: a centred, hover-highlighted avatar wall — the
/// large-screen take on the mobile grid.
class DesktopProfilesScreen extends StatefulWidget {
  const DesktopProfilesScreen({super.key});

  @override
  State<DesktopProfilesScreen> createState() => _DesktopProfilesScreenState();
}

class _DesktopProfilesScreenState extends State<DesktopProfilesScreen> {
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
    // level listener (desktop_app.dart) is what reacted to it and navigated
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
                          onTap: () => _select(p),
                        ),
                      _AddTile(onTap: _create),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Escape hatch for the case none of the local profiles can
                // actually be reached from here — every one of them
                // PIN-protected and locked, with no way to back out and
                // connect to a different Mycelium instead.
                TextButton(
                  onPressed: () =>
                      getIt<AuthBloc>().add(const ChangeServerEvent()),
                  child: const Text('Cambia server'),
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
                                    // Web-only, no-op on every other platform — see image_sizing.dart's
                                    // "ImageRenderMethodForWeb.HttpGet" section for why every
                                    // CachedNetworkImage call site in the app sets this.
                                    imageRenderMethodForWeb:
                                        ImageRenderMethodForWeb.HttpGet,
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
                      if (p.pinProtected && !p.unlocked)
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
