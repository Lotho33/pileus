// Part of player_overlay.dart — split out for readability (plan 2e). The
// library file holds the shared imports and the PlayerOverlay widget;
// private identifiers are shared across all parts.
part of '../player_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Live channel overlay
// ─────────────────────────────────────────────────────────────────────────────

class PlayerLiveOverlay extends StatefulWidget {
  final String? title;
  final List<String> liveSources;
  final List<String> liveSourceLabels;
  final String livePluginId;
  final String liveMediaId;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final void Function(String srcId, String srcLabel) onSwitchSource;
  // Tears the whole player engine down and rebuilds it in place, reopening
  // the same source (see _PlaybackViewState._restartPlayerInPlace) — the
  // fast path for the frozen-picture-but-audio-plays-on freeze some Android
  // TV boxes hit, instead of backing out to the library and re-entering.
  final VoidCallback onRestart;
  // Loading state — mirrors PlayerOverlay's: shows a centre spinner / buffer
  // ring + the plugin's resolve step while the picture is still coming up.
  final bool loading;
  final String? statusMessage;
  final String? statusKind;
  final bool buffering;
  final double bufferingPercent;

  const PlayerLiveOverlay({
    super.key,
    required this.onBack,
    required this.onOpenSettings,
    required this.onSwitchSource,
    required this.onRestart,
    this.title,
    this.liveSources = const [],
    this.liveSourceLabels = const [],
    this.livePluginId = '',
    this.liveMediaId = '',
    this.loading = false,
    this.statusMessage,
    this.statusKind,
    this.buffering = false,
    this.bufferingPercent = 0,
  });

  @override
  State<PlayerLiveOverlay> createState() => PlayerLiveOverlayState();
}

class PlayerLiveOverlayState extends State<PlayerLiveOverlay> {
  bool _showSources = false;
  int _focusedSource = 0;

  final _backFn = FocusNode();
  FocusNode? _swapFn;
  final _restartFn = FocusNode();
  final _settingsFn = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncSwapNode();
  }

  @override
  void didUpdateWidget(PlayerLiveOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSwapNode();
  }

  void _syncSwapNode() {
    final hasSwap = widget.liveSources.length > 1;
    if (hasSwap && _swapFn == null) {
      _swapFn = FocusNode();
    } else if (!hasSwap && _swapFn != null) {
      // Same fix as PlayerOverlayState._syncEpisodeNodes below: disposing a
      // focused node doesn't hand focus anywhere else, so the D-pad goes
      // dead if the user was sitting on the swap-source button when the
      // source list shrank to ≤1 (e.g. a background source-list refresh).
      if (_swapFn!.hasFocus) _backFn.requestFocus();
      _swapFn!.dispose();
      _swapFn = null;
    }
  }

  @override
  void dispose() {
    _backFn.dispose();
    _swapFn?.dispose();
    _restartFn.dispose();
    _settingsFn.dispose();
    super.dispose();
  }

  /// Mirrors PlayerOverlayState.requestInitialFocus — called by
  /// PlaybackScreen when this overlay is revealed via D-pad.
  void requestInitialFocus() => _backFn.requestFocus();

  List<FocusNode> get _chain =>
      [_backFn, if (_swapFn != null) _swapFn!, _restartFn, _settingsFn];

  void _moveIn(FocusNode self, int dir) {
    final chain = _chain;
    final next = chain.indexOf(self) + dir;
    if (next >= 0 && next < chain.length) chain[next].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent],
              stops: [0.0, 0.4],
            ),
          ),
          // Usa stessa logica responsive del VOD overlay
          child: Builder(builder: (context) {
            final h = MediaQuery.sizeOf(context).height;
            final iconSz = (h * 0.037).clamp(28.0, 48.0);
            final titleFs = (h * 0.024).clamp(18.0, 30.0);
            final hPad = AppScale.screenHPad(context);
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
                  child: Row(
                    children: [
                      _FocusableIconButton(
                        icon: Icons.arrow_back_ios_new,
                        size: iconSz,
                        onPressed: widget.onBack,
                        focusNode: _backFn,
                        onLeft: () => _moveIn(_backFn, -1),
                        onRight: () => _moveIn(_backFn, 1),
                      ),
                      const SizedBox(width: 4),
                      if (widget.title != null)
                        Expanded(
                          child: Text(
                            widget.title!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFs,
                              fontWeight: FontWeight.w600,
                              shadows: const [Shadow(blurRadius: 8)],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                      // Badge LIVE
                      Container(
                        margin:
                            EdgeInsets.only(right: AppScale.space(context, 8)),
                        padding: EdgeInsets.symmetric(
                            horizontal: AppScale.space(context, 10),
                            vertical: AppScale.space(context, 4)),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                color: Colors.white,
                                size: AppScale.space(context, 8)),
                            SizedBox(width: AppScale.space(context, 5)),
                            Text('LIVE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AppScale.caption(context),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ),
                      if (_swapFn != null)
                        _FocusableIconButton(
                          icon: Icons.swap_horiz_rounded,
                          size: iconSz,
                          focusNode: _swapFn!,
                          onLeft: () => _moveIn(_swapFn!, -1),
                          onRight: () => _moveIn(_swapFn!, 1),
                          onPressed: () => setState(() {
                            _showSources = !_showSources;
                            _focusedSource = 0;
                          }),
                        ),
                      _FocusableIconButton(
                        icon: Icons.restart_alt_rounded,
                        size: iconSz,
                        onPressed: widget.onRestart,
                        focusNode: _restartFn,
                        onLeft: () => _moveIn(_restartFn, -1),
                        onRight: () => _moveIn(_restartFn, 1),
                      ),
                      _FocusableIconButton(
                        icon: Icons.settings_rounded,
                        size: iconSz,
                        onPressed: widget.onOpenSettings,
                        focusNode: _settingsFn,
                        onLeft: () => _moveIn(_settingsFn, -1),
                        onRight: () => _moveIn(_settingsFn, 1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: widget.loading
                        ? _LiveLoadingCenter(
                            statusMessage: widget.statusMessage,
                            statusKind: widget.statusKind,
                            buffering: widget.buffering,
                            bufferingPercent: widget.bufferingPercent,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          }),
        ),
        if (_showSources)
          Positioned(
            top: 72,
            right: 16,
            child: _LiveSourcePanel(
              sources: widget.liveSources,
              labels: widget.liveSourceLabels,
              focusedIndex: _focusedSource,
              onFocusChanged: (i) => setState(() => _focusedSource = i),
              onSelect: (i) {
                setState(() => _showSources = false);
                _swapFn?.requestFocus();
                widget.onSwitchSource(
                    widget.liveSources[i], widget.liveSourceLabels[i]);
              },
              onClose: () {
                setState(() => _showSources = false);
                _swapFn?.requestFocus();
              },
            ),
          ),
      ],
    );
  }
}

/// Centre-screen loading indicator for the live overlay (which has no
/// play/pause button to fold the spinner into, unlike PlayerOverlay): a
/// buffer ring — determinate once mpv reports a fill %, indeterminate
/// before that — with the fill % under it and the plugin's current resolve
/// step + an outcome icon below.
class _LiveLoadingCenter extends StatelessWidget {
  final String? statusMessage;
  final String? statusKind;
  final bool buffering;
  final double bufferingPercent;
  const _LiveLoadingCenter({
    this.statusMessage,
    this.statusKind,
    this.buffering = false,
    this.bufferingPercent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final ringSz = (h * 0.07).clamp(48.0, 88.0);
    final fs = AppScale.caption(context);
    final pct = bufferingPercent;
    final hasPct = buffering && pct >= 1 && pct < 100;

    final (icon, iconColor) = switch (statusKind) {
      'success' => (Icons.check_circle_rounded, const Color(0xFF4CAF50)),
      'error' => (Icons.error_rounded, const Color(0xFFE53935)),
      'warning' => (Icons.warning_amber_rounded, const Color(0xFFFFB300)),
      _ => (null, Colors.white70),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PileusSpinner(
          size: ringSz,
          color: Colors.white70,
          value: hasPct ? pct / 100.0 : null,
        ),
        if (hasPct) ...[
          SizedBox(height: h * 0.012),
          Text('${pct.round()}%',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: fs,
                  fontWeight: FontWeight.w600)),
        ],
        if (statusMessage != null) ...[
          SizedBox(height: h * 0.014),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppScale.space(context, 420)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: fs * 1.2, color: iconColor),
                  SizedBox(width: fs * 0.5),
                ],
                Flexible(
                  child: Text(
                    statusMessage!,
                    style: TextStyle(color: Colors.white70, fontSize: fs),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LiveSourcePanel extends StatefulWidget {
  final List<String> sources;
  final List<String> labels;
  final int focusedIndex;
  final void Function(int) onFocusChanged;
  final void Function(int) onSelect;
  final VoidCallback onClose;

  const _LiveSourcePanel({
    required this.sources,
    required this.labels,
    required this.focusedIndex,
    required this.onFocusChanged,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_LiveSourcePanel> createState() => _LiveSourcePanelState();
}

class _LiveSourcePanelState extends State<_LiveSourcePanel> {
  late List<FocusNode> _fns =
      List.generate(widget.sources.length, (_) => FocusNode());

  @override
  void didUpdateWidget(_LiveSourcePanel old) {
    super.didUpdateWidget(old);
    if (old.sources.length != widget.sources.length) {
      // Disposing a focused FocusNode doesn't transfer focus anywhere else —
      // the D-pad would silently stop responding. Same failure mode already
      // guarded against in _PlayerLiveOverlayState._syncEpisodeNodes above;
      // not currently reachable (sources are fixed for the screen's
      // lifetime) but kept consistent in case that ever changes.
      final hadFocus = anyHasFocus(_fns);
      for (final n in _fns) {
        n.dispose();
      }
      _fns = List.generate(widget.sources.length, (_) => FocusNode());
      if (hadFocus) {
        if (_fns.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fns.first.requestFocus();
          });
        } else {
          widget.onClose();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final n in _fns) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This panel is Positioned(top: 72, right: 16) with no left/bottom
    // bound — a bare fixed width had nothing stopping it from extending
    // past the left edge of a narrow player window, and an unbounded
    // height meant a source list long enough to reach the bottom of the
    // screen just overflowed off it with no way to scroll to or reach the
    // rows below the edge. Capping both against the real screen size
    // (minus the panel's own offset and a symmetric margin) keeps it
    // fully on-screen and scrollable instead.
    final screenSize = MediaQuery.sizeOf(context);
    final maxW = (screenSize.width - 32.0).clamp(0.0, 280.0);
    final maxH = (screenSize.height - 72.0 - 16.0).clamp(0.0, double.infinity);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: maxW,
        constraints: BoxConstraints(maxHeight: maxH),
        padding: EdgeInsets.all(AppScale.space(context, 12)),
        decoration: BoxDecoration(
          color: const Color(0xEE111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // No close ("X") button here — on a remote-only interface it
            // would be unreachable by D-pad (nothing wires an arrow key to
            // it) and is redundant anyway: every source row below already
            // closes the panel on escape/back.
            Text('SORGENTI',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: AppScale.caption(context),
                    letterSpacing: 1.4)),
            SizedBox(height: AppScale.space(context, 8)),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.sources.length; i++)
                      _buildRow(context, i),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int i) {
    final isFocused = widget.focusedIndex == i;
    final label =
        i < widget.labels.length ? widget.labels[i] : widget.sources[i];
    return TvFocusable(
      focusNode: _fns[i],
      autofocus: i == 0,
      onFocusChange: (v) {
        if (v) widget.onFocusChanged(i);
      },
      onActivate: () => widget.onSelect(i),
      onUp: i > 0 ? () => _fns[i - 1].requestFocus() : null,
      onDown: i < _fns.length - 1 ? () => _fns[i + 1].requestFocus() : null,
      onEsc: widget.onClose,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(bottom: AppScale.space(context, 6)),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 12),
            vertical: AppScale.space(context, 10)),
        decoration: BoxDecoration(
          color: isFocused
              ? AppTheme.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? AppTheme.primary : Colors.transparent,
          ),
          boxShadow: isFocused ? AppScale.focusGlow(AppTheme.primary) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow_rounded,
                color: isFocused ? Colors.white : Colors.white54,
                size: AppScale.iconS(context)),
            SizedBox(width: AppScale.space(context, 8)),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: isFocused ? Colors.white : Colors.white70,
                    fontSize: AppScale.space(context, 14),
                    fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                  )),
            ),
            if (i == 0)
              Text('HD',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: AppScale.caption(context),
                      letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
