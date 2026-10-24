import 'package:flutter/material.dart';

import '../services/errors/app_failure.dart';
import '../theme/app_palette.dart';
import 'app_spacing.dart';

/// An inline, dismissible banner for displaying errors with an optional retry action.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    this.message,
    this.failure,
    this.onRetry,
    this.onDismiss,
    this.isRetrying = false,
  }) : assert(message != null || failure != null);

  final String? message;
  final AppFailure? failure;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final text = message ?? failure?.userMessage ?? 'An error occurred.';
    final canRetry = (failure == null || failure!.retryable) && onRetry != null;

    return Semantics(
      liveRegion: true,
      label: 'Error: $text',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: palette.danger,
              size: 20,
              semanticLabel: 'Error',
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (canRetry) ...[
              const SizedBox(width: AppSpacing.xs),
              TextButton(
                onPressed: isRetrying ? null : onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: palette.danger,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: isRetrying
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.danger,
                        ),
                      )
                    : const Text('Retry'),
              ),
            ],
            if (onDismiss != null) ...[
              IconButton(
                onPressed: onDismiss,
                iconSize: 18,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.zero,
                tooltip: 'Dismiss error',
                color: palette.danger,
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
