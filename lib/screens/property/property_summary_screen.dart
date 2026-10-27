import 'package:flutter/material.dart';

import '../../core/models/property.dart';
import '../../repositories/complaint_repository.dart';
import '../../repositories/property_repository.dart';
import '../../repositories/property_summary_repository.dart';
import '../../theme/app_palette.dart';
import '../../utils/complaint_query.dart';
import '../../utils/property_metrics.dart';
import '../../utils/rent_rules.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/stream_view.dart';
import '../complaints/search/complaint_search_screen.dart';
import 'property_summary_card.dart';

/// Full property-level operational summary screen.
///
/// Backed by [PropertySummaryRepository.watch] for live reactivity.
class PropertySummaryScreen extends StatefulWidget {
  const PropertySummaryScreen({
    super.key,
    required this.propertyId,
    this.initialProperty,
    this.summaryRepository,
    this.complaintRepository,
    this.propertyRepository,
    this.now,
    this.readOnly = false,
  });

  final String propertyId;
  final Property? initialProperty;
  final PropertySummaryRepository? summaryRepository;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;
  final DateTime? now;
  final bool readOnly;

  static Future<void> open(
    BuildContext context, {
    required String propertyId,
    Property? property,
    PropertySummaryRepository? summaryRepository,
    ComplaintRepository? complaintRepository,
    PropertyRepository? propertyRepository,
    DateTime? now,
    bool readOnly = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertySummaryScreen(
          propertyId: propertyId,
          initialProperty: property,
          summaryRepository: summaryRepository,
          complaintRepository: complaintRepository,
          propertyRepository: propertyRepository,
          now: now,
          readOnly: readOnly,
        ),
      ),
    );
  }

  @override
  State<PropertySummaryScreen> createState() => _PropertySummaryScreenState();
}

class _PropertySummaryScreenState extends State<PropertySummaryScreen> {
  late final PropertySummaryRepository _repository =
      widget.summaryRepository ?? DerivedPropertySummaryRepository();

  PropertyPeriod _selectedPeriod = PropertyPeriod.days30;

  DateTime get _effectiveNow => widget.now ?? DateTime.now();

  Stream<PropertySummary?> get _stream => _repository.watch(
    widget.propertyId,
    period: _selectedPeriod,
    now: _effectiveNow,
  );

  String _formatDuration(Duration? d) {
    if (d == null) return 'N/A';
    final hours = d.inMinutes / 60.0;
    if (hours < 1.0) {
      return '${d.inMinutes}m';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  void _openAllComplaints() {
    ComplaintSearchScreen.open(
      context,
      ComplaintFilter(propertyId: widget.propertyId),
      repository: widget.complaintRepository ?? InMemoryComplaintRepository(),
      propertyRepository:
          widget.propertyRepository ?? InMemoryPropertyRepository(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(widget.initialProperty?.name ?? 'Property Summary'),
        actions: [
          IconButton(
            tooltip: 'View all complaints',
            icon: const Icon(Icons.assignment_outlined),
            onPressed: _openAllComplaints,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamView<PropertySummary?>(
          stream: _stream,
          showLiveChip: true,
          skeletonBuilder: (_) => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: SkeletonList(itemCount: 4),
          ),
          emptyBuilder: (_) => const Center(
            child: EmptyState.noData(
              icon: Icons.domain_disabled,
              title: 'Property Not Found',
              message: 'No operational summary available for this property.',
            ),
          ),
          builder: (context, summary) {
            if (summary == null) {
              return const Center(
                child: EmptyState.noData(
                  icon: Icons.domain_disabled,
                  title: 'Property Not Found',
                  message:
                      'No operational summary available for this property.',
                ),
              );
            }

            final isWide = MediaQuery.sizeOf(context).width >= 600;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Period Selector Segmented Control
                  _buildPeriodSelector(palette, theme),
                  const SizedBox(height: AppSpacing.md),

                  // Health & Overview Card
                  PropertySummaryCard(summary: summary, showSparkline: true),
                  const SizedBox(height: AppSpacing.lg),

                  // KPIs Grid
                  _buildKpisSection(summary, isWide, palette, theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Category Breakdown & Technician Workload
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCategoryBreakdown(
                            summary,
                            palette,
                            theme,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildTechnicianWorkload(
                            summary,
                            palette,
                            theme,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildCategoryBreakdown(summary, palette, theme),
                    const SizedBox(height: AppSpacing.md),
                    _buildTechnicianWorkload(summary, palette, theme),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  // Rent Status Section
                  _buildRentSection(summary, palette, theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Recurring Issues Alert
                  if (summary.recurringIssues > 0) ...[
                    _buildRecurringIssuesCard(summary, palette, theme),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Action Button
                  Semantics(
                    label: 'View all complaints for ${summary.propertyName}',
                    button: true,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: palette.accent,
                        side: BorderSide(color: palette.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.search),
                      label: const Text('View All Complaints for Property'),
                      onPressed: _openAllComplaints,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(AppPalette palette, ThemeData theme) {
    return SegmentedButton<PropertyPeriod>(
      segments: const [
        ButtonSegment(value: PropertyPeriod.days7, label: Text('7 Days')),
        ButtonSegment(value: PropertyPeriod.days30, label: Text('30 Days')),
        ButtonSegment(value: PropertyPeriod.days90, label: Text('90 Days')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) {
          setState(() {
            _selectedPeriod = selected.first;
          });
        }
      },
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        side: WidgetStateProperty.all(BorderSide(color: palette.border)),
      ),
    );
  }

  Widget _buildKpisSection(
    PropertySummary summary,
    bool isWide,
    AppPalette palette,
    ThemeData theme,
  ) {
    final kpis = [
      _KpiData(
        label: 'Occupancy',
        value: '${summary.occupiedUnits} / ${summary.totalUnits}',
        subtitle: '${summary.occupancyRate.toStringAsFixed(0)}% occupied',
      ),
      _KpiData(
        label: 'Resolved (${summary.periodDays}d)',
        value: '${summary.resolvedInPeriod}',
        subtitle: '${summary.createdInPeriod} created',
      ),
      _KpiData(
        label: 'Avg Response',
        value: _formatDuration(summary.avgFirstResponse),
        subtitle: 'Target: < 2h',
      ),
      _KpiData(
        label: 'Avg Resolution',
        value: _formatDuration(summary.avgResolutionTime),
        subtitle: 'Target: < 24h',
      ),
      _KpiData(
        label: 'SLA Compliance',
        value: summary.slaPercent != null
            ? '${summary.slaPercent!.round()}%'
            : 'N/A',
        subtitle: 'Resolved on time',
        valueColor: summary.slaPercent != null && summary.slaPercent! >= 90.0
            ? palette.success
            : palette.warning,
      ),
      _KpiData(
        label: 'Repeat Visits',
        value: '${summary.repeatVisits}',
        subtitle: '${summary.recurringIssues} recurring',
        valueColor: summary.repeatVisits > 0 ? palette.danger : palette.ink,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isWide ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kpis.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isWide ? 2.2 : 1.8,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemBuilder: (context, index) {
            final kpi = kpis[index];
            return Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    kpi.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kpi.value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: kpi.valueColor ?? palette.ink,
                    ),
                  ),
                  if (kpi.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      kpi.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryBreakdown(
    PropertySummary summary,
    AppPalette palette,
    ThemeData theme,
  ) {
    final entries =
        summary.categoryBreakdown.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

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
          Text(
            'Complaints by Category',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (entries.isEmpty)
            Text(
              'No complaints recorded.',
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            )
          else
            for (final entry in entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.displayLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.ink,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.raised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildTechnicianWorkload(
    PropertySummary summary,
    AppPalette palette,
    ThemeData theme,
  ) {
    final entries = summary.technicianWorkload.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          Text(
            'Active Technician Workload',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (entries.isEmpty)
            Text(
              'No active assignments in this building.',
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            )
          else
            for (final entry in entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.ink,
                      ),
                    ),
                    Text(
                      '${entry.value} jobs',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildRentSection(
    PropertySummary summary,
    AppPalette palette,
    ThemeData theme,
  ) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rent Collection Status',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              Text(
                '${summary.collectionRate.toStringAsFixed(1)}% collected',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: summary.collectionRate >= 95.0
                      ? palette.success
                      : palette.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (summary.collectionRate / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: palette.raised,
              valueColor: AlwaysStoppedAnimation<Color>(
                summary.collectionRate >= 95.0
                    ? palette.success
                    : palette.warning,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Due: ${formatIndianCurrency(summary.totalRentDue)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
              Text(
                'Collected: ${formatIndianCurrency(summary.totalRentCollected)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
          ),
          if (summary.overdueRentCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${summary.overdueRentCount} units overdue: ${formatIndianCurrency(summary.overdueRentAmount)} pending',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurringIssuesCard(
    PropertySummary summary,
    AppPalette palette,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.repeat, color: palette.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.recurringIssues} Recurring Issues Detected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: palette.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Multiple complaints registered within 60 days in the same unit & category.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
}
