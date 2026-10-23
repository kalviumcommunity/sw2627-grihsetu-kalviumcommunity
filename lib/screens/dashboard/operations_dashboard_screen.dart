import 'package:flutter/material.dart';

import '../../app/user_role.dart' as app_role;
import '../../core/enums/complaint_audit_event_type.dart';
import '../../core/enums/complaint_status.dart';
import '../../core/enums/rent_status.dart';
import '../../core/models/complaint.dart';
import '../../core/models/complaint_audit_event.dart';
import '../../core/models/property.dart';
import '../../core/models/user.dart';
import '../../repositories/assignment_repository.dart';
import '../../repositories/complaint_repository.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/property_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../services/auth_service.dart';
import '../../services/errors/app_failure.dart';
import '../../services/errors/firebase_error_mapper.dart';
import '../../theme/app_palette.dart';
import '../../utils/attention_rules.dart';
import '../../utils/complaint_query.dart';
import '../../utils/dashboard_metrics.dart';
import '../../utils/visit_history.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/error_state.dart';
import '../../widgets/skeleton_box.dart';
import '../complaints/complaint_detail_screen.dart';
import '../complaints/search/complaint_search_screen.dart';
import '../property/unit_picker_screen.dart';
import '../rent/rent_list_screen.dart';
import 'attention_card.dart';

/// The operations dashboard answering "what needs a human right now?"
class OperationsDashboardScreen extends StatefulWidget {
  const OperationsDashboardScreen({
    super.key,
    this.dashboardRepository,
    this.complaintRepository,
    this.propertyRepository,
    this.rentRepository,
    this.authService,
    this.profile,
    this.readOnly = false,
    this.referenceNow,
  });

  final DashboardRepository? dashboardRepository;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;
  final RentRepository? rentRepository;
  final AuthService? authService;
  final AppUser? profile;
  final bool readOnly;
  final DateTime? referenceNow;

  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  late final DashboardRepository _repository =
      widget.dashboardRepository ?? InMemoryDashboardRepository();

  bool _isLoading = true;
  AppFailure? _failure;
  DashboardSnapshot? _snapshot;
  bool _showAllAttention = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _now => widget.referenceNow ?? DateTime.now();

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final snapshot = await _repository.load(now: _now);
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        final failure = FirebaseErrorMapper.map(e, st);
        setState(() {
          _failure = failure;
          _isLoading = false;
        });
      }
    }
  }

  void _onAttentionItemTapped(AttentionItem item) {
    if (item.targetFilter != null) {
      ComplaintSearchScreen.open(
        context,
        item.targetFilter!,
        repository: widget.complaintRepository ?? InMemoryComplaintRepository(),
        propertyRepository:
            widget.propertyRepository ?? InMemoryPropertyRepository(),
        authService: widget.authService,
        profile: widget.profile,
      );
    } else if (item.targetRoute != null && item.targetRoute!.contains('rent')) {
      final isOverdue = item.targetRoute!.contains('overdue');
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RentListScreen(
            repository: widget.rentRepository ?? InMemoryRentRepository(),
            readOnly: widget.readOnly,
            initialStatusFilter: isOverdue
                ? RentStatus.overdue
                : RentStatus.promised,
            showAppBar: true,
            now: _now,
          ),
        ),
      );
    }
  }

  void _onTechnicianTapped(TechnicianOption tech) {
    ComplaintSearchScreen.open(
      context,
      ComplaintFilter(technicianId: tech.id),
      repository: widget.complaintRepository ?? InMemoryComplaintRepository(),
      propertyRepository:
          widget.propertyRepository ?? InMemoryPropertyRepository(),
      authService: widget.authService,
      profile: widget.profile,
    );
  }

  void _onPropertyTapped(Property property) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnitPickerScreen(
          property: property,
          repository: widget.propertyRepository ?? InMemoryPropertyRepository(),
        ),
      ),
    );
  }

  void _onEventTapped(ComplaintAuditEvent event) {
    ComplaintDetailScreen.open(
      context,
      event.complaintId,
      complaintRepository: widget.complaintRepository,
      userRole: widget.readOnly
          ? app_role.UserRole.owner
          : app_role.UserRole.staff,
      referenceNow: _now,
      currentUserId: widget.profile?.id,
      currentUserName: widget.profile?.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_isLoading && _snapshot == null) {
      return Scaffold(
        backgroundColor: palette.canvas,
        body: const SafeArea(child: _DashboardSkeleton()),
      );
    }

    if (_failure != null && _snapshot == null) {
      return Scaffold(
        backgroundColor: palette.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ErrorState(failure: _failure, onRetry: _load),
            ),
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final attentionAnalysis = analyzeAttention(
      complaints: snapshot.complaints,
      rentRecords: snapshot.rentRecords,
      now: _now,
    );
    final todayMetrics = calculateTodayMetrics(
      complaints: snapshot.complaints,
      now: _now,
    );

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: palette.accent,
          backgroundColor: palette.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_failure != null) ...[
                  ErrorBanner(
                    failure: _failure,
                    onDismiss: () => setState(() => _failure = null),
                    onRetry: _failure!.retryable ? _load : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                // 1. Greeting header
                _GreetingHeader(
                  now: _now,
                  analysis: attentionAnalysis,
                  readOnly: widget.readOnly,
                ),
                const SizedBox(height: AppSpacing.md),

                // Responsive layout: 1 col on mobile; 2 cols on >=900px
                if (!isDesktop) ...[
                  // Hero: Attention list
                  _AttentionSection(
                    analysis: attentionAnalysis,
                    showAll: _showAllAttention,
                    onToggleShowAll: () =>
                        setState(() => _showAllAttention = !_showAllAttention),
                    onItemTap: _onAttentionItemTapped,
                    lastCheckedTime: snapshot.lastUpdated,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Today strip below attention list
                  _TodayStrip(metrics: todayMetrics),
                  const SizedBox(height: AppSpacing.lg),

                  // Technician workload
                  _TechnicianWorkloadSection(
                    technicians: snapshot.technicians,
                    onTapTechnician: _onTechnicianTapped,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Properties at a glance
                  _PropertiesAtAGlanceSection(
                    properties: snapshot.properties,
                    complaints: snapshot.complaints,
                    onTapProperty: _onPropertyTapped,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Recent activity
                  _RecentActivitySection(
                    events: snapshot.events,
                    onTapEvent: _onEventTapped,
                  ),
                ] else ...[
                  // Desktop 2-column layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left 60% Hero: Attention list
                      Expanded(
                        flex: 3,
                        child: _AttentionSection(
                          analysis: attentionAnalysis,
                          showAll: _showAllAttention,
                          onToggleShowAll: () => setState(
                            () => _showAllAttention = !_showAllAttention,
                          ),
                          onItemTap: _onAttentionItemTapped,
                          lastCheckedTime: snapshot.lastUpdated,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),

                      // Right 40%: Today strip, Workload, Properties
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TodayStrip(metrics: todayMetrics),
                            const SizedBox(height: AppSpacing.lg),
                            _TechnicianWorkloadSection(
                              technicians: snapshot.technicians,
                              onTapTechnician: _onTechnicianTapped,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _PropertiesAtAGlanceSection(
                              properties: snapshot.properties,
                              complaints: snapshot.complaints,
                              onTapProperty: _onPropertyTapped,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Full width activity at the bottom
                  _RecentActivitySection(
                    events: snapshot.events,
                    onTapEvent: _onEventTapped,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GREETING HEADER
// ---------------------------------------------------------------------------
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.now,
    required this.analysis,
    required this.readOnly,
  });

  final DateTime now;
  final AttentionAnalysis analysis;
  final bool readOnly;

  String _formatDate(DateTime dt) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = analysis.items.length;
    final summarySentence = count == 0
        ? 'All clear. Nothing needs attention.'
        : '$count ${count == 1 ? "thing needs" : "things need"} attention today.';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(now).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.muted,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                summarySentence,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (readOnly) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.raised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Read-only',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: palette.muted),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: analysis.healthScore >= 80
                      ? palette.success.withValues(alpha: 0.15)
                      : palette.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: analysis.healthScore >= 80
                        ? palette.success.withValues(alpha: 0.4)
                        : palette.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Health Score: ${analysis.healthScore}/100',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: analysis.healthScore >= 80
                        ? palette.success
                        : palette.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ATTENTION SECTION (HERO)
// ---------------------------------------------------------------------------
class _AttentionSection extends StatelessWidget {
  const _AttentionSection({
    required this.analysis,
    required this.showAll,
    required this.onToggleShowAll,
    required this.onItemTap,
    required this.lastCheckedTime,
  });

  final AttentionAnalysis analysis;
  final bool showAll;
  final VoidCallback onToggleShowAll;
  final ValueChanged<AttentionItem> onItemTap;
  final DateTime lastCheckedTime;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Needs Attention',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
                  ),
                ),
                if (!analysis.isAllClear) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${analysis.items.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (analysis.items.length > 6)
              TextButton(
                onPressed: onToggleShowAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  showAll
                      ? 'Show top 6'
                      : 'Show all (${analysis.items.length})',
                  style: TextStyle(color: palette.accent),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // All clear state or attention list
        if (analysis.isAllClear) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: palette.success,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All clear',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Nothing needs immediate human intervention.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Last checked ${_formatTime(lastCheckedTime)}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
        ] else ...[
          // Attention list items (top 6 or all)
          ...() {
            final visibleItems = showAll
                ? analysis.items
                : analysis.items.take(6).toList();
            return visibleItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AttentionCard(item: item, onTap: () => onItemTap(item)),
              );
            });
          }(),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TODAY STRIP
// ---------------------------------------------------------------------------
class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.metrics});

  final TodayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          _StatTile(metric: metrics.open),
          _StatTile(metric: metrics.resolvedToday),
          _StatTile(metric: metrics.avgFirstResponse),
          _StatTile(metric: metrics.slaPercent),
        ];

        // 2x2 grid if constrained, 4 columns if wide enough
        final isCompact = constraints.maxWidth < 480;

        if (isCompact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: tiles[0]),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: tiles[1]),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(child: tiles[2]),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: tiles[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.metric});

  final StatMetric metric;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.muted, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                metric.value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    metric.change >= 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 12,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${metric.change.abs().toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: palette.muted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TECHNICIAN WORKLOAD
// ---------------------------------------------------------------------------
class _TechnicianWorkloadSection extends StatelessWidget {
  const _TechnicianWorkloadSection({
    required this.technicians,
    required this.onTapTechnician,
  });

  final List<TechnicianOption> technicians;
  final ValueChanged<TechnicianOption> onTapTechnician;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Technician Workload',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final tech in technicians) ...[
            Semantics(
              label:
                  '${tech.name}, ${tech.todayJobCount} jobs today, ${tech.availability.label}',
              button: true,
              child: InkWell(
                onTap: () => onTapTechnician(tech),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: palette.accentSoft,
                        child: Text(
                          tech.initials,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: palette.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tech.name,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: palette.ink,
                                      ),
                                ),
                                Text(
                                  '${tech.todayJobCount} jobs',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: palette.muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (tech.todayJobCount / 5.0).clamp(
                                  0.0,
                                  1.0,
                                ),
                                minHeight: 4,
                                backgroundColor: palette.raised,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  tech.todayJobCount >= 4
                                      ? palette.warning
                                      : palette.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.raised,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          tech.availability.label,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontSize: 10, color: palette.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PROPERTIES AT A GLANCE
// ---------------------------------------------------------------------------
class _PropertiesAtAGlanceSection extends StatelessWidget {
  const _PropertiesAtAGlanceSection({
    required this.properties,
    required this.complaints,
    required this.onTapProperty,
  });

  final List<Property> properties;
  final List<Complaint> complaints;
  final ValueChanged<Property> onTapProperty;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Properties at a Glance',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final property in properties) ...[
            () {
              final propComplaints = complaints
                  .where((c) => c.propertyId == property.id)
                  .toList();
              final openCount = propComplaints
                  .where(
                    (c) =>
                        c.status != ComplaintStatus.closed &&
                        c.status != ComplaintStatus.cancelled,
                  )
                  .length;
              final repeatCount = propComplaints
                  .where((c) => repeatInfo(c, complaints).recurringIssue)
                  .length;
              final healthRatio = propComplaints.isEmpty
                  ? 1.0
                  : (1.0 - (openCount / 10.0)).clamp(0.2, 1.0);

              return Semantics(
                label:
                    '${property.name}, $openCount open complaints, $repeatCount recurring',
                button: true,
                child: InkWell(
                  onTap: () => onTapProperty(property),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                property.name,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: palette.ink,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$openCount open • $repeatCount repeat',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: palette.muted),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: palette.muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: healthRatio,
                            minHeight: 3,
                            backgroundColor: palette.raised,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              healthRatio > 0.7
                                  ? palette.accent
                                  : palette.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RECENT ACTIVITY
// ---------------------------------------------------------------------------
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.events,
    required this.onTapEvent,
  });

  final List<ComplaintAuditEvent> events;
  final ValueChanged<ComplaintAuditEvent> onTapEvent;

  String _formatEventTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _eventActionLabel(ComplaintAuditEventType type) {
    return switch (type) {
      ComplaintAuditEventType.complaintCreated => 'Complaint created',
      ComplaintAuditEventType.technicianAssigned => 'Technician assigned',
      ComplaintAuditEventType.technicianReassigned => 'Technician reassigned',
      ComplaintAuditEventType.complaintStatusChanged => 'Status changed',
      ComplaintAuditEventType.complaintResolved => 'Complaint resolved',
      ComplaintAuditEventType.complaintReopened => 'Complaint reopened',
      ComplaintAuditEventType.complaintClosed => 'Complaint closed',
      ComplaintAuditEventType.complaintCancelled => 'Complaint cancelled',
      ComplaintAuditEventType.complaintWaitingForParts => 'Waiting for parts',
      ComplaintAuditEventType.technicianAccepted => 'Technician accepted',
      ComplaintAuditEventType.technicianArrived => 'Technician arrived',
      ComplaintAuditEventType.repairStarted => 'Repair started',
      ComplaintAuditEventType.visitCompleted => 'Visit completed',
      _ => type.value.replaceAll('_', ' ').toLowerCase(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final event in events.take(8)) ...[
            Semantics(
              label:
                  '${event.actorId}: ${_eventActionLabel(event.eventType)} for ${event.complaintId}',
              button: true,
              child: InkWell(
                onTap: () => onTapEvent(event),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: palette.raised,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.history,
                          size: 16,
                          color: palette.muted,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_eventActionLabel(event.eventType)} (${event.complaintId})',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: palette.ink,
                                  ),
                            ),
                            Text(
                              'Actor: ${event.actorId}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: palette.muted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatEventTime(event.timestamp),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.muted),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: palette.muted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SKELETON
// ---------------------------------------------------------------------------
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const SkeletonBox(width: double.infinity, height: 60),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(width: double.infinity, height: 64),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(width: double.infinity, height: 64),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(width: double.infinity, height: 64),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 60)),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: SkeletonBox(height: 60)),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: SkeletonBox(height: 60)),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: SkeletonBox(height: 60)),
            ],
          ),
        ],
      ),
    );
  }
}
