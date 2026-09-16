import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/auth_bloc.dart';
import '../../../shared/utils/back_dispatch.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../core/db/models/local_profile.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/utils/image_sizing.dart';
import '../../../shared/widgets/default_avatars.dart';
import '../../../shared/widgets/on_screen_keyboard.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/settings/dialog_action_button.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  List<LocalProfile> _lastProfiles = [];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          context.go('/home');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        } else if (state is ProfileSelectionRequired) {
          _lastProfiles = state.profiles;
        }
      },
      builder: (context, state) {
        if (state is ProfileSelectionRequired) _lastProfiles = state.profiles;
        if (_lastProfiles.isNotEmpty || state is ProfileSelectionRequired) {
          return _ProfileSelectionView(profiles: _lastProfiles);
        }
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          body: Center(
              child: PileusSpinner(
                  size: AppScale.spinnerL(context),
                  color: const Color(0xFF7C6AF7))),
        );
      },
    );
  }
}

class _ProfileSelectionView extends StatefulWidget {
  final List<LocalProfile> profiles;
  const _ProfileSelectionView({required this.profiles});

  @override
  State<_ProfileSelectionView> createState() => _ProfileSelectionViewState();
}

class _ProfileSelectionViewState extends State<_ProfileSelectionView> {
  int _focusedIndex = 0;
  List<FocusNode> _fns = [];

  void _rebuildFns(int count) {
    for (final f in _fns) {
      f.dispose();
    }
    _fns = List.generate(count + 1, (_) => FocusNode());
  }

  @override
  void initState() {
    super.initState();
    _rebuildFns(widget.profiles.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fns.isNotEmpty) _fns[0].requestFocus();
    });
  }

  @override
  void didUpdateWidget(_ProfileSelectionView old) {
    super.didUpdateWidget(old);
    if (old.profiles.length != widget.profiles.length) {
      setState(() {
        _focusedIndex = 0;
        _rebuildFns(widget.profiles.length);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fns.isNotEmpty) _fns[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final f in _fns) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 900;
    // Responsive card size: ~10% of screen width, clamped 110–154 px
    final cardSize = (size.width * 0.10).clamp(110.0, 154.0);

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          final last = _fns.length - 1;
          final next = event.logicalKey == LogicalKeyboardKey.arrowLeft
              ? (_focusedIndex > 0 ? _focusedIndex - 1 : last)
              : (_focusedIndex < last ? _focusedIndex + 1 : 0);
          setState(() => _focusedIndex = next);
          _fns[next].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          if (context.canPop()) {
            if (consumeBackEvent()) context.pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.6),
                    radius: 1.2,
                    colors: [Color(0x337C6AF7), Color(0x000D0D1A)],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chi sta guardando?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppScale.title(context),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: AppScale.space(context, 64.8)),
                  // The window on the Linux/X11 dev target can still be
                  // settling into its final (fullscreen) geometry a frame or
                  // two after Flutter's first paint — see
                  // _enterNativeFullscreen() in main.dart — which briefly
                  // reports a smaller MediaQuery size before snapping to the
                  // real one. cardSize derives straight from that size, so
                  // the avatars and the add-profile card (same cardSize)
                  // used to visibly "pop" to their final size. Tweening the
                  // value itself smooths that out regardless of what causes
                  // cardSize to change, rather than chasing the window
                  // manager's timing.
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    tween: Tween<double>(end: cardSize),
                    builder: (context, animatedCardSize, _) => _ProfileRow(
                      profiles: widget.profiles,
                      fns: _fns,
                      focusedIndex: _focusedIndex,
                      onFocused: (i) => setState(() => _focusedIndex = i),
                      isWide: isWide,
                      cardSize: animatedCardSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile row ──────────────────────────────────────────────────────────────

class _ProfileRow extends StatelessWidget {
  final List<LocalProfile> profiles;
  final List<FocusNode> fns;
  final int focusedIndex;
  final void Function(int) onFocused;
  final bool isWide;
  final double cardSize;

  const _ProfileRow({
    required this.profiles,
    required this.fns,
    required this.focusedIndex,
    required this.onFocused,
    required this.isWide,
    required this.cardSize,
  });

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      ...profiles.asMap().entries.map((e) => _ProfileCard(
            profile: e.value,
            focusNode: fns[e.key],
            focused: focusedIndex == e.key,
            onFocused: () => onFocused(e.key),
            onSelect: () => context
                .read<AuthBloc>()
                .add(SelectProfileEvent(e.value.profileId)),
            cardSize: cardSize,
          )),
      _AddProfileCard(
        focusNode: fns[profiles.length],
        focused: focusedIndex == profiles.length,
        onFocused: () => onFocused(profiles.length),
        cardSize: cardSize,
      ),
    ];

    final wrapGap = AppScale.space(context, isWide ? 40 : 24);
    return Wrap(
      spacing: wrapGap,
      runSpacing: wrapGap,
      alignment: WrapAlignment.center,
      children: cards,
    );
  }
}

// ─── Profile card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final LocalProfile profile;
  final FocusNode focusNode;
  final bool focused;
  final VoidCallback onFocused;
  final VoidCallback onSelect;
  final double cardSize;

  const _ProfileCard({
    required this.profile,
    required this.focusNode,
    required this.focused,
    required this.onFocused,
    required this.onSelect,
    required this.cardSize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF7C6AF7),
      const Color(0xFF4FC3F7),
      const Color(0xFFE040FB),
      const Color(0xFF26A69A),
      const Color(0xFFEF5350),
    ];
    final accent = colors[profile.profileName.hashCode.abs() % colors.length];

    return Focus(
      focusNode: focusNode,
      onFocusChange: (v) {
        if (v) onFocused();
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onSelect,
        child: AnimatedScale(
          scale: focused ? AppScale.focusScaleCard : 1.0,
          duration: AppScale.focusDuration,
          curve: AppScale.focusCurve,
          child: SizedBox(
            width: cardSize + 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppScale.focusDuration,
                  curve: AppScale.focusCurve,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: focused ? accent : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: focused
                        ? AppScale.focusGlow(accent, alpha: 0.5, blur: 24)
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: isDefaultAvatarUrl(profile.avatarUrl)
                        ? DefaultAvatarView(
                            index: defaultAvatarIndex(profile.avatarUrl),
                            size: cardSize)
                        : profile.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                // Web-only, no-op on every other platform — see image_sizing.dart's
                                // "ImageRenderMethodForWeb.HttpGet" section for why every
                                // CachedNetworkImage call site in the app sets this.
                                imageRenderMethodForWeb:
                                    ImageRenderMethodForWeb.HttpGet,
                                imageUrl: profile.avatarUrl,
                                width: cardSize,
                                height: cardSize,
                                fit: BoxFit.cover,
                                memCacheWidth: cacheWidthFor(context, cardSize),
                                fadeInDuration:
                                    const Duration(milliseconds: 200),
                                placeholder: (_, __) => _AvatarFallback(
                                  name: profile.profileName,
                                  accent: accent,
                                  size: cardSize,
                                ),
                                errorWidget: (_, __, ___) => _AvatarFallback(
                                  name: profile.profileName,
                                  accent: accent,
                                  size: cardSize,
                                ),
                              )
                            : _AvatarFallback(
                                name: profile.profileName,
                                accent: accent,
                                size: cardSize),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.profileName,
                  style: TextStyle(
                    color: focused ? Colors.white : Colors.white70,
                    fontSize: AppScale.caption(context),
                    fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  final Color accent;
  final double size;
  const _AvatarFallback(
      {required this.name, required this.accent, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.8),
            accent.withValues(alpha: 0.3)
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Add profile card ─────────────────────────────────────────────────────────

class _AddProfileCard extends StatelessWidget {
  final FocusNode focusNode;
  final bool focused;
  final VoidCallback onFocused;
  final double cardSize;

  const _AddProfileCard({
    required this.focusNode,
    required this.focused,
    required this.onFocused,
    required this.cardSize,
  });

  Future<void> _showDialog(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddProfileDialog(),
    );
    if (name == null || !context.mounted) return;
    context.read<AuthBloc>().add(CreateProfileEvent(name: name));
  }

  @override
  Widget build(BuildContext context) {
    // Highlight is driven by the parent's `focused` flag (derived from
    // _focusedIndex), NOT by this widget's own FocusNode state — same as
    // _ProfileCard. After the "add profile" dialog closes, Flutter restores
    // keyboard focus to this card's node for a beat before the post-frame
    // requestFocus() moves it onto the freshly created profile; if the
    // highlight followed the real focus node it would light up here at the
    // same time as profile 0, so both cards looked selected and it wasn't
    // clear which one Select would hit.
    return TvFocusable(
      focusNode: focusNode,
      onFocusChange: (v) {
        if (v) onFocused();
      },
      onActivate: () => _showDialog(context),
      builder: (context, _) => AnimatedScale(
        scale: focused ? AppScale.focusScaleCard : 1.0,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        child: SizedBox(
          width: cardSize + 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppScale.focusDuration,
                curve: AppScale.focusCurve,
                width: cardSize,
                height: cardSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: focused ? Colors.white : Colors.white24,
                    width: 3,
                  ),
                  color: Colors.white.withValues(alpha: focused ? 0.08 : 0.04),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: focused ? Colors.white : Colors.white38,
                  size: cardSize * 0.35,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Aggiungi profilo',
                style: TextStyle(
                  color: focused ? Colors.white : Colors.white38,
                  fontSize: AppScale.caption(context),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add profile dialog ───────────────────────────────────────────────────────

class _AddProfileDialog extends StatefulWidget {
  const _AddProfileDialog();

  @override
  State<_AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<_AddProfileDialog> {
  final _nameCtrl = TextEditingController();
  final _nameFn = FocusNode();
  final _cancelFn = FocusNode();
  final _createFn = FocusNode();
  final _keyboardKey = GlobalKey<OnScreenKeyboardState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFn.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFn.dispose();
    _cancelFn.dispose();
    _createFn.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _nameFn.requestFocus();
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: TvFocusable(
        canRequestFocus: false,
        onEsc: () => Navigator.pop(context, null),
        builder: (context, _) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nuovo profilo',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: AppScale.label(context),
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                // Ancestor-only catcher — see server_discovery_screen.dart's
                // manual-address field for the same idiom. Was previously a
                // bare TextField with no D-pad-native way to type a name at
                // all.
                TvFocusable(
                  canRequestFocus: false,
                  onDown: () =>
                      _keyboardKey.currentState?.firstFocusNode.requestFocus(),
                  builder: (context, _) => TextField(
                    controller: _nameCtrl,
                    focusNode: _nameFn,
                    // See server_discovery_screen.dart's identical field for
                    // why — OnScreenKeyboard below is the only intended input
                    // source.
                    readOnly: true,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: AppScale.caption(context)),
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF7C6AF7)),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: 14),
                OnScreenKeyboard(
                  key: _keyboardKey,
                  controller: _nameCtrl,
                  // No "Invio" — the name is confirmed with the "Crea"
                  // button below. Space stays (names can have spaces).
                  showEnter: false,
                  onSubmit: _submit,
                  onNavigateUp: () => _nameFn.requestFocus(),
                  // Previously missing — the keyboard's own bottom row had
                  // nowhere to send focus on a Down press, so "Annulla"/"Crea"
                  // were unreachable by D-pad entirely.
                  onNavigateDown: () => _cancelFn.requestFocus(),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: DialogActionButton(
                        label: 'Annulla',
                        primary: false,
                        focusNode: _cancelFn,
                        onPressed: () => Navigator.pop(context, null),
                        onUp: () => _keyboardKey.currentState?.firstFocusNode
                            .requestFocus(),
                        onRight: () => _createFn.requestFocus(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DialogActionButton(
                        label: 'Crea',
                        primary: true,
                        focusNode: _createFn,
                        onPressed: _submit,
                        onUp: () => _keyboardKey.currentState?.firstFocusNode
                            .requestFocus(),
                        onLeft: () => _cancelFn.requestFocus(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
