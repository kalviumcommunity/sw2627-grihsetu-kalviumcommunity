import 'package:flutter/material.dart';

import '../services/errors/app_failure.dart';
import '../services/errors/firebase_error_mapper.dart';
import '../theme/app_palette.dart';

enum AppSnackType { info, success, error }

/// Helper that displays consistent, accessible SnackBars one at a time.
abstract final class AppSnack {
  /// Displays a SnackBar with the specified [type], clearing any active banner.
  static void show(
    BuildContext context,
    String message, {
    AppSnackType type = AppSnackType.info,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final palette = context.palette;

    final (bgColor, icon, semanticPrefix) = switch (type) {
      AppSnackType.success => (
        palette.success,
        Icons.check_circle_outline,
        'Success: ',
      ),
      AppSnackType.error => (palette.danger, Icons.error_outline, 'Error: '),
      AppSnackType.info => (palette.ink, Icons.info_outline, 'Notice: '),
    };

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: palette.surface, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: '$semanticPrefix$message',
                child: Text(
                  message,
                  style: TextStyle(
                    color: palette.surface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: action,
      ),
    );
  }

  /// Convenience for success SnackBars.
  static void success(BuildContext context, String message) {
    show(context, message, type: AppSnackType.success);
  }

  /// Convenience for informational SnackBars.
  static void info(BuildContext context, String message) {
    show(context, message, type: AppSnackType.info);
  }

  /// Convenience for error SnackBars, mapping raw exceptions or accepting an [AppFailure].
  static void error(
    BuildContext context,
    Object failureOrError, {
    VoidCallback? onRetry,
  }) {
    final failure = failureOrError is AppFailure
        ? failureOrError
        : FirebaseErrorMapper.map(failureOrError);

    SnackBarAction? action;
    if (failure.retryable && onRetry != null) {
      action = SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: onRetry,
      );
    }

    show(
      context,
      failure.userMessage,
      type: AppSnackType.error,
      action: action,
    );
  }
}
