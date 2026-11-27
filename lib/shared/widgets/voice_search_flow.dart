// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/voice_search.dart';
import 'settings/dialog_action_button.dart';

/// The microphone button's action, on every screen with one: the words
/// heard, or null. A recognizer without a dialog of its own
/// ([VoiceMode.app]: Android's recognition service, the browser's) gets the
/// app's "listening" dialog meanwhile, with "Annulla" focused for the remote.
Future<String?> voiceSearch(BuildContext context) async {
  final mode = await VoiceSearch.mode();
  if (mode == VoiceMode.none || !context.mounted) return null;
  if (mode == VoiceMode.system) return VoiceSearch.listen();

  final heard = VoiceSearch.listen();
  var open = true;
  final dialog = showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _Listening(),
  ).whenComplete(() {
    // Closed by the user (Annulla, Back, a tap outside): stop listening.
    if (open) {
      open = false;
      VoiceSearch.cancel();
    }
  });
  final text = await heard;
  if (open && context.mounted) {
    open = false;
    Navigator.of(context, rootNavigator: true).pop();
  }
  await dialog;
  return text;
}

class _Listening extends StatelessWidget {
  const _Listening();

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            Icon(Icons.mic_rounded, size: 48, color: AppTheme.primary),
            SizedBox(height: 16),
            Text('Sto ascoltando…',
                style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Di\' cosa vuoi guardare',
                style: TextStyle(color: AppTheme.textMid, fontSize: 14)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          DialogActionButton(
            label: 'Annulla',
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
}
