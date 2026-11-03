import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../grpc/host_resolver.dart';
import '../perf_profile.dart';

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
//
// ── web: ImageRenderMethodForWeb.HttpGet on every CachedNetworkImage ────────
//
// Every `CachedNetworkImage(` call site in this app passes
// `imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet`
// — a mechanical, repeated one-line override, referenced from each site back
// to this comment rather than re-explained inline every time.
//
// `cached_network_image`'s own default on web is `HtmlImage`: it decodes
// through a plain `<img>` element / `createImageCodecFromUrl`, handing
// CanvasKit a browser-owned `<img>`/`ImageBitmap` to upload as a GPU texture.
// `HttpGet` instead fetches the raw bytes itself and decodes via
// `ui.ImmutableBuffer` — no `<img>` element, no browser-owned bitmap handle,
// ever involved.
//
// This is the leading suspect for a recurring web-only bug: posters/hero
// backdrops rendering solid black after ANY teardown-and-recreate of the
// widget showing them —
// scrolling far enough to leave `ListView`'s cache extent and back, switching
// plugin (a full subtree replacement, not just a scroll), or opening a
// details page and returning to home. The browser console showed CanvasKit's
// `makeTexture` failing with `WebGL: INVALID_VALUE: texImage2D: no image`
// inside `Canvas._drawPicture` — exactly the signature of a texture upload
// fed a source that's already gone, which is what happens when the old
// widget's `<img>` element is torn down right as a freshly-recreated
// `CachedNetworkImage` tries to build a new codec from one. `HttpGet` doesn't
// touch an `<img>` element at any point, so that specific race can't happen.
//
// Two earlier, narrower fixes for pieces of this same symptom are still
// correct and still in place — this one is broader, not a replacement:
//   * `AutomaticKeepAliveClientMixin` on DesktopHero/MobileHero
//     — stops the hero specifically from being torn down by ListView's
//     cache-extent eviction on scroll (doesn't help a plugin switch, which
//     replaces the whole subtree regardless of keep-alive).
//   * MediaRepository.getDetails' 5-minute in-memory cache —
//     stops a re-created hero from re-issuing the network call, but the
//     CachedNetworkImage decode still happens fresh either way; doesn't
//     touch the texture-upload race itself.
// Not the whole story (found 03/11 with remote DevTools on a phone): wherever
// WebCodecs' ImageDecoder is missing (plain http from a LAN address,
// non-Chromium browsers) the engine decodes HttpGet bytes through an `<img>`
// too, and re-decoding a frame from it after its first use gave the same
// "no image" blank. See lib/web/web_image_binding.dart.
// No effect on non-web platforms: every native ImageLoader ignores this
// field entirely (see cached_network_image_platform_interface's ImageLoader
// contract), so passing it everywhere unconditionally is a no-op on
// Android/iOS/desktop/TV.

/// Decode width in physical pixels for an image drawn [logicalWidth] wide.
int cacheWidthFor(BuildContext context, double logicalWidth) =>
    (logicalWidth * MediaQuery.devicePixelRatioOf(context))
        .clamp(64.0, 1920.0)
        .round();

/// Decode width for a full-screen backdrop. Capped at 1920 px: backdrops sit
/// under dark gradients, so a 4K decode is indistinguishable but costs 4×.
/// The TV interface caps at 1280: on a 1080p panel, behind those gradients
/// and seen from a sofa, the difference doesn't show — while the decode is
/// 2.25× smaller in memory, and TMDB serves its own w1280 file (a smaller
/// download too, see backdropSrc). Every TV gets this, not just "hardware
/// modesto". TMDB backdrops are w1280 on every interface: the next size up
/// is "original", often 3840 px and over 1 MB (a 64 ms texture upload per
/// image in the web profile), for no visible gain under the gradients.
int backdropCacheWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
        .clamp(64.0, tvUi ? 1280.0 : 1920.0)
        .round();

// ── source-size selection ────────────────────────────────────────────────────

final _tmdbRe =
    RegExp(r'^(https?://image\.tmdb\.org/t/p/)(w\d+|original)(/.+)$');
// TMDB's own pre-generated JPEG sizes — perfectly encoded, no re-compression.
const _tmdbPosterLadder = [154, 185, 342, 500, 780];
const _tmdbBackdropLadder = [300, 780, 1280];

String _rewriteTmdb(String url, List<int> ladder, int targetPx) {
  final m = _tmdbRe.firstMatch(url);
  if (m == null) return url;
  for (final s in ladder) {
    if (s >= targetPx) return '${m.group(1)}w$s${m.group(3)}';
  }
  return '${m.group(1)}w${ladder.last}${m.group(3)}';
}

// Jellyfin/Emby image endpoints (/Items/<id>/Images/<type>) resize on the
// server when asked: without maxWidth they return the stored original, a
// 300-700 KB poster decoded at 1000+ px for a card drawn ~250 px wide. The
// width is rounded up to a short ladder so the `/img` cache (keyed by the
// upstream URL) holds a few entries per image, not one per device width.
final _jellyfinImageRe = RegExp(
    r'/Items/[0-9a-fA-F-]{32,36}/Images/(Primary|Backdrop|Thumb|Banner|Art)\b',
    caseSensitive: false);
const _jellyfinPosterLadder = [240, 360, 480, 720, 960];
const _jellyfinBackdropLadder = [780, 1280, 1920];

String _rewriteJellyfin(String url, List<int> ladder, int targetPx) {
  if (!_jellyfinImageRe.hasMatch(url)) return url;
  final lower = url.toLowerCase();
  if (lower.contains('maxwidth=') || lower.contains('fillwidth=')) return url;
  final w = ladder.firstWhere((s) => s >= targetPx, orElse: () => ladder.last);
  return '$url${url.contains('?') ? '&' : '?'}maxWidth=$w';
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
///
/// On web, [proxy] is forced on regardless of what the caller passed — see
/// [_forceProxyOnWeb].
String posterSrc(String upstream, int targetPx, {bool proxy = false}) {
  if (upstream.isEmpty) return upstream;
  final lower = upstream.toLowerCase();
  if (lower.startsWith('data:') || lower.contains('.svg')) return upstream;
  if (lower.contains('image.tmdb.org/t/p/')) {
    return _rewriteTmdb(upstream, _tmdbPosterLadder, targetPx);
  }
  upstream = _rewriteJellyfin(upstream, _jellyfinPosterLadder, targetPx);
  if (!proxy && !_forceProxyOnWeb) return upstream;
  return _imgProxy(upstream) ?? upstream;
}

/// Backdrop source URL. For TMDB it picks an appropriate pre-generated size.
/// For arbitrary plugin images, [proxy] routes them through mycelium's `/img`
/// WebP proxy — the home hero passes `true`; detail-page backdrops leave it
/// `false` (the old "box filter + re-JPEG looked bad on a full-screen image"
/// reason is gone now that the proxy is a Catmull-Rom-quality WebP transcode
/// with no downscale, but detail pages stay direct by the same
/// home-carousels-only rule as posterSrc).
///
/// On web, [proxy] is forced on regardless of what the caller passed — see
/// [_forceProxyOnWeb].
String backdropSrc(String upstream, int targetPx, {bool proxy = false}) {
  if (upstream.isEmpty) return upstream;
  final lower = upstream.toLowerCase();
  if (lower.startsWith('data:') || lower.contains('.svg')) return upstream;
  if (lower.contains('image.tmdb.org/t/p/')) {
    return _rewriteTmdb(upstream, _tmdbBackdropLadder, targetPx);
  }
  upstream = _rewriteJellyfin(upstream, _jellyfinBackdropLadder, targetPx);
  if (!proxy && !_forceProxyOnWeb) return upstream;
  return _imgProxy(upstream) ?? upstream;
}

// A `proxy: false` call site (every detail page) means "load the upstream
// URL directly" — a deliberate choice on native, where an HTTP client has no
// concept of CORS. On web this app always renders CachedNetworkImage with
// ImageRenderMethodForWeb.HttpGet (see the big comment up top): it fetches
// the bytes itself via the browser's fetch(), which — unlike a plain `<img
// src>` — genuinely enforces CORS on the response. A plugin's own image
// host essentially never sends Access-Control-Allow-Origin, so every direct
// (non-proxied) image on a detail page silently failed to load on web,
// falling back to the surface2 placeholder — a dark navy tile that reads as
// a blank/broken image. mycelium's `/img` proxy already sets
// Access-Control-Allow-Origin: * and serves a decode failure same-origin
// instead of redirecting out to a foreign non-CORS host — routing every
// non-TMDB web image through it, unconditionally, is what actually makes
// HttpGet's own fix hold on detail pages too, not just the home carousels
// that already passed `proxy: true`.
const bool _forceProxyOnWeb = kIsWeb;
