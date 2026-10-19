import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/user_role.dart';
import '../../core/enums/complaint_status.dart';
import '../../core/models/complaint.dart';
import '../../repositories/assignment_repository.dart';
import '../../repositories/complaint_repository.dart';
import '../../theme/app_palette.dart';
import '../../utils/action_feedback.dart';
import '../../utils/date_time_formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/audit_timeline.dart' as legacy_audit;
import '../../widgets/complaint_card.dart';
import '../../widgets/complaint_chips.dart';
import '../../widgets/error_state.dart';
import '../../widgets/empty_state.dart';
import '../../utils/visit_history.dart' as vh;
import '../../widgets/repeat_indicator.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/visit_summary_widgets.dart';
import 'detail/activity_timeline.dart';
import 'detail/complaint_action_bar.dart';
import 'detail/complaint_detail_controller.dart';
import 'detail/complaint_detail_models.dart';
import 'detail/visit_history_section.dart';

export 'detail/activity_timeline.dart';
export 'detail/complaint_action_bar.dart';
export 'detail/complaint_detail_controller.dart';
export 'detail/complaint_detail_models.dart';
export 'detail/visit_history_section.dart';

/// Single source of truth ComplaintDetailScreen.
///
/// ONE screen, ONE state holder ([ComplaintDetailController]), and ONE audit event list.
/// Tenant, technician, staff, and owner all see the same facts; only actions differ by role.
class ComplaintDetailScreen extends StatefulWidget {
  ComplaintDetailScreen({
    super.key,
    String? complaintId,
    this.complaint,
    this.propertyName,
    this.unitNumber,
    this.userRole = UserRole.staff,
    this.assignmentRepository,
    this.complaintRepository,
    this.initialTechnician,
    this.initialAuditEvents,
    this.controller,
    this.referenceNow,
    this.currentUserId,
    this.currentUserName,
  }) : complaintId = complaintId ?? (complaint != null ? complaint.id : '');

  final String complaintId;
  final Complaint? complaint;
  final String? propertyName;
  final String? unitNumber;
  final UserRole userRole;
  final AssignmentRepository? assignmentRepository;
  final ComplaintRepository? complaintRepository;
  final TechnicianOption? initialTechnician;
  final List<legacy_audit.AuditEvent>? initialAuditEvents;
  final ComplaintDetailController? controller;
  final DateTime? referenceNow;
  final String? currentUserId;
  final String? currentUserName;

  /// Canonical navigation helper to open a complaint detail view.
  static Future<void> open(
    BuildContext context,
    String id, {
    Complaint? complaint,
    String? propertyName,
    String? unitNumber,
    UserRole userRole = UserRole.staff,
    ComplaintRepository? complaintRepository,
    AssignmentRepository? assignmentRepository,
    DateTime? referenceNow,
    String? currentUserId,
    String? currentUserName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintDetailScreen(
          complaintId: id,
          complaint: complaint,
          propertyName: propertyName,
          unitNumber: unitNumber,
          userRole: userRole,
          complaintRepository: complaintRepository,
          assignmentRepository: assignmentRepository,
          referenceNow: referenceNow,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
        ),
      ),
    );
  }

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late ComplaintDetailController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final repo =
          widget.complaintRepository ??
          (widget.complaint != null
              ? InMemoryComplaintRepository(
                  initialComplaints: [widget.complaint!],
                )
              : InMemoryComplaintRepository());

      final initialEvents = widget.initialAuditEvents?.map((e) {
        return ActivityEvent(
          id: 'initial_${e.timestamp.millisecondsSinceEpoch}',
          complaintId: widget.complaintId,
          type: ActivityEventType.created,
          actorId: 'usr_init',
          actorName: e.actor,
          actorRole: e.role,
          timestamp: e.timestamp,
          note: e.note,
        );
      }).toList();

      _controller = ComplaintDetailController(
        complaintId: widget.complaintId,
        repository: repo,
        initialComplaint: widget.complaint,
        initialEvents: initialEvents,
        currentUserRole: widget.userRole.name,
        currentUserId: widget.currentUserId ?? 'usr_001',
        currentUserName: widget.currentUserName ?? 'Riya Sharma',
        referenceNow: widget.referenceNow,
      );
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(ComplaintDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.complaintId != oldWidget.complaintId ||
        widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return Scaffold(
          backgroundColor: palette.canvas,
          appBar: AppBar(
            title: const Text('Complaint details'),
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          bottomNavigationBar: state.hasData
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = MediaQuery.sizeOf(context).width >= 900;
                    if (isWide) return const SizedBox.shrink();
                    return ComplaintActionBar(
                      controller: _controller,
                      userRole: widget.userRole,
                      isColumn: false,
                      assignmentRepository: widget.assignmentRepository,
                    );
                  },
                )
              : null,
          body: SafeArea(child: _buildBody(context, state)),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ComplaintDetailState state) {
    if (state.isLoading) {
      return _buildLoadingSkeleton(context);
    }
    if (state.isNotFound) {
      return _buildNotFoundState(context);
    }
    if (state.isError) {
      return Center(
        child: ErrorState(
          message:
              state.errorMessage ??
              'Something went wrong while retrieving the record.',
          onRetry: () => _controller.retry(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return _buildWideLayout(context, state);
        }
        return _buildNarrowLayout(context, state);
      },
    );
  }

  // -------------------------------------------------------------
  // NARROW LAYOUT (<900px)
  // -------------------------------------------------------------
  Widget _buildNarrowLayout(BuildContext context, ComplaintDetailState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.currentStatus == ComplaintStatus.waitingForParts) ...[
                _buildWaitingForPartsBanner(context, state),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildHeader(context, state),
              const SizedBox(height: AppSpacing.md),
              _buildMetricsStrip(context, state),
              const SizedBox(height: AppSpacing.md),
              _buildProgressStepper(context, state),
              const SizedBox(height: AppSpacing.md),
              _buildSummaryCard(context, state),
              const SizedBox(height: AppSpacing.md),
              VisitSummaryCard(summary: state.visitSummary),
              const SizedBox(height: AppSpacing.md),
              _buildVisitHistoryCard(context, state),
              const SizedBox(height: AppSpacing.md),
              // Activity timeline centerpiece
              _buildTimelineSection(context, state),
              const SizedBox(height: AppSpacing.md),
              _buildMetaDetailsCard(context, state),
              const SizedBox(height: AppSpacing.md),
              _buildPlaceholderNotice(context),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // WIDE LAYOUT (>=900px)
  // -------------------------------------------------------------
  Widget _buildWideLayout(BuildContext context, ComplaintDetailState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.currentStatus == ComplaintStatus.waitingForParts) ...[
                _buildWaitingForPartsBanner(context, state),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildHeader(context, state),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Centerpiece Timeline (~60%)
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTimelineSection(context, state),
                        const SizedBox(height: AppSpacing.md),
                        _buildPlaceholderNotice(context),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  // Right Column: Summary, Metrics, Stepper, Actions (~40%)
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryCard(context, state),
                        const SizedBox(height: AppSpacing.md),
                        VisitSummaryCard(summary: state.visitSummary),
                        const SizedBox(height: AppSpacing.md),
                        _buildVisitHistoryCard(context, state),
                        const SizedBox(height: AppSpacing.md),
                        _buildMetricsStrip(context, state),
                        const SizedBox(height: AppSpacing.md),
                        _buildProgressStepper(context, state),
                        const SizedBox(height: AppSpacing.md),
                        ComplaintActionBar(
                          controller: _controller,
                          userRole: widget.userRole,
                          isColumn: true,
                          assignmentRepository: widget.assignmentRepository,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildMetaDetailsCard(context, state),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingForPartsBanner(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final date = state.expectedPartsDate;
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
    final dateStr = date != null
        ? '${date.day} ${months[date.month - 1]}'
        : 'pending';

    return Container(
      key: const Key('waiting_for_parts_banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_outlined, color: palette.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Waiting for parts: expected $dateStr',
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------
  Widget _buildHeader(BuildContext context, ComplaintDetailState state) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final c = state.complaint!;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ComplaintStatusChip(status: state.currentStatus),
              if (state.currentStatus == ComplaintStatus.reopened ||
                  c.status == ComplaintStatus.reopened ||
                  c.reopenCount > 0)
                const StatusBadge(
                  key: Key('reopened_header_badge'),
                  label: 'Reopened',
                  tone: StatusBadgeTone.warning,
                ),
              ComplaintPriorityChip(priority: c.priority),
              if (state.isRepeatIssue)
                RepeatIndicator.recurring(
                  count: state.numberOfVisits >= 2 ? state.numberOfVisits : 2,
                ),
              ComplaintCategoryChip(category: c.category),
              Text(
                '#${c.id.isEmpty ? "Pending" : c.id}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Text(
            c.title.isEmpty ? 'Untitled complaint' : c.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'Fraunces',
              color: palette.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Row(
            children: [
              Icon(Icons.apartment_outlined, size: 16, color: palette.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_displayPropertyName(c)} · Unit ${_displayUnitNumber(c)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SUMMARY CARD
  // -------------------------------------------------------------
  Widget _buildSummaryCard(BuildContext context, ComplaintDetailState state) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final c = state.complaint!;

    final techName =
        state.assignedTechnicianName ?? 'No technician currently assigned.';
    final hasTech = state.assignedTechnicianId != null;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Summary'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            c.description.isEmpty ? 'No description provided.' : c.description,
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.ink),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: palette.border, height: 1),
          const SizedBox(height: AppSpacing.sm),

          // Assigned technician row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Technician',
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          techName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: palette.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (hasTech) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            ActionFeedback.showInfo(
                              context,
                              'Calling technician +91 98111 22334...',
                            );
                          },
                          child: Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tenant row
          _SummaryRow(
            label: 'Tenant',
            value: c.tenantId.isNotEmpty ? c.tenantId : 'Resident',
          ),

          // Scheduled visit
          if (state.scheduledVisitDate != null)
            _SummaryRow(
              label: 'Scheduled visit',
              value: formatDate(state.scheduledVisitDate),
            ),

          // Created
          _SummaryRow(label: 'Created', value: formatDate(c.createdAt)),

          // Last updated
          _SummaryRow(
            label: 'Last updated',
            value: formatDate(state.lastUpdated),
          ),

          // Expected resolution
          if (state.expectedResolution != null)
            _SummaryRow(
              label: 'Expected resolution',
              value: formatDate(state.expectedResolution),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitHistoryCard(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    final complaint = state.complaint;
    var visits = vh.visitsFromEvents(state.events);
    if (state.visits.length > visits.length) {
      visits = vh.visitsFromEvents(state.visits);
    }
    if ((complaint?.visitCount ?? 0) > visits.length) {
      final vCount = complaint!.visitCount;
      visits = List.generate(
        vCount,
        (i) => vh.VisitRecord(
          date: complaint.createdAt ?? DateTime.now(),
          technician: complaint.currentTechnicianId ?? 'Technician',
          outcome:
              i == vCount - 1 && complaint.status == ComplaintStatus.resolved
              ? 'resolved'
              : 'needs another visit',
          visitNumber: i + 1,
        ),
      );
    }
    final info = complaint != null
        ? vh.repeatInfo(complaint, const <Complaint>[])
        : null;

    return VisitHistorySection(visits: visits, repeatInfo: info);
  }

  // -------------------------------------------------------------
  // METRICS STRIP
  // -------------------------------------------------------------
  Widget _buildMetricsStrip(BuildContext context, ComplaintDetailState state) {
    final palette = context.palette;

    final firstResponse = state.timeToFirstResponse != null
        ? formatElapsedDuration(state.timeToFirstResponse!)
        : 'Pending';

    final durationLabel = state.timeToResolve != null
        ? 'Resolution'
        : 'Time open';
    final durationValue = formatElapsedDuration(
      state.timeToResolve ?? state.timeOpen,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _MetricBox(
              label: 'First response',
              value: firstResponse,
              icon: Icons.timer_outlined,
            ),
            _MetricBox(
              label: 'Visits',
              value: '${state.numberOfVisits}',
              icon: Icons.location_on_outlined,
            ),
            _MetricBox(
              label: durationLabel,
              value: durationValue,
              icon: Icons.schedule_outlined,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SLA Status',
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: state.slaStatus.label,
                    tone: state.slaStatus == SlaStatus.onTrack
                        ? StatusBadgeTone.success
                        : (state.slaStatus == SlaStatus.atRisk
                              ? StatusBadgeTone.warning
                              : StatusBadgeTone.danger),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // PROGRESS STEPPER
  // -------------------------------------------------------------
  Widget _buildProgressStepper(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    final palette = context.palette;
    final steps = ProgressStep.values;
    final completed = state.completedSteps;
    final current = state.currentStep;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.linear_scale_outlined,
                size: 16,
                color: palette.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Workflow Progress',
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  _StepNode(
                    step: steps[i],
                    isCompleted: completed.contains(steps[i]),
                    isCurrent: steps[i] == current,
                    isLast: i == steps.length - 1,
                  ),
                  if (i < steps.length - 1)
                    Container(
                      width: 24,
                      height: 2,
                      color: completed.contains(steps[i])
                          ? palette.accent
                          : palette.border,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TIMELINE CENTERPIECE
  // -------------------------------------------------------------
  Widget _buildTimelineSection(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    // Keep the legacy constructor contract working for callers that provide
    // prebuilt AuditEvent objects. Live Firestore-backed screens use the
    // richer ActivityTimeline below.
    if (widget.initialAuditEvents != null) {
      if (widget.initialAuditEvents!.isEmpty) {
        return AppCard(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            title: 'No activity recorded yet',
            message:
                'Timeline events will appear here as the complaint progresses.',
            icon: Icons.history_toggle_off_outlined,
          ),
        );
      }
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: legacy_audit.AuditTimeline(events: widget.initialAuditEvents!),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Audit timeline'),
          const SizedBox(height: AppSpacing.md),
          ActivityTimeline(
            events: state.events,
            userRole: widget.userRole,
            previousVisits: state.previousVisits,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // RECORD DETAILS META
  // -------------------------------------------------------------
  Widget _buildMetaDetailsCard(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    final c = state.complaint!;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Record details'),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            label: 'Complaint ID',
            value: c.id.isEmpty ? 'Pending ID' : c.id,
          ),
          _SummaryRow(label: 'Category', value: c.category.displayLabel),
          _SummaryRow(label: 'Status', value: state.currentStatus.displayLabel),
          _SummaryRow(label: 'Priority', value: c.priority.displayLabel),
          _SummaryRow(label: 'Property ID', value: c.propertyId),
          _SummaryRow(label: 'Unit ID', value: c.unitId),
          if (c.tenantId.isNotEmpty)
            _SummaryRow(label: 'Tenant ID', value: c.tenantId),
          _SummaryRow(label: 'Visit count', value: '${state.numberOfVisits}'),
          if (c.reopenCount > 0)
            _SummaryRow(label: 'Reopen count', value: '${c.reopenCount}'),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // COMPATIBILITY NOTICE
  // -------------------------------------------------------------
  Widget _buildPlaceholderNotice(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: palette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complaint workflow connected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use the actions panel to assign technicians, record visits, resolve complaints, and review the audit timeline.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STATES
  // -------------------------------------------------------------
  Widget _buildLoadingSkeleton(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBox(
                width: double.infinity,
                height: 160,
                borderRadius: 12,
              ),
              const SizedBox(height: AppSpacing.md),
              SkeletonBox(width: double.infinity, height: 80, borderRadius: 12),
              const SizedBox(height: AppSpacing.md),
              SkeletonBox(
                width: double.infinity,
                height: 120,
                borderRadius: 12,
              ),
              const SizedBox(height: AppSpacing.md),
              SkeletonBox(
                width: double.infinity,
                height: 320,
                borderRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotFoundState(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 56, color: palette.muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Complaint not found',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontFamily: 'Fraunces', color: palette.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The requested complaint record (#${widget.complaintId}) could not be located.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------------
  String _displayPropertyName(Complaint c) {
    final p = widget.propertyName?.trim();
    if (p != null && p.isNotEmpty) return p;
    if (c.propertyId.trim().isNotEmpty) return c.propertyId;
    return 'Unknown property';
  }

  String _displayUnitNumber(Complaint c) {
    final u = widget.unitNumber?.trim();
    if (u != null && u.isNotEmpty) return u;
    if (c.unitId.trim().isNotEmpty) return c.unitId;
    return 'Unknown unit';
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: palette.accent),
          const SizedBox(width: AppSpacing.xs + 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: palette.muted, fontSize: 11)),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  final ProgressStep step;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isCompleted ? palette.accent : palette.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isCurrent ? palette.accent : palette.border,
            ),
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? Icon(Icons.check, size: 14, color: palette.surface)
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isCurrent ? palette.accent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent || isCompleted
                ? FontWeight.bold
                : FontWeight.w500,
            color: isCurrent || isCompleted ? palette.ink : palette.muted,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
