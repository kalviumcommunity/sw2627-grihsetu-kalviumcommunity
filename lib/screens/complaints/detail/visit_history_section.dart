import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../utils/visit_history.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_spacing.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/repeat_indicator.dart';
import '../../../widgets/status_badge.dart';

/// Collapsible "Visit history (N)" section displaying on-site visits and recurring issue alerts.
///
/// Purely derived from the complaint's audit event list.
class VisitHistorySection extends StatefulWidget {
  const VisitHistorySection({
    super.key,
    required this.visits,
    this.repeatInfo,
    this.initiallyExpanded = true,
  });

  final List<VisitRecord> visits;
  final RepeatInfo? repeatInfo;
  final bool initiallyExpanded;

  @override
  State<VisitHistorySection> createState() => _VisitHistorySectionState();
}

class _VisitHistorySectionState extends State<VisitHistorySection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  String _formatDate(DateTime date) {
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
    final m = months[(date.month - 1).clamp(0, 11)];
    return '$m ${date.day}, ${date.year}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final mins = d.inMinutes.remainder(60);
      return mins > 0 ? '${d.inHours}h ${mins}m' : '${d.inHours}h';
    }
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final count = widget.visits.length;
    final info = widget.repeatInfo;
    final isRecurring = info?.recurringIssue == true || count >= 3;

    // Order visits newest first
    final orderedVisits = List<VisitRecord>.from(widget.visits)
      ..sort((a, b) {
        final comp = b.date.compareTo(a.date);
        if (comp != 0) return comp;
        return (b.visitNumber ?? 0).compareTo(a.visitNumber ?? 0);
      });

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collapsible Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 20,
                    color: palette.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Visit history ($count)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  if (count >= 2) ...[
                    RepeatIndicator.repeat(count),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: palette.muted,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const SizedBox(height: AppSpacing.md),

            // Recurring Issue Card
            if (isRecurring) ...[
              _RecurringIssueCard(repeatInfo: info, count: count),
              const SizedBox(height: AppSpacing.md),
            ],

            // Empty state
            if (orderedVisits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: EmptyState(
                  title: 'No visits yet',
                  message:
                      'No maintenance visits have been recorded for this complaint.',
                  icon: Icons.history_toggle_off_outlined,
                ),
              )
            else
              // Vertical list of visit cards, newest first
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orderedVisits.length,
                separatorBuilder: (context, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final visit = orderedVisits[index];
                  return _VisitCard(
                    visit: visit,
                    formatDate: _formatDate,
                    formatDuration: _formatDuration,
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _RecurringIssueCard extends StatelessWidget {
  const _RecurringIssueCard({required this.repeatInfo, required this.count});

  final RepeatInfo? repeatInfo;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final techs = repeatInfo?.previousTechnicians ?? const [];
    final actions = repeatInfo?.previousActions ?? const [];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.accent.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: palette.accent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  'Recurring issue detected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: palette.accent,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Requires root-cause inspection',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Previous technicians: ${techs.isNotEmpty ? techs.join(', ') : 'Not specified'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Previous actions: ${actions.isNotEmpty ? actions.join('; ') : 'Diagnostics and component inspection conducted'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatefulWidget {
  const _VisitCard({
    required this.visit,
    required this.formatDate,
    required this.formatDuration,
  });

  final VisitRecord visit;
  final String Function(DateTime) formatDate;
  final String Function(Duration) formatDuration;

  @override
  State<_VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<_VisitCard> {
  bool _showMoreNotes = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final visit = widget.visit;
    final visitNum = visit.visitNumber ?? 1;

    // Outcome badge tone
    final (badgeLabel, badgeTone) = switch (visit.outcome.toLowerCase()) {
      final s when s.contains('resolved') => ('Resolved', StatusBadgeTone.success),
      final s when s.contains('needs') || s.contains('another') || s.contains('follow') =>
        ('Needs another visit', StatusBadgeTone.warning),
      _ => ('In progress', StatusBadgeTone.accent),
    };

    final timeOnSite = visit.timeOnSite != null
        ? widget.formatDuration(visit.timeOnSite!)
        : (visit.isInProgress ? 'In progress' : 'Not recorded');

    final notes = visit.notes ?? visit.note ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visit Header row: Visit number, repeat pill, outcome badge
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Visit #$visitNum',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              if (visitNum >= 2) RepeatIndicator.visit(visitNum),
              StatusBadge(label: badgeLabel, tone: badgeTone),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),

          // Metadata row
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.formatDate(visit.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    visit.technician,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
                    timeOnSite,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Notes with "Show more"
          if (notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Builder(
              builder: (context) {
                final isLong = notes.length > 80;
                final displayText = isLong && !_showMoreNotes
                    ? '${notes.substring(0, 80)}...'
                    : notes;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.ink,
                        fontSize: 13,
                      ),
                    ),
                    if (isLong)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showMoreNotes = !_showMoreNotes),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _showMoreNotes ? 'Show less' : 'Show more',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],

          // Parts used
          if (visit.parts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.extension_outlined,
                  size: 14,
                  color: palette.muted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Parts used: ${visit.parts.join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Photo thumbnails
          if (visit.photoCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (var i = 0; i < (visit.photoCount > 4 ? 4 : visit.photoCount); i++)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.border),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: 16,
                      color: palette.muted,
                    ),
                  ),
                if (visit.photoCount > 4)
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${visit.photoCount - 4}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
