import 'package:flutter/material.dart';

import '../../core/models/complaint.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/complaint_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';

/// Lightweight detail placeholder screen for a selected complaint.
class ComplaintDetailScreen extends StatelessWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.complaint,
    this.propertyName,
    this.unitNumber,
  });

  final Complaint complaint;
  final String? propertyName;
  final String? unitNumber;

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
    if (date == null) return 'Date unavailable';
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

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Complaint details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header card with title, badges, and location
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ComplaintStatusBadge(status: complaint.status),
                            ComplaintPriorityBadge(
                              priority: complaint.priority,
                            ),
                            if (complaint.isRepeatVisit)
                              const StatusBadge(
                                label: 'Repeat visit',
                                tone: StatusBadgeTone.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          complaint.title.isEmpty
                              ? 'Untitled complaint'
                              : complaint.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: palette.ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(
                              Icons.apartment_outlined,
                              size: 18,
                              color: palette.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$_displayPropertyName · Unit $_displayUnitNumber',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: palette.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 18,
                              color: palette.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Created ${_formatDate(complaint.createdAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Description card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Description'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          complaint.description.isEmpty
                              ? 'No description provided.'
                              : complaint.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Meta details card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Record details'),
                        const SizedBox(height: AppSpacing.md),
                        _DetailRow(
                          label: 'Complaint ID',
                          value: complaint.id.isEmpty
                              ? 'Pending ID'
                              : complaint.id,
                        ),
                        _DetailRow(
                          label: 'Category',
                          value: complaint.category.displayLabel,
                        ),
                        _DetailRow(
                          label: 'Status',
                          value: complaint.status.displayLabel,
                        ),
                        _DetailRow(
                          label: 'Priority',
                          value: complaint.priority.displayLabel,
                        ),
                        _DetailRow(
                          label: 'Property ID',
                          value: complaint.propertyId,
                        ),
                        _DetailRow(label: 'Unit ID', value: complaint.unitId),
                        if (complaint.tenantId.isNotEmpty)
                          _DetailRow(
                            label: 'Tenant ID',
                            value: complaint.tenantId,
                          ),
                        _DetailRow(
                          label: 'Visit count',
                          value: '${complaint.visitCount}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Placeholder notice
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: palette.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Complaint detail placeholder',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: palette.ink,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Full workflow actions (technician assignment, visit logs, resolution, and audit history) will be introduced in subsequent updates.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: palette.muted, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
