import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/perf_profile.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/android_video_settings.dart';
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
        const _ReservePrefRow(live: false),
        SizedBox(height: AppScale.space(context, 4)),
        const _ReservePrefRow(live: true),
        SizedBox(height: AppScale.space(context, 4)),
        const _LowPowerPrefRow(),
        if (!kIsWeb && Platform.isAndroid) ...[
          SizedBox(height: AppScale.space(context, 4)),
          const _MaxVideoHeightPrefRow(),
          SizedBox(height: AppScale.space(context, 4)),
          const _AndroidVideoPrefRow(
            label: 'Decodifica video software',
            caption: 'Usa il decoder software al posto di quello del box '
                '(che resta come riserva). Può evitare blocchi '
                'dell\'immagine su alcuni chip, ma pesa sul processore: oltre '
                'il 720p può andare a scatti. Vale dalla prossima '
                'riproduzione.',
            softwareDecoder: true,
          ),
          SizedBox(height: AppScale.space(context, 4)),
          const _AndroidVideoPrefRow(
            label: 'Rendering video compatibile',
            caption: 'Disegna il video con il metodo delle versioni '
                'precedenti. Da provare se il video resta nero, si blocca '
                'o va a scatti mentre l\'audio continua. Vale dalla '
                'prossima riproduzione.',
            softwareDecoder: false,
          ),
        ],
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

/// "Qualità video massima" — see SettingsRepository.getMaxVideoHeight.
/// Left/right (or OK, which cycles) steps through the options; applied to
/// the next player created.
class _MaxVideoHeightPrefRow extends StatefulWidget {
  const _MaxVideoHeightPrefRow();

  @override
  State<_MaxVideoHeightPrefRow> createState() => _MaxVideoHeightPrefRowState();
}

class _MaxVideoHeightPrefRowState extends State<_MaxVideoHeightPrefRow> {
  final _repo = getIt<SettingsRepository>();
  static const _options = SettingsRepository.maxVideoHeightOptions;
  late int _value = _repo.getMaxVideoHeight();

  static String _label(int h) => h == 0 ? 'Automatica' : '${h}p';

  void _step(int dir, {bool wrap = false}) {
    var i = _options.indexOf(_value) + dir;
    if (wrap) {
      i %= _options.length;
    } else if (i < 0 || i >= _options.length) {
      return;
    }
    final next = _options[i];
    setState(() => _value = next);
    _repo
        .setMaxVideoHeight(next)
        .then((_) => applyAndroidVideoSettings(_repo, tvSwitches: true));
  }

  @override
  Widget build(BuildContext context) {
    final captionFs =
        (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 20),
          vertical: AppScale.space(context, 6)),
      child: TvFocusable(
        onLeft: () => _step(-1),
        onRight: () => _step(1),
        onActivate: () => _step(1, wrap: true),
        onFocusChange: (f) {
          if (f && context.mounted && Scrollable.maybeOf(context) != null) {
            Scrollable.ensureVisible(context,
                alignment: 0.5, duration: const Duration(milliseconds: 200));
          }
        },
        builder: (context, focused) {
          final color = focused ? Colors.white : Colors.white54;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Qualità video massima',
                      style: TextStyle(color: color, fontSize: captionFs)),
                  const Spacer(),
                  Text('‹  ${_label(_value)}  ›',
                      style: TextStyle(color: color, fontSize: captionFs)),
                ],
              ),
              SizedBox(height: AppScale.space(context, 4)),
              Text(
                'Limita la qualità scelta in automatico. Utile con una '
                'connessione lenta o un box poco potente; una qualità scelta '
                'a mano nel player resta possibile. Vale dalla prossima '
                'riproduzione.',
                style: TextStyle(
                    color: Colors.white38, fontSize: captionFs * 0.9),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The two Android video escape hatches — see
/// SettingsRepository.getSoftwareVideoDecoder / getCompatVideoSurface.
/// Self-contained like _LowPowerPrefRow; the native player reads the new
/// value when the next one is created.
class _AndroidVideoPrefRow extends StatefulWidget {
  final String label;
  final String caption;

  /// true: "decodifica software"; false: "rendering compatibile".
  final bool softwareDecoder;

  const _AndroidVideoPrefRow({
    required this.label,
    required this.caption,
    required this.softwareDecoder,
  });

  @override
  State<_AndroidVideoPrefRow> createState() => _AndroidVideoPrefRowState();
}

class _AndroidVideoPrefRowState extends State<_AndroidVideoPrefRow> {
  final _repo = getIt<SettingsRepository>();
  late bool _on = widget.softwareDecoder
      ? _repo.getSoftwareVideoDecoder()
      : _repo.getCompatVideoSurface();

  Future<void> _set(bool v) async {
    setState(() => _on = v);
    if (widget.softwareDecoder) {
      await _repo.setSoftwareVideoDecoder(v);
    } else {
      await _repo.setCompatVideoSurface(v);
    }
    applyAndroidVideoSettings(_repo, tvSwitches: true);
  }

  @override
  Widget build(BuildContext context) {
    final captionFs =
        (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsToggleRow(label: widget.label, value: _on, onChanged: _set),
        Padding(
          padding: EdgeInsets.fromLTRB(AppScale.space(context, 24),
              AppScale.space(context, 4), AppScale.space(context, 24), 0),
          child: Text(
            widget.caption,
            style: TextStyle(color: Colors.white38, fontSize: captionFs * 0.9),
          ),
        ),
      ],
    );
  }
}

/// "Modalità hardware modesto" — see SettingsRepository.getLowPowerMode.
/// Self-contained like _ReservePrefRow: the player re-reads it on the next
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

/// "Riserva di riproduzione" — seconds of media kept buffered ahead (see
/// SettingsRepository.getVodBufferSec), one row for on-demand and one for
/// live (a big live reserve only adds pre-roll and latency). Self-contained:
/// the player re-reads it on the next playback, nothing else observes it.
class _ReservePrefRow extends StatefulWidget {
  final bool live;
  const _ReservePrefRow({required this.live});

  @override
  State<_ReservePrefRow> createState() => _ReservePrefRowState();
}

class _ReservePrefRowState extends State<_ReservePrefRow> {
  final _repo = getIt<SettingsRepository>();
  late int _sec =
      widget.live ? _repo.getLiveBufferSec() : _repo.getVodBufferSec();

  int get _min => widget.live
      ? SettingsRepository.liveBufferSecMin
      : SettingsRepository.vodBufferSecMin;
  int get _max => widget.live
      ? SettingsRepository.liveBufferSecMax
      : SettingsRepository.vodBufferSecMax;
  // 15→180 in 11 presses; 6→60 in 18.
  int get _step => widget.live ? 3 : 15;

  void _nudge(int dir) {
    final next = (_sec + dir * _step).clamp(_min, _max);
    if (next == _sec) return;
    setState(() => _sec = next);
    widget.live ? _repo.setLiveBufferSec(next) : _repo.setVodBufferSec(next);
  }

  @override
  Widget build(BuildContext context) {
    final captionFs =
        (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    final frac = (_sec - _min) / (_max - _min);
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
                Text(
                    widget.live
                        ? 'Riserva di riproduzione (live)'
                        : 'Riserva di riproduzione',
                    style: TextStyle(
                        color: focused ? Colors.white : Colors.white54,
                        fontSize: captionFs)),
                const Spacer(),
                Text('$_sec s',
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
              widget.live
                  ? 'Secondi tenuti pronti in anticipo. Più riserva = meno '
                      'interruzioni, ma più ritardo rispetto alla diretta e '
                      'un po\' di memoria in più. Vale dalla prossima '
                      'riproduzione.'
                  : 'Secondi di video tenuti pronti in anticipo. Più '
                      'riserva = meno interruzioni, al costo di un po\' di '
                      'memoria. Vale dalla prossima riproduzione.',
              style:
                  TextStyle(color: Colors.white38, fontSize: captionFs * 0.9),
            ),
          ],
        ),
      ),
    );
  }
}
