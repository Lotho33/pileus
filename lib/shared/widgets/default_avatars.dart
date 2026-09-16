import 'package:flutter/material.dart';

// Standard, bundled-in-the-app avatar set — replaces what used to be a
// "paste an image URL" prompt for the avatar row (profile_settings_screen.dart),
// which meant setting an avatar required hosting an image somewhere and
// wasn't reachable at all by a user with no way to type a URL comfortably
// on a remote. These are drawn entirely in code (icon + gradient, same
// visual language _AvatarFallback already uses for the initials fallback)
// rather than bundled image files — no asset download/decode cost, crisp
// at any size, and nothing to import from outside the app.
//
// Persisted as a plain string in the existing avatarUrl field using a
// fake-scheme URL (avatar://<index>) so it round-trips through the same
// storage/sync path a real URL would, without needing a schema change.
const String _kDefaultAvatarScheme = 'avatar://';

const List<({IconData icon, Color color})> kDefaultAvatars = [
  (icon: Icons.face_rounded, color: Color(0xFF7C6AF7)),
  (icon: Icons.pets_rounded, color: Color(0xFFf97316)),
  (icon: Icons.rocket_launch_rounded, color: Color(0xFF38bdf8)),
  (icon: Icons.movie_rounded, color: Color(0xFFef4444)),
  (icon: Icons.sports_esports_rounded, color: Color(0xFF22c55e)),
  (icon: Icons.star_rounded, color: Color(0xFFf59e0b)),
  (icon: Icons.local_fire_department_rounded, color: Color(0xFFdc2626)),
  (icon: Icons.emoji_events_rounded, color: Color(0xFFa855f7)),
  (icon: Icons.music_note_rounded, color: Color(0xFFec4899)),
  (icon: Icons.eco_rounded, color: Color(0xFF14b8a6)),
];

bool isDefaultAvatarUrl(String url) => url.startsWith(_kDefaultAvatarScheme);

/// Index into [kDefaultAvatars], clamped so a value written by a future
/// version with more options never throws on an older client.
int defaultAvatarIndex(String url) {
  final raw = int.tryParse(url.substring(_kDefaultAvatarScheme.length)) ?? 0;
  return raw.clamp(0, kDefaultAvatars.length - 1);
}

String defaultAvatarUrlFor(int index) => '$_kDefaultAvatarScheme$index';

/// Renders one default avatar — used both for the actual profile avatar
/// (once selected) and for each option tile in the picker.
class DefaultAvatarView extends StatelessWidget {
  final int index;
  final double size;
  const DefaultAvatarView({super.key, required this.index, required this.size});

  @override
  Widget build(BuildContext context) {
    final entry = kDefaultAvatars[index.clamp(0, kDefaultAvatars.length - 1)];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            entry.color.withValues(alpha: 0.85),
            entry.color.withValues(alpha: 0.35)
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(entry.icon, color: Colors.white, size: size * 0.5),
    );
  }
}
