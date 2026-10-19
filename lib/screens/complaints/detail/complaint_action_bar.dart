import 'package:flutter/material.dart';

import '../../../app/user_role.dart';
import '../../../core/enums/complaint_priority.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../repositories/assignment_repository.dart';
import '../../../repositories/complaint_repository.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/action_feedback.dart';
import '../../../utils/status_transitions.dart';
import '../../../utils/visit_validators.dart';
import '../../../widgets/app_spacing.dart';
import '../../technician/visit/visit_completion_form.dart';
import '../../technician/visit/visit_screen.dart';
import '../assignment/assign_technician_sheet.dart';
import 'actions/close_sheet.dart';
import 'actions/reopen_sheet.dart';
import 'actions/waiting_for_parts_sheet.dart';
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
    final currentStatus = state.currentStatus;
    final allowed = allowedNext(
      currentStatus,
      UserRole.tenant,
      closedAt: state.complaint?.closedAt,
      referenceNow: state.referenceNow,
    );

    final buttons = <Widget>[];

    if (allowed.contains(ComplaintStatus.reopened)) {
      buttons.add(
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
          onPressed: () => _openTenantReopenSheet(context, state),
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Not fixed, reopen'),
        ),
      );
    }

    if (currentStatus == ComplaintStatus.resolved) {
      buttons.add(
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
          onPressed: () async {
            await controller.changeComplaintStatus(
              StatusChange(
                complaintId: state.complaint!.id,
                to: ComplaintStatus.closed,
                actor: controller.currentUserId,
                role: 'Tenant',
                tenantConfirmed: true,
                note: 'Tenant confirmed repair was successful.',
              ),
            );
            if (context.mounted) {
              ActionFeedback.showSuccess(context, 'Resolution confirmed.');
            }
          },
          icon: const Icon(Icons.task_alt, size: 18),
          label: const Text("Confirm it's fixed"),
        ),
      );
    }

    return buttons;
  }

  Future<void> _openTenantReopenSheet(
    BuildContext context,
    ComplaintDetailState state,
  ) async {
    final result = await ReopenSheet.show(
      context,
      reopenCount: state.complaint?.reopenCount ?? 0,
      onSubmit: (res) async {
        await controller.changeComplaintStatus(
          StatusChange(
            complaintId: state.complaint!.id,
            to: ComplaintStatus.reopened,
            actor: controller.currentUserId,
            role: 'Tenant',
            reason: res.reason,
            note: res.note,
            photos: res.photos,
          ),
        );
      },
    );
    if (result != null && context.mounted) {
      ActionFeedback.showSuccess(context, 'Complaint reopened.');
    }
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
    final allowed = allowedNext(
      currentStatus,
      UserRole.technician,
    );

    if (currentStatus == ComplaintStatus.resolved ||
        currentStatus == ComplaintStatus.closed ||
        currentStatus == ComplaintStatus.cancelled) {
      return const [];
    }

    if (allowed.contains(ComplaintStatus.inProgress)) {
      // Waiting for parts -> Resume work is the only allowed action
      return [
        FilledButton.icon(
          key: const Key('tech_resume_work_button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 48),
            backgroundColor: palette.accent,
            foregroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _openWaitingForPartsSheet(context, state),
          icon: const Icon(Icons.play_arrow_outlined, size: 18),
          label: const Text('Resume work'),
        ),
      ];
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

    final holdForPartsButton = allowed.contains(ComplaintStatus.waitingForParts)
        ? OutlinedButton.icon(
            key: const Key('tech_hold_parts_button'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(130, 48),
              foregroundColor: palette.warning,
              side: BorderSide(color: palette.warning),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _openWaitingForPartsSheet(context, state),
            icon: const Icon(Icons.pause_circle_outline, size: 18),
            label: const Text('Hold for parts'),
          )
        : null;

    // Work is active -> Complete visit or hold for parts
    return [
      visitScreenButton,
      if (holdForPartsButton != null) holdForPartsButton,
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

  Future<void> _openWaitingForPartsSheet(
    BuildContext context,
    ComplaintDetailState state,
  ) async {
    final result = await WaitingForPartsSheet.show(
      context,
      currentStatus: state.currentStatus,
      referenceNow: state.referenceNow,
      onSubmit: (res) async {
        if (res.isResume) {
          await controller.changeComplaintStatus(
            StatusChange(
              complaintId: state.complaint!.id,
              to: ComplaintStatus.inProgress,
              actor: controller.currentUserId,
              role: 'Technician',
              note: 'Technician resumed work after parts arrived.',
            ),
          );
        } else {
          await controller.changeComplaintStatus(
            StatusChange(
              complaintId: state.complaint!.id,
              to: ComplaintStatus.waitingForParts,
              actor: controller.currentUserId,
              role: 'Technician',
              reason: res.reason,
              parts: res.parts,
              expectedDate: res.expectedDate,
              note: res.note,
            ),
          );
        }
      },
    );
    if (result != null && context.mounted) {
      ActionFeedback.showSuccess(
        context,
        result.isResume ? 'Work resumed.' : 'Placed on hold for parts.',
      );
    }
  }

  // -------------------------------------------------------------
  // STAFF ACTIONS
  // -------------------------------------------------------------
  List<Widget> _buildStaffActions(
    BuildContext context,
    ComplaintDetailState state,
  ) {
    final palette = context.palette;
    final currentStatus = state.currentStatus;
    final allowed = allowedNext(
      currentStatus,
      UserRole.staff,
      closedAt: state.complaint?.closedAt,
      referenceNow: state.referenceNow,
    );

    final isTerminal = currentStatus == ComplaintStatus.resolved ||
        currentStatus == ComplaintStatus.closed ||
        currentStatus == ComplaintStatus.cancelled ||
        state.complaint?.status == ComplaintStatus.resolved ||
        state.complaint?.status == ComplaintStatus.closed ||
        state.complaint?.status == ComplaintStatus.cancelled;

    final isAssigned = state.assignedTechnicianId != null;

    final buttons = <Widget>[];

    // Close action for staff (allowed from resolved)
    if (allowed.contains(ComplaintStatus.closed)) {
      buttons.add(
        FilledButton.icon(
          key: const Key('staff_close_button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(130, 48),
            backgroundColor: palette.accent,
            foregroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _openCloseSheet(context, state),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Close complaint'),
        ),
      );
    }

    // Reopen action for staff (allowed from resolved or closed within window)
    if (allowed.contains(ComplaintStatus.reopened)) {
      buttons.add(
        OutlinedButton.icon(
          key: const Key('staff_reopen_button'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(130, 48),
            foregroundColor: palette.danger,
            side: BorderSide(color: palette.danger),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _openStaffReopenSheet(context, state),
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Reopen complaint'),
        ),
      );
    } else if (currentStatus == ComplaintStatus.closed) {
      // Reopen window has expired: show disabled button with whyNot tooltip
      final tooltip = whyNot(
        currentStatus,
        ComplaintStatus.reopened,
        UserRole.staff,
        closedAt: state.complaint?.closedAt,
        referenceNow: state.referenceNow,
      );
      buttons.add(
        Tooltip(
          message: tooltip ??
              'Reopen window has expired (within 7 days of closing only).',
          child: OutlinedButton.icon(
            key: const Key('staff_reopen_disabled_button'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(130, 48),
              side: BorderSide(color: palette.border),
            ),
            onPressed: null,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Reopen complaint'),
          ),
        ),
      );
    }

    // Cancel action for staff (only allowed from open or assigned)
    if (allowed.contains(ComplaintStatus.cancelled)) {
      buttons.add(
        OutlinedButton.icon(
          key: const Key('staff_cancel_button'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(130, 48),
            foregroundColor: palette.danger,
            side: BorderSide(color: palette.danger),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _confirmCancel(context, state),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('Cancel complaint'),
        ),
      );
    }

    if (!isTerminal) {
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
              onPressed: () => _openAssignmentSheet(context, isReassign: true),
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
              onPressed: () => _openAssignmentSheet(context, isReassign: false),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Assign technician'),
            );

      buttons.add(assignButton);
      buttons.add(
        OutlinedButton.icon(
          key: const Key('change_priority_button'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(120, 48),
            side: BorderSide(color: palette.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _showPriorityDialog(context, state),
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: const Text('Change priority'),
        ),
      );
    }

    buttons.add(
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
    );

    return buttons;
  }

  Future<void> _openCloseSheet(
    BuildContext context,
    ComplaintDetailState state,
  ) async {
    final hasTenantConfirmation = state.events.any(
      (e) =>
          e.type == ActivityEventType.tenantConfirmed ||
          e.metadata['tenantConfirmed'] == true,
    );
    final hasNotes = state.events.any(
      (e) =>
          (e.type == ActivityEventType.repairCompleted ||
              e.type == ActivityEventType.markedResolved) &&
          e.note != null &&
          e.note!.isNotEmpty,
    );
    final hasPhotos = state.events.any(
      (e) =>
          (e.type == ActivityEventType.repairCompleted ||
              e.type == ActivityEventType.markedResolved ||
              e.type == ActivityEventType.photoUploaded) &&
          e.photos.isNotEmpty,
    );

    final result = await CloseSheet.show(
      context,
      initialTenantConfirmed: hasTenantConfirmation,
      initialResolutionNotesPresent: hasNotes,
      initialAfterPhotosPresent: hasPhotos,
      onSubmit: (res) async {
        await controller.changeComplaintStatus(
          StatusChange(
            complaintId: state.complaint!.id,
            to: ComplaintStatus.closed,
            actor: controller.currentUserId,
            role: 'Staff',
            tenantConfirmed: res.tenantConfirmed,
            reason: res.reason,
            note: res.tenantConfirmed
                ? 'Complaint closed after tenant confirmation.'
                : 'Complaint closed without tenant confirmation: ${res.reason}',
          ),
        );
      },
    );
    if (result != null && context.mounted) {
      ActionFeedback.showSuccess(context, 'Complaint closed.');
    }
  }

  Future<void> _openStaffReopenSheet(
    BuildContext context,
    ComplaintDetailState state,
  ) async {
    final result = await ReopenSheet.show(
      context,
      reopenCount: state.complaint?.reopenCount ?? 0,
      onSubmit: (res) async {
        await controller.changeComplaintStatus(
          StatusChange(
            complaintId: state.complaint!.id,
            to: ComplaintStatus.reopened,
            actor: controller.currentUserId,
            role: 'Staff',
            reason: res.reason,
            note: res.note,
            photos: res.photos,
          ),
        );
      },
    );
    if (result != null && context.mounted) {
      ActionFeedback.showSuccess(context, 'Complaint reopened.');
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    ComplaintDetailState state,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Cancel complaint',
            style: TextStyle(fontFamily: 'Fraunces', color: palette.ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel this complaint? This cannot be undone.',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('cancel_reason_field'),
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Cancellation reason (optional)...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Back'),
            ),
            FilledButton(
              key: const Key('confirm_cancel_submit_button'),
              style: FilledButton.styleFrom(backgroundColor: palette.danger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Cancel complaint'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await controller.changeComplaintStatus(
        StatusChange(
          complaintId: state.complaint!.id,
          to: ComplaintStatus.cancelled,
          actor: controller.currentUserId,
          role: 'Staff',
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : 'Cancelled by staff',
        ),
      );
      if (context.mounted) {
        ActionFeedback.showSuccess(context, 'Complaint cancelled.');
      }
    }
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
        ActionFeedback.showSuccess(
          context,
          'Assigned to ${result.assignedTechnician.name}',
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
