import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_spacing.dart';

/// Reusable user-friendly error state with retry protection and responsive wrapping.
///
/// Supports full-screen and [compact] inline presentations.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = "Couldn't load this",
    required this.message,
    this.onRetry,
    this.isRetrying = false,
    this.icon = Icons.cloud_off_outlined,
    this.retryLabel = 'Retry',
    this.compact = false,
  });

  /// Factory for network or connectivity failures.
  const ErrorState.connectivity({
    super.key,
    this.title = 'Unable to connect',
    this.message = 'The service is temporarily unavailable. Check your connection and try again.',
    required this.onRetry,
    this.isRetrying = false,
    this.retryLabel = 'Retry',
    this.compact = false,
  }) : icon = Icons.wifi_off_outlined;

  /// Factory for permission or authorization errors where retry is not available.
  const ErrorState.permission({
    super.key,
    this.title = 'Access restricted',
    this.message = "You don't have permission to view this information.",
    this.onRetry,
    this.isRetrying = false,
    this.retryLabel = 'Retry',
    this.compact = false,
  }) : icon = Icons.lock_outline;

  /// Compact error state for inline sections like cards, bottom sheets, or panels.
  const ErrorState.compact({
    super.key,
    this.title = "Couldn't load this",
    required this.message,
    this.onRetry,
    this.isRetrying = false,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Retry',
  }) : compact = true;

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool isRetrying;
  final IconData icon;
  final String retryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final maxWidth = compact ? 360.0 : 420.0;
    final padding = compact ? AppSpacing.md : AppSpacing.lg;
    final iconSize = compact ? 32.0 : 40.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: iconSize,
                        color: palette.danger,
                        semanticLabel: 'Error',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style:
                            (compact
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.titleLarge)
                                ?.copyWith(
                                  color: palette.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style:
                            (compact
                                    ? theme.textTheme.bodySmall
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(color: palette.muted),
                      ),
                      if (onRetry != null) ...[
                        SizedBox(
                          height: compact ? AppSpacing.sm : AppSpacing.md,
                        ),
                        FilledButton.icon(
                          onPressed: isRetrying ? null : onRetry,
                          style: FilledButton.styleFrom(
                            minimumSize: Size(
                              compact ? 100 : 120,
                              compact ? 40 : 48,
                            ),
                          ),
                          icon: isRetrying
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.surface,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 18),
                          label: Text(
                            isRetrying ? 'Retrying...' : retryLabel,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
