import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/perf_profile.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ambient_glow_background.dart';
import '../../../shared/widgets/settings/settings_header.dart';
import '../../../shared/widgets/settings/settings_section_header.dart';
import '../../../shared/widgets/settings/settings_toggle_row.dart';
import '../../../shared/widgets/settings/subtitle_style_section.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/settings_cubit.dart';
import '../bloc/settings_state.dart';
import '../data/settings_repository.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SettingsCubit>()..load(),
      child: const _PreferencesBody(),
    );
  }
}

class _PreferencesBody extends StatefulWidget {
  const _PreferencesBody();

  @override
  State<_PreferencesBody> createState() => _PreferencesBodyState();
}

class _PreferencesBodyState extends State<_PreferencesBody> {
  final _backFn = FocusNode();

  @override
  void dispose() {
    _backFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      canRequestFocus: false,
      onEsc: () => context.pop(),
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: AmbientGlowBackground(
            child: Column(
          children: [
            SettingsHeader(
              title: 'Preferenze',
              focusNode: _backFn,
              autofocus: true,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, state) {
                  return PileusLoadingSwitcher(
                    isLoading: state is! SettingsLoaded,
                    spinnerSize: AppScale.spinnerL(context),
                    child: state is SettingsLoaded
                        ? _buildForm(context, state)
                        : const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _buildForm(BuildContext context, SettingsLoaded state) {
    final data = state.data;
    final cubit = context.read<SettingsCubit>();
    return ListView(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.screenHPad(context),
          vertical: AppScale.space(context, 12)),
      children: [
        const SettingsSectionHeader('Sottotitoli'),
        SubtitleStyleSection(
          fontSize: data.subtitleFontSize,
          color: data.subtitleColor,
          bgEnabled: data.subtitleBgEnabled,
          bottomPadding: data.subtitleBottomPadding,
          onFontSizeChanged: cubit.updateSubtitleFontSize,
          onColorChanged: cubit.updateSubtitleColor,
          onBgToggled: cubit.updateSubtitleBgEnabled,
          onPaddingChanged: cubit.updateSubtitleBottomPadding,
        ),
        SizedBox(height: AppScale.space(context, 12)),
        const SettingsSectionHeader('Player'),
        const _BufferPrefRow(),
        SizedBox(height: AppScale.space(context, 4)),
        const _LiveBufferPrefRow(),
        SizedBox(height: AppScale.space(context, 4)),
        const _LowPowerPrefRow(),
        if (!kIsWeb && Platform.isAndroid) ...[
          SizedBox(height: AppScale.space(context, 12)),
          const SettingsSectionHeader('Schermo TV'),
          const _OverscanPrefRow(),
        ],
        SizedBox(height: AppScale.space(context, 12)),
        const SettingsSectionHeader('Avanzate'),
        const _DiagnosticsPrefRow(),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// TV overscan compensation — left/right nudges the safe-area margin the
/// whole app is inset by on Android. Writing it updates
/// SettingsRepository.overscan (a ValueNotifier main.dart listens to), so
/// the border reflows live while you hold the D-pad. See
/// SettingsRepository.getOverscanPercent.
class _OverscanPrefRow extends StatefulWidget {
  const _OverscanPrefRow();

  @override
  State<_OverscanPrefRow> createState() => _OverscanPrefRowState();
}

class _OverscanPrefRowState extends State<_OverscanPrefRow> {
  final _repo = getIt<SettingsRepository>();
  late double _pct = _repo.getOverscanPercent();
  static const _step = 0.5;

  void _nudge(int dir) {
    final next =
        (_pct + dir * _step).clamp(0.0, SettingsRepository.overscanPercentMax);
    if (next == _pct) return;
    setState(() => _pct = next);
    _repo.setOverscanPercent(next);
  }

  @override
  Widget build(BuildContext context) {
    final captionFs =
        (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    final frac = _pct / SettingsRepository.overscanPercentMax;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 20),
          vertical: AppScale.space(context, 6)),
      child: TvFocusable(
        onLeft: () => _nudge(-1),
        onRight: () => _nudge(1),
        onFocusChange: (f) {
          if (f && context.mounted && Scrollable.maybeOf(context) != null) {
            Scrollable.ensureVisible(context,
                alignment: 0.5, duration: const Duration(milliseconds: 200));
          }
        },
        builder: (context, focused) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Margine schermo (overscan)',
                    style: TextStyle(
                        color: focused ? Colors.white : Colors.white54,
                        fontSize: captionFs)),
                const Spacer(),
                Text('${_pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: focused ? Colors.white : Colors.white54,
                        fontSize: captionFs)),
              ],
            ),
            SizedBox(height: AppScale.space(context, 8)),
            LayoutBuilder(
              builder: (context, cc) => Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 4,
                    width: cc.maxWidth * frac,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow:
                          focused ? AppScale.focusGlow(Colors.white) : null,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppScale.space(context, 6)),
            Text(
              'Alza il valore se la TV taglia i bordi dell\'immagine, '
              'abbassalo a 0 se non li taglia. Effetto immediato.',
              style:
                  TextStyle(color: Colors.white38, fontSize: captionFs * 0.9),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Diagnostica" — see SettingsRepository.getDiagnostics. Read once into
/// kPerfDiagnostics at startup, so a change needs an app restart.
class _DiagnosticsPrefRow extends StatefulWidget {
  const _DiagnosticsPrefRow();

  @override
  State<_DiagnosticsPrefRow> createState() => _DiagnosticsPrefRowState();
}

class _DiagnosticsPrefRowState extends State<_DiagnosticsPrefRow> {
  final _repo = getIt<SettingsRepository>();
  late bool _on = _repo.getDiagnostics();

  @override
  Widget build(BuildContext context) {
    final captionFs =
        (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsToggleRow(
          label: 'Diagnostica (log su adb)',
          value: _on,
          onChanged: (v) {
            setState(() => _on = v);
            _repo.setDiagnostics(v);
          },
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(AppScale.space(context, 24),
              AppScale.space(context, 4), AppScale.space(context, 24), 0),
          child: Text(
            'Scrive i log di performance del player in "adb logcat" '
            '(pileus/perf, pileus/jank). Solo per debug su un box specifico. '
            'Richiede il riavvio dell\'app.',
            style: TextStyle(color: Colors.white38, fontSize: captionFs * 0.9),
          ),
        ),
      ],
    );
  }
}

/// "Modalità hardware modesto" — see SettingsRepository.getLowPowerMode.
/// Self-contained like _BufferPrefRow: the player re-reads it on the next
/// playback, nothing else observes it.
class _LowPowerPrefRow extends StatefulWidget {
  const _LowPowerPrefRow();

  @override
  State<_LowPowerPrefRow> createState() => _LowPowerPrefRowState();
}

class _LowPowerPrefRowState extends State<_LowPowerPrefRow> {
  final _repo = getIt<SettingsRepository>();
  late bool _on = _repo.getLowPowerMode();

  @override
  Widget build(BuildContext context) {
    final captionFs =
        (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsToggleRow(
          label: 'Modalità hardware modesto',
          value: _on,
          onChanged: (v) {
            setState(() => _on = v);
            _repo.setLowPowerMode(v);
            // UI-side effects (no blur shaders, no route-scale) take effect
            // on the next screen build. A full effect still wants a restart
            // (image-cache ceiling is set once in main()).
            lowPowerUi = v;
          },
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(AppScale.space(context, 24),
              AppScale.space(context, 4), AppScale.space(context, 24), 0),
          child: Text(
            'Riduce blur ed effetti dell\'interfaccia su box lenti a scapito '
            'di un filo di resa visiva.',
            style: TextStyle(color: Colors.white38, fontSize: captionFs * 0.9),
          ),
        ),
      ],
    );
  }
}

/// Video demux buffer size (MiB), stored straight in SettingsRepository —
/// not reactive anywhere but the player, which re-reads it on the next
/// playback, so it doesn't need to go through SettingsCubit.
class _BufferPrefRow extends StatefulWidget {
  const _BufferPrefRow();

  @override
  State<_BufferPrefRow> createState() => _BufferPrefRowState();
}

class _BufferPrefRowState extends State<_BufferPrefRow> {
  final _repo = getIt<SettingsRepository>();
  late int _mib = _repo.getPlayerBufferMiB();
  static const _step = 8;

  void _nudge(int dir) {
    final next = (_mib + dir * _step).clamp(
        SettingsRepository.playerBufferMiBMin,
        SettingsRepository.playerBufferMiBMax);
    if (next == _mib) return;
    setState(() => _mib = next);
    _repo.setPlayerBufferMiB(next);
  }

  @override
  Widget build(BuildContext context) {
    final captionFs =
        (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    final frac = (_mib - SettingsRepository.playerBufferMiBMin) /
        (SettingsRepository.playerBufferMiBMax -
            SettingsRepository.playerBufferMiBMin);
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 20),
          vertical: AppScale.space(context, 6)),
      child: TvFocusable(
        onLeft: () => _nudge(-1),
        onRight: () => _nudge(1),
        onFocusChange: (f) {
          if (f && context.mounted && Scrollable.maybeOf(context) != null) {
            Scrollable.ensureVisible(context,
                alignment: 0.5, duration: const Duration(milliseconds: 200));
          }
        },
        builder: (context, focused) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Buffer video (on demand)',
                    style: TextStyle(
                        color: focused ? Colors.white : Colors.white54,
                        fontSize: captionFs)),
                const Spacer(),
                Text('$_mib MB',
                    style: TextStyle(
                        color: focused ? Colors.white : Colors.white54,
                        fontSize: captionFs)),
              ],
            ),
            SizedBox(height: AppScale.space(context, 8)),
            LayoutBuilder(
              builder: (context, cc) => Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 4,
                    width: cc.maxWidth * frac,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow:
                          focused ? AppScale.focusGlow(Colors.white) : null,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppScale.space(context, 6)),
            Text(
              'Più alto = meno rebuffering su rete lenta, più RAM usata. '
              'Si applica alla prossima riproduzione.',
              style:
                  TextStyle(color: Colors.white38, fontSize: captionFs * 0.9),
            ),
          ],
        ),
      ),
    );
  }
}

/// Separate, smaller demux buffer for live streams — a big buffer there only
/// adds pre-roll and latency. See SettingsRepository.getLiveBufferMiB.
class _LiveBufferPrefRow extends StatefulWidget {
  const _LiveBufferPrefRow();

  @override
  State<_LiveBufferPrefRow> createState() => _LiveBufferPrefRowState();
}

class _LiveBufferPrefRowState extends State<_LiveBufferPrefRow> {
  final _repo = getIt<SettingsRepository>();
  late int _mib = _repo.getLiveBufferMiB();
  static const _step = 4;

  void _nudge(int dir) {
    final next = (_mib + dir * _step).clamp(SettingsRepository.liveBufferMiBMin,
        SettingsRepository.liveBufferMiBMax);
    if (next == _mib) return;
    setState(() => _mib = next);
    _repo.setLiveBufferMiB(next);
  }

  @override
  Widget build(BuildContext context) {
    final captionFs =
        (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    final frac = (_mib - SettingsRepository.liveBufferMiBMin) /
        (SettingsRepository.liveBufferMiBMax -
            SettingsRepository.liveBufferMiBMin);
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 20),
          vertical: AppScale.space(context, 6)),
      child: TvFocusable(
        onLeft: () => _nudge(-1),
        onRight: () => _nudge(1),
        onFocusChange: (f) {
          if (f && context.mounted && Scrollable.maybeOf(context) != null) {
            Scrollable.ensureVisible(context,
                alignment: 0.5, duration: const Duration(milliseconds: 200));
          }
        },
        builder: (context, focused) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Buffer live',
                    style: TextStyle(
                        color: focused ? Colors.white : Colors.white54,
                        fontSize: captionFs)),
                const Spacer(),
                Text('$_mib MB',
                    style: TextStyle(
                        color: focused ? Colors.white : Colors.white54,
                        fontSize: captionFs)),
              ],
            ),
            SizedBox(height: AppScale.space(context, 8)),
            LayoutBuilder(
              builder: (context, cc) => Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 4,
                    width: cc.maxWidth * frac,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow:
                          focused ? AppScale.focusGlow(Colors.white) : null,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppScale.space(context, 6)),
            Text(
              'Più basso = la diretta parte prima e resta vicina al live. '
              'Si applica alla prossima riproduzione.',
              style:
                  TextStyle(color: Colors.white38, fontSize: captionFs * 0.9),
            ),
          ],
        ),
      ),
    );
  }
}
