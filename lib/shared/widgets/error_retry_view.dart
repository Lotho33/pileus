import 'package:flutter/material.dart';

import '../../core/theme/app_scale.dart';
import '../../core/theme/app_theme.dart';
import 'tv_focusable.dart';

/// Full-bleed error state with a retry affordance, styled to match the rest
/// of the app (AppTheme palette, sh-ratio sizing, the same violet D-pad
/// focus ring every other control uses).
///
/// Exists so a network/backend failure stops dead-ending the user on a bare
/// red error string with no way forward — most importantly the plugin list
/// failing to load (home screen + Impostazioni > Plugin), where the only
/// previous recovery was killing and relaunching the app.
class ErrorRetryView extends StatefulWidget {
  final String title;
  final String? message;

  /// Raw error text — shown small and dim under [message] for support/debug,
  /// never as the primary copy.
  final String? detail;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;

  /// Whether the first action button grabs focus on mount — true wherever
  /// this view owns the screen, false if it's embedded under something that
  /// manages focus itself.
  final bool autofocus;

  const ErrorRetryView({
    super.key,
    this.title = 'Qualcosa è andato storto',
    this.message,
    this.detail,
    this.icon = Icons.cloud_off_rounded,
    this.onRetry,
    this.retryLabel = 'Riprova',
    this.onSecondary,
    this.secondaryLabel,
    this.autofocus = true,
  });

  @override
  State<ErrorRetryView> createState() => _ErrorRetryViewState();
}

class _ErrorRetryViewState extends State<ErrorRetryView> {
  final _retryFn = FocusNode();
  final _secondaryFn = FocusNode();

  @override
  void dispose() {
    _retryFn.dispose();
    _secondaryFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRetry = widget.onRetry != null;
    final hasSecondary =
        widget.onSecondary != null && widget.secondaryLabel != null;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppScale.space(context, 560)),
        child: Padding(
          padding: EdgeInsets.all(AppScale.space(context, 32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: AppScale.space(context, 56),
                  color: const Color(0xFFef4444)),
              SizedBox(height: AppScale.space(context, 20)),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: AppScale.title(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.message != null) ...[
                SizedBox(height: AppScale.space(context, 10)),
                Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textMid,
                    fontSize: AppScale.caption(context),
                    height: 1.5,
                  ),
                ),
              ],
              if (widget.detail != null && widget.detail!.trim().isNotEmpty) ...[
                SizedBox(height: AppScale.space(context, 12)),
                Text(
                  widget.detail!.trim(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textLow,
                    fontSize: AppScale.space(context, 12),
                    height: 1.4,
                  ),
                ),
              ],
              if (hasRetry || hasSecondary) ...[
                SizedBox(height: AppScale.space(context, 28)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasRetry)
                      _ErrorActionButton(
                        icon: Icons.refresh_rounded,
                        label: widget.retryLabel,
                        primary: true,
                        focusNode: _retryFn,
                        autofocus: widget.autofocus,
                        onTap: widget.onRetry!,
                        onRight: hasSecondary
                            ? () => _secondaryFn.requestFocus()
                            : null,
                      ),
                    if (hasRetry && hasSecondary)
                      SizedBox(width: AppScale.space(context, 12)),
                    if (hasSecondary)
                      _ErrorActionButton(
                        icon: Icons.settings_outlined,
                        label: widget.secondaryLabel!,
                        primary: false,
                        focusNode: _secondaryFn,
                        autofocus: widget.autofocus && !hasRetry,
                        onTap: widget.onSecondary!,
                        onLeft: hasRetry
                            ? () => _retryFn.requestFocus()
                            : null,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  const _ErrorActionButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.focusNode,
    required this.autofocus,
    required this.onTap,
    this.onLeft,
    this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onTap,
      onLeft: onLeft,
      onRight: onRight,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
          horizontal: AppScale.space(context, 24),
          vertical: AppScale.space(context, 12),
        ),
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.primary
              : primary
                  ? AppTheme.textHigh.withValues(alpha: 0.12)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused
                ? AppTheme.primary
                : AppTheme.textHigh.withValues(alpha: 0.28),
            width: 1.5,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: AppScale.space(context, 20),
                color: focused ? AppTheme.textHigh : AppTheme.textMid),
            SizedBox(width: AppScale.space(context, 8)),
            Text(
              label,
              style: TextStyle(
                color: focused ? AppTheme.textHigh : AppTheme.textMid,
                fontSize: AppScale.space(context, 15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
