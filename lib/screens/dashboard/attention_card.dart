import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../utils/attention_rules.dart';
import '../../widgets/app_spacing.dart';

class AttentionCard extends StatelessWidget {
  const AttentionCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final AttentionItem item;
  final VoidCallback onTap;

  IconData _iconForType(AttentionType type) {
    return switch (type) {
      AttentionType.unassigned => Icons.person_search_outlined,
      AttentionType.slaRiskOrBreached => Icons.timer_outlined,
      AttentionType.urgentUnvisited => Icons.priority_high_outlined,
      AttentionType.recurringIssues => Icons.repeat_outlined,
      AttentionType.waitingForParts => Icons.build_outlined,
      AttentionType.unconfirmedResolution => Icons.mark_email_unread_outlined,
      AttentionType.reopened => Icons.replay_outlined,
      AttentionType.overdueRent => Icons.receipt_long_outlined,
      AttentionType.brokenPromises => Icons.event_busy_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isUrgent = item.severity == AttentionSeverity.urgent;
    // Severity uses amber (warning) or terracotta (danger) only
    final severityColor = isUrgent ? palette.danger : palette.warning;
    final severityLabel = isUrgent ? 'urgent' : 'warning';

    return Semantics(
      label: '${item.title}, count: ${item.count}, severity: $severityLabel',
      button: true,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left severity bar
                  Container(
                    width: 5,
                    color: severityColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Icon
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _iconForType(item.type),
                          size: 20,
                          color: severityColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Title, subtitle & oldest age
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.title,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: palette.ink,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              // Oldest age chip/text
                              Text(
                                '• ${item.oldestAgeLabel}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: palette.muted,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: palette.muted,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Count badge
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(left: 4, right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.count}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: severityColor,
                            ),
                      ),
                    ),
                  ),
                  // Chevron
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Center(
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
