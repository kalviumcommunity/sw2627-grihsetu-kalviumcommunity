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
import '../../widgets/empty_state.dart';
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
    _complaint = widget.complaint;
    _repository = widget.assignmentRepository ?? InMemoryAssignmentRepository();
    _assignedTechnician =
        widget.initialTechnician ?? _defaultInitialTechnician();
    _initAuditEvents();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  TechnicianOption? _defaultInitialTechnician() {
    if (_complaint.currentTechnicianId == null) return null;
    // Map sample technician for fixture compatibility
    if (_complaint.currentTechnicianId == 'usr_002') {
      return const TechnicianOption(
        id: 'usr_002',
        name: 'Aman Verma',
        phone: '+91 98111 22334',
        specialties: [
          ComplaintCategory.electrical,
          ComplaintCategory.appliance,
        ],
        todayJobCount: 2,
        availability: TechnicianAvailability.available,
      );
    }
    return TechnicianOption(
      id: _complaint.currentTechnicianId!,
      name: 'Assigned Technician',
      phone: '+91 98000 00000',
      specialties: [_complaint.category],
      todayJobCount: 1,
      availability: TechnicianAvailability.available,
    );
  }

  void _initAuditEvents() {
    if (widget.initialAuditEvents != null) {
      _auditEvents = List.of(widget.initialAuditEvents!);
      return;
    }

    final createdAt = _complaint.createdAt ?? DateTime(2026, 10, 1, 10, 0);
    final events = <AuditEvent>[
      AuditEvent(
        title: 'Complaint created',
        actor: 'Priya Patel',
        role: 'Tenant',
        timestamp: createdAt,
        note: 'Reported via GrihSetu tenant portal.',
        tone: AuditTone.neutral,
      ),
    ];

    if (_complaint.firstAssignedAt != null && _assignedTechnician != null) {
      events.add(
        AuditEvent(
          title: 'Technician assigned',
          actor: 'Riya Sharma',
          role: 'Staff Operations',
          timestamp: _complaint.firstAssignedAt!,
          note: 'Assigned to ${_assignedTechnician!.name}.',
          tone: AuditTone.accent,
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
    final theme = Theme.of(context);
    final isStaff = widget.userRole == UserRole.staff;

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
                            ComplaintStatusBadge(status: _complaint.status),
                            ComplaintPriorityBadge(
                              priority: _complaint.priority,
                            ),
                            if (_complaint.isRepeatVisit)
                              const StatusBadge(
                                label: 'Repeat visit',
                                tone: StatusBadgeTone.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _complaint.title.isEmpty
                              ? 'Untitled complaint'
                              : _complaint.title,
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
                            Expanded(
                              child: Text(
                                'Created ${_formatDate(_complaint.createdAt)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Assigned Technician Card
                  _buildTechnicianSection(context, isStaff),
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
                          _complaint.description.isEmpty
                              ? 'No description provided.'
                              : _complaint.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Audit Timeline Card
                  _buildAuditTimelineSection(context),
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
                          value: _complaint.id.isEmpty
                              ? 'Pending ID'
                              : _complaint.id,
                        ),
                        _DetailRow(
                          label: 'Category',
                          value: _complaint.category.displayLabel,
                        ),
                        _DetailRow(
                          label: 'Status',
                          value: _complaint.status.displayLabel,
                        ),
                        _DetailRow(
                          label: 'Priority',
                          value: _complaint.priority.displayLabel,
                        ),
                        _DetailRow(
                          label: 'Property ID',
                          value: _complaint.propertyId,
                        ),
                        _DetailRow(label: 'Unit ID', value: _complaint.unitId),
                        if (_complaint.tenantId.isNotEmpty)
                          _DetailRow(
                            label: 'Tenant ID',
                            value: _complaint.tenantId,
                          ),
                        _DetailRow(
                          label: 'Visit count',
                          value: '${_complaint.visitCount}',
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

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Assigned technician',
            trailing: isStaff && isAssigned
                ? _buildActionButton(
                    context,
                    isReassign: true,
                    isTerminal: isTerminal,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (isAssigned) ...[
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCurrent ? palette.accent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tech.initials,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tech.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final s in tech.specialties)
                            Text(
                              s.displayLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.muted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tech.phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  'No technician currently assigned.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                  ),
                ),
                if (isStaff)
                  _buildActionButton(
                    context,
                    isReassign: false,
                    isTerminal: isTerminal,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required bool isReassign,
    required bool isTerminal,
  }) {
    final tooltipMsg = isTerminal
        ? 'Cannot ${isReassign ? "reassign" : "assign"} technician when complaint is ${_complaint.status.displayLabel.toLowerCase()}.'
        : null;

    final button = isReassign
        ? OutlinedButton.icon(
            key: const Key('reassign_technician_button'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(120, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: isTerminal
                ? null
                : () => _handleOpenAssignmentSheet(isReassign: true),
            icon: const Icon(Icons.sync_alt, size: 16),
            label: const Text('Reassign'),
          )
        : FilledButton.icon(
            key: const Key('assign_technician_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(140, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: isTerminal
                ? null
                : () => _handleOpenAssignmentSheet(isReassign: false),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Assign technician'),
          );

    if (tooltipMsg != null) {
      return Tooltip(message: tooltipMsg, child: button);
    }
    return button;
  }

  Widget _buildAuditTimelineSection(BuildContext context) {
    final palette = context.palette;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _highlightAudit
            ? palette.accentSoft.withValues(alpha: 0.6)
            : palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _highlightAudit ? palette.accent : palette.border,
          width: _highlightAudit ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Audit timeline',
            trailing: _highlightAudit
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Updated',
                      style: TextStyle(
                        color: palette.surface,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_auditEvents.isEmpty)
            const EmptyState.compact(
              icon: Icons.history_toggle_off_outlined,
              title: 'No activity recorded yet',
              message: 'Timeline events will appear here as the complaint progresses.',
            )
          else
            AuditTimeline(events: _auditEvents),
        ],
      ),
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
