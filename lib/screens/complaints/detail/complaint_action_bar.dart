import 'package:flutter/material.dart';

import '../../../app/user_role.dart';
import '../../../core/enums/complaint_priority.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../repositories/assignment_repository.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/visit_validators.dart';
import '../../../widgets/app_spacing.dart';
import '../../technician/visit/visit_completion_form.dart';
import '../../technician/visit/visit_screen.dart';
import '../assignment/assign_technician_sheet.dart';
import 'complaint_detail_controller.dart';
import 'complaint_detail_models.dart';

/// Role-based action bar for ComplaintDetailScreen.
///
/// Renders sticky at the bottom on phones, or as a right column section on wide screens.
/// Actions the role cannot take are absent, not disabled.
class ComplaintActionBar extends StatelessWidget {
  const ComplaintActionBar({
    super.key,
    required this.controller,
    required this.userRole,
    this.isColumn = false,
    this.assignmentRepository,
  });

  final ComplaintDetailController controller;
  final UserRole userRole;
  final bool isColumn;
  final AssignmentRepository? assignmentRepository;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (!state.hasData) return const SizedBox.shrink();

    final buttons = _buildActionButtons(context, state);
    if (buttons.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;

    if (isColumn) {
      return Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFamily: 'Fraunces',
                color: palette.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              buttons[i],
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: buttons,
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    switch (userRole) {
      case UserRole.tenant:
        return _buildTenantActions(context, state);
      case UserRole.technician:
        return _buildTechnicianActions(context, state);
      case UserRole.staff:
        return _buildStaffActions(context, state);
      case UserRole.owner:
        // Owner is strictly read-only
        return const [];
    }
  }

  // -------------------------------------------------------------
  // TENANT ACTIONS
  // -------------------------------------------------------------
  List<Widget> _buildTenantActions(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    final palette = context.palette;
    if (state.currentStatus != ComplaintStatus.resolved) {
      return const [];
    }

    return [
      OutlinedButton.icon(
        key: const Key('tenant_reopen_button'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 48),
          foregroundColor: palette.danger,
          side: BorderSide(color: palette.danger),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => _showReopenDialog(context),
        icon: const Icon(Icons.replay, size: 18),
        label: const Text('Not fixed, reopen'),
      ),
      FilledButton.icon(
        key: const Key('tenant_confirm_button'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(140, 48),
          backgroundColor: palette.success,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => controller.confirmFixed(),
        icon: const Icon(Icons.task_alt, size: 18),
        label: const Text("Confirm it's fixed"),
      ),
    ];
  }

  void _showReopenDialog(BuildContext context) {
    final controllerText = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Reopen complaint',
            style: TextStyle(fontFamily: 'Fraunces', color: palette.ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please explain why the issue is not fixed so the technician can address it:',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('reopen_reason_field'),
                controller: controllerText,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for reopening...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm_reopen_submit_button'),
              style: FilledButton.styleFrom(backgroundColor: palette.danger),
              onPressed: () {
                final reason = controllerText.text.trim();
                if (reason.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  controller.reopen(reason: reason);
                }
              },
              child: const Text('Reopen complaint'),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TECHNICIAN ACTIONS
  // -------------------------------------------------------------
  List<Widget> _buildTechnicianActions(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    final palette = context.palette;
    final currentStatus = state.currentStatus;
    if (currentStatus == ComplaintStatus.resolved ||
        currentStatus == ComplaintStatus.closed ||
        currentStatus == ComplaintStatus.cancelled) {
      return const [];
    }

    final hasAccepted = state.events.any(
      (e) =>
          e.type == ActivityEventType.accepted ||
          (e.metadata['rawEventType'] ?? '').toString().contains(
            'JOB_ACCEPTED',
          ) ||
          (e.metadata['rawEventType'] ?? '').toString().contains(
            'TECHNICIAN_ACCEPTED',
          ),
    );
    final hasTravelStarted = state.events.any(
      (e) =>
          e.type == ActivityEventType.travelStarted ||
          (e.metadata['rawEventType'] ?? '').toString().contains('TRAVELL') ||
          (e.metadata['rawEventType'] ?? '').toString().contains(
            'TRAVEL_STARTED',
          ),
    );
    final hasArrived = state.events.any(
      (e) =>
          e.type == ActivityEventType.arrived ||
          (e.metadata['rawEventType'] ?? '').toString().contains('ARRIVED'),
    );
    final hasInspection = state.events.any(
      (e) =>
          (e.metadata['rawEventType'] ?? '').toString().contains(
            'INSPECTION',
          ) ||
          (e.note ?? '').toUpperCase().contains('INSPECTION'),
    );
    final hasWorkStarted = state.events.any(
      (e) =>
          e.type == ActivityEventType.workStarted ||
          (e.metadata['rawEventType'] ?? '').toString().contains(
            'REPAIR_STARTED',
          ) ||
          (e.metadata['rawEventType'] ?? '').toString().contains(
            'WORK_STARTED',
          ),
    );

    final visitScreenButton = OutlinedButton.icon(
      key: const Key('open_visit_screen_button'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(120, 48),
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => VisitScreen.open(
        context,
        complaintId: state.complaint!.id,
        repository: controller.repository,
        technicianId: controller.currentUserId,
      ),
      icon: const Icon(Icons.phone_android_outlined, size: 18),
      label: const Text('Visit Screen'),
    );

    if (!hasAccepted && currentStatus == ComplaintStatus.assigned) {
      return [
        visitScreenButton,
        FilledButton.icon(
          key: const Key('tech_accept_job_button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 48),
            backgroundColor: palette.accent,
            foregroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () =>
              controller.advanceVisitWorkflowStep(VisitWorkflowStep.accepted),
          icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
          label: const Text('Accept job'),
        ),
      ];
    }

    if (!hasTravelStarted) {
      return [
        visitScreenButton,
        FilledButton.icon(
          key: const Key('tech_start_travel_button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 48),
            backgroundColor: palette.accent,
            foregroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () =>
              controller.advanceVisitWorkflowStep(VisitWorkflowStep.travelling),
          icon: const Icon(Icons.directions_car_outlined, size: 18),
          label: const Text('Start travel'),
        ),
      ];
    }

    if (!hasArrived) {
      return [
        visitScreenButton,
        FilledButton.icon(
          key: const Key('tech_arrived_button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 48),
            backgroundColor: palette.accent,
            foregroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () =>
              controller.advanceVisitWorkflowStep(VisitWorkflowStep.arrived),
          icon: const Icon(Icons.location_on_outlined, size: 18),
          label: const Text("I've arrived"),
        ),
      ];
    }

    if (!hasInspection) {
      return [
        visitScreenButton,
        FilledButton.icon(
          key: const Key('tech_start_inspection_button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 48),
            backgroundColor: palette.accent,
            foregroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () =>
              controller.advanceVisitWorkflowStep(VisitWorkflowStep.inspection),
          icon: const Icon(Icons.search_outlined, size: 18),
          label: const Text('Start inspection'),
        ),
      ];
    }

    if (!hasWorkStarted) {
      return [
        visitScreenButton,
        FilledButton.icon(
          key: const Key('tech_start_work_button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 48),
            backgroundColor: palette.accent,
            foregroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () =>
              controller.advanceVisitWorkflowStep(VisitWorkflowStep.repairing),
          icon: const Icon(Icons.build_outlined, size: 18),
          label: const Text('Start repair'),
        ),
      ];
    }

    // Work is active -> Complete visit
    return [
      visitScreenButton,
      FilledButton.icon(
        key: const Key('tech_complete_visit_button'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(140, 48),
          backgroundColor: palette.success,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => VisitCompletionForm.open(
          context,
          complaintId: state.complaint!.id,
          repository: controller.repository,
          technicianId: controller.currentUserId,
          technicianName: controller.currentUserName,
        ),
        icon: const Icon(Icons.verified_outlined, size: 18),
        label: const Text('Complete visit'),
      ),
    ];
  }

  // -------------------------------------------------------------
  // STAFF ACTIONS
  // -------------------------------------------------------------
  List<Widget> _buildStaffActions(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    final palette = context.palette;
    final isTerminal =
        state.currentStatus == ComplaintStatus.resolved ||
        state.currentStatus == ComplaintStatus.closed ||
        state.currentStatus == ComplaintStatus.cancelled ||
        state.complaint?.status == ComplaintStatus.resolved ||
        state.complaint?.status == ComplaintStatus.closed ||
        state.complaint?.status == ComplaintStatus.cancelled;

    final isAssigned = state.assignedTechnicianId != null;

    final assignButton = isAssigned
        ? OutlinedButton.icon(
            key: const Key('reassign_technician_button'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(130, 48),
              side: BorderSide(color: palette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: isTerminal
                ? null
                : () => _openAssignmentSheet(context, isReassign: true),
            icon: const Icon(Icons.sync_alt, size: 18),
            label: const Text('Reassign'),
          )
        : FilledButton.icon(
            key: const Key('assign_technician_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(130, 48),
              backgroundColor: palette.accent,
              foregroundColor: palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: isTerminal
                ? null
                : () => _openAssignmentSheet(context, isReassign: false),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Assign technician'),
          );

    return [
      assignButton,
      OutlinedButton.icon(
        key: const Key('change_priority_button'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 48),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: isTerminal
            ? null
            : () => _showPriorityDialog(context, state),
        icon: const Icon(Icons.flag_outlined, size: 18),
        label: const Text('Change priority'),
      ),
      OutlinedButton.icon(
        key: const Key('add_internal_note_button'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 48),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => _showInternalNoteDialog(context),
        icon: const Icon(Icons.note_add_outlined, size: 18),
        label: const Text('Add internal note'),
      ),
    ];
  }

  Future<void> _openAssignmentSheet(
    BuildContext context, {
    required bool isReassign,
  }) async {
    final repo = assignmentRepository ?? InMemoryAssignmentRepository();
    final result = await AssignTechnicianSheet.show(
      context,
      complaint: controller.state.complaint!,
      repository: repo,
      isReassign: isReassign,
    );
    if (result != null) {
      await controller.assignTechnician(
        result.assignedTechnician.id,
        technicianName: result.assignedTechnician.name,
        notes: result.auditEvent.note,
        scheduledDate: result.updatedComplaint.firstAssignedAt,
        reason: isReassign ? 'Operational reallocation' : null,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned to ${result.assignedTechnician.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPriorityDialog(BuildContext context, ComplaintDetailState state) {
    var selected = state.complaint?.priority ?? ComplaintPriority.medium;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final palette = ctx.palette;
          return AlertDialog(
            backgroundColor: palette.surface,
            title: Text(
              'Change priority',
              style: TextStyle(fontFamily: 'Fraunces', color: palette.ink),
            ),
            content: RadioGroup<ComplaintPriority>(
              groupValue: selected,
              onChanged: (val) {
                if (val != null) setDialogState(() => selected = val);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in ComplaintPriority.values)
                    RadioListTile<ComplaintPriority>(
                      key: Key('priority_option_${p.name}'),
                      title: Text(p.displayLabel),
                      value: p,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm_priority_button'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  controller.changePriority(selected);
                },
                child: const Text('Update priority'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInternalNoteDialog(BuildContext context) {
    final noteController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Add internal note',
            style: TextStyle(fontFamily: 'Fraunces', color: palette.ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Internal notes are strictly visible to operations staff only.',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('internal_note_field'),
                controller: noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter internal remarks...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('submit_internal_note_button'),
              onPressed: () {
                final text = noteController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  controller.addInternalNote(text);
                }
              },
              child: const Text('Save note'),
            ),
          ],
        );
      },
    );
  }
}
