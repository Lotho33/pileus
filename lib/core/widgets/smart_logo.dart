import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../grpc/clients/media_client.dart' show LogoMeta;
import '../perf_profile.dart';
import '../theme/app_theme.dart';
import '../utils/image_sizing.dart';

// ── Legacy `logo_url` encoding ───────────────────────────────────────────────

// Parses "url|norm_w|norm_h|dark" encoded logo string. Returns the URL part.
// Also handles legacy "url|w|h" (3-part) format.
String logoUrlOnly(String encoded) {
  final parts = encoded.split('|');
  // 4-part: url|norm_w|norm_h|dark  — url is everything before the last 3 pipes
  if (parts.length >= 4) {
    return parts.sublist(0, parts.length - 3).join('|');
  }
  // 3-part legacy: url|w|h
  if (parts.length == 3) {
    return parts.sublist(0, parts.length - 2).join('|');
  }
  return encoded;
}

// Returns true if the logo was flagged dark (field 4 == "1").
bool logoDark(String encoded) {
  final parts = encoded.split('|');
  if (parts.length >= 4) return parts.last == '1';
  return false;
}

// Computes render size for a logo using server-side normalized dimensions.
// norm_w/norm_h come from mycelium.image.analyze_logo (800px wide, cap 200h).
// maxH/maxW are Flutter-side caps (screen-relative). Falls back to 3:1 if dims unknown.
({double w, double h}) logoRenderSize(
  String encoded, {
  required double targetW,
  required double maxH,
  required double maxW,
}) {
  double srcW = 0, srcH = 0;
  final parts = encoded.split('|');
  // 4-part: url|norm_w|norm_h|dark
  if (parts.length >= 4) {
    srcW = double.tryParse(parts[parts.length - 3]) ?? 0;
    srcH = double.tryParse(parts[parts.length - 2]) ?? 0;
  } else if (parts.length == 3) {
    // legacy 3-part: url|w|h
    srcW = double.tryParse(parts[parts.length - 2]) ?? 0;
    srcH = double.tryParse(parts[parts.length - 1]) ?? 0;
  }
  return _fitLogo(srcW, srcH, targetW: targetW, maxH: maxH, maxW: maxW);
}

({double w, double h}) _fitLogo(
  double srcW,
  double srcH, {
  required double targetW,
  required double maxH,
  required double maxW,
}) {
  double rw, rh;
  if (srcW > 0 && srcH > 0) {
    rw = targetW;
    rh = targetW * srcH / srcW;
  } else {
    rw = targetW;
    rh = targetW / 3.0;
  }

  // Cap: se troppo alto (logo quasi quadrato) scala giù da maxH.
  if (rh > maxH) {
    rw = rw * maxH / rh;
    rh = maxH;
  }
  // Cap larghezza (non dovrebbe servire ma per sicurezza).
  if (rw > maxW) {
    rh = rh * maxW / rw;
    rw = maxW;
  }
  // Floor: loghi ultra-wide non diventano filini.
  final minH = maxH * 0.30;
  if (rh < minH) {
    rh = minH;
  }

  return (w: rw, h: rh);
}

// ── Readability rule ─────────────────────────────────────────────────────────

/// Luminance of the app's dark theme, what nearly every logo is drawn on.
const double kDarkBackgroundLuminance = 0.02;

enum LogoHaloKind { none, light, dark }

/// [strong]: thin strokes (low coverage) need more of it to read.
typedef LogoHalo = ({LogoHaloKind kind, bool strong});

// An unset proto field reads as a default instance, not null: a measured
// logo always has a size or a coverage.
bool _measured(LogoMeta? m) =>
    m != null && ((m.width > 0 && m.height > 0) || m.coverage > 0);

/// Which halo the logo at [encodedUrl] needs on a background of
/// [backgroundLuminance] — see mycelium's pileus-contract.md, "Logo
/// readability". With no [meta] (the server measures a new logo in the
/// background) the legacy `dark` flag of the URL decides; it says the logo
/// is dark, so it only matters on a dark background.
LogoHalo logoHaloFor(
  String encodedUrl,
  LogoMeta? meta, {
  double backgroundLuminance = kDarkBackgroundLuminance,
}) {
  final onLight = backgroundLuminance > 0.5;
  if (!_measured(meta)) {
    return (
      kind: !onLight && logoDark(encodedUrl)
          ? LogoHaloKind.light
          : LogoHaloKind.none,
      strong: false,
    );
  }
  final m = meta!;
  final kind = onLight
      ? (m.lumMid > 0.6 || m.lightShare >= 0.35
          ? LogoHaloKind.dark
          : LogoHaloKind.none)
      : (m.halo == 'light' ? LogoHaloKind.light : LogoHaloKind.none);
  return (kind: kind, strong: m.coverage < 0.2);
}

/// Draw size of a logo: the measured proportions, else the legacy ones of
/// the URL, else 3:1.
({double w, double h}) logoDisplaySize(
  String encodedUrl,
  LogoMeta? meta, {
  required double maxWidth,
  required double maxHeight,
}) {
  if (_measured(meta) && meta!.width > 0 && meta.height > 0) {
    return _fitLogo(meta.width.toDouble(), meta.height.toDouble(),
        targetW: maxWidth, maxH: maxHeight, maxW: maxWidth);
  }
  return logoRenderSize(encodedUrl,
      targetW: maxWidth, maxH: maxHeight, maxW: maxWidth);
}

// ── Widget ───────────────────────────────────────────────────────────────────

/// A title's logo, with the halo that keeps it readable on what's behind
/// it. The one logo widget of the app: home heroes, details, La mia lista.
///
/// [url] is the raw `logo_url` (the legacy `|w|h|dark` suffix is handled
/// here). [fallback] shows if the image can't load.
class SmartLogo extends StatelessWidget {
  final String url;
  final LogoMeta? meta;
  final double maxWidth;
  final double maxHeight;
  final double backgroundLuminance;
  final Alignment alignment;
  final Widget fallback;

  /// Replaces the network image in tests; receives the tint of each copy
  /// (null = the sharp logo itself).
  @visibleForTesting
  final Widget Function(Color? tint)? debugImage;

  const SmartLogo({
    super.key,
    required this.url,
    required this.meta,
    required this.maxWidth,
    required this.maxHeight,
    required this.fallback,
    this.backgroundLuminance = kDarkBackgroundLuminance,
    this.alignment = Alignment.centerLeft,
    this.debugImage,
  });

  Widget _withHalo(LogoHalo halo, Widget Function(Color? tint) image) {
    if (halo.kind == LogoHaloKind.none) return image(null);
    final color =
        halo.kind == LogoHaloKind.light ? AppTheme.textHigh : Colors.black;
    // "Hardware modesto": no Gaussian blur (shader cost on a layer that
    // repaints during the hero crossfade) — an outline of shifted copies.
    if (lowPowerUi) {
      final d = halo.strong ? 2.0 : 1.0;
      final offsets = [
        Offset(-d, -d),
        Offset(d, -d),
        Offset(-d, d),
        Offset(d, d),
        if (halo.strong) ...[
          Offset(-d, 0),
          Offset(d, 0),
          Offset(0, -d),
          Offset(0, d),
        ],
      ];
      // RepaintBoundary for the same reason as below: up to 9 copies (each
      // a full vector redraw for an SVG logo) every frame of the hero
      // crossfade, on exactly the hardware least able to afford it.
      return RepaintBoundary(
        child: Stack(
          alignment: alignment,
          children: [
            for (final o in offsets)
              Transform.translate(offset: o, child: image(color)),
            image(null),
          ],
        ),
      );
    }
    final sigma = halo.strong ? 7.0 : 10.0;
    // RepaintBoundary: the blur is a real per-frame gaussian while it's in a
    // repainting layer — and a hero logo lives inside an AnimatedSwitcher
    // crossfade, which repaints both children every frame for 300ms on each
    // item change. Cached as its own layer it's rasterized once.
    return RepaintBoundary(
      child: Stack(
        alignment: alignment,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: image(color.withValues(alpha: halo.strong ? 0.9 : 0.55)),
          ),
          image(null),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final halo = logoHaloFor(url, meta,
        backgroundLuminance: backgroundLuminance);
    final size = logoDisplaySize(url, meta,
        maxWidth: maxWidth, maxHeight: maxHeight);
    return Align(
      alignment: alignment,
      widthFactor: 1,
      heightFactor: 1,
      child: _logo(context, halo, size),
    );
  }

  Widget _logo(
      BuildContext context, LogoHalo halo, ({double w, double h}) size) {
    if (debugImage != null) return _withHalo(halo, debugImage!);
    final src = logoUrlOnly(url);
    // A large share of TMDB wordmark logos are SVG — CachedNetworkImage
    // can't decode those and fell through to the text fallback, which is
    // why "the logo often doesn't load". Route .svg URLs to flutter_svg.
    final lower = src.toLowerCase();
    if (lower.endsWith('.svg') || lower.contains('.svg?')) {
      return _withHalo(
        halo,
        (tint) => SvgPicture.network(
          src,
          width: size.w,
          height: size.h,
          fit: BoxFit.contain,
          alignment: alignment,
          colorFilter:
              tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn),
          placeholderBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    final cacheW = cacheWidthFor(context, size.w);
    return CachedNetworkImage(
      // Web-only, no-op on every other platform — see image_sizing.dart's
      // "ImageRenderMethodForWeb.HttpGet" section for why every
      // CachedNetworkImage call site in the app sets this.
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
      imageUrl: posterSrc(src, cacheW),
      width: size.w,
      height: size.h,
      fit: BoxFit.contain,
      alignment: alignment,
      memCacheWidth: cacheW,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      imageBuilder: (_, imageProvider) => _withHalo(
        halo,
        (tint) => Image(
          image: imageProvider,
          width: size.w,
          height: size.h,
          fit: BoxFit.contain,
          alignment: alignment,
          color: tint,
          colorBlendMode: tint == null ? null : BlendMode.srcIn,
        ),
      ),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
