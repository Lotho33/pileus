import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A titled horizontal carousel for the desktop home. Hover reveals paging
/// chevrons on either edge; the mouse wheel / trackpad scrolls it.
class MediaRow extends StatefulWidget {
  final String title;
  final double rowHeight;
  final double pageStep; // ~one card width, for chevron paging math
  final int itemCount;
  final double gutter;
  final double titleSize;
  final IndexedWidgetBuilder itemBuilder;

  const MediaRow({
    super.key,
    required this.title,
    required this.rowHeight,
    required this.pageStep,
    required this.itemCount,
    required this.gutter,
    required this.itemBuilder,
    this.titleSize = 18,
  });

  @override
  State<MediaRow> createState() => _MediaRowState();
}

class _MediaRowState extends State<MediaRow> {
  final _c = ScrollController();
  // (canLeft, canRight) — updated on scroll WITHOUT setState so a wheel
  // scroll doesn't rebuild the whole row 60x/s; only the two chevrons
  // listen.
  final _edges = ValueNotifier<(bool, bool)>((false, false));
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onScroll);
    // Seed the edge flags once the list is laid out so the right chevron is
    // available on hover before the first scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onScroll);
    _c.dispose();
    _edges.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_c.hasClients || !_c.position.hasContentDimensions) return;
    _edges.value = (
      _c.offset > 4,
      _c.offset < _c.position.maxScrollExtent - 4,
    );
  }

  void _page(int dir) {
    if (!_c.hasClients || !_c.position.hasContentDimensions) return;
    final vp = _c.position.viewportDimension;
    final step = ((vp * 0.9) / widget.pageStep).floor() * widget.pageStep;
    final delta = (step <= 0 ? vp : step).toDouble();
    final target =
        (_c.offset + dir * delta).clamp(0.0, _c.position.maxScrollExtent);
    _c.animateTo(target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(widget.gutter, 0, widget.gutter, 10),
            child: Text(
              widget.title,
              style: TextStyle(
                color: AppTheme.textHigh,
                fontSize: widget.titleSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: widget.rowHeight,
            child: Stack(
              // Clip.none: the cards scale up ~5% on hover; a hard clip cuts
              // the top of the scaled card (and its drop shadow) off.
              clipBehavior: Clip.none,
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: ListView.separated(
                    controller: _c,
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding:
                        EdgeInsets.symmetric(horizontal: widget.gutter),
                    itemCount: widget.itemCount,
                    physics: const ClampingScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    // Centre each card in the row so the hover scale has
                    // slack above and below instead of overflowing the top.
                    itemBuilder: (ctx, i) =>
                        Center(child: widget.itemBuilder(ctx, i)),
                  ),
                ),
                ValueListenableBuilder<(bool, bool)>(
                  valueListenable: _edges,
                  builder: (_, e, __) => Stack(
                    children: [
                      _Chevron(
                          left: true,
                          visible: _hover && e.$1,
                          onTap: () => _page(-1)),
                      _Chevron(
                          left: false,
                          visible: _hover && e.$2,
                          onTap: () => _page(1)),
                    ],
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

class _Chevron extends StatelessWidget {
  final bool left;
  final bool visible;
  final VoidCallback onTap;
  const _Chevron(
      {required this.left, required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: IgnorePointer(
          ignoring: !visible,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: left ? Alignment.centerLeft : Alignment.centerRight,
                    end: left ? Alignment.centerRight : Alignment.centerLeft,
                    colors: [
                      AppTheme.bg.withValues(alpha: 0.88),
                      AppTheme.bg.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Icon(
                  left
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: AppTheme.textHigh,
                  size: 34,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
