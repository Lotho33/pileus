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
  final List<List<String>> liveSourcePaths;
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
    this.liveSourcePaths = const [],
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
              paths: widget.liveSourcePaths,
              current: widget.liveSourceLabels.indexOf(widget.sourceLabel),
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
  // source_tree.dart: groups to open with OK; empty = the flat list.
  final List<List<String>> paths;
  // The source playing (its group opens first), -1 when unknown.
  final int current;
  final int focusedIndex;
  final void Function(int) onFocusChanged;
  final void Function(int) onSelect;
  final VoidCallback onClose;

  const _LiveSourcePanel({
    required this.sources,
    required this.labels,
    this.paths = const [],
    this.current = -1,
    required this.focusedIndex,
    required this.onFocusChanged,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_LiveSourcePanel> createState() => _LiveSourcePanelState();
}

class _LiveSourcePanelState extends State<_LiveSourcePanel> {
  late List<String> _open =
      groupOf(widget.paths, widget.current >= 0 ? widget.current : 0);
  // One node per visible row, rebuilt when a group opens or closes.
  List<FocusNode> _fns = [];
  int _focusedRow = 0;

  List<SourceRow> get _rows => sourceRows(
      widget.paths,
      List.generate(widget.sources.length,
          (i) => i < widget.labels.length ? widget.labels[i] : widget.sources[i]),
      open: hasSourceGroups(widget.paths) ? _open : null);

  // A new node per visible row when their number changes. The old nodes are
  // disposed after the frame (the rows being replaced still hold them), and
  // focus goes back to the row it was on: a disposed focused node would leave
  // the D-pad with nothing to move.
  void _syncNodes(int n) {
    if (_fns.length == n) return;
    final old = _fns;
    final hadFocus = old.isEmpty ? _refocus : anyHasFocus(old);
    _refocus = false;
    _fns = List.generate(n, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final f in old) {
        f.dispose();
      }
      if (!mounted || !hadFocus) return;
      if (_fns.isEmpty) {
        widget.onClose();
      } else {
        _fns[_focusedRow.clamp(0, _fns.length - 1)].requestFocus();
      }
    });
  }

  bool _refocus = false;

  void _toggle(SourceRow r, int rowIndex) {
    setState(() {
      _open = toggleGroup(_open, r.group);
      _focusedRow = rowIndex; // the header stays where it was
      _refocus = anyHasFocus(_fns);
    });
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
    final rows = _rows;
    _syncNodes(rows.length);
    // Capped to the screen and scrollable (a long list used to run off it).
    final screenSize = MediaQuery.sizeOf(context);
    final maxW = (screenSize.width - 32.0).clamp(0.0, 300.0);
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
            // No close button: unreachable by D-pad; back closes the panel.
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
                    for (var i = 0; i < rows.length; i++)
                      _buildRow(context, rows[i], i, rows.length),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, SourceRow r, int i, int n) {
    final isFocused = _focusedRow == i;
    final isCurrent = !r.isGroup && r.index == widget.current;
    final open = r.isGroup && groupIsOpen(_open, r.group);
    return TvFocusable(
      focusNode: _fns[i],
      autofocus: i == 0,
      onFocusChange: (v) {
        if (!v) return;
        setState(() => _focusedRow = i);
        if (!r.isGroup) widget.onFocusChanged(r.index!);
      },
      onActivate: () =>
          r.isGroup ? _toggle(r, i) : widget.onSelect(r.index!),
      onUp: i > 0 ? () => _fns[i - 1].requestFocus() : null,
      onDown: i < n - 1 ? () => _fns[i + 1].requestFocus() : null,
      onEsc: widget.onClose,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(
            bottom: AppScale.space(context, 6),
            left: AppScale.space(context, 14) * r.depth),
        padding: EdgeInsets.symmetric(
            horizontal: AppScale.space(context, 12),
            vertical: AppScale.space(context, 10)),
        decoration: BoxDecoration(
          color: isFocused
              ? AppTheme.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: r.isGroup ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? AppTheme.primary : Colors.transparent,
          ),
          boxShadow: isFocused ? AppScale.focusGlow(AppTheme.primary) : null,
        ),
        child: Row(
          children: [
            Icon(
                r.isGroup
                    ? (open
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded)
                    : (isCurrent
                        ? Icons.check_rounded
                        : Icons.play_arrow_rounded),
                color: isFocused || isCurrent ? Colors.white : Colors.white54,
                size: AppScale.iconS(context)),
            SizedBox(width: AppScale.space(context, 8)),
            Expanded(
              child: Text(r.title,
                  style: TextStyle(
                    color: isFocused ? Colors.white : Colors.white70,
                    fontSize: AppScale.space(context, 14),
                    fontWeight: isFocused || r.isGroup
                        ? FontWeight.w600
                        : FontWeight.normal,
                  )),
            ),
            if (r.isGroup)
              Text('${r.count}',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: AppScale.caption(context))),
          ],
        ),
      ),
    );
  }
}
