import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../grpc/host_resolver.dart';

// Decode-size helpers for network images.
//
// Without an explicit memCacheWidth every image is decoded at its native
// resolution (posters/fanart are often ≥1920 px) no matter how small it is
// drawn. On low-RAM TV boxes (Fire Stick & co.) that wastes memory and CPU;
// capping the decode at the physical on-screen size is lossless visually.
//
// The decode cap is NOT reduced below the physical on-screen size — an
// earlier "×0.7 in low-power" pass made backdrops visibly soft for one
// image's worth of RAM. The bandwidth/CPU win comes from the source: a
// metadata provider's own size ladder, or — for plugin-supplied images on
// the home carousels — mycelium's `/img` proxy, which now just transcodes to WebP at
// the source resolution (no server-side resize) and caches one entry per
// image, shared across every device on that server. Display-size
// downscaling stays a client concern (memCacheWidth / cacheWidthFor).

/// Decode width in physical pixels for an image drawn [logicalWidth] wide.
int cacheWidthFor(BuildContext context, double logicalWidth) =>
    (logicalWidth * MediaQuery.devicePixelRatioOf(context))
        .clamp(64.0, 1920.0)
        .round();

/// Decode width for a full-screen backdrop. Capped at 1920 px: backdrops sit
/// under dark gradients, so a 4K decode is indistinguishable but costs 4×.
int backdropCacheWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
        .clamp(64.0, 1920.0)
        .round();

// ── source-size selection ────────────────────────────────────────────────────

final _tmdbRe =
    RegExp(r'^(https?://image\.tmdb\.org/t/p/)(w\d+|original)(/.+)$');
// TMDB's own pre-generated JPEG sizes — perfectly encoded, no re-compression.
const _tmdbPosterLadder = [154, 185, 342, 500, 780];
const _tmdbBackdropLadder = [300, 780, 1280];

String _rewriteTmdb(String url, List<int> ladder, int targetPx,
    {bool allowOriginal = false}) {
  final m = _tmdbRe.firstMatch(url);
  if (m == null) return url;
  for (final s in ladder) {
    if (s >= targetPx) return '${m.group(1)}w$s${m.group(3)}';
  }
  final seg = allowOriginal ? 'original' : 'w${ladder.last}';
  return '${m.group(1)}$seg${m.group(3)}';
}

// mycelium's `/img` proxy: fetch upstream once, transcode to WebP at the
// source resolution, cache it keyed by the URL alone (no width) so every
// device/profile that asks for the same image reuses one server-side entry.
// Fails open (302 to the original) on any problem. No `w` param: the server
// no longer resizes and ignores it — leaving it off keeps the client's own
// CachedNetworkImage cache from fragmenting by device pixel width too.
String? _imgProxy(String upstream) {
  final base = myceliumHttpBase();
  if (base == null || base.isEmpty || upstream.startsWith(base)) return null;
  final u = base64Url.encode(utf8.encode(upstream)).replaceAll('=', '');
  return '$base/img?u=$u';
}

/// Poster/thumbnail source URL for a poster drawn [targetPx] physical pixels
/// wide. TMDB images just pick the smallest pre-generated size that still
/// covers the display — sharp, zero re-encode. For arbitrary plugin images,
/// [proxy] routes them through mycelium's `/img` WebP proxy (home carousels
/// pass `true`; detail pages leave it `false` and load the upstream URL
/// directly). The proxy fails open, so `true` is always safe.
String posterSrc(String upstream, int targetPx, {bool proxy = false}) {
  if (upstream.isEmpty) return upstream;
  final lower = upstream.toLowerCase();
  if (lower.startsWith('data:') || lower.contains('.svg')) return upstream;
  if (lower.contains('image.tmdb.org/t/p/')) {
    return _rewriteTmdb(upstream, _tmdbPosterLadder, targetPx);
  }
  if (!proxy) return upstream;
  return _imgProxy(upstream) ?? upstream;
}

/// Backdrop source URL. For TMDB it picks an appropriate pre-generated size.
/// For arbitrary plugin images, [proxy] routes them through mycelium's `/img`
/// WebP proxy — the home hero passes `true`; detail-page backdrops leave it
/// `false` (the old "box filter + re-JPEG looked bad on a full-screen image"
/// reason is gone now that the proxy is a Catmull-Rom-quality WebP transcode
/// with no downscale, but detail pages stay direct by the same
/// home-carousels-only rule as posterSrc).
String backdropSrc(String upstream, int targetPx, {bool proxy = false}) {
  if (upstream.isEmpty) return upstream;
  final lower = upstream.toLowerCase();
  if (lower.startsWith('data:') || lower.contains('.svg')) return upstream;
  if (lower.contains('image.tmdb.org/t/p/')) {
    return _rewriteTmdb(upstream, _tmdbBackdropLadder, targetPx,
        allowOriginal: true);
  }
  if (!proxy) return upstream;
  return _imgProxy(upstream) ?? upstream;
}
