import 'package:flutter/material.dart';

import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import '../../engine/player_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Settings panel — single-column drill-down list (Android TV Settings /
// YouTube's quality picker), not a tabbed icon rail. A master list of rows
// (Volume, Audio, Video, Sottotitoli), each showing its current value; Select
// or Right opens a category's option list, Left or Back returns to the
// master list. One navigation axis per screen (Up/Down + Select/Back) instead
// of a two-axis tab-rail-plus-list. Subtitle *style* (font/colore/sfondo/
// padding) still lives only in Impostazioni → Preferenze — this panel only
// deals with playback-track selection.
// ─────────────────────────────────────────────────────────────────────────────

enum _SettingsCategory { audio, video, subtitles }

enum _PanelView { master, detail }

class PlayerSettingsPanel extends StatefulWidget {
  final PlayerEngine engine;
  final double volume;
  final VoidCallback onClose;
  final ValueChanged<double> onVolumeChanged;

  const PlayerSettingsPanel({
    super.key,
    required this.engine,
    required this.volume,
    required this.onClose,
    required this.onVolumeChanged,
  });

  @override
  State<PlayerSettingsPanel> createState() => PlayerSettingsPanelState();
}

class PlayerSettingsPanelState extends State<PlayerSettingsPanel> {
  static const _bg = Color(0xF0101018);
  static const _dividerColor = Color(0x33FFFFFF);
  static const _volumeStep = 5.0;

  _PanelView _view = _PanelView.master;
  _SettingsCategory? _detailCategory;

  // Master-list row nodes — always alive for the panel's lifetime (only 4 of
  // them, never disposed until the panel itself closes), so a category
  // toggling in/out of availability is just a canRequestFocus flip.
  final _closeFn = FocusNode();
  final _volumeRowFn = FocusNode();
  final _audioRowFn = FocusNode();
  final _videoRowFn = FocusNode();
  final _subsRowFn = FocusNode();

  // Entry point into each category's option list, landed on when a row is
  // opened — one per category, also alive for the panel's whole lifetime.
  final _audioFirstFn = FocusNode();
  final _videoFirstFn = FocusNode();
  final _subsFirstFn = FocusNode();

  List<MediaTrack> get _audioTracks => widget.engine.audioTracks;
  List<MediaTrack> get _videoTracks => widget.engine.videoTracks;
  List<MediaTrack> get _subTracks => widget.engine.subtitleTracks;

  bool get _hasAudio => _audioTracks.length > 1;
  bool get _hasVideo => _videoTracks.length > 1;
  bool get _hasSubs => _subTracks.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineTick);
    _syncAvailability();
  }

  @override
  void didUpdateWidget(PlayerSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.engine, widget.engine)) {
      oldWidget.engine.removeListener(_onEngineTick);
      widget.engine.addListener(_onEngineTick);
    }
    _syncAvailability();
  }

  // Track lists arrive a beat after playback starts — rebuild so the rows
  // appear (and their canRequestFocus flips) without needing the panel to be
  // reopened. Only when the visible content actually changed (the engine
  // notifies on every position tick).
  String _lastSig = '';
  void _onEngineTick() {
    if (!mounted) return;
    final sig = '${_audioTracks.length}/${_videoTracks.length}/'
        '${_subTracks.length}/${widget.engine.activeAudioTrack?.id}/'
        '${widget.engine.activeSubtitleTrack?.id}/'
        '${widget.engine.activeVideoTrack?.id}';
    if (sig == _lastSig) return;
    _lastSig = sig;
    setState(_syncAvailability);
  }

  void _syncAvailability() {
    _audioRowFn.canRequestFocus = _hasAudio;
    _videoRowFn.canRequestFocus = _hasVideo;
    _subsRowFn.canRequestFocus = _hasSubs;
    if (_view == _PanelView.detail) {
      final stillVisible = switch (_detailCategory!) {
        _SettingsCategory.audio => _hasAudio,
        _SettingsCategory.video => _hasVideo,
        _SettingsCategory.subtitles => _hasSubs,
      };
      // The category the user was looking at just disappeared (e.g. an
      // episode change dropped down to a single audio track) — bail to the
      // master list before anything sitting there gets stranded off-tree.
      if (!stillVisible) _returnToMaster(focusRow: _volumeRowFn);
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineTick);
    _closeFn.dispose();
    _volumeRowFn.dispose();
    _audioRowFn.dispose();
    _videoRowFn.dispose();
    _subsRowFn.dispose();
    _audioFirstFn.dispose();
    _videoFirstFn.dispose();
    _subsFirstFn.dispose();
    super.dispose();
  }

  /// Called by PlaybackScreen right after opening this panel. Needed because
  /// the first row's `autofocus` alone doesn't reliably win here: the button
  /// that triggered openSettings() still holds focus in the same frame the
  /// panel mounts, so the scope already has a focused descendant and
  /// autofocus is a no-op — same class of bug as the overlay's own
  /// requestInitialFocus(), which this mirrors.
  void requestInitialFocus() => _volumeRowFn.requestFocus();

  List<FocusNode> get _masterChain =>
      [_volumeRowFn, _audioRowFn, _videoRowFn, _subsRowFn];

  void _moveMasterRow(FocusNode from, int dir) {
    var i = _masterChain.indexOf(from);
    if (i == -1) return;
    do {
      i += dir;
    } while (
        i >= 0 && i < _masterChain.length && !_masterChain[i].canRequestFocus);
    if (i >= 0 && i < _masterChain.length) {
      _masterChain[i].requestFocus();
    } else if (i < 0) {
      _closeFn.requestFocus();
    }
  }

  void _openDetail(_SettingsCategory c, FocusNode entryFn) {
    setState(() {
      _view = _PanelView.detail;
      _detailCategory = c;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) entryFn.requestFocus();
    });
  }

  void _returnToMaster({FocusNode? focusRow}) {
    final row = focusRow ??
        switch (_detailCategory) {
          _SettingsCategory.audio => _audioRowFn,
          _SettingsCategory.video => _videoRowFn,
          _SettingsCategory.subtitles => _subsRowFn,
          null => _volumeRowFn,
        };
    setState(() {
      _view = _PanelView.master;
      _detailCategory = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // The 300 floor is a preferred minimum, not a guarantee — this is
    // Positioned(right: 0, width: panelWidth), which extends leftward from
    // the screen edge by exactly panelWidth. Without checking against the
    // real screen width, a narrow enough player window would push the
    // panel's left edge off-screen.
    final screenW = MediaQuery.sizeOf(context).width;
    final panelWidth =
        (screenW * (420.0 / 1920.0)).clamp(300.0, 520.0).clamp(0.0, screenW);
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: Colors.black38),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: panelWidth,
          child: Material(
            color: _bg,
            child: Column(
              children: [
                _PanelHeader(
                  onClose: widget.onClose,
                  closeFocusNode: _closeFn,
                  onDown: () => _volumeRowFn.requestFocus(),
                ),
                const Divider(color: _dividerColor, height: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: AppScale.fadeCurve,
                    switchOutCurve: AppScale.fadeCurve,
                    child: _view == _PanelView.master
                        ? _buildMaster(context)
                        : _buildDetail(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaster(BuildContext context) {
    final activeAudio = widget.engine.activeAudioTrack;
    final activeVideo = widget.engine.activeVideoTrack;
    final activeSub = widget.engine.activeSubtitleTrack;
    return ListView(
      key: const ValueKey('master'),
      padding: EdgeInsets.symmetric(vertical: AppScale.space(context, 8)),
      children: [
        _VolumeRow(
          focusNode: _volumeRowFn,
          autofocus: true,
          volume: widget.volume,
          maxVolume: widget.engine.maxVolume,
          onChanged: widget.onVolumeChanged,
          onUp: () => _closeFn.requestFocus(),
          onDown: () => _moveMasterRow(_volumeRowFn, 1),
        ),
        if (_hasAudio)
          _CategoryRow(
            icon: Icons.multitrack_audio_rounded,
            label: 'Audio',
            value: activeAudio?.label ?? '—',
            focusNode: _audioRowFn,
            onUp: () => _moveMasterRow(_audioRowFn, -1),
            onDown: () => _moveMasterRow(_audioRowFn, 1),
            onOpen: () => _openDetail(_SettingsCategory.audio, _audioFirstFn),
            onCloseFromLeft: widget.onClose,
          ),
        if (_hasVideo)
          _CategoryRow(
            icon: Icons.video_settings_rounded,
            label: 'Video',
            value: activeVideo?.label ?? '—',
            focusNode: _videoRowFn,
            onUp: () => _moveMasterRow(_videoRowFn, -1),
            onDown: () => _moveMasterRow(_videoRowFn, 1),
            onOpen: () => _openDetail(_SettingsCategory.video, _videoFirstFn),
            onCloseFromLeft: widget.onClose,
          ),
        if (_hasSubs)
          _CategoryRow(
            icon: Icons.subtitles_rounded,
            label: 'Sottotitoli',
            value: activeSub == null ? 'Disattivati' : activeSub.label,
            focusNode: _subsRowFn,
            onUp: () => _moveMasterRow(_subsRowFn, -1),
            onDown: () => _moveMasterRow(_subsRowFn, 1),
            onOpen: () =>
                _openDetail(_SettingsCategory.subtitles, _subsFirstFn),
            onCloseFromLeft: widget.onClose,
          ),
      ],
    );
  }

  Widget _buildDetail(BuildContext context) {
    switch (_detailCategory!) {
      case _SettingsCategory.audio:
        final tracks = _audioTracks;
        final active = widget.engine.activeAudioTrack;
        return ListView(
          key: const ValueKey('detail_audio'),
          padding: EdgeInsets.symmetric(vertical: AppScale.space(context, 8)),
          children: [
            _DetailHeader(label: 'Audio', onBack: _returnToMaster),
            for (var i = 0; i < tracks.length; i++)
              _TrackTile(
                label: tracks[i].label,
                selected: active == tracks[i],
                onTap: () => widget.engine.selectAudioTrack(tracks[i]),
                focusNode: i == 0 ? _audioFirstFn : null,
                onBack: _returnToMaster,
              ),
          ],
        );

      case _SettingsCategory.video:
        final tracks = _videoTracks;
        final active = widget.engine.activeVideoTrack;
        return ListView(
          key: const ValueKey('detail_video'),
          padding: EdgeInsets.symmetric(vertical: AppScale.space(context, 8)),
          children: [
            _DetailHeader(label: 'Video', onBack: _returnToMaster),
            for (var i = 0; i < tracks.length; i++)
              _TrackTile(
                label: tracks[i].label,
                selected: active == tracks[i],
                onTap: () => widget.engine.selectVideoTrack(tracks[i]),
                focusNode: i == 0 ? _videoFirstFn : null,
                onBack: _returnToMaster,
              ),
          ],
        );

      case _SettingsCategory.subtitles:
        final tracks = _subTracks;
        final active = widget.engine.activeSubtitleTrack;
        return ListView(
          key: const ValueKey('detail_subtitles'),
          padding: EdgeInsets.symmetric(vertical: AppScale.space(context, 8)),
          children: [
            _DetailHeader(label: 'Sottotitoli', onBack: _returnToMaster),
            _TrackTile(
              label: 'Disattivati',
              selected: active == null,
              onTap: () => widget.engine.selectSubtitleTrack(null),
              focusNode: _subsFirstFn,
              onBack: _returnToMaster,
            ),
            for (final t in tracks)
              _TrackTile(
                label: t.label,
                selected: active == t,
                onTap: () => widget.engine.selectSubtitleTrack(t),
                onBack: _returnToMaster,
              ),
          ],
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  final FocusNode closeFocusNode;
  final VoidCallback onDown;
  const _PanelHeader(
      {required this.onClose,
      required this.closeFocusNode,
      required this.onDown});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppScale.space(context, 20),
          AppScale.space(context, 4),
          AppScale.space(context, 8),
          AppScale.space(context, 12)),
      child: Row(
        children: [
          Icon(Icons.settings_rounded,
              color: AppTheme.textHigh.withValues(alpha: 0.55),
              size: AppScale.iconM(context)),
          SizedBox(width: AppScale.space(context, 10)),
          Text('Impostazioni',
              style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: AppScale.space(context, 17),
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          _CloseButton(
              onTap: onClose, focusNode: closeFocusNode, onDown: onDown),
        ],
      ),
    );
  }
}

/// Header close button — reachable via Up from the master list's first row
/// (Volume), and hands focus back down to it too.
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final FocusNode focusNode;
  final VoidCallback onDown;
  const _CloseButton(
      {required this.onTap, required this.focusNode, required this.onDown});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onTap,
      onDown: onDown,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.all(AppScale.space(context, 6)),
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused ? AppTheme.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Icon(Icons.close_rounded,
            color: focused
                ? AppTheme.textHigh
                : AppTheme.textHigh.withValues(alpha: 0.55),
            size: AppScale.iconM(context)),
      ),
    );
  }
}

/// Small back row shown at the top of every detail (option) list — mirrors
/// the label of the category it belongs to and gives an explicit, visible
/// "go back" affordance in addition to Left/Escape, matching the
/// chevron-back convention of Android TV's own Settings app.
class _DetailHeader extends StatelessWidget {
  final String label;
  final VoidCallback onBack;
  const _DetailHeader({required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onActivate: onBack,
      onEsc: onBack,
      onLeft: onBack,
      builder: (context, focused) => Container(
        decoration: BoxDecoration(
          color: focused ? AppTheme.textHigh.withValues(alpha: 0.08) : null,
        ),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 20) - 3,
            vertical: AppScale.space(context, 12)),
        child: Row(
          children: [
            Icon(Icons.arrow_back_rounded,
                color: focused
                    ? AppTheme.textHigh
                    : AppTheme.textHigh.withValues(alpha: 0.5),
                size: AppScale.iconM(context)),
            SizedBox(width: AppScale.space(context, 12)),
            Text(label,
                style: TextStyle(
                  color: focused
                      ? AppTheme.textHigh
                      : AppTheme.textHigh.withValues(alpha: 0.7),
                  fontSize: AppScale.space(context, 15),
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

/// A master-list row that opens a drill-down option list — shows the
/// category's current value inline (no need to open it just to check what's
/// selected) and a trailing chevron marking it as "opens something", unlike
/// the directly-adjustable Volume row below.
class _CategoryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final FocusNode focusNode;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onOpen;
  final VoidCallback onCloseFromLeft;

  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.focusNode,
    required this.onUp,
    required this.onDown,
    required this.onOpen,
    required this.onCloseFromLeft,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onOpen,
      onRight: onOpen,
      onUp: onUp,
      onDown: onDown,
      onLeft: onCloseFromLeft,
      builder: (context, focused) => Container(
        decoration: BoxDecoration(
          color: focused ? AppTheme.textHigh.withValues(alpha: 0.08) : null,
          border: Border(
            left: BorderSide(
                color: focused ? AppTheme.primary : Colors.transparent,
                width: 3),
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 20) - 3,
            vertical: AppScale.space(context, 12)),
        child: Row(
          children: [
            Icon(icon,
                color: focused
                    ? AppTheme.textHigh
                    : AppTheme.textHigh.withValues(alpha: 0.6),
                size: AppScale.iconM(context)),
            SizedBox(width: AppScale.space(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: focused ? AppTheme.textHigh : AppTheme.textMid,
                        fontSize: AppScale.space(context, 16),
                        fontWeight: FontWeight.w600,
                      )),
                  SizedBox(height: AppScale.space(context, 2)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.primary
                            .withValues(alpha: focused ? 1 : 0.85),
                        fontSize: AppScale.caption(context),
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHigh.withValues(alpha: focused ? 0.7 : 0.3),
                size: AppScale.iconM(context)),
          ],
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  // Set only on the first tile of a category's list, so the master list has
  // a stable node to land on when opening this category.
  final FocusNode? focusNode;
  final VoidCallback onBack;

  const _TrackTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.focusNode,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onTap,
      onEsc: onBack,
      onLeft: onBack,
      // Track lists here can run longer than the panel's viewport (many
      // audio tracks/subtitle languages) — ListView's default D-pad
      // traversal moves focus off-screen without scrolling to follow it.
      onFocusChange: (focused) {
        if (!focused) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.2,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          }
        });
      },
      builder: (context, focused) => Container(
        decoration: BoxDecoration(
          color: focused ? AppTheme.textHigh.withValues(alpha: 0.08) : null,
          border: Border(
            left: BorderSide(
              color: focused ? AppTheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: ListTile(
          minTileHeight: AppScale.space(context, 64),
          contentPadding:
              EdgeInsets.symmetric(horizontal: AppScale.space(context, 20) - 3),
          leading: Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected || focused ? AppTheme.textHigh : AppTheme.textLow,
            size: AppScale.iconM(context),
          ),
          title: Text(label,
              style: TextStyle(
                color:
                    selected || focused ? AppTheme.textHigh : AppTheme.textMid,
                fontSize: AppScale.space(context, 16),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              )),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Master-list row for volume — directly adjustable in place (Left/Right
/// nudge the value) rather than drilling into a submenu, same as a TV's own
/// system volume row: there's nothing to "pick", just a value to change.
class _VolumeRow extends StatelessWidget {
  final double volume;
  final double maxVolume;
  final ValueChanged<double> onChanged;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _VolumeRow({
    required this.volume,
    required this.maxVolume,
    required this.onChanged,
    required this.focusNode,
    required this.onUp,
    required this.onDown,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final frac = (volume / maxVolume).clamp(0.0, 1.0);
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onUp: onUp,
      onDown: onDown,
      onLeft: () => onChanged((volume - PlayerSettingsPanelState._volumeStep)
          .clamp(0.0, maxVolume)),
      onRight: () => onChanged((volume + PlayerSettingsPanelState._volumeStep)
          .clamp(0.0, maxVolume)),
      builder: (context, focused) => Container(
        decoration: BoxDecoration(
          color: focused ? AppTheme.textHigh.withValues(alpha: 0.08) : null,
          border: Border(
            left: BorderSide(
                color: focused ? AppTheme.primary : Colors.transparent,
                width: 3),
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 20) - 3,
            vertical: AppScale.space(context, 14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  volume == 0
                      ? Icons.volume_off_rounded
                      : volume < maxVolume / 2
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  color: focused
                      ? AppTheme.textHigh
                      : AppTheme.textHigh.withValues(alpha: 0.6),
                  size: AppScale.iconM(context),
                ),
                SizedBox(width: AppScale.space(context, 16)),
                Text('Volume',
                    style: TextStyle(
                      color: focused ? AppTheme.textHigh : AppTheme.textMid,
                      fontSize: AppScale.space(context, 16),
                      fontWeight: FontWeight.w600,
                    )),
                const Spacer(),
                Text(
                  '${volume.round()}%',
                  style: TextStyle(
                    color:
                        AppTheme.primary.withValues(alpha: focused ? 1 : 0.85),
                    fontSize: AppScale.caption(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppScale.space(context, 8)),
            Padding(
              padding: EdgeInsets.only(left: AppScale.space(context, 40)),
              child: LayoutBuilder(
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
                        color: AppTheme.textHigh,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: focused
                            ? AppScale.focusGlow(AppTheme.textHigh)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
