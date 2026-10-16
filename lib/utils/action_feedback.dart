import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Semantic outcome types supported by [ActionFeedback].
enum ActionFeedbackType { success, error, info, warning }

/// Shared action-feedback helper for standardizing SnackBars and confirmation dialogs.
abstract final class ActionFeedback {
  /// Shows a success SnackBar with a positive semantic tone and checkmark icon.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      type: ActionFeedbackType.success,
      action: action,
      duration: duration,
    );
  }

  /// Shows an error SnackBar with a danger semantic tone and error icon.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 5),
  }) {
    return show(
      context,
      message: message,
      type: ActionFeedbackType.error,
      action: action,
      duration: duration,
    );
  }

  /// Shows an informational SnackBar with an accent tone and info icon.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      type: ActionFeedbackType.info,
      action: action,
      duration: duration,
    );
  }

  /// Shows a warning SnackBar with an attention tone and warning icon.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showWarning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      type: ActionFeedbackType.warning,
      action: action,
      duration: duration,
    );
  }

  /// Displays a SnackBar configured according to [type].
  ///
  /// Replaces any currently showing SnackBar to avoid stacking multiple SnackBars.
  /// Safely checks `context.mounted` before accessing the ScaffoldMessenger.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context, {
    required String message,
    ActionFeedbackType type = ActionFeedbackType.info,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return null;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;

    final palette = context.palette;
    final theme = Theme.of(context);

    final (color, icon) = switch (type) {
      ActionFeedbackType.success => (
        palette.success,
        Icons.check_circle_outline,
      ),
      ActionFeedbackType.error => (palette.danger, Icons.error_outline),
      ActionFeedbackType.warning => (
        palette.warning,
        Icons.warning_amber_rounded,
      ),
      ActionFeedbackType.info => (palette.accent, Icons.info_outline),
    };

    final backgroundColor = Color.alphaBlend(
      color.withValues(alpha: palette.isDark ? 0.16 : 0.08),
      palette.surface,
    );

    messenger.hideCurrentSnackBar();

    return messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        elevation: 2,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        action: action,
        content: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Standardized confirmation dialog preserving cancellation and confirmation semantics.
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    if (!context.mounted) return Future.value(null);

    final palette = context.palette;
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'Fraunces',
            color: palette.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: palette.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel, style: TextStyle(color: palette.muted)),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: palette.danger,
                    foregroundColor: palette.surface,
                  )
                : FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.surface,
                  ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
