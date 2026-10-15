import 'package:flutter/material.dart';

import '../screens/complaints/detail/complaint_detail_models.dart';
import '../theme/app_palette.dart';
import '../utils/date_time_formatters.dart';
import 'app_card.dart';
import 'app_spacing.dart';
import 'status_badge.dart';

/// Reusable widget displaying the total visit count for a complaint.
class TotalVisitsWidget extends StatelessWidget {
  const TotalVisitsWidget({
    super.key,
    required this.count,
    this.label = 'Total visits',
  });

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: palette.muted),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.muted,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$count',
          key: const Key('total_visits_count_text'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: palette.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Reusable widget displaying the last maintenance visit date.
class LastVisitWidget extends StatelessWidget {
  const LastVisitWidget({
    super.key,
    required this.lastVisitDate,
    this.label = 'Last visit',
    this.placeholder = 'No recorded visits',
    this.isInProgress = false,
  });

  final DateTime? lastVisitDate;
  final String label;
  final String placeholder;
  final bool isInProgress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final formatted = formatDate(lastVisitDate, placeholder: placeholder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_outlined, size: 14, color: palette.muted),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (isInProgress)
              const StatusBadge(label: 'Active', tone: StatusBadgeTone.accent),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          formatted,
          key: const Key('last_visit_date_text'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: lastVisitDate != null ? palette.ink : palette.muted,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Reusable widget displaying repeat-visit status and repeat-visit count.
class RepeatVisitSummaryWidget extends StatelessWidget {
  const RepeatVisitSummaryWidget({
    super.key,
    required this.isRepeat,
    this.repeatCount = 0,
    this.reopenCount = 0,
    this.label = 'Repeat status',
  });

  final bool isRepeat;
  final int repeatCount;
  final int reopenCount;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final statusText = isRepeat
        ? (repeatCount > 0
              ? '$repeatCount follow-up${repeatCount > 1 ? "s" : ""}'
              : (reopenCount > 0 ? 'Reopened' : 'Repeat issue'))
        : 'First visit';

    final tone = isRepeat ? StatusBadgeTone.warning : StatusBadgeTone.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat_outlined, size: 14, color: palette.muted),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.muted,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        StatusBadge(
          key: const Key('repeat_status_badge'),
          label: statusText,
          tone: tone,
        ),
      ],
    );
  }
}

/// Reusable card aggregating total visits, last visit, and repeat-visit status.
class VisitSummaryCard extends StatelessWidget {
  const VisitSummaryCard({
    super.key,
    required this.summary,
    this.title = 'Visit overview',
  });

  final VisitSummary summary;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return AppCard(
      key: const Key('visit_summary_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: palette.accent,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Fraunces',
                        color: palette.ink,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (summary.isRepeat)
                const StatusBadge(
                  label: 'Repeat issue',
                  tone: StatusBadgeTone.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TotalVisitsWidget(count: summary.totalVisits),
                    const SizedBox(height: AppSpacing.sm),
                    Divider(color: palette.border, height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    LastVisitWidget(
                      lastVisitDate: summary.lastVisitDate,
                      isInProgress: summary.isVisitInProgress,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Divider(color: palette.border, height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    RepeatVisitSummaryWidget(
                      isRepeat: summary.isRepeat,
                      repeatCount: summary.repeatVisitsCount,
                      reopenCount: summary.reopenCount,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TotalVisitsWidget(count: summary.totalVisits),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 4,
                    child: LastVisitWidget(
                      lastVisitDate: summary.lastVisitDate,
                      isInProgress: summary.isVisitInProgress,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 4,
                    child: RepeatVisitSummaryWidget(
                      isRepeat: summary.isRepeat,
                      repeatCount: summary.repeatVisitsCount,
                      reopenCount: summary.reopenCount,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
