import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/user_role.dart';
import '../../core/models/complaint.dart';
import '../../repositories/assignment_repository.dart';
import '../../repositories/complaint_repository.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/audit_timeline.dart' as legacy_audit;
import '../../widgets/complaint_card.dart';
import '../../widgets/error_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/status_badge.dart';
import 'detail/activity_timeline.dart';
import 'detail/complaint_action_bar.dart';
import 'detail/complaint_detail_controller.dart';
import 'detail/complaint_detail_models.dart';

export 'detail/activity_timeline.dart';
export 'detail/complaint_action_bar.dart';
export 'detail/complaint_detail_controller.dart';
export 'detail/complaint_detail_models.dart';

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
              _buildHeader(context, state),
              const SizedBox(height: AppSpacing.md),
              _buildMetricsStrip(context, state),
              const SizedBox(height: AppSpacing.md),
              _buildProgressStepper(context, state),
              const SizedBox(height: AppSpacing.md),
              _buildSummaryCard(context, state),
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
              ComplaintStatusBadge(status: state.currentStatus),
              ComplaintPriorityBadge(priority: c.priority),
              if (state.isRepeatIssue)
                const StatusBadge(
                  label: 'Repeat issue',
                  tone: StatusBadgeTone.warning,
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.shimmer,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  c.category.displayLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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

    final techName = state.assignedTechnicianName ?? 'Unassigned';
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        techName,
                        overflow: TextOverflow.ellipsis,
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Calling technician +91 98111 22334...',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
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
              value: _formatDate(state.scheduledVisitDate),
            ),

          // Created
          _SummaryRow(label: 'Created', value: _formatDate(c.createdAt)),

          // Last updated
          _SummaryRow(
            label: 'Last updated',
            value: _formatDate(state.lastUpdated),
          ),

          // Expected resolution
          if (state.expectedResolution != null)
            _SummaryRow(
              label: 'Expected resolution',
              value: _formatDate(state.expectedResolution),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // METRICS STRIP
  // -------------------------------------------------------------
  Widget _buildMetricsStrip(BuildContext context, ComplaintDetailState state) {
    final palette = context.palette;

    final firstResponse = state.timeToFirstResponse != null
        ? _formatDuration(state.timeToFirstResponse!)
        : 'Pending';

    final durationLabel = state.timeToResolve != null
        ? 'Resolution'
        : 'Time open';
    final durationValue = _formatDuration(
      state.timeToResolve ?? state.timeOpen ?? Duration.zero,
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

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '< 1m';
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
