import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_audit_event_type.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/complaint_audit_event.dart';
import 'package:grihsetu/utils/consistency_rules.dart';

void main() {
  group('ConsistencyRules', () {
    final t0 = DateTime(2026, 10, 1, 10, 0);
    final t1 = DateTime(2026, 10, 1, 11, 0);
    final t2 = DateTime(2026, 10, 1, 12, 0);

    Complaint baseComplaint({
      String id = 'cmp_test',
      ComplaintStatus status = ComplaintStatus.open,
      String? currentTechnicianId,
      int visitCount = 0,
      int reopenCount = 0,
      DateTime? resolvedAt,
      DateTime? closedAt,
    }) {
      return Complaint(
        id: id,
        tenantId: 't1',
        propertyId: 'p1',
        unitId: 'u1',
        title: 'Test complaint',
        description: 'Test description',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.medium,
        status: status,
        currentTechnicianId: currentTechnicianId,
        visitCount: visitCount,
        reopenCount: reopenCount,
        resolvedAt: resolvedAt,
        closedAt: closedAt,
        createdBy: 'usr_1',
        createdAt: t0,
      );
    }

    test('Rule 1: unique_ids passing vs failing', () {
      final complaint = baseComplaint();
      final passingEvents = [
        ComplaintAuditEvent(
          id: 'evt_1',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'evt_2',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t1,
          details: {'newTechnicianId': 'tech_1'},
        ),
      ];

      final failingEvents = [
        ComplaintAuditEvent(
          id: 'evt_dup',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'evt_dup',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t1,
          details: {'newTechnicianId': 'tech_1'},
        ),
      ];

      expect(
        ConsistencyRules.validateComplaint(
          complaint,
          passingEvents,
        ).any((v) => v.rule == 'unique_ids'),
        isFalse,
      );
      final violations = ConsistencyRules.validateComplaint(
        complaint,
        failingEvents,
      );
      expect(violations.any((v) => v.rule == 'unique_ids'), isTrue);
    });

    test('Rule 2: event_order passing vs failing', () {
      final complaint = baseComplaint();
      final passingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t1,
          details: {'newTechnicianId': 'tech_1'},
        ),
      ];

      final failingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t1,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t0, // Earlier than e1!
          details: {'newTechnicianId': 'tech_1'},
        ),
      ];

      expect(
        ConsistencyRules.validateComplaint(
          complaint,
          passingEvents,
        ).any((v) => v.rule == 'event_order'),
        isFalse,
      );
      expect(
        ConsistencyRules.validateComplaint(
          complaint,
          failingEvents,
        ).any((v) => v.rule == 'event_order'),
        isTrue,
      );
    });

    test('Rule 3: no_events_after_cancelled passing vs failing', () {
      final complaint = baseComplaint(status: ComplaintStatus.cancelled);
      final passingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.complaintCancelled,
          actorId: 'usr_1',
          timestamp: t1,
        ),
      ];

      final failingEvents = [
        ...passingEvents,
        ComplaintAuditEvent(
          id: 'e3',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t2,
          details: {'newTechnicianId': 'tech_1'},
        ),
      ];

      expect(
        ConsistencyRules.validateComplaint(
          complaint,
          passingEvents,
        ).any((v) => v.rule == 'no_events_after_cancelled'),
        isFalse,
      );
      expect(
        ConsistencyRules.validateComplaint(
          complaint,
          failingEvents,
        ).any((v) => v.rule == 'no_events_after_cancelled'),
        isTrue,
      );
    });

    test('Rule 4: status_matches_last_event passing vs failing', () {
      final passingComplaint = baseComplaint(
        status: ComplaintStatus.inProgress,
        currentTechnicianId: 'tech_1',
        visitCount: 1,
      );
      final events = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t1,
          details: {'newTechnicianId': 'tech_1'},
        ),
        ComplaintAuditEvent(
          id: 'e3',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.technicianArrived,
          actorId: 'tech_1',
          timestamp: t2,
        ),
      ];

      expect(
        ConsistencyRules.validateComplaint(
          passingComplaint,
          events,
        ).any((v) => v.rule == 'status_matches_last_event'),
        isFalse,
      );

      final failingComplaint = passingComplaint.copyWith(
        status: ComplaintStatus.closed,
      );
      expect(
        ConsistencyRules.validateComplaint(
          failingComplaint,
          events,
        ).any((v) => v.rule == 'status_matches_last_event'),
        isTrue,
      );
    });

    test('Rule 5: technician_matches_assignment passing vs failing', () {
      final complaint = baseComplaint(
        status: ComplaintStatus.assigned,
        currentTechnicianId: 'tech_correct',
      );
      final passingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t1,
          details: {'newTechnicianId': 'tech_correct'},
        ),
      ];

      final failingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: complaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t1,
          details: {'newTechnicianId': 'tech_other'},
        ),
      ];

      expect(
        ConsistencyRules.validateComplaint(
          complaint,
          passingEvents,
        ).any((v) => v.rule == 'technician_matches_assignment'),
        isFalse,
      );
      expect(
        ConsistencyRules.validateComplaint(
          complaint,
          failingEvents,
        ).any((v) => v.rule == 'technician_matches_assignment'),
        isTrue,
      );
    });

    test('Rule 6: resolved_has_event_and_visit passing vs failing', () {
      final passingComplaint = baseComplaint(
        status: ComplaintStatus.resolved,
        currentTechnicianId: 'tech_1',
        visitCount: 1,
        resolvedAt: t2,
      );
      final passingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t0.add(const Duration(minutes: 10)),
          details: {'newTechnicianId': 'tech_1'},
        ),
        ComplaintAuditEvent(
          id: 'e3',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.technicianArrived,
          actorId: 'tech_1',
          timestamp: t1,
        ),
        ComplaintAuditEvent(
          id: 'e4',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.complaintResolved,
          actorId: 'tech_1',
          timestamp: t2,
        ),
      ];

      expect(
        ConsistencyRules.validateComplaint(
          passingComplaint,
          passingEvents,
        ).any((v) => v.rule == 'resolved_has_event_and_visit'),
        isFalse,
      );

      // Missing resolved event
      final failingEventsNoResolvedEvent = passingEvents.sublist(0, 3);
      expect(
        ConsistencyRules.validateComplaint(
          passingComplaint,
          failingEventsNoResolvedEvent,
        ).any((v) => v.rule == 'resolved_has_event_and_visit'),
        isTrue,
      );

      // Missing visit count and visit events
      final failingNoVisit = passingComplaint.copyWith(visitCount: 0);
      final eventsNoVisit = [
        passingEvents[0],
        passingEvents[1],
        passingEvents[3],
      ];
      expect(
        ConsistencyRules.validateComplaint(
          failingNoVisit,
          eventsNoVisit,
        ).any((v) => v.rule == 'resolved_has_event_and_visit'),
        isTrue,
      );
    });

    test('Rule 7: closed_has_close_event passing vs failing', () {
      final passingComplaint = baseComplaint(
        status: ComplaintStatus.closed,
        closedAt: t2,
      );
      final passingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.complaintClosed,
          actorId: 'usr_1',
          timestamp: t2,
        ),
      ];

      final failingEvents = [passingEvents[0]];

      expect(
        ConsistencyRules.validateComplaint(
          passingComplaint,
          passingEvents,
        ).any((v) => v.rule == 'closed_has_close_event'),
        isFalse,
      );
      expect(
        ConsistencyRules.validateComplaint(
          passingComplaint,
          failingEvents,
        ).any((v) => v.rule == 'closed_has_close_event'),
        isTrue,
      );
    });

    test('Rule 8: visit_count_matches_arrived_events passing vs failing', () {
      final passingComplaint = baseComplaint(
        status: ComplaintStatus.inProgress,
        currentTechnicianId: 'tech_1',
        visitCount: 2,
      );
      final passingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_1',
          timestamp: t0.add(const Duration(minutes: 5)),
          details: {'newTechnicianId': 'tech_1'},
        ),
        ComplaintAuditEvent(
          id: 'e3',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.technicianArrived,
          actorId: 'tech_1',
          timestamp: t1,
        ),
        ComplaintAuditEvent(
          id: 'e4',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.technicianArrived,
          actorId: 'tech_1',
          timestamp: t2,
        ),
      ];

      expect(
        ConsistencyRules.validateComplaint(
          passingComplaint,
          passingEvents,
        ).any((v) => v.rule == 'visit_count_matches_arrived_events'),
        isFalse,
      );

      final failingComplaint = passingComplaint.copyWith(visitCount: 1);
      expect(
        ConsistencyRules.validateComplaint(
          failingComplaint,
          passingEvents,
        ).any((v) => v.rule == 'visit_count_matches_arrived_events'),
        isTrue,
      );
    });

    test('Rule 9: reopen_count_matches_reopened_events passing vs failing', () {
      final passingComplaint = baseComplaint(
        status: ComplaintStatus.reopened,
        reopenCount: 1,
      );
      final passingEvents = [
        ComplaintAuditEvent(
          id: 'e1',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_1',
          timestamp: t0,
        ),
        ComplaintAuditEvent(
          id: 'e2',
          complaintId: passingComplaint.id,
          eventType: ComplaintAuditEventType.complaintReopened,
          actorId: 'usr_1',
          timestamp: t1,
        ),
      ];

      expect(
        ConsistencyRules.validateComplaint(
          passingComplaint,
          passingEvents,
        ).any((v) => v.rule == 'reopen_count_matches_reopened_events'),
        isFalse,
      );

      final failingComplaint = passingComplaint.copyWith(reopenCount: 2);
      expect(
        ConsistencyRules.validateComplaint(
          failingComplaint,
          passingEvents,
        ).any((v) => v.rule == 'reopen_count_matches_reopened_events'),
        isTrue,
      );
    });
  });
}
