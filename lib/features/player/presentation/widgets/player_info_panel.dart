// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../player_info.dart';

/// The player's info panel: a translucent column on the right with what is
/// known about the title playing — the video keeps playing beside it. Shows
/// [base] at once and swaps in [details] when it lands.
///
/// [tv]: sized off the screen height (as the TV player's controls) and
/// driven by the remote — it takes focus, ↑/↓ scroll, Back/Info/OK close
/// (through [onClose]). Elsewhere: a close button and the mouse wheel /
/// touch scroll.
class PlayerInfoPanel extends StatefulWidget {
  final PlayerInfo base;
  final Future<PlayerInfo>? details;
  final VoidCallback onClose;
  final bool tv;

  const PlayerInfoPanel({
    super.key,
    required this.base,
    required this.onClose,
    this.details,
    this.tv = false,
  });

  @override
  State<PlayerInfoPanel> createState() => _PlayerInfoPanelState();
}

class _PlayerInfoPanelState extends State<PlayerInfoPanel> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'player-info');

  @override
  void initState() {
    super.initState();
    if (widget.tv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowUp) {
      if (_scroll.hasClients) {
        final step = MediaQuery.sizeOf(context).height * 0.12;
        final to = (_scroll.offset +
                (k == LogicalKeyboardKey.arrowDown ? step : -step))
            .clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.animateTo(to,
            duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
      }
      return KeyEventResult.handled;
    }
    if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.info)) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    // ←/→ stay with the panel (no seek while reading); Back bubbles up to
    // the player, which closes the panel.
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // TV: everything off the screen height, as the TV controls (1080p px).
    final u = widget.tv ? size.height / 1080 : 1.0;
    final width =
        widget.tv ? size.width * 0.38 : (size.width * 0.42).clamp(280.0, 460.0);

    final panel = FutureBuilder<PlayerInfo>(
      future: widget.details,
      initialData: widget.base,
      builder: (context, snap) => _content(snap.data ?? widget.base, u,
          loading: snap.connectionState == ConnectionState.waiting),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Focus(
        focusNode: _focus,
        canRequestFocus: widget.tv,
        onKeyEvent: _onKey,
        child: Container(
          width: width,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xCC0D0D1A), Color(0xF20D0D1A)],
            ),
          ),
          child: SafeArea(left: false, child: panel),
        ),
      ),
    );
  }

  Widget _content(PlayerInfo i, double u, {required bool loading}) {
    final tv = widget.tv;
    double fs(double phone, double tvPx) => tv ? tvPx * u : phone;
    final pad = fs(20, 48);

    Widget chip(String t) => Container(
          padding:
              EdgeInsets.symmetric(horizontal: fs(8, 14), vertical: fs(3, 6)),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(fs(6, 10)),
          ),
          child: Text(t,
              style: TextStyle(color: AppTheme.textHigh, fontSize: fs(12, 22))),
        );

    return Stack(
      children: [
        ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * 1.5),
          children: [
            if (i.overline.isNotEmpty)
              Text(i.overline,
                  style: TextStyle(
                      color: AppTheme.textMid,
                      fontSize: fs(13, 24),
                      fontWeight: FontWeight.w600)),
            if (i.badge.isNotEmpty) ...[
              SizedBox(height: fs(4, 8)),
              Text(i.badge,
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: fs(13, 24),
                      fontWeight: FontWeight.w700)),
            ],
            SizedBox(height: fs(4, 8)),
            Text(i.title,
                style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: fs(22, 40),
                    fontWeight: FontWeight.w800,
                    height: 1.15)),
            if (i.facts.isNotEmpty) ...[
              SizedBox(height: fs(10, 18)),
              Wrap(
                spacing: fs(6, 10),
                runSpacing: fs(6, 10),
                children: [for (final f in i.facts) chip(f)],
              ),
            ],
            if (i.genres.isNotEmpty) ...[
              SizedBox(height: fs(10, 16)),
              Text(i.genres.join(' · '),
                  style:
                      TextStyle(color: AppTheme.textMid, fontSize: fs(13, 22))),
            ],
            if (i.plot.isNotEmpty) ...[
              SizedBox(height: fs(14, 24)),
              Text(i.plot,
                  style: TextStyle(
                      color: AppTheme.textHigh.withValues(alpha: 0.9),
                      fontSize: fs(14, 24),
                      height: 1.45)),
            ],
            if (i.rows.isNotEmpty) SizedBox(height: fs(14, 24)),
            for (final (label, value) in i.rows)
              Padding(
                padding: EdgeInsets.only(bottom: fs(8, 14)),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$label  ',
                        style: const TextStyle(color: AppTheme.textLow)),
                    TextSpan(
                        text: value,
                        style: const TextStyle(color: AppTheme.textHigh)),
                  ]),
                  style: TextStyle(fontSize: fs(13, 22), height: 1.35),
                ),
              ),
            if (loading)
              Padding(
                padding: EdgeInsets.only(top: fs(8, 12)),
                child: Text('Carico altri dettagli…',
                    style: TextStyle(
                        color: AppTheme.textLow, fontSize: fs(12, 20))),
              ),
            if (tv)
              Padding(
                padding: EdgeInsets.only(top: fs(12, 24)),
                child: Text('↑↓ scorri · OK o Indietro per chiudere',
                    style: TextStyle(
                        color: AppTheme.textLow, fontSize: fs(12, 20))),
              ),
          ],
        ),
        if (!tv)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Chiudi',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, color: AppTheme.textHigh),
            ),
          ),
      ],
    );
  }
}
