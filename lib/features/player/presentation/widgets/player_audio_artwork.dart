import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/image_sizing.dart';

class PlayerAudioArtwork extends StatelessWidget {
  final String? poster;
  final String? title;
  const PlayerAudioArtwork({super.key, this.poster, this.title});

  @override
  Widget build(BuildContext context) {
    final hasPoster = poster != null && poster!.isNotEmpty;
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 240,
              height: 240,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasPoster
                  ? CachedNetworkImage(
                      imageUrl: poster!,
                      fit: BoxFit.cover,
                      memCacheWidth: cacheWidthFor(context, 240),
                      errorWidget: (context, url, error) => const Icon(
                          Icons.music_note_outlined,
                          color: Colors.white38,
                          size: 80),
                    )
                  : const Icon(Icons.music_note_outlined,
                      color: Colors.white38, size: 80),
            ),
            if (title != null && title!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
