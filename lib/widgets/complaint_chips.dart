import 'package:flutter/material.dart';

import '../core/enums/complaint_category.dart';
import '../core/enums/complaint_priority.dart';
import '../core/enums/complaint_status.dart';
import '../theme/app_palette.dart';
import 'status_badge.dart';

export 'status_badge.dart' show StatusBadgeTone, StatusBadge;

/// Distinguishable operational status chip rendering all 8 [ComplaintStatus] values.
///
/// Uses [ComplaintStatus.displayLabel] for human-readable labels, and combines
/// both theme tones and distinct icons so information is not conveyed by color alone.
class ComplaintStatusChip extends StatelessWidget {
  const ComplaintStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  /// Safely parses an external status string with a fallback.
  ComplaintStatusChip.fromValue(
    String? value, {
    super.key,
    ComplaintStatus fallback = ComplaintStatus.open,
    this.compact = false,
  }) : status = ComplaintStatus.fromValue(value, fallback: fallback);

  final ComplaintStatus status;
  final bool compact;

  /// Returns the semantic tone and icon associated with [status].
  static (StatusBadgeTone, IconData) visualProperties(
    ComplaintStatus status,
  ) => switch (status) {
    ComplaintStatus.open => (StatusBadgeTone.accent, Icons.fiber_new_outlined),
    ComplaintStatus.assigned => (
      StatusBadgeTone.neutral,
      Icons.assignment_ind_outlined,
    ),
    ComplaintStatus.inProgress => (
      StatusBadgeTone.accent,
      Icons.pending_actions_outlined,
    ),
    ComplaintStatus.waitingForParts => (
      StatusBadgeTone.warning,
      Icons.hourglass_top_outlined,
    ),
    ComplaintStatus.resolved => (
      StatusBadgeTone.success,
      Icons.check_circle_outline,
    ),
    ComplaintStatus.closed => (
      StatusBadgeTone.neutral,
      Icons.task_alt_outlined,
    ),
    ComplaintStatus.reopened => (StatusBadgeTone.danger, Icons.replay_outlined),
    ComplaintStatus.cancelled => (
      StatusBadgeTone.danger,
      Icons.cancel_outlined,
    ),
  };

  static StatusBadgeTone toneFor(ComplaintStatus status) =>
      visualProperties(status).$1;

  static IconData iconFor(ComplaintStatus status) =>
      visualProperties(status).$2;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = visualProperties(status);
    final palette = context.palette;
    final (foreground, background) = switch (tone) {
      StatusBadgeTone.neutral => (palette.ink, palette.shimmer),
      StatusBadgeTone.accent => (palette.accent, palette.accentSoft),
      StatusBadgeTone.success => (palette.success, palette.surface),
      StatusBadgeTone.warning => (palette.warning, palette.surface),
      StatusBadgeTone.danger => (palette.danger, palette.surface),
    };

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 24 : 28),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: foreground.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backwards-compatible alias for [ComplaintStatusChip].
typedef ComplaintStatusBadge = ComplaintStatusChip;

/// Distinguishable operational priority chip rendering all 4 [ComplaintPriority] values.
///
/// Uses [ComplaintPriority.displayLabel] for human-readable labels, and combines
/// both theme tones and distinct icons so information is not conveyed by color alone.
class ComplaintPriorityChip extends StatelessWidget {
  const ComplaintPriorityChip({
    super.key,
    required this.priority,
    this.compact = false,
  });

  /// Safely parses an external priority string with a fallback.
  ComplaintPriorityChip.fromValue(
    String? value, {
    super.key,
    ComplaintPriority fallback = ComplaintPriority.medium,
    this.compact = false,
  }) : priority = ComplaintPriority.fromValue(value, fallback: fallback);

  final ComplaintPriority priority;
  final bool compact;

  /// Returns the semantic tone and icon associated with [priority].
  static (StatusBadgeTone, IconData) visualProperties(
    ComplaintPriority priority,
  ) => switch (priority) {
    ComplaintPriority.low => (
      StatusBadgeTone.neutral,
      Icons.arrow_downward_outlined,
    ),
    ComplaintPriority.medium => (StatusBadgeTone.accent, Icons.remove_outlined),
    ComplaintPriority.high => (
      StatusBadgeTone.warning,
      Icons.arrow_upward_outlined,
    ),
    ComplaintPriority.urgent => (
      StatusBadgeTone.danger,
      Icons.warning_amber_rounded,
    ),
  };

  static StatusBadgeTone toneFor(ComplaintPriority priority) =>
      visualProperties(priority).$1;

  static IconData iconFor(ComplaintPriority priority) =>
      visualProperties(priority).$2;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = visualProperties(priority);
    final palette = context.palette;
    final (foreground, background) = switch (tone) {
      StatusBadgeTone.neutral => (palette.ink, palette.shimmer),
      StatusBadgeTone.accent => (palette.accent, palette.accentSoft),
      StatusBadgeTone.success => (palette.success, palette.surface),
      StatusBadgeTone.warning => (palette.warning, palette.surface),
      StatusBadgeTone.danger => (palette.danger, palette.surface),
    };

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 24 : 28),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: foreground.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              priority.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backwards-compatible alias for [ComplaintPriorityChip].
typedef ComplaintPriorityBadge = ComplaintPriorityChip;

/// Distinguishable operational category chip rendering all 8 [ComplaintCategory] values.
///
/// Uses [ComplaintCategory.displayLabel] for human-readable labels and provides
/// thematic icons for immediate visual trade recognition.
class ComplaintCategoryChip extends StatelessWidget {
  const ComplaintCategoryChip({
    super.key,
    required this.category,
    this.compact = false,
  });

  /// Safely parses an external category string with a fallback.
  ComplaintCategoryChip.fromValue(
    String? value, {
    super.key,
    ComplaintCategory fallback = ComplaintCategory.other,
    this.compact = false,
  }) : category = ComplaintCategory.fromValue(value, fallback: fallback);

  final ComplaintCategory category;
  final bool compact;

  /// Returns the trade-specific icon associated with [category].
  static IconData iconFor(ComplaintCategory category) => switch (category) {
    ComplaintCategory.plumbing => Icons.plumbing_outlined,
    ComplaintCategory.electrical => Icons.bolt_outlined,
    ComplaintCategory.structural => Icons.home_repair_service_outlined,
    ComplaintCategory.appliance => Icons.kitchen_outlined,
    ComplaintCategory.security => Icons.security_outlined,
    ComplaintCategory.cleaning => Icons.cleaning_services_outlined,
    ComplaintCategory.commonArea => Icons.domain_outlined,
    ComplaintCategory.other => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final icon = iconFor(category);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: palette.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              category.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
