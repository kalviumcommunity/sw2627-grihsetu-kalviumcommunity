import 'package:flutter/material.dart';

import '../core/enums/complaint_category.dart';
import '../core/enums/complaint_priority.dart';
import '../core/enums/complaint_status.dart';
import '../core/models/complaint.dart';
import '../theme/app_palette.dart';
import 'app_card.dart';
import 'app_spacing.dart';
import 'status_badge.dart';

/// Reusable complaint presentation card.
///
/// Purely presentational and Firestore-independent: receives complaint data
/// and display context as parameters.
class ComplaintCard extends StatelessWidget {
  const ComplaintCard({
    super.key,
    required this.complaint,
    this.propertyName,
    this.unitNumber,
    this.onTap,
    this.selected = false,
  });

  final Complaint complaint;
  final String? propertyName;
  final String? unitNumber;
  final VoidCallback? onTap;
  final bool selected;

  String get _displayPropertyName {
    final name = propertyName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (complaint.propertyId.trim().isNotEmpty) return complaint.propertyId;
    return 'Unknown property';
  }

  String get _displayUnitNumber {
    final unit = unitNumber?.trim();
    if (unit != null && unit.isNotEmpty) return unit;
    if (complaint.unitId.trim().isNotEmpty) return complaint.unitId;
    return 'Unknown unit';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[(date.month - 1).clamp(0, 11)];
    return '$month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final dateStr = _formatDate(complaint.createdAt);

    return AppCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Badges
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ComplaintStatusBadge(status: complaint.status),
              ComplaintPriorityBadge(priority: complaint.priority),
              if (complaint.isRepeatVisit)
                const StatusBadge(
                  label: 'Repeat visit',
                  tone: StatusBadgeTone.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Title
          Text(
            complaint.title.isEmpty ? 'Untitled complaint' : complaint.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Location and unit context
          Row(
            children: [
              Icon(
                Icons.apartment_outlined,
                size: 16,
                color: palette.muted,
                semanticLabel: 'Location',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$_displayPropertyName · Unit $_displayUnitNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Bottom row: Category chip and Creation date
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.raised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _categoryIcon(complaint.category),
                      size: 14,
                      color: palette.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      complaint.category.displayLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (dateStr.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 14,
                      color: palette.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(ComplaintCategory category) => switch (category) {
    ComplaintCategory.plumbing => Icons.plumbing_outlined,
    ComplaintCategory.electrical => Icons.bolt_outlined,
    ComplaintCategory.structural => Icons.home_repair_service_outlined,
    ComplaintCategory.appliance => Icons.kitchen_outlined,
    ComplaintCategory.security => Icons.security_outlined,
    ComplaintCategory.cleaning => Icons.cleaning_services_outlined,
    ComplaintCategory.commonArea => Icons.domain_outlined,
    ComplaintCategory.other => Icons.category_outlined,
  };
}

/// Distinguishable status badge rendering all 8 [ComplaintStatus] values.
///
/// Uses [ComplaintStatus.displayLabel] for human-readable labels, and combines
/// both theme tones and distinct icons so information is not conveyed by color alone.
class ComplaintStatusBadge extends StatelessWidget {
  const ComplaintStatusBadge({super.key, required this.status});

  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (status) {
      ComplaintStatus.open => (
        StatusBadgeTone.accent,
        Icons.fiber_new_outlined,
      ),
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
      ComplaintStatus.reopened => (
        StatusBadgeTone.danger,
        Icons.replay_outlined,
      ),
      ComplaintStatus.cancelled => (
        StatusBadgeTone.neutral,
        Icons.cancel_outlined,
      ),
    };

    final palette = context.palette;
    final (foreground, background) = switch (tone) {
      StatusBadgeTone.neutral => (palette.ink, palette.shimmer),
      StatusBadgeTone.accent => (palette.accent, palette.accentSoft),
      StatusBadgeTone.success => (palette.success, palette.surface),
      StatusBadgeTone.warning => (palette.warning, palette.surface),
      StatusBadgeTone.danger => (palette.danger, palette.surface),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: foreground.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
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

/// Distinguishable priority badge rendering all 4 [ComplaintPriority] values.
///
/// Uses [ComplaintPriority.displayLabel] for human-readable labels, and combines
/// both theme tones and distinct icons so information is not conveyed by color alone.
class ComplaintPriorityBadge extends StatelessWidget {
  const ComplaintPriorityBadge({super.key, required this.priority});

  final ComplaintPriority priority;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (priority) {
      ComplaintPriority.low => (
        StatusBadgeTone.neutral,
        Icons.arrow_downward_outlined,
      ),
      ComplaintPriority.medium => (
        StatusBadgeTone.accent,
        Icons.remove_outlined,
      ),
      ComplaintPriority.high => (
        StatusBadgeTone.warning,
        Icons.arrow_upward_outlined,
      ),
      ComplaintPriority.urgent => (
        StatusBadgeTone.danger,
        Icons.warning_amber_rounded,
      ),
    };

    final palette = context.palette;
    final (foreground, background) = switch (tone) {
      StatusBadgeTone.neutral => (palette.ink, palette.shimmer),
      StatusBadgeTone.accent => (palette.accent, palette.accentSoft),
      StatusBadgeTone.success => (palette.success, palette.surface),
      StatusBadgeTone.warning => (palette.warning, palette.surface),
      StatusBadgeTone.danger => (palette.danger, palette.surface),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: foreground.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
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
