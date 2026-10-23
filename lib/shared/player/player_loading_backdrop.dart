import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/perf_profile.dart';
import '../../core/utils/image_sizing.dart';

/// What the player shows while a stream is being prepared, instead of a
/// bare black screen: the title's own picture, darkened, with its name and
/// where it will start ("Riprende da 12:34"). Each screen keeps drawing its
/// own spinner and progress text on top — this is only the backdrop, the
/// layer that used to be a plain black cover.
///
/// Must stay fully opaque: it is also what hides the video view until the
/// first frame (the screens fade it out once the video has started).
class PlayerLoadingBackdrop extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  // Where playback will start, in seconds — 0 (from the start) or a live
  // stream shows nothing.
  final int resumeAtSeconds;
  // "Disponibile solo in inglese" — a language version other than the
  // profile's preferred one (PlaybackArgs.languageNotice).
  final String notice;

  const PlayerLoadingBackdrop({
    super.key,
    this.imageUrl = '',
    this.title = '',
    this.subtitle = '',
    this.resumeAtSeconds = 0,
    this.notice = '',
  });

  /// "12:34", or "1:02:03" past the hour.
  static String formatPosition(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = (size.shortestSide / 720).clamp(0.6, 2.0);
    final lines = [
      if (subtitle.isNotEmpty) subtitle,
      if (resumeAtSeconds > 0) 'Riprende da ${formatPosition(resumeAtSeconds)}',
      if (notice.isNotEmpty) notice,
    ];
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: backdropSrc(imageUrl, backdropCacheWidth(context)),
              memCacheWidth: backdropCacheWidth(context),
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 250),
              // Weak boxes: same picture, no extra compositing work beyond
              // the dimming below.
              color: Colors.black.withValues(alpha: lowPowerUi ? 0.62 : 0.55),
              colorBlendMode: BlendMode.darken,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          // Bottom-left legibility for the title, whatever the picture.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [Color(0xE6000000), Color(0x00000000)],
                stops: [0.0, 0.7],
              ),
            ),
          ),
          if (title.isNotEmpty || lines.isNotEmpty)
            Positioned(
              left: 40 * scale,
              right: 40 * scale,
              bottom: 36 * scale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26 * scale,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  for (final l in lines)
                    Padding(
                      padding: EdgeInsets.only(top: 6 * scale),
                      child: Text(
                        l,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.w600,
                        ),
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
