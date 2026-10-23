import 'package:flutter/material.dart';

/// Loading placeholders shaped like what's coming, instead of a spinner on
/// an empty screen — same flat, static look as the home's own skeleton rows
/// (no shimmer: zero animation cost on weak TV boxes, and nothing to fight
/// a "reduce motion" setting).
const skeletonColor = Color(0xFF1A1A2A);

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox(
      {super.key, this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: skeletonColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// A grid of poster-shaped boxes with a title line under each — search
/// results while they load (mobile, desktop, web). Same grid shape as the
/// results it stands in for.
class PosterGridSkeleton extends StatelessWidget {
  final double maxCrossAxisExtent;
  final double childAspectRatio;
  final EdgeInsets padding;
  final double spacing;

  const PosterGridSkeleton({
    super.key,
    required this.maxCrossAxisExtent,
    required this.childAspectRatio,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: 18,
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: SkeletonBox(height: double.infinity, radius: 10)),
          SizedBox(height: 8),
          FractionallySizedBox(
              widthFactor: 0.75, child: SkeletonBox(height: 10)),
        ],
      ),
    );
  }
}

/// A title's details screen while GetDetails answers: title, a meta line,
/// a few lines of plot and the play button — neutral background, no
/// picture (the final layout depends on the media type, unknown yet).
class DetailsSkeleton extends StatelessWidget {
  const DetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final unit = size.height / 1080;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          size.width * 0.06, size.height * 0.22, size.width * 0.45, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: size.width * 0.32, height: 56 * unit),
          SizedBox(height: 24 * unit),
          SkeletonBox(width: size.width * 0.18, height: 18 * unit),
          SizedBox(height: 32 * unit),
          for (final f in const [1.0, 0.96, 0.9, 0.6]) ...[
            FractionallySizedBox(
                widthFactor: f, child: SkeletonBox(height: 16 * unit)),
            SizedBox(height: 12 * unit),
          ],
          SizedBox(height: 36 * unit),
          SkeletonBox(width: 200 * unit, height: 58 * unit, radius: 8),
        ],
      ),
    );
  }
}
