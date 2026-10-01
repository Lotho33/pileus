import 'package:flutter/material.dart';

/// Mouse/touch equivalent of `SkipIntroButton` (TV, D-pad/`TvFocusable`-
/// driven) — same look and role (a floating "skip this interval" pill with a
/// small dismiss button next to it), for desktop and web where a click/tap
/// replaces D-pad focus navigation entirely.
class PointerSkipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onSkip;
  final VoidCallback onDismiss;

  const PointerSkipButton({
    super.key,
    required this.label,
    required this.onSkip,
    required this.onDismiss,
    this.icon = Icons.fast_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSkip,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onDismiss,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white54, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
