import 'package:flutter/material.dart';

import '../di/injection.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../../shared/widgets/settings/dialog_action_button.dart';
import '../../shared/widgets/tv_focusable.dart';
import 'update_service.dart';

/// Runs an update check and, if a newer release is out (and the user hasn't
/// dismissed that exact version), shows a one-shot informational dialog.
///
/// Non-blocking and best-effort: any failure — feature disabled, offline,
/// rate-limited — is a silent no-op. Safe to call unconditionally from a
/// screen's post-frame callback.
Future<void> maybePromptForUpdate(BuildContext context) async {
  final UpdateService service;
  try {
    service = getIt<UpdateService>();
  } catch (_) {
    return; // not registered (shouldn't happen) — bail quietly
  }

  final info = await service.check();
  if (info == null || !info.updateAvailable) return;
  if (service.dismissedVersion == info.latestVersion) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogCtx) => TvFocusable(
      canRequestFocus: false,
      onEsc: () => Navigator.of(dialogCtx).pop(),
      builder: (_, __) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded,
                color: AppTheme.primary, size: 22),
            SizedBox(width: 10),
            Expanded(child: Text('Aggiornamento disponibile')),
          ],
        ),
        content: _UpdateBody(info: info),
        actions: [
          DialogActionButton(
            label: 'Ignora questa versione',
            onPressed: () {
              service.dismiss(info.latestVersion);
              Navigator.of(dialogCtx).pop();
            },
          ),
          DialogActionButton(
            label: 'Più tardi',
            primary: true,
            autofocus: true,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
        ],
      ),
    ),
  );
}

class _UpdateBody extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateBody({required this.info});

  @override
  Widget build(BuildContext context) {
    final notes = info.releaseNotes.isEmpty
        ? null
        : info.releaseNotes
            .split('\n')
            .map((l) => l.trimRight())
            .where((l) => l.isNotEmpty)
            .take(8)
            .join('\n');

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: AppScale.space(context, 520)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.isPrerelease
                ? '${info.releaseName}  ·  beta'
                : info.releaseName,
            style: const TextStyle(
                color: AppTheme.textHigh, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Nuova versione ${info.latestVersion} — hai la ${info.currentVersion}.',
            style: const TextStyle(color: AppTheme.textMid),
          ),
          if (notes != null) ...[
            const SizedBox(height: 12),
            Text('Novità',
                style: TextStyle(
                    color: AppTheme.textLow,
                    fontSize: AppScale.caption(context),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: AppScale.space(context, 220)),
              child: SingleChildScrollView(
                child: Text(notes,
                    style: TextStyle(
                        color: AppTheme.textMid,
                        fontSize: AppScale.caption(context),
                        height: 1.5)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Aggiorna dal gestore che usi per il sideload (es. Obtainium su '
            'Android) o dal gestore pacchetti su Linux.',
            style: TextStyle(
                color: AppTheme.textLow, fontSize: AppScale.caption(context)),
          ),
        ],
      ),
    );
  }
}
