// Part of home_screen.dart — split out for readability (plan 2e). The library
// file holds the shared imports plus the _HomeFsm enum and the HomeScreen
// entry point; private identifiers are shared across all parts.
part of '../home_screen.dart';

// ── Continue watching strip ────────────────────────────────────────────────────

class _ContinueWatchingStrip extends StatefulWidget {
  final List<ContinueWatchingItem> items;
  final void Function(FocusNode) onFirstCardFocus;
  final void Function(ContinueWatchingItem)? onItemFocused;
  final VoidCallback onOpenNav;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final void Function(LogicalKeyboardKey key, bool isDown)?
      onNavigateHoldChanged;

  const _ContinueWatchingStrip({
    super.key,
    required this.items,
    required this.onFirstCardFocus,
    required this.onOpenNav,
    this.onItemFocused,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onNavigateHoldChanged,
  });

  @override
  State<_ContinueWatchingStrip> createState() => _ContinueWatchingStripState();
}

class _ContinueWatchingStripState extends State<_ContinueWatchingStrip> {
  int _focusedIndex = 0;
  late List<FocusNode> _fns;

  double _cardW = 0;
  double _cardH = 0;
  double _cardGap = 0;
  double _hPad = 0;
  double _scaleOvf = 0;
  double _avail = 0;

  // How many landscape cards actually fit in the strip's own width at the
  // card size computed below — replaces a fixed slot count now that the
  // card's width is derived from a target height (see didChangeDependencies)
  // rather than the other way around, so it isn't fixed either.
  int get _visibleCards =>
      ((_avail + _cardGap) / (_cardW + _cardGap)).floor().clamp(1, 999);

  @override
  void initState() {
    super.initState();
    _buildFocusNodes(initialFocus: true);
  }

  // Called by _StandardHomeShellState (via GlobalKey) whenever this strip
  // becomes the shown row — the strip stays mounted across plugin re-visits,
  // so its own initState self-focus only runs the first time. Returns
  // whether the node is real (attached + focusable), i.e. the request will
  // actually take.
  bool focusFirstCard() {
    if (_fns.isEmpty) return false;
    final n = _fns[0];
    if (n.context == null || !n.canRequestFocus) return false;
    n.requestFocus();
    widget.onFirstCardFocus(n);
    widget.onItemFocused?.call(widget.items[0]);
    return true;
  }

  @override
  void didUpdateWidget(_ContinueWatchingStrip old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) {
      final prevFocused = _focusedIndex;
      // Only restore focus into the strip if it already had focus somewhere
      // inside it — otherwise a background reload (e.g. LoadContinueWatchingEvent
      // firing while the user has since moved into the side nav or elsewhere)
      // yanks focus back into this strip out from under them. Same guard as
      // card_carousel_block_view.dart's _FixedCarouselView/_LiveRowView.
      final hadFocus = anyHasFocus(_fns);
      for (final n in _fns) {
        n.dispose();
      }
      _buildFocusNodes(initialFocus: false);
      // Move focus to nearest valid index after deletion.
      // Guard against empty list: clamp(0, -1) throws ArgumentError.
      if (widget.items.isNotEmpty && hadFocus) {
        final target = prevFocused.clamp(0, widget.items.length - 1);
        if (target < _fns.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fns[target].requestFocus();
          });
        }
      }
    } else if (!identical(old.items, widget.items) &&
        _focusedIndex < widget.items.length) {
      // Same count but a reload swapped in fresh instances (e.g. the just-
      // watched entry got updated metadata) — re-notify for the focused
      // card so the hero picks up the new data without a focus move.
      // Deferred: onItemFocused calls setState on an ancestor, which can't
      // run during this didUpdateWidget.
      final focusedItem = widget.items[_focusedIndex];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onItemFocused?.call(focusedItem);
      });
    }
  }

  void _buildFocusNodes({required bool initialFocus}) {
    _fns = List.generate(widget.items.length, (_) => FocusNode());
    for (var i = 0; i < _fns.length; i++) {
      final idx = i;
      _fns[idx].addListener(() {
        if (_fns[idx].hasFocus && _focusedIndex != idx) {
          setState(() => _focusedIndex = idx);
          widget.onItemFocused?.call(widget.items[idx]);
        }
      });
    }
    if (_fns.isNotEmpty && initialFocus) {
      widget.onFirstCardFocus(_fns[0]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fns[0].requestFocus();
          widget.onItemFocused?.call(widget.items[0]);
        }
      });
    }
  }

  // Called every time MediaQuery changes (window resize, orientation, etc.)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenW = MediaQuery.sizeOf(context).width;
    final baseHPad = AppScale.catalogHPadRatio(screenW);
    final baseGap = AppScale.catalogGapRatio(screenW);
    _avail = screenW - baseHPad * 2;
    // Height matches the poster carousels' own card height (same
    // _kVisibleCards/formula they use, see card_carousel_block_view.dart)
    // instead of being computed from a fixed CW-only visible-card count —
    // landscape (16:9) cards sized that way used to end up roughly half as
    // tall as the poster rows right below them, reading as a visibly
    // smaller, lower-priority strip on the same screen.
    final posterCardW =
        (_avail - baseGap * (_kVisibleCards - 1)) / _kVisibleCards;
    _cardH = posterCardW * 1.5;
    _cardW = _cardH * 16 / 9; // keep the landscape aspect at that height
    // A landscape card is much wider than a poster card at the same
    // height, so the same shared focus scale (AppScale.focusScaleCard)
    // overflows far more in absolute pixels here — left unaccounted for,
    // the focused card visibly overlapped its neighbour, and this strip's
    // own leading edge sat further left than the poster carousels' below
    // it once their own (much smaller) overflow is factored in. Reserve
    // exactly the extra overflow versus a poster card at the same scale,
    // so neighbouring cards never overlap and both rows' focused-card
    // edges line up.
    final overflowCW = _cardW * (AppScale.focusScaleCard - 1) / 2;
    final overflowPoster = posterCardW * (AppScale.focusScaleCard - 1) / 2;
    _hPad = baseHPad + (overflowCW - overflowPoster);
    _cardGap = baseGap + overflowCW;
    _scaleOvf = _cardH * 0.08;
  }

  // Mirrors card_carousel_block_view.dart: a fresh Left press steps back a
  // card or opens the side nav on the first one; a held Left (routed to
  // _navigateLeftRepeat by the card via HeldKeyGate) only ever steps.
  void _navigateLeft(int i) {
    if (i > 0) {
      _fns[i - 1].requestFocus();
    } else {
      widget.onOpenNav();
    }
  }

  void _navigateLeftRepeat(int i) {
    if (i > 0) _fns[i - 1].requestFocus();
  }

  @override
  void dispose() {
    for (final n in _fns) {
      n.dispose();
    }
    super.dispose();
  }

  void _onTap(BuildContext ctx, ContinueWatchingItem item) {
    final extra = <String, dynamic>{
      // playableID is the plugin's already-resolved, per-language streamId —
      // same value every other /player push site passes as 'streamId' to
      // resolve it directly. Without this, PlaybackScreen falls back to
      // InitializeVideoEvent, which re-runs GetStreams on playableID as if
      // it were a bare mediaId; a plugin whose ids already carry a
      // language/variant suffix can then double-suffix it and fail its own
      // parsing, so the resolve fails outright.
      'streamId': item.playableID,
      // A "roll-forward" row (the next episode written when you finished the
      // previous one — see playback_screen._onPosition) is stored at ~31 s
      // purely to clear mycelium's `progress_time >= 30` CW filter; it's not
      // a real resume point. Recognise it (no known duration + tiny
      // progress) and start from the top instead.
      'seekTo': (item.totalTime <= 0 && item.progressTime <= 35)
          ? 0
          : item.progressTime.toInt(),
      'poster': item.poster,
      'parentId': item.parentID,
      if (item.title.isNotEmpty) 'title': item.title,
      // Re-sent on resume so a re-watch keeps refreshing these (the
      // backend's UpsertProgress won't let a blank value overwrite an
      // already-stored one, so this is purely "keep it fresh," never lossy).
      // PlaybackArgs.genres expects a List — item.genres already is one.
      'showTitle': item.showTitle,
      'plot': item.plot,
      'rating': item.rating,
      if (item.genres.isNotEmpty) 'genres': item.genres,
      if (item.year > 0) 'year': item.year,
      'durationSeconds': item.durationSeconds,
    };

    // Episode prev/next list is rebuilt player-side after playback starts
    // (PlaybackScreen._resolveEpisodeListIfMissing) — it may need to walk
    // several season directories, so it's not worth blocking the tap on
    // here. Just pass the plugin id so that resolver knows who to ask.
    if (item.parentID.isNotEmpty) extra['pluginId'] = item.providerID;

    ctx.push(
      '/player/${item.providerID}/${Uri.encodeComponent(item.playableID)}',
      extra: extra,
    );
  }

  void _onDelete(BuildContext ctx, ContinueWatchingItem item) {
    ctx.read<ContinueWatchingBloc>().add(
          RemoveContinueWatchingEvent(item.providerID, item.playableID),
        );
  }

  // parentID resolves to the *series* when this item is an episode (see
  // _onTap's own lookupId logic above for the same rule) — for a movie it's
  // empty, so playableID (the movie's own mediaId) is the right fallback.
  void _onDetails(BuildContext ctx, ContinueWatchingItem item) {
    final lookupId = item.parentID.isNotEmpty ? item.parentID : item.playableID;
    ctx.push('/details/${item.providerID}/${Uri.encodeComponent(lookupId)}');
  }

  @override
  Widget build(BuildContext context) {
    final scrollIdx = _focusedIndex.clamp(
        0, (widget.items.length - _visibleCards).clamp(0, 9999));
    final translateX = scrollIdx * (_cardW + _cardGap);

    final row = Padding(
      padding: EdgeInsets.only(left: _hPad),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < widget.items.length; i++) ...[
            if (i > 0) SizedBox(width: _cardGap),
            _ContinueWatchingCard(
              item: widget.items[i],
              focusNode: _fns[i],
              width: _cardW,
              height: _cardH,
              scaleOvf: _scaleOvf,
              onTap: () => _onTap(context, widget.items[i]),
              onDetails: () => _onDetails(context, widget.items[i]),
              onDelete: () => _onDelete(context, widget.items[i]),
              onLeft: () => _navigateLeft(i),
              onLeftRepeat: () => _navigateLeftRepeat(i),
              onRight:
                  i < _fns.length - 1 ? () => _fns[i + 1].requestFocus() : null,
              onUp: widget.onNavigateUp,
              onDown: widget.onNavigateDown,
              onHoldChanged: widget.onNavigateHoldChanged,
              // Back leaves the home (PopScope's exit-confirm), it doesn't
              // open the side nav — same as the catalog rows.
              onEsc: () {
                if (consumeBackEvent()) Navigator.of(context).maybePop();
              },
            ),
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _cardH + _scaleOvf * 2,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: _scaleOvf),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: translateX),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  builder: (_, tx, __) => Transform.translate(
                    offset: Offset(-tx, 0),
                    child: row,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.sizeOf(context).height * (20.0 / 1080.0)),
        SizedBox(height: MediaQuery.sizeOf(context).height * (24.0 / 1080.0)),
      ],
    );
  }
}

// mm:ss (or h:mm:ss past an hour) — the point a continue-watching item was
// stopped at, same clock format the player's own seek bar uses.
String _fmtClock(double seconds) {
  final total = seconds.round().clamp(0, 359999);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

// Coarser than _fmtClock on purpose — "how much is left" reads better as a
// rounded minute count than a literal countdown clock.
String _fmtRemaining(double secondsLeft) {
  final mins = (secondsLeft / 60).round();
  if (mins < 1) return 'meno di 1 min rimanente';
  if (mins < 60) return '$mins min rimanenti';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m > 0 ? '${h}h ${m}min rimanenti' : '${h}h rimanenti';
}

class _ContinueWatchingCard extends StatefulWidget {
  final ContinueWatchingItem item;
  final FocusNode focusNode;
  final double width;
  final double height;
  final double scaleOvf;
  final VoidCallback onTap;
  final VoidCallback? onDetails;
  final VoidCallback? onDelete;
  final VoidCallback? onLeft;
  // See _PosterCardView.onLeftRepeat in card_carousel_block_view.dart.
  final VoidCallback? onLeftRepeat;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  // Distinct from onUp — see _PosterCardView.onEsc's doc in
  // card_carousel_block_view.dart for why: onUp here means "focus the
  // search bar" (this strip is the topmost row), so Back used to silently
  // open search instead of the side nav.
  final VoidCallback? onEsc;
  // See _PosterCardView.onHoldChanged's doc in card_carousel_block_view.dart.
  final void Function(LogicalKeyboardKey key, bool isDown)? onHoldChanged;

  const _ContinueWatchingCard({
    required this.item,
    required this.focusNode,
    required this.width,
    required this.height,
    required this.scaleOvf,
    required this.onTap,
    this.onDetails,
    this.onDelete,
    this.onLeft,
    this.onLeftRepeat,
    this.onRight,
    this.onUp,
    this.onDown,
    this.onEsc,
    this.onHoldChanged,
  });

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  bool _focused = false;
  bool _selectHeld = false;
  bool _contextMenuShown = false;
  final _leftGate = HeldKeyGate();
  // Wall-clock hold detection for OK/Enter — HDMI-CEC boxes deliver a
  // KeyDown then a KeyUp with no KeyRepeatEvent in between, so a held OK on
  // CEC never tripped the repeat-only branch below and always read as a
  // tap. The timer fires the context menu independently of repeats (same
  // approach _PosterCardView already uses in card_carousel_block_view.dart).
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _leftGate.dispose();
    super.dispose();
  }

  void _showContextMenu(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => _CwContextMenu(
        title: widget.item.showTitle.isNotEmpty &&
                widget.item.showTitle.toLowerCase() !=
                    widget.item.title.toLowerCase()
            ? '${widget.item.showTitle} · ${widget.item.title}'
            : widget.item.title,
        onDetails: () {
          Navigator.of(dialogCtx).pop();
          widget.onDetails?.call();
        },
        onRemove: () {
          Navigator.of(dialogCtx).pop();
          widget.onDelete?.call();
        },
        onCancel: () => Navigator.of(dialogCtx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Was a magic 1.08 — shared with every other card in the app so CW
    // doesn't scale differently from the poster/live rows right below it.
    final scale = _focused ? AppScale.focusScaleCard : 1.0;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
        // See _PosterCardView's onKeyEvent in card_carousel_block_view.dart
        // for why arrowUp/arrowDown report onHoldChanged on both press and
        // release instead of relying on native key-repeat.
        if (event is KeyUpEvent &&
            (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown)) {
          widget.onHoldChanged?.call(event.logicalKey, false);
          return KeyEventResult.ignored;
        }
        // Swallow held-arrow repeats when the parent drives its own
        // hold-repeat timer — see the matching note in
        // card_carousel_block_view.dart's _PosterCardView: an unhandled
        // KeyRepeatEvent bubbles to Flutter's default directional traversal
        // and ping-pongs focus between this strip and the search bar,
        // flickering quick search while Up is held.
        if (event is KeyRepeatEvent &&
            widget.onHoldChanged != null &&
            (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown)) {
          return KeyEventResult.handled;
        }
        // Left key-up → feed the gate so the next Left press reads as fresh.
        if (event is KeyUpEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _leftGate.isRepeat(event);
          return KeyEventResult.ignored;
        }
        // Held Left → step card-to-card, never open the side nav.
        if (event is KeyRepeatEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _leftGate.isRepeat(event);
          (widget.onLeftRepeat ?? widget.onLeft)?.call();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            (_leftGate.isRepeat(event)
                    ? (widget.onLeftRepeat ?? widget.onLeft)
                    : widget.onLeft)
                ?.call();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onRight?.call();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onUp?.call();
            widget.onHoldChanged?.call(event.logicalKey, true);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onDown?.call();
            widget.onHoldChanged?.call(event.logicalKey, true);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            widget.onDelete?.call();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            final cb = widget.onEsc ?? widget.onUp;
            cb?.call();
            return cb != null ? KeyEventResult.handled : KeyEventResult.ignored;
          }
        }
        // OK/Enter: hold = context menu, tap = play
        final isOk = event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter;
        if (isOk) {
          if (event is KeyDownEvent) {
            if (!_selectHeld) {
              _selectHeld = true;
              _contextMenuShown = false;
              _holdTimer?.cancel();
              _holdTimer = Timer(const Duration(milliseconds: 500), () {
                if (!mounted || !_selectHeld || _contextMenuShown) return;
                _contextMenuShown = true;
                _showContextMenu(context);
              });
            }
            return KeyEventResult.handled;
          }
          // OS-level repeat (physical remotes): fire the menu immediately.
          if (event is KeyRepeatEvent && _selectHeld && !_contextMenuShown) {
            _holdTimer?.cancel();
            _contextMenuShown = true;
            _showContextMenu(context);
            return KeyEventResult.handled;
          }
          if (event is KeyUpEvent && _selectHeld) {
            _holdTimer?.cancel();
            if (!_contextMenuShown) widget.onTap();
            _selectHeld = false;
            _contextMenuShown = false;
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: scale,
        duration: AppScale.focusDuration,
        curve: AppScale.focusCurve,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            children: [
              // Poster / thumbnail
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: widget.item.poster.isNotEmpty
                      ? CachedNetworkImage(
                          // Web-only, no-op on every other platform — see image_sizing.dart's
                          // "ImageRenderMethodForWeb.HttpGet" section for why every
                          // CachedNetworkImage call site in the app sets this.
                          imageRenderMethodForWeb:
                              ImageRenderMethodForWeb.HttpGet,
                          imageUrl: posterSrc(widget.item.poster,
                              cacheWidthFor(context, widget.width),
                              proxy: true),
                          fit: BoxFit.cover,
                          memCacheWidth: cacheWidthFor(context, widget.width),
                          fadeInDuration: const Duration(milliseconds: 200),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF1A1A2A)),
                        )
                      : const ColoredBox(color: Color(0xFF1A1A2A)),
                ),
              ),
              // Tap / long-press area
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onLongPress: () => _showContextMenu(context),
                ),
              ),
              // Focus ring
              if (_focused)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary, width: 3),
                      ),
                    ),
                  ),
                ),
              // Title gradient + text
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        8,
                        widget.item.progressFraction > 0 ? 20 : 16,
                        8,
                        widget.item.progressFraction > 0 ? 14 : 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Series name (overline) — only when this is an
                          // episode and it isn't just a repeat of the title.
                          if (widget.item.showTitle.isNotEmpty &&
                              widget.item.showTitle.toLowerCase() !=
                                  widget.item.title.toLowerCase()) ...[
                            Text(
                              widget.item.showTitle,
                              style: TextStyle(
                                color: AppTheme.textMid,
                                fontSize: AppScale.space(context, 11),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            widget.item.title,
                            style: TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: AppScale.space(context, 16),
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.item.totalTime > 0) ...[
                            const SizedBox(height: 3),
                            Text(
                              '${_fmtClock(widget.item.progressTime)} · '
                              '${_fmtRemaining(widget.item.totalTime - widget.item.progressTime)}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: AppScale.space(context, 11),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Progress bar — on top of gradient, well visible
              if (widget.item.progressFraction > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      child: SizedBox(
                        height: 5,
                        child: LinearProgressIndicator(
                          value: widget.item.progressFraction,
                          backgroundColor:
                              AppTheme.textHigh.withValues(alpha: 0.22),
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CW context menu ────────────────────────────────────────────────────────────

class _CwContextMenu extends StatefulWidget {
  final String title;
  final VoidCallback onDetails;
  final VoidCallback onRemove;
  final VoidCallback onCancel;

  const _CwContextMenu({
    required this.title,
    required this.onDetails,
    required this.onRemove,
    required this.onCancel,
  });

  @override
  State<_CwContextMenu> createState() => _CwContextMenuState();
}

class _CwContextMenuState extends State<_CwContextMenu> {
  final _detailsFn = FocusNode();
  final _removeFn = FocusNode();
  final _cancelFn = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _detailsFn.requestFocus();
    });
  }

  @override
  void dispose() {
    _detailsFn.dispose();
    _removeFn.dispose();
    _cancelFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: const Color(0xFF14141F),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: AppScale.space(context, 18),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  CwMenuButton(
                    focusNode: _detailsFn,
                    icon: Icons.info_outline_rounded,
                    label: 'Dettagli',
                    color: AppTheme.textMid,
                    onTap: widget.onDetails,
                    onUp: null,
                    onDown: () => _removeFn.requestFocus(),
                  ),
                  const SizedBox(height: 8),
                  CwMenuButton(
                    focusNode: _removeFn,
                    icon: Icons.delete_outline_rounded,
                    label: 'Rimuovi dai continua a guardare',
                    color: const Color(0xFFef4444),
                    onTap: widget.onRemove,
                    onUp: () => _detailsFn.requestFocus(),
                    onDown: () => _cancelFn.requestFocus(),
                  ),
                  const SizedBox(height: 8),
                  CwMenuButton(
                    focusNode: _cancelFn,
                    icon: Icons.close_rounded,
                    label: 'Annulla',
                    color: AppTheme.textMid,
                    onTap: widget.onCancel,
                    onUp: () => _removeFn.requestFocus(),
                    onDown: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  final bool featured;
  const _SkeletonRow({this.featured = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleCards = featured ? _kVisibleCardsFeatured : _kVisibleCards;
        final screenW = constraints.maxWidth;
        final hPad = AppScale.catalogHPadRatio(screenW);
        final cardGap = AppScale.catalogGapRatio(screenW);
        final avail = screenW - hPad * 2;
        final cardW = (avail - cardGap * (visibleCards - 1)) / visibleCards;
        final cardH = cardW * 3 / 2;

        return SizedBox(
          height: cardH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: visibleCards,
            itemBuilder: (_, __) => Padding(
              padding: EdgeInsets.only(right: cardGap),
              child: Container(
                width: cardW,
                height: cardH,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2A),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
