import 'package:flutter/material.dart';

/// Soft radial accent glow behind a screen's content — the auth flow
/// (device_pairing_screen.dart, server_discovery_screen.dart) already used
/// this exact gradient inline;
/// pulled out here so the settings screens (previously flat AppTheme.bg,
/// visibly plainer than the rest of the app) can share it instead of each
/// re-declaring the same decoration. Purely decorative — sits behind
/// [child] via a Stack, doesn't intercept hits or affect layout.
class AmbientGlowBackground extends StatelessWidget {
  final Widget child;
  final Color color;
  final Alignment center;

  const AmbientGlowBackground({
    super.key,
    required this.child,
    this.color = const Color(0xFF7C6AF7),
    this.center = const Alignment(0, -0.3),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // RepaintBoundary: the gradient never changes for a screen's
        // lifetime — give it its own cached layer so a busy foreground
        // (settings lists scrolling, focus glows animating) doesn't drag it
        // into every repaint.
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: center,
                    radius: 1.0,
                    colors: [
                      color.withValues(alpha: 0.16),
                      color.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
