import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/grpc/auth_interceptor.dart';
import '../../../../core/grpc/clients/auth_client.dart' show SetProfilePinResponse;
import '../../../../core/grpc/grpc_errors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/on_screen_keyboard.dart';
import '../../../../shared/widgets/on_screen_text_display.dart';
import '../../../../shared/widgets/settings/dialog_action_button.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import '../../data/auth_repository.dart';

/// Unlocks a PIN-protected profile — the dialog shown for a profile with
/// `pinProtected && !unlocked` (see LocalProfile's doc), whether the user
/// tapped it directly or AuthBloc bounced back here (an app-cold-start
/// default that couldn't auto-enter, or a mid-session ProfileLockedEvent).
///
/// Deliberately dumb about what happens next, same as
/// showSettingsTextInputDialog's `_AddProfileDialog` precedent: on success
/// it wires the interceptor (see below) and pops `true`; the caller is the
/// one that actually enters the profile (dispatch SelectProfileEvent) —
/// this dialog never touches AuthBloc directly.
Future<bool> showProfileUnlockDialog(
  BuildContext context, {
  required String profileId,
  required String profileName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => _ProfileUnlockDialog(
      profileId: profileId,
      profileName: profileName,
    ),
  );
  return result ?? false;
}

class _ProfileUnlockDialog extends StatefulWidget {
  final String profileId;
  final String profileName;
  const _ProfileUnlockDialog(
      {required this.profileId, required this.profileName});

  @override
  State<_ProfileUnlockDialog> createState() => _ProfileUnlockDialogState();
}

class _ProfileUnlockDialogState extends State<_ProfileUnlockDialog> {
  // Live on this State, not function-scoped locals disposed right after
  // `await showDialog` — see settings_text_dialog.dart's doc for the red-
  // screen-during-transition race that shape causes.
  late final _pinController = TextEditingController();
  final _fieldFn = FocusNode();
  final _keyboardKey = GlobalKey<OnScreenKeyboardState>();
  final _rememberFn = FocusNode();
  final _cancelFn = FocusNode();
  final _confirmFn = FocusNode();

  // Default unchecked — "just this time" on a shared/guest device is the
  // safer default; the user opts into persistent trust explicitly.
  bool _remember = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldFn.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _fieldFn.dispose();
    _rememberFn.dispose();
    _cancelFn.dispose();
    _confirmFn.dispose();
    super.dispose();
  }

  void _pop([bool value = false]) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(value);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _pinController.text.trim();
    // 4-8 digits per proto/auth.proto's Profile PIN section — checked
    // client-side first so a too-short/too-long PIN never even reaches the
    // server (and never counts against the rate limit there).
    if (pin.length < 4 || pin.length > 8) {
      setState(() => _error = 'Il PIN deve avere 4-8 cifre.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = getIt<AuthRepository>();
      final response = await repo.unlockProfile(widget.profileId, pin,
          rememberDevice: _remember);
      if (!mounted) return;
      // Point the interceptor at this profile — with the SAME jwt/profileId
      // the caller's own SelectProfileEvent will set right after this
      // returns — *before* stashing the one-off session token below.
      // AuthInterceptor.setCredentials only clears that token on an actual
      // profile *change*; setting it here first, then letting the caller's
      // subsequent (now no-op) setCredentials call happen, is what keeps
      // the token from being wiped the instant it's set.
      final interceptor = getIt<AuthInterceptor>();
      final session = await repo.getStoredSession();
      if (session != null) {
        interceptor.setCredentials(session.deviceJwt, widget.profileId);
        if (!_remember && response.sessionToken.isNotEmpty) {
          interceptor.setProfileSessionToken(response.sessionToken);
        }
      }
      if (!mounted) return;
      _pop(true);
    } catch (e) {
      // Wrong PIN (PERMISSION_DENIED) or rate-limited (RESOURCE_EXHAUSTED)
      // both come with a message already written for the user — shown
      // verbatim, never toString().
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = grpcMessage(e);
      });
    }
  }

  void _toggleRemember() => setState(() => _remember = !_remember);

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => _pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'PIN di ${widget.profileName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ancestor-only catcher, same idiom as every other field+
                // OnScreenKeyboard pair in the app — EditableText only binds
                // left/right itself, so Down is free to hand off here.
                TvFocusable(
                  canRequestFocus: false,
                  onDown: () => _keyboardKey.currentState?.firstFocusNode
                      .requestFocus(),
                  builder: (context, _) => OnScreenTextDisplay(
                    controller: _pinController,
                    focusNode: _fieldFn,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 8,
                    ),
                    fillColor: AppTheme.bg,
                    borderColor: AppTheme.border,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                OnScreenKeyboard(
                  key: _keyboardKey,
                  controller: _pinController,
                  digitsOnly: true,
                  // Previously only enforced by the real TextField's own
                  // maxLength — which, like every other field's maxLength in
                  // this app, never actually applied to on-screen-keyboard
                  // input in the first place (it writes straight into the
                  // controller, bypassing TextField's input formatters
                  // entirely). _submit() still validates length server-side
                  // too, so this was never a silent-acceptance bug, just a
                  // "didn't visually stop you at 8" one.
                  maxLength: 8,
                  onSubmit: _submit,
                  onNavigateUp: () => _fieldFn.requestFocus(),
                  onNavigateDown: () => _rememberFn.requestFocus(),
                ),
                const SizedBox(height: 16),
                _RememberDeviceToggle(
                  value: _remember,
                  focusNode: _rememberFn,
                  onToggle: _toggleRemember,
                  onUp: () => _keyboardKey.currentState?.focusLastRow(),
                  onDown: () => _cancelFn.requestFocus(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            focusNode: _cancelFn,
            onPressed: _submitting ? null : () => _pop(),
            onUp: () => _rememberFn.requestFocus(),
            onRight: () => _confirmFn.requestFocus(),
          ),
          DialogActionButton(
            label: 'Sblocca',
            primary: true,
            focusNode: _confirmFn,
            onPressed: _submitting ? null : _submit,
            onUp: () => _rememberFn.requestFocus(),
            onLeft: () => _cancelFn.requestFocus(),
          ),
        ],
      ),
    );
  }
}

class _RememberDeviceToggle extends StatelessWidget {
  final bool value;
  final FocusNode focusNode;
  final VoidCallback onToggle;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  const _RememberDeviceToggle({
    required this.value,
    required this.focusNode,
    required this.onToggle,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C6AF7);
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onToggle,
      onUp: onUp,
      onDown: onDown,
      builder: (context, focused) => GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: focused ? accent : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: value ? accent : Colors.transparent,
                  border: Border.all(
                    color: value ? accent : Colors.white38,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: value
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ricorda su questo dispositivo',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Set / change / remove PIN ────────────────────────────────────────────

/// Sets or changes a profile's PIN — a short step wizard on the same
/// digits-only keyboard as [showProfileUnlockDialog]: current PIN first
/// (only if [hasExistingPin]), then the new one, then a confirm step so a
/// mistyped new PIN doesn't lock the profile out from a typo. Performs the
/// SetProfilePin RPC itself and returns the raw response (null if
/// cancelled) — the caller should immediately re-offer
/// [showProfileUnlockDialog] when `response.pinProtected` comes back true:
/// the server just revoked every device's trust for this profile,
/// including this one (see AuthRepository.setProfilePin's doc).
Future<SetProfilePinResponse?> showPinSetupDialog(
  BuildContext context, {
  required String profileId,
  required bool hasExistingPin,
}) {
  return showDialog<SetProfilePinResponse>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _PinSetupDialog(
      profileId: profileId,
      hasExistingPin: hasExistingPin,
    ),
  );
}

/// Removes a profile's PIN — same current-PIN check as changing it, just
/// with an empty new PIN. Returns true once the server confirms the profile
/// is no longer protected.
Future<bool> showPinRemoveDialog(BuildContext context,
    {required String profileId}) async {
  final response = await showDialog<SetProfilePinResponse>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _PinSetupDialog(
      profileId: profileId,
      hasExistingPin: true,
      removeMode: true,
    ),
  );
  return response != null && !response.pinProtected;
}

enum _PinStep { current, newPin, confirm }

class _PinSetupDialog extends StatefulWidget {
  final String profileId;
  final bool hasExistingPin;
  final bool removeMode;
  const _PinSetupDialog({
    required this.profileId,
    required this.hasExistingPin,
    this.removeMode = false,
  });

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  late _PinStep _step =
      widget.hasExistingPin ? _PinStep.current : _PinStep.newPin;
  late final _pinController = TextEditingController();
  final _fieldFn = FocusNode();
  final _keyboardKey = GlobalKey<OnScreenKeyboardState>();
  final _cancelFn = FocusNode();
  final _nextFn = FocusNode();
  String _currentPin = '';
  String _newPin = '';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldFn.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _fieldFn.dispose();
    _cancelFn.dispose();
    _nextFn.dispose();
    super.dispose();
  }

  void _pop([SetProfilePinResponse? value]) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(value);
  }

  String get _title {
    if (widget.removeMode) return 'Rimuovi PIN — PIN attuale';
    return switch (_step) {
      _PinStep.current => 'PIN attuale',
      _PinStep.newPin => widget.hasExistingPin ? 'Nuovo PIN' : 'Imposta un PIN',
      _PinStep.confirm => 'Conferma il nuovo PIN',
    };
  }

  String get _confirmLabel =>
      widget.removeMode || _step == _PinStep.confirm ? 'Conferma' : 'Avanti';

  void _advance() {
    final pin = _pinController.text.trim();
    if (pin.length < 4 || pin.length > 8) {
      setState(() => _error = 'Il PIN deve avere 4-8 cifre.');
      return;
    }
    switch (_step) {
      case _PinStep.current:
        _currentPin = pin;
        if (widget.removeMode) {
          _submit();
          return;
        }
        setState(() {
          _step = _PinStep.newPin;
          _pinController.clear();
          _error = null;
        });
        return;
      case _PinStep.newPin:
        _newPin = pin;
        setState(() {
          _step = _PinStep.confirm;
          _pinController.clear();
          _error = null;
        });
        return;
      case _PinStep.confirm:
        if (pin != _newPin) {
          setState(() {
            _error = 'I PIN non coincidono.';
            _step = _PinStep.newPin;
            _newPin = '';
            _pinController.clear();
          });
          return;
        }
        _submit();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final response = await getIt<AuthRepository>().setProfilePin(
        widget.profileId,
        currentPin: _currentPin,
        newPin: widget.removeMode ? '' : _newPin,
      );
      if (!mounted) return;
      _pop(response);
    } catch (e) {
      // A wrong current PIN is the only realistic failure past client-side
      // length validation — back up to that step (if there was one) so the
      // user can retry instead of restarting the whole wizard.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = grpcMessage(e);
        if (widget.hasExistingPin) {
          _step = _PinStep.current;
          _currentPin = '';
          _pinController.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => _pop(),
      builder: (context, _) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(_title),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TvFocusable(
                  canRequestFocus: false,
                  onDown: () => _keyboardKey.currentState?.firstFocusNode
                      .requestFocus(),
                  builder: (context, _) => OnScreenTextDisplay(
                    controller: _pinController,
                    focusNode: _fieldFn,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 8,
                    ),
                    fillColor: AppTheme.bg,
                    borderColor: AppTheme.border,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                OnScreenKeyboard(
                  key: _keyboardKey,
                  controller: _pinController,
                  digitsOnly: true,
                  // See the first PIN field's identical doc.
                  maxLength: 8,
                  onSubmit: _advance,
                  onNavigateUp: () => _fieldFn.requestFocus(),
                  onNavigateDown: () => _cancelFn.requestFocus(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          DialogActionButton(
            label: 'Annulla',
            focusNode: _cancelFn,
            onPressed: _submitting ? null : () => _pop(),
            onUp: () => _keyboardKey.currentState?.focusLastRow(),
            onRight: () => _nextFn.requestFocus(),
          ),
          DialogActionButton(
            label: _confirmLabel,
            primary: true,
            focusNode: _nextFn,
            onPressed: _submitting ? null : _advance,
            onUp: () => _keyboardKey.currentState?.focusLastRow(),
            onLeft: () => _cancelFn.requestFocus(),
          ),
        ],
      ),
    );
  }
}
