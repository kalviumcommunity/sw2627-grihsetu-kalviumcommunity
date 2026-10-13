import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/user_role.dart';
import '../../core/enums/complaint_category.dart';
import '../../core/enums/complaint_status.dart';
import '../../core/models/complaint.dart';
import '../../repositories/assignment_repository.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/audit_timeline.dart';
import '../../widgets/complaint_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';
import 'assignment/assign_technician_sheet.dart';

/// Complaint detail screen supporting technician assignment, reassignment,
/// status tracking, and live-highlighted audit history.
class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.complaint,
    this.propertyName,
    this.unitNumber,
    this.userRole = UserRole.staff,
    this.assignmentRepository,
    this.initialTechnician,
    this.initialAuditEvents,
  });

  final Complaint complaint;
  final String? propertyName;
  final String? unitNumber;
  final UserRole userRole;
  final AssignmentRepository? assignmentRepository;
  final TechnicianOption? initialTechnician;
  final List<AuditEvent>? initialAuditEvents;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late Complaint _complaint;
  late final AssignmentRepository _repository;
  TechnicianOption? _assignedTechnician;
  late List<AuditEvent> _auditEvents;
  bool _highlightAudit = false;
  Timer? _highlightTimer;

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
    _highlightTimer?.cancel();
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

    _auditEvents = events;
  }

  bool get _isTerminalStatus =>
      _complaint.status == ComplaintStatus.resolved ||
      _complaint.status == ComplaintStatus.closed ||
      _complaint.status == ComplaintStatus.cancelled;

  String get _displayPropertyName {
    final name = widget.propertyName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (_complaint.propertyId.trim().isNotEmpty) return _complaint.propertyId;
    return 'Unknown property';
  }

  String get _displayUnitNumber {
    final unit = widget.unitNumber?.trim();
    if (unit != null && unit.isNotEmpty) return unit;
    if (_complaint.unitId.trim().isNotEmpty) return _complaint.unitId;
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

  Future<void> _handleOpenAssignmentSheet({required bool isReassign}) async {
    final result = await AssignTechnicianSheet.show(
      context,
      complaint: _complaint,
      repository: _repository,
      currentTechnician: _assignedTechnician,
      isReassign: isReassign,
    );

    if (result != null && mounted) {
      setState(() {
        _complaint = result.updatedComplaint;
        _assignedTechnician = result.assignedTechnician;
        _auditEvents = [..._auditEvents, result.auditEvent];
        _highlightAudit = true;
      });

      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _highlightAudit = false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned to ${result.assignedTechnician.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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

  Widget _buildTechnicianSection(BuildContext context, bool isStaff) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final tech = _assignedTechnician;
    final isAssigned = tech != null && _complaint.currentTechnicianId != null;
    final isTerminal = _isTerminalStatus;

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
                    color: palette.accentSoft,
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
