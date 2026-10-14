import 'package:flutter/material.dart';

import '../../../core/enums/complaint_status.dart';
import '../../../core/models/complaint_audit_event.dart';
import '../../../repositories/complaint_repository.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/visit_validators.dart';
import 'visit_completion_form.dart';
import 'visit_models.dart';

/// Next-step workflow button used on technician job cards and detail screen.
/// Follows workflow: Accept job -> Start travel -> I've arrived -> Start inspection -> Start repair -> Complete visit.
class TechnicianNextStepButton extends StatefulWidget {
  const TechnicianNextStepButton({
    super.key,
    required this.complaintId,
    required this.status,
    required this.repository,
    this.technicianId = 'usr_002',
    this.technicianName = 'Aman Verma',
    this.initialEvents,
    this.isFullWidth = true,
  });

  final String complaintId;
  final ComplaintStatus status;
  final ComplaintRepository repository;
  final String technicianId;
  final String technicianName;
  final List<ComplaintAuditEvent>? initialEvents;
  final bool isFullWidth;

  @override
  State<TechnicianNextStepButton> createState() =>
      _TechnicianNextStepButtonState();
}

class _TechnicianNextStepButtonState extends State<TechnicianNextStepButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (widget.status == ComplaintStatus.resolved ||
        widget.status == ComplaintStatus.closed ||
        widget.status == ComplaintStatus.cancelled) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<ComplaintAuditEvent>>(
      stream: widget.repository.watchAuditEvents(widget.complaintId),
      initialData: widget.initialEvents ?? const [],
      builder: (context, snapshot) {
        final events = snapshot.data ?? const [];
        final nextStep = resolveNextVisitStepFromEvents(
          events,
          widget.status.value,
        );

        if (nextStep == null) return const SizedBox.shrink();

        final isComplete = nextStep == VisitWorkflowStep.completed;

        final button = SizedBox(
          height: 48, // 48px tap target
          width: widget.isFullWidth ? double.infinity : null,
          child: FilledButton.icon(
            key: Key('tech_next_step_${nextStep.name}_${widget.complaintId}'),
            style: FilledButton.styleFrom(
              backgroundColor: isComplete ? palette.success : palette.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isLoading
                ? null
                : () async {
                    if (isComplete) {
                      await VisitCompletionForm.open(
                        context,
                        complaintId: widget.complaintId,
                        repository: widget.repository,
                        technicianId: widget.technicianId,
                        technicianName: widget.technicianName,
                      );
                    } else {
                      setState(() => _isLoading = true);
                      try {
                        await widget.repository.advanceVisitStep(
                          widget.complaintId,
                          nextStep,
                          actorId: widget.technicianId,
                          role: 'technician',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Action failed: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    }
                  },
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isComplete
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                    size: 18,
                  ),
            label: Text(
              _isLoading ? 'Updating...' : nextStep.actionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        );

        return button;
      },
    );
  }
}
