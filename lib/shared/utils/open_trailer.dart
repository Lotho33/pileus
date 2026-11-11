import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The YouTube video id of a trailer link — `watch?v=`, `youtu.be/`,
/// `/embed/`, `/shorts/`, or a bare 11-character id (what TMDB's videos
/// API gives as `key`). Null for anything else.
String? youtubeIdOf(String url) {
  final s = url.trim();
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(s)) return s;
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.host.contains('youtu')) return null;
  final v = uri.queryParameters['v'];
  if (v != null && v.isNotEmpty) return v;
  final seg = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  if (uri.host.contains('youtu.be') && seg.isNotEmpty) return seg.first;
  for (final k in const ['embed', 'shorts', 'v']) {
    final i = seg.indexOf(k);
    if (i >= 0 && i + 1 < seg.length) return seg[i + 1];
  }
  return null;
}

/// Opens a title's trailer outside Pileus — trailers are YouTube videos
/// (TMDB only lists those), which our player can't play: YouTube streams
/// can't be extracted within its terms, and break whenever they change.
/// Android (TV included): the YouTube app through its own `vnd.youtube:`
/// scheme, else the https link (YouTube app or a browser, whichever
/// handles it). Desktop/web: the browser. False when nothing could open it
/// (an Android TV box with no YouTube app and no browser).
Future<bool> openTrailer(String url) async {
  final id = youtubeIdOf(url);
  final web = id != null
      ? Uri.parse('https://www.youtube.com/watch?v=$id')
      : Uri.tryParse(url.trim());
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && id != null) {
    try {
      if (await launchUrl(Uri.parse('vnd.youtube:$id'),
          mode: LaunchMode.externalNonBrowserApplication)) {
        return true;
      }
    } catch (_) {}
  }
  if (web == null || !web.hasScheme) return false;
  try {
    return await launchUrl(web, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// [openTrailer], telling the user when nothing on the device can play it.
Future<void> openTrailerWithFeedback(
    ScaffoldMessengerState messenger, String url) async {
  if (await openTrailer(url)) return;
  messenger.showSnackBar(const SnackBar(
    content: Text('Per vedere il trailer serve l\'app YouTube o un browser.'),
  ));
}
