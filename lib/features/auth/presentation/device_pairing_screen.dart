import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_scale.dart';
import '../../../shared/widgets/on_screen_keyboard.dart';
import '../../../shared/widgets/on_screen_text_display.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../friendly_error.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  final _submitFn = FocusNode();
  final _changeServerFn = FocusNode();
  final _keyboardKey = GlobalKey<OnScreenKeyboardState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    _submitFn.dispose();
    _changeServerFn.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    context.read<AuthBloc>().add(AuthenticateDeviceEvent(pin));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ProfileSelectionRequired) context.go('/profiles');
        if (state is AuthenticatedState) context.go('/home');
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyPairingErrorMessage(state.message)),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Stack(
          children: [
            // Ambient radial glow
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.0,
                    colors: [Color(0x287C6AF7), Color(0x000D0D1A)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: AppScale.space(context, 32),
                            horizontal: AppScale.space(context, 16)),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: AppScale.space(context, 480)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Pileus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppScale.space(context, 62),
                                  letterSpacing: 2.0,
                                ),
                              ),
                              SizedBox(height: AppScale.space(context, 8)),
                              Text(
                                'Connettiti a Mycelium',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: AppScale.label(context),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: AppScale.space(context, 40)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppScale.space(context, 40),
                                    vertical: AppScale.space(context, 36)),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141428),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFF2A2A4A), width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Codice di abbinamento',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: AppScale.caption(context),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    SizedBox(
                                        height: AppScale.space(context, 4)),
                                    Text(
                                      'Generato dalla dashboard admin di '
                                      'Mycelium — scade dopo pochi minuti.',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize:
                                            AppScale.caption(context) * 0.85,
                                      ),
                                    ),
                                    SizedBox(
                                        height: AppScale.space(context, 10)),
                                    _PairingCodeField(
                                      controller: _pinController,
                                      focusNode: _focusNode,
                                      onNavigateDown: () => _keyboardKey
                                          .currentState?.firstFocusNode
                                          .requestFocus(),
                                    ),
                                    SizedBox(
                                        height: AppScale.space(context, 14)),
                                    // A remote has no physical keyboard —
                                    // without this, the admin password
                                    // (arbitrary text) had no way to be
                                    // typed at all, blocking first-run
                                    // pairing entirely on a D-pad-only
                                    // device.
                                    OnScreenKeyboard(
                                      key: _keyboardKey,
                                      controller: _pinController,
                                      upperAlphanumericOnly: true,
                                      // Up from 6: the demo
                                      // instance store reviewers connect to
                                      // uses a longer static code, not the
                                      // usual short rotating one.
                                      maxLength: 16,
                                      // No "Invio": the code is confirmed
                                      // with the button below, and the
                                      // layer already has no Space.
                                      showEnter: false,
                                      onSubmit: () => _submit(context),
                                      onNavigateUp: () =>
                                          _focusNode.requestFocus(),
                                      onNavigateDown: () =>
                                          _submitFn.requestFocus(),
                                    ),
                                    SizedBox(
                                        height: AppScale.space(context, 20)),
                                    BlocBuilder<AuthBloc, AuthState>(
                                      builder: (context, state) {
                                        return PileusLoadingSwitcher(
                                          isLoading: state is AuthLoading,
                                          spinnerSize:
                                              AppScale.spinnerL(context),
                                          child: _SubmitButton(
                                            focusNode: _submitFn,
                                            onNavigateUp: () => _keyboardKey
                                                .currentState?.firstFocusNode
                                                .requestFocus(),
                                            onNavigateDown: () =>
                                                _changeServerFn.requestFocus(),
                                            onPressed: () => _submit(context),
                                          ),
                                        );
                                      },
                                    ),
                                    // Auto-discovery (configureDependencies(),
                                    // once at cold start) silently points
                                    // this screen at whatever LAN server
                                    // answered first — no manual-entry screen
                                    // ever shown when that succeeds. Without
                                    // this, a device on a LAN with more than
                                    // one Mycelium (or the wrong one for this
                                    // device) had no way back to that field.
                                    SizedBox(
                                        height: AppScale.space(context, 8)),
                                    _TextActionButton(
                                      label: 'Cambia server',
                                      focusNode: _changeServerFn,
                                      onNavigateUp: () =>
                                          _submitFn.requestFocus(),
                                      onPressed: () => context
                                          .read<AuthBloc>()
                                          .add(const ChangeServerEvent()),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: AppScale.space(context, 24)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A short-lived pairing code, not a password — nothing here needs
// obscuring, so this is a plain read-only display field (no eye toggle,
// no obscureText/visiblePassword left over from an earlier, mistaken
// "it's a secret" framing).
class _PairingCodeField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onNavigateDown;
  const _PairingCodeField({
    required this.controller,
    required this.focusNode,
    required this.onNavigateDown,
  });

  @override
  Widget build(BuildContext context) {
    // Ancestor-only catcher — arrowDown is free to bubble up here and hand
    // off to the on-screen keyboard below, same idiom used throughout the
    // app wherever a display field is paired with one.
    return TvFocusable(
      canRequestFocus: false,
      onDown: onNavigateDown,
      builder: (context, _) => OnScreenTextDisplay(
        controller: controller,
        focusNode: focusNode,
        hintText: 'es. 8H7K12',
        hintStyle: TextStyle(
            color: Colors.white24, fontSize: AppScale.label(context)),
        style:
            TextStyle(color: Colors.white, fontSize: AppScale.label(context)),
        fillColor: const Color(0xFF0D0D1A),
        borderColor: const Color(0xFF2A2A4A),
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 20),
            vertical: AppScale.space(context, 18)),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final VoidCallback onPressed;
  const _SubmitButton(
      {this.focusNode,
      this.onNavigateUp,
      this.onNavigateDown,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onUp: onNavigateUp,
      onDown: onNavigateDown,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: AppScale.space(context, 56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: focused
                ? [const Color(0xFF9D8FFF), const Color(0xFF7C6AF7)]
                : [const Color(0xFF7C6AF7), const Color(0xFF5A4FD4)],
          ),
          boxShadow: focused
              ? AppScale.focusGlow(const Color(0xFF7C6AF7),
                  alpha: 0x55 / 255, blur: 20)
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          'Autorizza',
          style: TextStyle(
            color: Colors.white,
            fontSize: AppScale.label(context),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// Same look as server_discovery_screen.dart's identical private widget —
// kept separate rather than shared since each screen's focus chain is its
// own small, self-contained loop.
class _TextActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  const _TextActionButton({
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.onNavigateUp,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onUp: onNavigateUp,
      builder: (context, focused) => Padding(
        padding: EdgeInsets.symmetric(vertical: AppScale.space(context, 8)),
        child: Text(
          label,
          style: TextStyle(
            color: focused ? Colors.white : Colors.white38,
            fontSize: AppScale.caption(context),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
