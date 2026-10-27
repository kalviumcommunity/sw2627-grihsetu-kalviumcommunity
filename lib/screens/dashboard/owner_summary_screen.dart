import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/enums/complaint_category.dart';
import '../../core/fixtures/sample_fixtures.dart';
import '../../core/models/complaint.dart';
import '../../core/models/property.dart';
import '../../core/models/rent_record.dart';
import '../../core/models/user.dart';
import '../../repositories/complaint_repository.dart';
import '../../repositories/complaint_store.dart';
import '../../repositories/property_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../theme/app_palette.dart';
import '../../utils/owner_summary.dart';
import '../../utils/property_metrics.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/charts/bar_compare_chart.dart';
import '../../widgets/charts/donut_or_stacked_bar.dart';
import '../../widgets/charts/trend_line_chart.dart';
import '../../widgets/repeat_indicator.dart';
import '../../widgets/responsive_grid.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/stream_view.dart';
import '../property/property_summary_screen.dart';

/// Owner portfolio overview screen presenting aggregated operational and financial health.
class OwnerSummaryScreen extends StatefulWidget {
  const OwnerSummaryScreen({
    this.profile,
    this.complaintStore,
    this.propertyRepository,
    this.complaintRepository,
    this.rentRepository,
    this.properties,
    this.units,
    this.rentRecords,
    this.printMode = false,
    this.initialPeriodDays,
    this.now,
    super.key,
  });

  final AppUser? profile;
  final ComplaintStore? complaintStore;
  final PropertyRepository? propertyRepository;
  final ComplaintRepository? complaintRepository;
  final RentRepository? rentRepository;
  final List<Property>? properties;
  final List<Unit>? units;
  final List<RentRecord>? rentRecords;
  final bool printMode;
  final int? initialPeriodDays;
  final DateTime? now;

  /// In-memory persistence for period selection across navigation instances.
  static int rememberedPeriodDays = 30;

  static Route<void> route({
    AppUser? profile,
    bool printMode = false,
    int? initialPeriodDays,
    DateTime? now,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => OwnerSummaryScreen(
        profile: profile,
        printMode: printMode,
        initialPeriodDays: initialPeriodDays,
        now: now,
      ),
    );
  }

  @override
  State<OwnerSummaryScreen> createState() => _OwnerSummaryScreenState();
}

class _OwnerSummaryScreenState extends State<OwnerSummaryScreen> {
  late int _periodDays;
  late final ComplaintStore _store =
      widget.complaintStore ?? ComplaintStore.instance;

  @override
  void initState() {
    super.initState();
    _periodDays =
        widget.initialPeriodDays ?? OwnerSummaryScreen.rememberedPeriodDays;
  }

  void _onPeriodChanged(int days) {
    setState(() {
      _periodDays = days;
      OwnerSummaryScreen.rememberedPeriodDays = days;
    });
  }

  DateTime get _effectiveNow => widget.now ?? DateTime.now();

  void _copySummaryToClipboard(OwnerSummary summary) {
    final text = buildOwnerSummaryPlainText(summary);
    Clipboard.setData(ClipboardData(text: text));
    AppSnack.show(context, 'Portfolio summary copied to clipboard');
  }

  void _openPrintMode(OwnerSummary summary) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OwnerSummaryScreen(
          profile: widget.profile,
          complaintStore: widget.complaintStore,
          propertyRepository: widget.propertyRepository,
          complaintRepository: widget.complaintRepository,
          rentRepository: widget.rentRepository,
          properties: widget.properties,
          units: widget.units,
          rentRecords: widget.rentRecords,
          printMode: true,
          initialPeriodDays: _periodDays,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return StreamBuilder<List<Complaint>>(
      stream: _store.watchAll(),
      initialData: _store.snapshot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: palette.canvas,
            appBar: AppBar(title: const Text('Portfolio Summary')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: palette.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Failed to load operational data',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.muted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final complaints = snapshot.data ?? _store.snapshot;

        // Fetch properties & rent
        final properties = widget.properties ?? SampleFixtures.sampleProperties;
        final units = widget.units ?? SampleFixtures.sampleUnits;
        final rentRecords =
            widget.rentRecords ?? SampleFixtures.sampleRentRecords;

        final summary = calculateOwnerSummary(
          properties: properties,
          units: units,
          complaints: complaints.isNotEmpty
              ? complaints
              : (widget.properties != null
                    ? complaints
                    : SampleFixtures.sampleComplaints),
          rentRecords: rentRecords,
          periodDays: _periodDays,
          now: _effectiveNow,
        );

        if (summary.totalProperties == 0) {
          return Scaffold(
            backgroundColor: palette.canvas,
            appBar: AppBar(title: const Text('Portfolio Summary')),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: palette.accentSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.domain_add,
                            size: 48,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Welcome to GrihSetu!',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: palette.ink,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'No properties in your portfolio yet. Add your first building to start tracking operational health, complaints, technician jobs, and rent collections.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.muted),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton.icon(
                          onPressed: () {
                            AppSnack.show(
                              context,
                              'Property onboarding wizard',
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Property'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (widget.printMode) {
          return _buildPrintModeView(context, summary);
        }

        return Scaffold(
          backgroundColor: palette.canvas,
          appBar: AppBar(
            title: const Text('Portfolio Summary'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Copy summary text',
                onPressed: () => _copySummaryToClipboard(summary),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: 'Print friendly mode',
                onPressed: () => _openPrintMode(summary),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future<void>.delayed(const Duration(milliseconds: 200));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ResponsiveDashboardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Period Selector & Header
                    _buildHeaderSection(context, summary),
                    const SizedBox(height: AppSpacing.md),

                    // 2. Highlights Card
                    _buildHighlightsCard(context, summary),
                    const SizedBox(height: AppSpacing.lg),

                    // 3. KPI Metrics Grid
                    _buildKpiSection(context, summary),
                    const SizedBox(height: AppSpacing.xl),

                    // 4. Trend & Category Charts
                    _buildChartsSection(context, summary),
                    const SizedBox(height: AppSpacing.xl),

                    // 5. Property Comparison (Table vs Cards)
                    _buildPropertyComparisonSection(context, summary),
                    const SizedBox(height: AppSpacing.xl),

                    // 6. Rent Collection Overview
                    _buildRentCollectionSection(context, summary),
                    const SizedBox(height: AppSpacing.xl),

                    // 7. Technician Performance & Recurring Issues
                    _buildOperationalDetailsSection(context, summary),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(BuildContext context, OwnerSummary summary) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;

        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio Operational Health',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
            ),
            const SizedBox(height: 2),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: 4,
              children: [
                Text(
                  '${summary.totalProperties} properties • ${summary.totalUnits} units',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.muted),
                ),
                const LiveStatusChip(label: 'Live'),
              ],
            ),
          ],
        );

        final segmentedButton = SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7D')),
            ButtonSegment(value: 30, label: Text('30D')),
            ButtonSegment(value: 90, label: Text('90D')),
          ],
          selected: {_periodDays},
          onSelectionChanged: (val) {
            if (val.isNotEmpty) _onPeriodChanged(val.first);
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(const Size(48, 48)),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: WidgetStateProperty.all(
              Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: AppSpacing.sm),
              segmentedButton,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleColumn),
            const SizedBox(width: AppSpacing.md),
            segmentedButton,
          ],
        );
      },
    );
  }

  Widget _buildHighlightsCard(BuildContext context, OwnerSummary summary) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: palette.accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Key Highlights & Observations',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final highlight in summary.highlights) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: palette.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      highlight,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: palette.ink),
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

  Widget _buildKpiSection(BuildContext context, OwnerSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount = w >= 900 ? 4 : (w >= 540 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: crossAxisCount == 1 ? 3.0 : 1.7,
          children: [
            OwnerKpiCard(
              label: 'Occupancy Rate',
              value: '${summary.occupancyRate.toStringAsFixed(1)}%',
              subtitle:
                  '${summary.occupiedUnits} of ${summary.totalUnits} units',
              icon: Icons.apartment,
            ),
            OwnerKpiCard(
              label: 'Open Complaints',
              value: '${summary.openComplaints}',
              subtitle: '${summary.waitingForPartsCount} waiting parts',
              icon: Icons.assignment_late_outlined,
            ),
            OwnerKpiCard(
              label: 'Resolved in Period',
              value: '${summary.resolvedInPeriod}',
              delta: summary.resolvedDelta,
              subtitle: 'of ${summary.createdInPeriod} created',
              icon: Icons.check_circle_outline,
            ),
            OwnerKpiCard(
              label: 'SLA Met %',
              value: summary.slaPercent != null
                  ? '${summary.slaPercent!.toStringAsFixed(1)}%'
                  : 'N/A',
              delta: summary.slaDelta,
              subtitle: 'Expected resolution deadline',
              icon: Icons.speed,
            ),
            OwnerKpiCard(
              label: 'Avg First Response',
              value: summary.avgFirstResponse != null
                  ? _formatDuration(summary.avgFirstResponse!)
                  : 'N/A',
              delta: summary.responseDelta,
              subtitle: 'Tenant wait to assign',
              icon: Icons.timelapse,
            ),
            OwnerKpiCard(
              label: 'Avg Resolution Time',
              value: summary.avgResolutionTime != null
                  ? _formatDuration(summary.avgResolutionTime!)
                  : 'N/A',
              delta: summary.resolutionDelta,
              subtitle: 'Creation to close',
              icon: Icons.hourglass_bottom,
            ),
            OwnerKpiCard(
              label: 'Rent Collection',
              value: '${summary.collectionRate.toStringAsFixed(1)}%',
              delta: summary.collectionDelta,
              subtitle: '₹${summary.totalRentCollected.round()} collected',
              icon: Icons.payments_outlined,
            ),
            OwnerKpiCard(
              label: 'Overdue Rent',
              value: '₹${summary.overdueRentAmount.round()}',
              subtitle: '${summary.overdueRentCount} overdue accounts',
              icon: Icons.warning_amber_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartsSection(BuildContext context, OwnerSummary summary) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;

        final trendLabels = _buildIntervalLabels(summary.periodDays);

        final trendCard = AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Complaint Volume & Resolutions'),
              const SizedBox(height: 2),
              Text(
                'Created vs resolved over the past $_periodDays days',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              RepaintBoundary(
                child: TrendLineChart(
                  createdPoints: summary.createdTrend,
                  resolvedPoints: summary.resolvedTrend,
                  labels: trendLabels,
                  height: 190,
                ),
              ),
            ],
          ),
        );

        final categorySegments = summary.categoryMix.entries
            .where((e) => e.value > 0)
            .map(
              (e) => CategorySegment(
                label: e.key.displayLabel,
                value: e.value,
                color: _categoryColor(context, e.key),
              ),
            )
            .toList();

        final categoryCard = AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Category Breakdown'),
              const SizedBox(height: 2),
              Text(
                'Issue distribution across trades',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (categorySegments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No complaint category data in this period'),
                  ),
                )
              else
                RepaintBoundary(
                  child: DonutOrStackedBar(
                    segments: categorySegments,
                    height: 190,
                  ),
                ),
            ],
          ),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: trendCard),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 2, child: categoryCard),
            ],
          );
        } else {
          return Column(
            children: [
              trendCard,
              const SizedBox(height: AppSpacing.md),
              categoryCard,
            ],
          );
        }
      },
    );
  }

  Widget _buildPropertyComparisonSection(
    BuildContext context,
    OwnerSummary summary,
  ) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Property Operational Comparison',
            trailing: Text(
              '${summary.propertySummaries.length} total',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.muted),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Select any building to view its full operational summary',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.muted),
          ),
          if (summary.propertySummaries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            RepaintBoundary(
              child: BarCompareChart(
                items: summary.propertySummaries
                    .map(
                      (p) => BarCompareItem(
                        label: p.propertyName.split(' ').first,
                        value1: p.openComplaints.toDouble(),
                        value2: p.resolvedInPeriod.toDouble(),
                        value1Label: 'Open',
                        value2Label: 'Resolved',
                      ),
                    )
                    .toList(),
                height: 160,
                series1Name: 'Open Issues',
                series2Name: 'Resolved Issues',
                series1Color: palette.warning,
                series2Color: palette.success,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 720) {
                // Wide: DataTable
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Property')),
                      DataColumn(label: Text('Occupancy')),
                      DataColumn(label: Text('Open Issues')),
                      DataColumn(label: Text('SLA %')),
                      DataColumn(label: Text('Overdue Rent')),
                      DataColumn(label: Text('Health Score')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: [
                      for (final prop in summary.propertySummaries)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                prop.propertyName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${prop.occupancyRate.toStringAsFixed(0)}% (${prop.occupiedUnits}/${prop.totalUnits})',
                              ),
                            ),
                            DataCell(Text('${prop.openComplaints}')),
                            DataCell(
                              Text(
                                prop.slaPercent != null
                                    ? '${prop.slaPercent!.toStringAsFixed(1)}%'
                                    : '—',
                              ),
                            ),
                            DataCell(
                              Text(
                                prop.overdueRentCount > 0
                                    ? '₹${prop.overdueRentAmount.round()}'
                                    : 'None',
                                style: TextStyle(
                                  color: prop.overdueRentCount > 0
                                      ? palette.warning
                                      : palette.ink,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    child: LinearProgressIndicator(
                                      value: prop.healthScore,
                                      backgroundColor: palette.raised,
                                      color: prop.healthScore > 0.7
                                          ? palette.success
                                          : palette.warning,
                                      minHeight: 5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${(prop.healthScore * 100).round()}%'),
                                ],
                              ),
                            ),
                            DataCell(
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: () => _openPropertySummary(prop),
                                child: const Text('View Summary'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              } else {
                // Phone: Stacked comparison cards
                return Column(
                  children: [
                    for (final prop in summary.propertySummaries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          onTap: () => _openPropertySummary(prop),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prop.propertyName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: palette.ink,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${prop.occupiedUnits}/${prop.totalUnits} units • ${prop.openComplaints} open • ${prop.overdueRentCount} overdue rent',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: palette.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: palette.muted),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRentCollectionSection(
    BuildContext context,
    OwnerSummary summary,
  ) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Rent Collection Status'),
          const SizedBox(height: 2),
          Text(
            'Portfolio billing and overdue management',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Billed',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: palette.muted),
                    ),
                    Text(
                      '₹${summary.totalRentDue.round()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collected',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: palette.muted),
                    ),
                    Text(
                      '₹${summary.totalRentCollected.round()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: palette.success,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Overdue',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: palette.muted),
                    ),
                    Text(
                      '₹${summary.overdueRentAmount.round()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: summary.overdueRentAmount > 0
                            ? palette.warning
                            : palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.totalRentDue > 0
                  ? summary.totalRentCollected / summary.totalRentDue
                  : 1.0,
              minHeight: 8,
              backgroundColor: palette.raised,
              color: palette.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalDetailsSection(
    BuildContext context,
    OwnerSummary summary,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;

        final recurringWidget = AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Recurring Issues'),
              const SizedBox(height: 2),
              Text(
                '${summary.recurringIssues.length} repeated unit tickets',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.palette.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (summary.recurringIssues.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No recurring unit complaints detected'),
                  ),
                )
              else
                for (final issue in summary.recurringIssues.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const RepeatIndicator(),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            issue.title,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge(label: issue.status.displayLabel),
                      ],
                    ),
                  ),
            ],
          ),
        );

        final techWidget = AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Technician Performance'),
              const SizedBox(height: 2),
              Text(
                '${summary.technicianPerformance.length} active technicians',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.palette.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (summary.technicianPerformance.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('No technician jobs recorded')),
                )
              else
                for (final tech in summary.technicianPerformance.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tech.technicianName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${tech.jobsCompleted} jobs • ${tech.repeatVisitRate.toStringAsFixed(0)}% repeat',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.palette.muted),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: recurringWidget),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: techWidget),
            ],
          );
        } else {
          return Column(
            children: [
              recurringWidget,
              const SizedBox(height: AppSpacing.md),
              techWidget,
            ],
          );
        }
      },
    );
  }

  Widget _buildPrintModeView(BuildContext context, OwnerSummary summary) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Print Summary'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy as text',
            onPressed: () => _copySummaryToClipboard(summary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GRIHSETU PORTFOLIO OPERATIONAL REPORT',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Evaluation Period: Last ${summary.periodDays} days  |  Date: ${summary.calculatedAt.toLocal()}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 32, thickness: 1.5, color: Colors.black26),
            const Text(
              'EXECUTIVE HIGHLIGHTS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            for (final h in summary.highlights)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $h', style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 24),
            const Text(
              'PORTFOLIO METRICS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.black26),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Metric',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Value',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Period Change',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Occupancy Rate'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${summary.occupancyRate.toStringAsFixed(1)}%',
                      ),
                    ),
                    const Padding(padding: EdgeInsets.all(6), child: Text('—')),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Resolved Complaints'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text('${summary.resolvedInPeriod}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(summary.resolvedDelta.formattedChange),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('SLA Compliance %'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        summary.slaPercent != null
                            ? '${summary.slaPercent!.toStringAsFixed(1)}%'
                            : 'N/A',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(summary.slaDelta.formattedChange),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Rent Collection Rate'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${summary.collectionRate.toStringAsFixed(1)}%',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(summary.collectionDelta.formattedChange),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'PROPERTY BREAKDOWN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.black26),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Property',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Occupancy',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Open Issues',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Overdue Rent',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                for (final prop in summary.propertySummaries)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(prop.propertyName),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${prop.occupiedUnits}/${prop.totalUnits}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${prop.openComplaints}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('₹${prop.overdueRentAmount.round()}'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPropertySummary(PropertySummary summary) {
    PropertySummaryScreen.open(
      context,
      propertyId: summary.propertyId,
      now: _effectiveNow,
    );
  }

  List<String> _buildIntervalLabels(int days) {
    return ['T1', 'T2', 'T3', 'T4', 'T5', 'T6'];
  }

  Color _categoryColor(BuildContext context, ComplaintCategory category) {
    final palette = context.palette;
    return switch (category) {
      ComplaintCategory.plumbing => palette.accent,
      ComplaintCategory.electrical => palette.warning,
      ComplaintCategory.structural => palette.danger,
      ComplaintCategory.appliance => palette.success,
      ComplaintCategory.cleaning => palette.accent.withValues(alpha: 0.7),
      ComplaintCategory.security => palette.ink,
      ComplaintCategory.commonArea => palette.border,
      ComplaintCategory.other => palette.muted,
    };
  }

  String _formatDuration(Duration d) {
    if (d.inHours < 24) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    return '${days}d ${hours}h';
  }
}

class OwnerKpiCard extends StatelessWidget {
  const OwnerKpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.delta,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final MetricDelta? delta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final deltaText = delta != null && delta!.hasPrevious
        ? '. Period change: ${delta!.formattedChange}'
        : '';

    return Semantics(
      label: '$label: $value. $subtitle$deltaText',
      container: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 18, color: palette.muted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (delta != null && delta!.hasPrevious) ...[
                  _DeltaIndicator(delta: delta!),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: palette.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaIndicator extends StatelessWidget {
  const _DeltaIndicator({required this.delta});

  final MetricDelta delta;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (color, icon) = switch (delta.direction) {
      ChangeDirection.better => (palette.success, Icons.arrow_upward),
      ChangeDirection.worse => (palette.danger, Icons.arrow_downward),
      ChangeDirection.neutral => (palette.muted, Icons.remove),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          delta.formattedChange,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Formats the complete summary into clean, printable plain text for sharing.
String buildOwnerSummaryPlainText(OwnerSummary summary) {
  final buffer = StringBuffer();
  buffer.writeln('=== GRIHSETU PORTFOLIO OPERATIONAL SUMMARY ===');
  buffer.writeln('Period: Last ${summary.periodDays} days');
  buffer.writeln(
    'Properties: ${summary.totalProperties}  |  Units: ${summary.totalUnits}',
  );
  buffer.writeln(
    'Occupancy: ${summary.occupancyRate.toStringAsFixed(1)}% (${summary.occupiedUnits}/${summary.totalUnits})',
  );
  buffer.writeln('');
  buffer.writeln('KEY METRICS:');
  buffer.writeln('- Open Complaints: ${summary.openComplaints}');
  buffer.writeln(
    '- Resolved in Period: ${summary.resolvedInPeriod} (${summary.resolvedDelta.formattedChange} vs prior)',
  );
  buffer.writeln(
    '- SLA Compliance: ${summary.slaPercent != null ? '${summary.slaPercent!.toStringAsFixed(1)}%' : 'N/A'}',
  );
  buffer.writeln(
    '- Rent Collection: ${summary.collectionRate.toStringAsFixed(1)}% (Overdue: ₹${summary.overdueRentAmount.round()})',
  );
  buffer.writeln('');
  buffer.writeln('EXECUTIVE HIGHLIGHTS:');
  for (final h in summary.highlights) {
    buffer.writeln('• $h');
  }
  buffer.writeln('');
  buffer.writeln('PROPERTY BREAKDOWN:');
  for (final p in summary.propertySummaries) {
    buffer.writeln(
      '• ${p.propertyName}: ${p.openComplaints} open, ${p.occupiedUnits}/${p.totalUnits} occupied, Overdue: ₹${p.overdueRentAmount.round()}',
    );
  }
  return buffer.toString();
}
