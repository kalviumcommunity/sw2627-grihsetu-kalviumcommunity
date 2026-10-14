import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_spacing.dart';

/// Reusable empty, no-results, and access-restricted placeholder widget.
///
/// Supports standard and [compact] variants for full-screen and nested cards.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// Factory for empty operational lists or inbox-zero states.
  const EmptyState.noData({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// Factory for search or filter operations yielding zero matches.
  const EmptyState.noResults({
    super.key,
    this.icon = Icons.search_off_outlined,
    this.title = 'No results found',
    this.message = 'Try adjusting your search terms or active filters.',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// Factory for access-restricted or unauthorized screens and sections.
  const EmptyState.restricted({
    super.key,
    this.icon = Icons.lock_outline,
    this.title = 'Access restricted',
    this.message = 'You do not have permission to view this information.',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// Compact empty state for inline sections like cards, panels, or sheets.
  const EmptyState.compact({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : compact = true;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final hasAction =
        actionLabel != null &&
        actionLabel!.trim().isNotEmpty &&
        onAction != null;

    final circleSize = compact ? 52.0 : 72.0;
    final iconSize = compact ? 24.0 : 32.0;
    final maxWidth = compact ? 360.0 : 420.0;
    final contentPadding = compact ? AppSpacing.md : AppSpacing.lg;

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
                  padding: EdgeInsets.all(contentPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: iconSize,
                          color: palette.accent,
                        ),
                      ),
                      SizedBox(height: compact ? AppSpacing.md : 20),
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
                      if (hasAction) ...[
                        SizedBox(
                          height: compact ? AppSpacing.sm : AppSpacing.md,
                        ),
                        FilledButton(
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            minimumSize: Size(
                              compact ? 100 : 120,
                              compact ? 40 : 48,
                            ),
                          ),
                          child: Text(
                            actionLabel!.trim(),
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
