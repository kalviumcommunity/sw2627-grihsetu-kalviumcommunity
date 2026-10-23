import 'package:flutter/material.dart';

import '../services/errors/app_failure.dart';
import '../theme/app_palette.dart';
import 'app_spacing.dart';

/// Reusable user-friendly error state with retry protection and responsive wrapping.
///
/// Supports full-screen and [compact] inline presentations, and integrates with [AppFailure].
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = "Couldn't load this",
    this.message,
    this.failure,
    this.onRetry,
    this.isRetrying = false,
    this.icon,
    this.retryLabel = 'Retry',
    this.compact = false,
  }) : assert(
         message != null || failure != null,
         'Either message or failure must be provided.',
       );

  /// Builds an [ErrorState] directly from an [AppFailure].
  factory ErrorState.fromFailure({
    Key? key,
    required AppFailure failure,
    VoidCallback? onRetry,
    bool isRetrying = false,
    String? title,
    String retryLabel = 'Retry',
    bool compact = false,
  }) {
    return ErrorState(
      key: key,
      failure: failure,
      title: title ?? _defaultTitleForFailure(failure),
      onRetry: failure.retryable ? onRetry : null,
      isRetrying: isRetrying,
      retryLabel: retryLabel,
      compact: compact,
    );
  }

  /// Factory for network or connectivity failures.
  const ErrorState.connectivity({
    super.key,
    this.title = 'Unable to connect',
    this.message = 'The service is temporarily unavailable. Check your connection and try again.',
    this.failure,
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
    this.failure,
    this.onRetry,
    this.isRetrying = false,
    this.retryLabel = 'Retry',
    this.compact = false,
  }) : icon = Icons.lock_outline;

  /// Compact error state for inline sections like cards, bottom sheets, or panels.
  const ErrorState.compact({
    super.key,
    this.title = "Couldn't load this",
    this.message,
    this.failure,
    this.onRetry,
    this.isRetrying = false,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Retry',
  }) : compact = true,
       assert(
         message != null || failure != null,
         'Either message or failure must be provided.',
       );

  final String title;
  final String? message;
  final AppFailure? failure;
  final VoidCallback? onRetry;
  final bool isRetrying;
  final IconData? icon;
  final String retryLabel;
  final bool compact;

  static String _defaultTitleForFailure(AppFailure failure) =>
      switch (failure) {
        NetworkFailure() => 'Unable to connect',
        TimeoutFailure() => 'Request timed out',
        UnavailableFailure() => 'Service unavailable',
        PermissionDeniedFailure() => 'Access restricted',
        UnauthenticatedFailure() => 'Sign-in required',
        NotFoundFailure() => 'Not found',
        ConflictFailure() => 'Conflict detected',
        RateLimitedFailure() => 'Slow down',
        InvalidCredentialsFailure() => 'Authentication failed',
        EmailInUseFailure() => 'Account exists',
        WeakPasswordFailure() => 'Weak password',
        ValidationFailure() => 'Check entered information',
        UnknownFailure() => "Something went wrong",
      };

  static IconData _iconForFailure(AppFailure failure) => switch (failure) {
    NetworkFailure() => Icons.wifi_off_outlined,
    TimeoutFailure() => Icons.timer_outlined,
    UnavailableFailure() => Icons.cloud_off_outlined,
    PermissionDeniedFailure() || UnauthenticatedFailure() => Icons.lock_outline,
    NotFoundFailure() => Icons.search_off_outlined,
    ConflictFailure() => Icons.sync_problem_outlined,
    RateLimitedFailure() => Icons.hourglass_empty_outlined,
    InvalidCredentialsFailure() ||
    EmailInUseFailure() ||
    WeakPasswordFailure() ||
    ValidationFailure() ||
    UnknownFailure() => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final maxWidth = compact ? 360.0 : 420.0;
    final padding = compact ? AppSpacing.md : AppSpacing.lg;
    final iconSize = compact ? 32.0 : 40.0;

    final resolvedIcon =
        icon ??
        (failure != null ? _iconForFailure(failure!) : Icons.error_outline);
    final resolvedMessage =
        failure?.userMessage ?? message ?? 'An error occurred.';
    final canRetry = (failure == null || failure!.retryable) && onRetry != null;

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
                        resolvedIcon,
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
                        resolvedMessage,
                        textAlign: TextAlign.center,
                        style:
                            (compact
                                    ? theme.textTheme.bodySmall
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(color: palette.muted),
                      ),
                      if (canRetry) ...[
                        SizedBox(
                          height: compact ? AppSpacing.sm : AppSpacing.md,
                        ),
                        FilledButton.icon(
                          onPressed: isRetrying ? null : onRetry,
                          style: FilledButton.styleFrom(
                            minimumSize: Size(
                              compact ? 100 : 120,
                              48, // Standard 48px touch target
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
