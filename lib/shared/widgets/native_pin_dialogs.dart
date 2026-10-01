import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/auth_interceptor.dart';
import '../../core/grpc/clients/auth_client.dart' show SetProfilePinResponse;
import '../../core/grpc/grpc_errors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/data/auth_repository.dart';

/// Native-widget counterpart of
/// features/auth/presentation/widgets/profile_pin_dialog.dart, for the three
/// screens built on plain TextField/AlertDialog + the platform's own soft
/// keyboard instead of TvFocusable/OnScreenKeyboard — desktop_profiles_
/// screen.dart, mobile_profiles_screen.dart, desktop_settings_pane.dart and
/// mobile_profile_settings_screen.dart (matching showTextPrompt, which those
/// same screens already use for renaming). Same RPCs and interceptor wiring
/// as the TV dialog either way.

Widget _pinField(TextEditingController controller,
    {String? label, String? errorText, VoidCallback? onSubmitted}) {
  return TextField(
    controller: controller,
    autofocus: true,
    obscureText: true,
    obscuringCharacter: '•',
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    maxLength: 8,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 22, letterSpacing: 8),
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      errorText: errorText,
    ),
    onSubmitted: (_) => onSubmitted?.call(),
  );
}

/// Unlocks a PIN-protected profile — see the TV dialog's doc for the
/// interceptor-ordering reasoning (setCredentials before
/// setProfileSessionToken, so the caller's own follow-up SelectProfileEvent
/// doesn't wipe the token the instant it's set).
Future<bool> showNativePinUnlockDialog(
  BuildContext context, {
  required String profileId,
  required String profileName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _NativePinUnlockDialog(
      profileId: profileId,
      profileName: profileName,
    ),
  );
  return result ?? false;
}

class _NativePinUnlockDialog extends StatefulWidget {
  final String profileId;
  final String profileName;
  const _NativePinUnlockDialog(
      {required this.profileId, required this.profileName});

  @override
  State<_NativePinUnlockDialog> createState() =>
      _NativePinUnlockDialogState();
}

class _NativePinUnlockDialogState extends State<_NativePinUnlockDialog> {
  late final _ctrl = TextEditingController();
  bool _remember = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _ctrl.text.trim();
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
      final interceptor = getIt<AuthInterceptor>();
      final session = await repo.getStoredSession();
      if (session != null) {
        interceptor.setCredentials(session.deviceJwt, widget.profileId);
        if (!_remember && response.sessionToken.isNotEmpty) {
          interceptor.setProfileSessionToken(response.sessionToken);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = grpcMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Row(children: [
        const Icon(Icons.lock_outline, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text('PIN di ${widget.profileName}',
                overflow: TextOverflow.ellipsis)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pinField(_ctrl, errorText: _error, onSubmitted: _submit),
          CheckboxListTile(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Ricorda su questo dispositivo'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Sblocca'),
        ),
      ],
    );
  }
}

/// Sets/changes a profile's PIN — current PIN first (if [hasExistingPin]),
/// then the new one twice (entry + confirm). Returns the raw response
/// (null if cancelled); the caller should re-offer
/// [showNativePinUnlockDialog] when `response.pinProtected` comes back true
/// — see AuthRepository.setProfilePin's doc for why (every device's trust,
/// including this one, was just revoked).
Future<SetProfilePinResponse?> showNativePinSetupDialog(
  BuildContext context, {
  required String profileId,
  required bool hasExistingPin,
}) {
  return showDialog<SetProfilePinResponse>(
    context: context,
    builder: (_) => _NativePinSetupDialog(
        profileId: profileId, hasExistingPin: hasExistingPin),
  );
}

/// Removes a profile's PIN (current PIN required, new PIN empty). Returns
/// true once the server confirms the profile is no longer protected.
Future<bool> showNativePinRemoveDialog(BuildContext context,
    {required String profileId}) async {
  final response = await showDialog<SetProfilePinResponse>(
    context: context,
    builder: (_) => _NativePinSetupDialog(
        profileId: profileId, hasExistingPin: true, removeMode: true),
  );
  return response != null && !response.pinProtected;
}

enum _NativePinStep { current, newPin, confirm }

class _NativePinSetupDialog extends StatefulWidget {
  final String profileId;
  final bool hasExistingPin;
  final bool removeMode;
  const _NativePinSetupDialog({
    required this.profileId,
    required this.hasExistingPin,
    this.removeMode = false,
  });

  @override
  State<_NativePinSetupDialog> createState() => _NativePinSetupDialogState();
}

class _NativePinSetupDialogState extends State<_NativePinSetupDialog> {
  late _NativePinStep _step =
      widget.hasExistingPin ? _NativePinStep.current : _NativePinStep.newPin;
  late final _ctrl = TextEditingController();
  String _currentPin = '';
  String _newPin = '';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.removeMode) return 'Rimuovi PIN';
    return switch (_step) {
      _NativePinStep.current => 'PIN attuale',
      _NativePinStep.newPin =>
        widget.hasExistingPin ? 'Nuovo PIN' : 'Imposta un PIN',
      _NativePinStep.confirm => 'Conferma il nuovo PIN',
    };
  }

  void _advance() {
    final pin = _ctrl.text.trim();
    if (pin.length < 4 || pin.length > 8) {
      setState(() => _error = 'Il PIN deve avere 4-8 cifre.');
      return;
    }
    switch (_step) {
      case _NativePinStep.current:
        _currentPin = pin;
        if (widget.removeMode) {
          _submit();
          return;
        }
        setState(() {
          _step = _NativePinStep.newPin;
          _ctrl.clear();
          _error = null;
        });
        return;
      case _NativePinStep.newPin:
        _newPin = pin;
        setState(() {
          _step = _NativePinStep.confirm;
          _ctrl.clear();
          _error = null;
        });
        return;
      case _NativePinStep.confirm:
        if (pin != _newPin) {
          setState(() {
            _error = 'I PIN non coincidono.';
            _step = _NativePinStep.newPin;
            _newPin = '';
            _ctrl.clear();
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
      Navigator.of(context).pop(response);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = grpcMessage(e);
        if (widget.hasExistingPin) {
          _step = _NativePinStep.current;
          _currentPin = '';
          _ctrl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(_title),
      content: _pinField(_ctrl, errorText: _error, onSubmitted: _advance),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _advance,
          child: Text(widget.removeMode || _step == _NativePinStep.confirm
              ? 'Conferma'
              : 'Avanti'),
        ),
      ],
    );
  }
}
