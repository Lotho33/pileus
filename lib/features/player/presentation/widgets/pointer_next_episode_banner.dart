import 'package:flutter/material.dart';

/// Mouse/touch equivalent of the TV player's `_NextEpisodeBanner`
/// (`presentation/playback_screen/next_episode_banner.dart`, private to that
/// `part of` file) — same countdown-toward-auto-advance banner, for desktop
/// and web where a click replaces D-pad focus navigation.
class PointerNextEpisodeBanner extends StatelessWidget {
  final int secsRemaining;
  final String? nextTitle;
  final VoidCallback onPlay;
  final VoidCallback onDismiss;

  const PointerNextEpisodeBanner({
    super.key,
    required this.secsRemaining,
    required this.onPlay,
    required this.onDismiss,
    this.nextTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Prossimo episodio in ${secsRemaining}s',
            style: const TextStyle(
                color: Colors.white54, fontSize: 13, letterSpacing: 0.3),
          ),
          if (nextTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              nextTitle!,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPlay,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.skip_next_rounded,
                            color: Colors.black, size: 18),
                        SizedBox(width: 6),
                        Text('Vai subito',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
