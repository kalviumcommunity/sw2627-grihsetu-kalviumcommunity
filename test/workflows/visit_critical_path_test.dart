import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_audit_event_type.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/complaint_audit_event.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/screens/technician/visit/visit_models.dart';
import 'package:grihsetu/utils/visit_validators.dart';

void main() {
  setUp(
    () => ComplaintStore.resetInstance(
      ComplaintStore(initialComplaints: const []),
    ),
  );
  tearDown(ComplaintStore.resetInstance);

  test(
    'visit steps advance in order and both completion outcomes persist',
    () async {
      final events = <ComplaintAuditEvent>[];
      expect(
        resolveNextVisitStepFromEvents(events, 'assigned'),
        VisitWorkflowStep.accepted,
      );
      for (final transition in const [
        ('JOB_ACCEPTED', VisitWorkflowStep.travelling),
        ('TRAVEL_STARTED', VisitWorkflowStep.arrived),
        ('ARRIVED', VisitWorkflowStep.inspection),
        ('INSPECTION_STARTED', VisitWorkflowStep.repairing),
        ('REPAIR_STARTED', VisitWorkflowStep.completed),
      ]) {
        events.add(_event(transition.$1, events.length));
        expect(
          resolveNextVisitStepFromEvents(events, 'in_progress'),
          transition.$2,
        );
      }

      final resolvedRepo = InMemoryComplaintRepository(
        initialComplaints: [_assignedComplaint('cmp_resolve')],
      );
      final resolved = await resolvedRepo.completeVisit(
        'cmp_resolve',
        const VisitCompletionInput(
          whatWasFound: 'A failed angle valve was leaking under pressure.',
          whatWasRepaired: 'Replaced the valve and pressure-tested the line.',
          tenantResolutionNotes: 'Leak stopped and cabinet area left dry.',
          afterPhotos: ['after.jpg'],
          noPartsUsed: true,
        ),
        actorId: 'tech_1',
        role: 'Technician',
      );
      expect(resolved.status, ComplaintStatus.resolved);
      expect(resolved.visitCount, 1);

      final followUpRepo = InMemoryComplaintRepository(
        initialComplaints: [_assignedComplaint('cmp_follow_up')],
      );
      final followUp = await followUpRepo.requestFollowUpVisit(
        'cmp_follow_up',
        const FollowUpRequestInput(
          reason: FollowUpReason.partNotAvailable,
          details: 'Bring a compatible brass valve for the return visit.',
        ),
        actorId: 'tech_1',
        role: 'Technician',
      );
      expect(followUp.status, ComplaintStatus.assigned);
      expect(followUp.visitCount, 1);
    },
  );
}

Complaint _assignedComplaint(String id) => Complaint(
  id: id,
  title: 'Kitchen pipe leak',
  description: 'Water leaks continuously below the kitchen sink cabinet.',
  category: ComplaintCategory.plumbing,
  priority: ComplaintPriority.high,
  status: ComplaintStatus.assigned,
  propertyId: 'prop_001',
  unitId: 'unit_101',
  tenantId: 'ten_001',
  currentTechnicianId: 'tech_1',
  createdBy: 'ten_001',
  createdAt: DateTime(2026, 10, 6, 9),
);

ComplaintAuditEvent _event(String rawType, int offset) => ComplaintAuditEvent(
  id: 'evt_$offset',
  complaintId: 'cmp_sequence',
  eventType: ComplaintAuditEventType.unknown,
  rawEventType: rawType,
  actorId: 'tech_1',
  timestamp: DateTime(2026, 10, 6, 10, offset),
);
