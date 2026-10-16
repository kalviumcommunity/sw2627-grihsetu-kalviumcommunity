import 'package:flutter/material.dart';

import '../core/models/complaint.dart';
import '../theme/app_palette.dart';
import 'app_card.dart';
import 'app_spacing.dart';
import 'complaint_chips.dart';
import 'repeat_indicator.dart';

export 'complaint_chips.dart';

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
    this.bottomAction,
  });

  final Complaint complaint;
  final String? propertyName;
  final String? unitNumber;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? bottomAction;

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
              if (complaint.isRepeatVisit || complaint.visitCount >= 2)
                RepeatIndicator.repeat(
                  complaint.visitCount >= 2 ? complaint.visitCount : 2,
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
              ComplaintCategoryChip(category: complaint.category),
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
          if (bottomAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: palette.border, height: 1),
            const SizedBox(height: AppSpacing.xs),
            bottomAction!,
          ],
        ],
      ),
    );
  }
}
