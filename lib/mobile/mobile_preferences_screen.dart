import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/media/data/media_repository.dart';
import '../features/player/android_video_settings.dart';
import '../features/settings/data/settings_repository.dart';
import '../shared/utils/tap_guard.dart';

class MobilePreferencesScreen extends StatefulWidget {
  const MobilePreferencesScreen({super.key});

  @override
  State<MobilePreferencesScreen> createState() =>
      _MobilePreferencesScreenState();
}

class _MobilePreferencesScreenState extends State<MobilePreferencesScreen> {
  final _s = getIt<SettingsRepository>();

  late int _vodBuf = _s.getVodBufferSec();
  late int _liveBuf = _s.getLiveBufferSec();
  late double _subSize = _s.getSubtitleFontSize();
  late Color _subColor = _s.getSubtitleColor();
  late bool _subBg = _s.getSubtitleBgEnabled();
  late double _subPad = _s.getSubtitleBottomPadding();
  late bool _diag = _s.getDiagnostics();
  late int _maxHeight = _s.getMaxVideoHeight();

  static const _swatches = <Color>[
    Colors.white,
    Color(0xFFFFEB3B),
    Color(0xFF00E5FF),
    Color(0xFF69F0AE),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: const GuardedBackButton(),
        backgroundColor: AppTheme.bg,
        title: const Text('Preferenze'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _header('Player'),
          _sliderTile(
            'Riserva di riproduzione',
            '$_vodBuf s',
            _vodBuf.toDouble(),
            SettingsRepository.vodBufferSecMin.toDouble(),
            SettingsRepository.vodBufferSecMax.toDouble(),
            (v) => setState(() {
              _vodBuf = (v / 5).round() * 5;
              _s.setVodBufferSec(_vodBuf);
            }),
          ),
          _sliderTile(
            'Riserva di riproduzione (live)',
            '$_liveBuf s',
            _liveBuf.toDouble(),
            SettingsRepository.liveBufferSecMin.toDouble(),
            SettingsRepository.liveBufferSecMax.toDouble(),
            (v) => setState(() {
              _liveBuf = v.round();
              _s.setLiveBufferSec(_liveBuf);
            }),
          ),
          _note('Secondi di video tenuti pronti in anticipo. Più riserva = '
              'meno interruzioni, al costo di un po\' di memoria (per le '
              'dirette anche più ritardo).'),
          // ExoPlayer-only (patched better_player_plus): no effect on iOS.
          if (Platform.isAndroid)
            ListTile(
              title: const Text('Qualità video massima',
                  style: TextStyle(color: AppTheme.textHigh)),
              subtitle: const Text(
                  'Limita la qualità scelta in automatico (connessione lenta).',
                  style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
              trailing: DropdownButton<int>(
                value: _maxHeight,
                dropdownColor: AppTheme.bg,
                underline: const SizedBox.shrink(),
                items: [
                  for (final h in SettingsRepository.maxVideoHeightOptions)
                    DropdownMenuItem(
                      value: h,
                      child: Text(h == 0 ? 'Automatica' : '${h}p',
                          style: const TextStyle(color: AppTheme.textHigh)),
                    ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _maxHeight = v);
                  await _s.setMaxVideoHeight(v);
                  applyAndroidVideoSettings(_s, tvSwitches: false);
                },
              ),
            ),
          _note('Si applica alla prossima riproduzione.'),
          _header('Sottotitoli'),
          _sliderTile(
            'Dimensione',
            _subSize.round().toString(),
            _subSize,
            16,
            48,
            (v) => setState(() {
              _subSize = v;
              _s.setSubtitleFontSize(v);
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                const Text('Colore', style: TextStyle(color: AppTheme.textMid)),
                const SizedBox(width: 16),
                for (final c in _swatches)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _subColor = c;
                        _s.setSubtitleColor(c);
                      }),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _subColor.toARGB32() == c.toARGB32()
                                ? AppTheme.primary
                                : AppTheme.border,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            value: _subBg,
            onChanged: (v) => setState(() {
              _subBg = v;
              _s.setSubtitleBgEnabled(v);
            }),
            title: const Text('Sfondo dietro il testo',
                style: TextStyle(color: AppTheme.textHigh)),
          ),
          _sliderTile(
            'Distanza dal fondo',
            _subPad.round().toString(),
            _subPad,
            0,
            200,
            (v) => setState(() {
              _subPad = v;
              _s.setSubtitleBottomPadding(v);
            }),
          ),
          _header('Avanzate'),
          SwitchListTile(
            value: _diag,
            onChanged: (v) => setState(() {
              _diag = v;
              _s.setDiagnostics(v);
            }),
            title: const Text('Diagnostica (log su adb)',
                style: TextStyle(color: AppTheme.textHigh)),
            subtitle: const Text('Richiede il riavvio dell\'app.',
                style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined,
                color: AppTheme.textMid),
            title: const Text('Svuota cache catalogo',
                style: TextStyle(color: AppTheme.textHigh)),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await getIt<MediaRepository>().clearCatalogCache();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Cache svuotata')),
                );
              } catch (e) {
                // Same feedback as the TV settings screen — this used to
                // fail silently (and leave an uncaught async error).
                messenger.showSnackBar(SnackBar(
                    content: Text('Impossibile svuotare la cache: $e')));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .8)),
      );

  Widget _note(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(t,
            style: const TextStyle(color: AppTheme.textLow, fontSize: 12)),
      );

  Widget _sliderTile(String label, String value, double v, double min,
      double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textHigh)),
              Text(value, style: const TextStyle(color: AppTheme.textMid)),
            ],
          ),
          Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
