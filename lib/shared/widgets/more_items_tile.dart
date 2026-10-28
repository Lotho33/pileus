import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The last slot of a home row that pages by itself (mobile/desktop): a
/// card-shaped placeholder with a spinner while the next page comes, or
/// "Riprova" after it failed. See features/media/paging.dart.
class MoreItemsTile extends StatelessWidget {
  final double width;
  final bool landscape;
  final bool failed;
  final VoidCallback onRetry;

  const MoreItemsTile({
    super.key,
    required this.width,
    required this.landscape,
    required this.failed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.topCenter,
        child: AspectRatio(
          aspectRatio: landscape ? 16 / 9 : 2 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: failed
                  ? TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Riprova'),
                    )
                  : const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
