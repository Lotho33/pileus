// Part of player_overlay.dart — split out for readability (plan 2e). The
// library file holds the shared imports and the PlayerOverlay widget;
// private identifiers are shared across all parts.
part of '../player_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Live channel overlay
// ─────────────────────────────────────────────────────────────────────────────

class PlayerLiveOverlay extends StatefulWidget {
  final String? title;

  /// The source playing now ("Diretta", a channel name) — under the title.
  final String sourceLabel;
  final List<String> liveSources;
  final List<String> liveSourceLabels;
  final String livePluginId;
  final String liveMediaId;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  // The (i) button: the info panel. Null hides it.
  final VoidCallback? onOpenInfo;
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
    this.onOpenInfo,
    required this.onSwitchSource,
    required this.onRestart,
    this.title,
    this.sourceLabel = '',
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

  FocusNode? _swapFn;
  final _restartFn = FocusNode();
  final _settingsFn = FocusNode();
  final _infoFn = FocusNode();

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
      if (_swapFn!.hasFocus) _restartFn.requestFocus();
      _swapFn!.dispose();
      _swapFn = null;
    }
  }

  @override
  void dispose() {
    _swapFn?.dispose();
    _restartFn.dispose();
    _settingsFn.dispose();
    _infoFn.dispose();
    super.dispose();
  }

  /// Mirrors PlayerOverlayState.requestInitialFocus — called by
  /// PlaybackScreen when this overlay is revealed via D-pad. A live has no
  /// pause: focus lands on "Riavvia", as on the Vega OS player.
  void requestInitialFocus() => _restartFn.requestFocus();

  // The bottom row, left to right: source switch (more than one source),
  // then "Riavvia" and settings at the far right.
  List<FocusNode> get _chain => [
        if (_swapFn != null) _swapFn!,
        _restartFn,
        if (widget.onOpenInfo != null) _infoFn,
        _settingsFn,
      ];

  void _moveIn(FocusNode self, int dir) {
    final chain = _chain;
    final next = chain.indexOf(self) + dir;
    if (next >= 0 && next < chain.length) chain[next].requestFocus();
  }

  // Layout of the Vega OS player on a live (pileus-vega PlayerScreen), like
  // PlayerOverlay's on a film: title and source top left; at the bottom the
  // IN DIRETTA badge and under it the row of round buttons. Sizes in 1080p
  // pixels of the screen height. Spinner and resolve status in the middle
  // while loading.
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final u = sh / 1080;
    final hPad = 64 * u;
    // Row height (72) + its top margin (28) + bottom padding (48), so the
    // source list opens just above the row.
    final rowTop = 48 * u + 72 * u;

    Widget rowButton(FocusNode fn,
        {IconData? icon,
        String? label,
        required String semantic,
        VoidCallback? onPressed}) {
      return _ShakaButton(
        icon: icon,
        label: label,
        semanticLabel: semantic,
        onPressed: onPressed,
        focusNode: fn,
        onLeft: () => _moveIn(fn, -1),
        onRight: () => _moveIn(fn, 1),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000),
                  Colors.transparent,
                  Color(0xDD000000)
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // ── Top: title, source ────────────────────────────────────────────
        Positioned(
          left: hPad,
          right: hPad,
          top: 48 * u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.title != null)
                Text(
                  widget.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 40 * u,
                    fontWeight: FontWeight.w800,
                    shadows: const [Shadow(blurRadius: 8)],
                  ),
                ),
              if (widget.sourceLabel.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 6 * u),
                  child: Text(
                    widget.sourceLabel,
                    style: TextStyle(color: AppTheme.textMid, fontSize: 24 * u),
                  ),
                ),
            ],
          ),
        ),

        // ── Middle: loading ───────────────────────────────────────────────
        if (widget.loading)
          Center(
            child: _LiveLoadingCenter(
              statusMessage: widget.statusMessage,
              statusKind: widget.statusKind,
              buffering: widget.buffering,
              bufferingPercent: widget.bufferingPercent,
            ),
          ),

        // ── Bottom: badge, buttons ────────────────────────────────────────
        Positioned(
          left: hPad,
          right: hPad,
          bottom: 48 * u,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14 * u, vertical: 6 * u),
                decoration: BoxDecoration(
                  color: const Color(0xE6E53935),
                  borderRadius: BorderRadius.circular(6 * u),
                ),
                child: Text('IN DIRETTA',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20 * u,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ),
              SizedBox(height: 28 * u),
              Row(
                children: [
                  if (_swapFn != null)
                    rowButton(_swapFn!,
                        icon: Icons.swap_horiz_rounded,
                        label: 'Sorgente',
                        semantic: 'Cambia sorgente',
                        onPressed: () => setState(() {
                              _showSources = !_showSources;
                              _focusedSource = 0;
                            })),
                  const Spacer(),
                  rowButton(_restartFn,
                      icon: Icons.refresh_rounded,
                      label: 'Riavvia',
                      semantic: 'Riavvia la diretta',
                      onPressed: widget.onRestart),
                  SizedBox(width: 16 * u),
                  if (widget.onOpenInfo != null) ...[
                    rowButton(_infoFn,
                        icon: Icons.info_outline_rounded,
                        semantic: 'Informazioni sulla diretta',
                        onPressed: widget.onOpenInfo),
                    SizedBox(width: 16 * u),
                  ],
                  rowButton(_settingsFn,
                      icon: Icons.settings_rounded,
                      semantic: 'Impostazioni di riproduzione',
                      onPressed: widget.onOpenSettings),
                ],
              ),
            ],
          ),
        ),

        if (_showSources)
          Positioned(
            left: hPad,
            bottom: rowTop + 16 * u,
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
