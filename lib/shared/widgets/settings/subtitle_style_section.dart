import 'package:flutter/material.dart';

import '../../../core/theme/app_scale.dart';
import '../tv_focusable.dart';

/// Subtitle style controls (size/color/background/vertical position) —
/// promoted out of player_settings_panel.dart's in-player quick-settings
/// panel so the same UI is shared with the Preferenze screen instead of
/// being duplicated.
class SubtitleStyleSection extends StatelessWidget {
  final double fontSize;
  final Color color;
  final bool bgEnabled;
  final double bottomPadding;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<bool> onBgToggled;
  final ValueChanged<double> onPaddingChanged;

  const SubtitleStyleSection({
    super.key,
    required this.fontSize,
    required this.color,
    required this.bgEnabled,
    required this.bottomPadding,
    required this.onFontSizeChanged,
    required this.onColorChanged,
    required this.onBgToggled,
    required this.onPaddingChanged,
  });

  static const _colors = [
    (Colors.white, 'Bianco'),
    (Color(0xFFFFEB3B), 'Giallo'),
    (Color(0xFF80FF80), 'Verde'),
    (Color(0xFF80D8FF), 'Ciano'),
  ];

  @override
  Widget build(BuildContext context) {
    // Sliders/color-swatch labels use a bespoke, denser caption size — this
    // widget is shared with the compact in-player quick-settings overlay
    // (player_settings_panel.dart) where dense utility labels over video
    // are intentional, so it doesn't pull from AppScale.caption's
    // slightly-larger shared tier. "Sfondo sottotitoli" is a real row
    // label alongside a Switch, so it does use the shared tier.
    final captionFs = (AppScale.sh(context) * (13.0 / 1080.0)).clamp(10.0, 20.0);
    final labelFs = AppScale.caption(context);
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 20), vertical: AppScale.space(context, 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SliderRow(
            label: 'Dimensione',
            value: fontSize,
            min: 16,
            max: 64,
            step: 2,
            display: '${fontSize.round()}px',
            fontSize: captionFs,
            onChanged: onFontSizeChanged,
          ),
          SizedBox(height: AppScale.space(context, 12)),
          Text('Colore testo', style: TextStyle(color: Colors.white54, fontSize: captionFs)),
          SizedBox(height: AppScale.space(context, 8)),
          _ColorSwatchRow(
            colors: _colors,
            selectedColor: color,
            swatchSize: AppScale.space(context, 32),
            gap: AppScale.space(context, 10),
            onColorChanged: onColorChanged,
          ),
          SizedBox(height: AppScale.space(context, 12)),
          Row(
            children: [
              Text('Sfondo sottotitoli', style: TextStyle(color: Colors.white70, fontSize: labelFs)),
              const Spacer(),
              Switch(
                value: bgEnabled,
                onChanged: onBgToggled,
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? Colors.white : Colors.white38),
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? null : Colors.white12),
              ),
            ],
          ),
          SizedBox(height: AppScale.space(context, 4)),
          _SliderRow(
            label: 'Posizione verticale',
            value: bottomPadding,
            min: 0,
            max: 300,
            step: 10,
            display: '${bottomPadding.round()}',
            fontSize: captionFs,
            onChanged: onPaddingChanged,
          ),
        ],
      ),
    );
  }
}

// Owns one FocusNode per swatch so left/right moves between them directly
// instead of relying on Flutter's implicit default focus traversal (the
// only place in this section that used to) — up/down still bubble out
// unhandled, since this row is embedded in two different surrounding
// layouts (the standalone Preferenze screen and player_settings_panel.dart's
// in-player overlay) that already own their own vertical chain.
class _ColorSwatchRow extends StatefulWidget {
  final List<(Color, String)> colors;
  final Color selectedColor;
  final double swatchSize;
  final double gap;
  final ValueChanged<Color> onColorChanged;

  const _ColorSwatchRow({
    required this.colors,
    required this.selectedColor,
    required this.swatchSize,
    required this.gap,
    required this.onColorChanged,
  });

  @override
  State<_ColorSwatchRow> createState() => _ColorSwatchRowState();
}

class _ColorSwatchRowState extends State<_ColorSwatchRow> {
  late List<FocusNode> _fns = List.generate(widget.colors.length, (_) => FocusNode());

  @override
  void didUpdateWidget(_ColorSwatchRow old) {
    super.didUpdateWidget(old);
    if (old.colors.length != widget.colors.length) {
      for (final n in _fns) { n.dispose(); }
      _fns = List.generate(widget.colors.length, (_) => FocusNode());
    }
  }

  @override
  void dispose() {
    for (final n in _fns) { n.dispose(); }
    super.dispose();
  }

  void _move(int index, int dir) {
    final next = index + dir;
    if (next < 0 || next >= _fns.length) return; // stop at edges, no wrap
    _fns[next].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < widget.colors.length; i++)
          Padding(
            padding: EdgeInsets.only(right: widget.gap),
            child: _ColorSwatch(
              focusNode: _fns[i],
              swatchColor: widget.colors[i].$1,
              label: widget.colors[i].$2,
              selected: widget.selectedColor == widget.colors[i].$1,
              size: widget.swatchSize,
              onTap: () => widget.onColorChanged(widget.colors[i].$1),
              onNavigateLeft: () => _move(i, -1),
              onNavigateRight: () => _move(i, 1),
            ),
          ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final FocusNode focusNode;
  final Color swatchColor;
  final String label;
  final bool selected;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onNavigateLeft;
  final VoidCallback onNavigateRight;

  const _ColorSwatch({
    required this.focusNode,
    required this.swatchColor,
    required this.label,
    required this.selected,
    required this.size,
    required this.onTap,
    required this.onNavigateLeft,
    required this.onNavigateRight,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onTap,
      onLeft: onNavigateLeft,
      onRight: onNavigateRight,
      builder: (context, focused) => Tooltip(
        message: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: swatchColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected || focused ? Colors.white : Colors.transparent,
              width: focused ? 3.5 : 2.5,
            ),
            boxShadow: selected || focused
                ? [BoxShadow(color: swatchColor.withValues(alpha: 0.6), blurRadius: 6)]
                : null,
          ),
        ),
      ),
    );
  }
}

/// A D-pad-adjustable value bar. Deliberately NOT Flutter's `Slider`: that
/// widget binds Up/Down (as well as Left/Right) to value changes, so once
/// D-pad focus landed on it there was no way to leave the control
/// vertically — the user got stuck on the bar. This claims only Left/Right
/// (nudge by [step]) and leaves Up/Down unhandled so they bubble to the
/// enclosing ListView's directional focus traversal, matching the in-player
/// `_VolumeRow` bar in player_settings_panel.dart. See
/// [[pileus_tv_design_preferences]].
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String display;
  final double fontSize;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.display,
    required this.fontSize,
    required this.onChanged,
  });

  void _nudge(int dir) {
    final next = (value + dir * step).clamp(min, max).toDouble();
    if (next != value) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final frac = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return TvFocusable(
      onLeft: () => _nudge(-1),
      onRight: () => _nudge(1),
      builder: (context, focused) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: focused ? Colors.white : Colors.white54,
                      fontSize: fontSize)),
              const Spacer(),
              Text(display,
                  style: TextStyle(
                      color: focused ? Colors.white : Colors.white54,
                      fontSize: fontSize)),
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
        ],
      ),
    );
  }
}
