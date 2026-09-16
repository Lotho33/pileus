// Part of home_screen.dart — split out for readability (plan 2e). The library
// file holds the shared imports plus the _HomeFsm enum and the HomeScreen
// entry point; private identifiers are shared across all parts.
part of '../home_screen.dart';

// ── smart logo — applies white glow only when the logo is predominantly dark ──
// Renders a logo image with optional white glow for dark logos.
// isDark flag comes from the server-side encoded logo string (4th field).
class _LogoWidget extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final bool isDark;
  final Widget fallback;
  const _LogoWidget({
    required this.url,
    required this.width,
    required this.height,
    required this.isDark,
    required this.fallback,
  });

  // Wraps the raw logo image in the dark-logo white glow (a blurred,
  // white-filled copy behind a sharp copy) when [isDark].
  Widget _withGlow(Widget img) {
    if (!isDark) return img;
    // "Hardware modesto": no Gaussian blur (shader cost on a layer that
    // repaints during the hero crossfade). A dark/black-lettered logo would
    // vanish on the flat dark background though, so give it a cheap solid
    // light plate instead — flat fill, no shader.
    if (lowPowerUi) {
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: height * 0.14, vertical: height * 0.08),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(height * 0.16),
        ),
        child: img,
      );
    }
    // RepaintBoundary: the blur is a real per-frame gaussian while it's in a
    // repainting layer — and this logo lives inside the hero's
    // AnimatedSwitcher crossfade, which repaints both children every frame
    // for 300ms on each item change. Caching the blurred glow as its own
    // layer means it's rasterized once, not re-blurred ~18× per transition.
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ColorFiltered(
              colorFilter:
                  const ColorFilter.mode(AppTheme.textHigh, BlendMode.srcIn),
              child: Opacity(opacity: 0.55, child: img),
            ),
          ),
          img,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A large share of TMDB wordmark logos are SVG — CachedNetworkImage
    // can't decode those and fell through to the text fallback, which is
    // why "the logo often doesn't load". Route .svg URLs to flutter_svg.
    final lower = url.toLowerCase();
    final isSvg = lower.endsWith('.svg') || lower.contains('.svg?');
    if (isSvg) {
      return _withGlow(
        SvgPicture.network(
          url,
          width: width,
          height: height,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          placeholderBuilder: (_) => const SizedBox.shrink(),
        ),
      );
    }
    return CachedNetworkImage(
      // Web-only, no-op on every other platform — see image_sizing.dart's
      // "ImageRenderMethodForWeb.HttpGet" section for why every
      // CachedNetworkImage call site in the app sets this.
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
      imageUrl: posterSrc(url, cacheWidthFor(context, width)),
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      memCacheWidth: cacheWidthFor(context, width),
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      imageBuilder: (_, imageProvider) => _withGlow(Image(
        image: imageProvider,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      )),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

// ── meta zone — crossfade wrapper that never duplicates keys ──────────────────
// Keeps its own Key internally; updates the key only when itemId changes so
// AnimatedSwitcher always sees distinct keys during a transition.

class _MetaZone extends StatefulWidget {
  final String itemId;
  final double width;
  final double height;
  final Alignment alignment;
  final Widget child;

  const _MetaZone({
    required this.itemId,
    required this.width,
    required this.height,
    required this.alignment,
    required this.child,
  });

  @override
  State<_MetaZone> createState() => _MetaZoneState();
}

class _MetaZoneState extends State<_MetaZone> {
  late Key _childKey;

  @override
  void initState() {
    super.initState();
    _childKey = UniqueKey();
  }

  @override
  void didUpdateWidget(_MetaZone old) {
    super.didUpdateWidget(old);
    if (old.itemId != widget.itemId) _childKey = UniqueKey();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedSwitcher(
        switchInCurve: AppScale.fadeCurve,
        switchOutCurve: AppScale.fadeCurve,
        duration:
            lowPowerUi ? Duration.zero : const Duration(milliseconds: 140),
        // Always widget.alignment, never AnimatedSwitcher.defaultLayoutBuilder
        // (Alignment.center) — every call site here uses the default
        // clipBehavior (Clip.hardEdge), so all of them used to take the
        // center-aligned branch: the incoming child (e.g. a shorter title
        // or fewer genre pills) would render centered against the taller
        // outgoing one during the ~260ms crossfade, then visibly snap to
        // widget.alignment once the old child left the tree. Same class of
        // bug as the plot zone's AnimatedSwitcher above.
        layoutBuilder: (cur, prev) => Stack(
          alignment: widget.alignment,
          children: [...prev, if (cur != null) cur],
        ),
        child: Align(
          key: _childKey,
          alignment: widget.alignment,
          child: widget.child,
        ),
      ),
    );
  }
}

// ── meta widgets ───────────────────────────────────────────────────────────────

// ── live event status line (home hero) ────────────────────────────────────
// Sits just under the (vertically-centred) live title: an "IN DIRETTA" pill
// when the event is on air, plus its start time whenever the plugin provides
// one (see _liveStartTime for the extra keys it looks for).

// Genre/tag values that just restate "this is live" — redundant with the
// red pill, so they're filtered out of a live item's genre chips.
const _redundantLiveGenres = <String>{
  'in diretta',
  'diretta',
  'live',
  'in onda',
  'on air',
  'en vivo',
  'en directo',
  'streaming',
};

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String? _liveStartTime(CatalogItem item) {
  const keys = [
    // The SDK's LiveDetails message calls it stream_start (that message is
    // GetDetails-only — the catalog CatalogItem has no typed time field, so
    // mycelium flattens it into `extra` under some key; stream_start is the
    // one to expect, the rest are defensive fallbacks for other plugins).
    'stream_start',
    'streamStart',
    'start_time',
    'start',
    'start_at',
    'starts_at',
    'start_unix',
    'event_time',
    'kickoff',
    'time',
    'begin',
    'scheduled'
  ];
  for (final k in keys) {
    final raw = item.extra[k];
    if (raw == null || raw.trim().isEmpty) continue;
    final v = raw.trim();
    // Unix epoch (seconds or milliseconds).
    final n = int.tryParse(v);
    if (n != null && n > 1000000000) {
      final ms = n > 100000000000 ? n : n * 1000;
      return _hhmm(
          DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal());
    }
    // Already a HH:MM (possibly inside a longer string).
    final m = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(v);
    if (m != null) return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
    // ISO-8601 / RFC-3339.
    final dt = DateTime.tryParse(v);
    if (dt != null) return _hhmm(dt.toLocal());
  }
  return null;
}

class _LiveStatusLine extends StatelessWidget {
  final CatalogItem item;
  const _LiveStatusLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final fs = (sh * 0.020).clamp(13.0, 34.0);
    final isLive = item.extra['is_live'] == '1';
    final start = _liveStartTime(item);
    final sportCat = (item.extra['sport_cat'] ?? '').trim();

    final parts = <Widget>[];
    if (isLive) parts.add(_LivePill(fontSize: fs));
    // The sport belongs right here next to the live state, not buried in
    // the generic genre chips below (where it also used to show a redundant
    // "In diretta" tag the plugin adds — filtered out now, see
    // _buildMetaLayers).
    if (sportCat.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(SizedBox(width: fs * 0.7));
      parts.add(_SportChip(cat: sportCat, fontSize: fs));
    }
    // The line under the title carries the start time — not a second copy
    // of "IN DIRETTA".
    if (start != null) {
      if (parts.isNotEmpty) parts.add(SizedBox(width: fs * 0.7));
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: fs * 1.05, color: AppTheme.textMid),
          SizedBox(width: fs * 0.32),
          Text('Inizio $start',
              style: TextStyle(
                  color: AppTheme.textMid,
                  fontSize: fs,
                  fontWeight: FontWeight.w600)),
        ],
      ));
    } else if (!isLive && sportCat.isEmpty) {
      parts.add(Text('Non in diretta',
          style: TextStyle(color: AppTheme.textLow, fontSize: fs)));
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    // FittedBox (not Wrap): _MetaZone gives this a fixed height sized for one
    // line — scale the row down to fit the width instead of letting it wrap
    // and get clipped.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: parts,
      ),
    );
  }
}

// Sport-category badge (emoji + name) shown in the live hero status line and
// nowhere else — same visual language as live_event_popup.dart's chip.
class _SportChip extends StatelessWidget {
  final String cat;
  final double fontSize;
  const _SportChip({required this.cat, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final accent = sportAccentColor(cat);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.55, vertical: fontSize * 0.26),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(fontSize * 0.5),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sportIcon(cat), size: fontSize * 0.95, color: Colors.white),
          SizedBox(width: fontSize * 0.32),
          Text(cat.toUpperCase().replaceAll('-', ' '),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize * 0.82,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final double fontSize;
  const _LivePill({required this.fontSize});

  static const _red = Color(0xFFFF3B3B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.62, vertical: fontSize * 0.30),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(fontSize * 1.4),
        border: Border.all(color: _red.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: fontSize * 0.42,
            height: fontSize * 0.42,
            decoration:
                const BoxDecoration(color: _red, shape: BoxShape.circle),
          ),
          SizedBox(width: fontSize * 0.42),
          Text('IN DIRETTA',
              style: TextStyle(
                  color: const Color(0xFFFF6B6B),
                  fontSize: fontSize * 0.82,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? iconColor;
  const _MetaChip({required this.text, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final fs = (MediaQuery.sizeOf(context).height * 0.022).clamp(11.0, 48.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fs * 0.9, color: iconColor ?? AppTheme.textMid),
          SizedBox(width: fs * 0.17),
        ],
        Text(text,
            style: TextStyle(
                color: AppTheme.textMid,
                fontSize: fs,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final dotSz = (sh * (3.0 / 1080.0)).clamp(2.0, 8.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sh * (10.0 / 1080.0)),
      child: Container(
        width: dotSz,
        height: dotSz,
        decoration: BoxDecoration(
          color: AppTheme.textLow,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
