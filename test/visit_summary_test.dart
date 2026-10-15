import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/maintenance_visit_outcome.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/maintenance_visit.dart';
import 'package:grihsetu/screens/complaints/detail/complaint_detail_models.dart';

void main() {
  Complaint buildComplaint({
    String id = 'cmp_test',
    int visitCount = 0,
    int reopenCount = 0,
  }) {
    return Complaint(
      id: id,
      tenantId: 'ten_001',
      propertyId: 'prop_001',
      unitId: 'unit_101',
      title: 'Water pipe leak',
      description: 'Leak in bathroom pipe',
      category: ComplaintCategory.plumbing,
      priority: ComplaintPriority.high,
      status: ComplaintStatus.open,
      createdBy: 'ten_001',
      visitCount: visitCount,
      reopenCount: reopenCount,
    );
  }

  MaintenanceVisit buildVisit({
    required String id,
    required int visitNumber,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return MaintenanceVisit(
      id: id,
      complaintId: 'cmp_test',
      technicianId: 'tech_001',
      visitNumber: visitNumber,
      startedAt: startedAt,
      completedAt: completedAt,
      observation: 'Observation for $id',
      actionTaken: 'Repairs for $id',
      outcome: MaintenanceVisitOutcome.resolved,
      isResolved: completedAt != null,
      followUpRequired: false,
      followUpNotes: null,
      resolutionSummary: 'Completed',
      operationId: 'op_$id',
    );
  }

  group('VisitSummary - Domain Logic Derivations', () {
    test('derives empty summary when no visits, events, or complaint records exist', () {
      final summary = VisitSummary.from();

      expect(summary.totalVisits, 0);
      expect(summary.lastVisitDate, isNull);
      expect(summary.isRepeat, isFalse);
      expect(summary.repeatVisitsCount, 0);
      expect(summary.reopenCount, 0);
      expect(summary.isVisitInProgress, isFalse);
      expect(summary.repeatStatusLabel, 'No visits');
    });

    test('derives single completed visit correctly', () {
      final visit = buildVisit(
        id: 'visit_1',
        visitNumber: 1,
        startedAt: DateTime.utc(2026, 10, 10, 9, 0),
        completedAt: DateTime.utc(2026, 10, 10, 10, 30),
      );

      final summary = VisitSummary.from(
        complaint: buildComplaint(visitCount: 1),
        visits: [visit],
      );

      expect(summary.totalVisits, 1);
      expect(summary.lastVisitDate, DateTime.utc(2026, 10, 10, 10, 30));
      expect(summary.isRepeat, isFalse);
      expect(summary.repeatVisitsCount, 0);
      expect(summary.isVisitInProgress, isFalse);
      expect(summary.repeatStatusLabel, 'First visit');
    });

    test(
      'derives in-progress visit using startedAt when completedAt is null',
      () {
        final visit = buildVisit(
          id: 'visit_active',
          visitNumber: 1,
          startedAt: DateTime.utc(2026, 10, 12, 14, 0),
          completedAt: null,
        );

        final summary = VisitSummary.from(
          complaint: buildComplaint(visitCount: 1),
          visits: [visit],
        );

        expect(summary.totalVisits, 1);
        expect(summary.lastVisitDate, DateTime.utc(2026, 10, 12, 14, 0));
        expect(summary.isVisitInProgress, isTrue);
      },
    );

    test(
      'handles missing start and completion timestamps without crashing',
      () {
        final visit = buildVisit(
          id: 'visit_missing_dates',
          visitNumber: 1,
          startedAt: null,
          completedAt: null,
        );

        final summary = VisitSummary.from(
          complaint: buildComplaint(visitCount: 1),
          visits: [visit],
        );

        expect(summary.totalVisits, 1);
        expect(summary.lastVisitDate, isNull);
      },
    );

    test(
      'determines latest visit chronologically regardless of list ordering',
      () {
        final visitEarlier = buildVisit(
          id: 'visit_early',
          visitNumber: 1,
          startedAt: DateTime.utc(2026, 10, 5, 9, 0),
          completedAt: DateTime.utc(2026, 10, 5, 11, 0),
        );
        final visitMiddle = buildVisit(
          id: 'visit_mid',
          visitNumber: 2,
          startedAt: DateTime.utc(2026, 10, 10, 9, 0),
          completedAt: DateTime.utc(2026, 10, 10, 11, 0),
        );
        final visitLatest = buildVisit(
          id: 'visit_late',
          visitNumber: 3,
          startedAt: DateTime.utc(2026, 10, 14, 15, 0),
          completedAt: DateTime.utc(2026, 10, 14, 17, 0),
        );

        // Supply non-chronological list: middle, latest, earlier
        final summary = VisitSummary.from(
          complaint: buildComplaint(visitCount: 3),
          visits: [visitMiddle, visitLatest, visitEarlier],
        );

        expect(summary.totalVisits, 3);
        expect(summary.lastVisitDate, DateTime.utc(2026, 10, 14, 17, 0));
        expect(summary.isRepeat, isTrue);
        expect(summary.repeatVisitsCount, 2);
        expect(summary.repeatStatusLabel, 'Repeat (2 follow-ups)');
      },
    );

    test('legacy audit-event fallback derives count and date when visits list is empty', () {
      final events = [
        ActivityEvent(
          id: 'evt_created',
          complaintId: 'cmp_test',
          type: ActivityEventType.created,
          actorId: 'ten_001',
          actorName: 'Tenant',
          actorRole: 'Tenant',
          timestamp: DateTime.utc(2026, 10, 1, 8, 0),
        ),
        ActivityEvent(
          id: 'evt_arrived_1',
          complaintId: 'cmp_test',
          type: ActivityEventType.arrived,
          actorId: 'tech_001',
          actorName: 'Aman',
          actorRole: 'Technician',
          timestamp: DateTime.utc(2026, 10, 2, 10, 0),
        ),
        ActivityEvent(
          id: 'evt_arrived_2',
          complaintId: 'cmp_test',
          type: ActivityEventType.arrived,
          actorId: 'tech_001',
          actorName: 'Aman',
          actorRole: 'Technician',
          timestamp: DateTime.utc(2026, 10, 8, 14, 0),
        ),
      ];

      final summary = VisitSummary.from(
        complaint: buildComplaint(visitCount: 2),
        visits: const [],
        events: events,
      );

      expect(summary.totalVisits, 2);
      expect(summary.lastVisitDate, DateTime.utc(2026, 10, 8, 14, 0));
      expect(summary.isRepeat, isTrue);
      expect(summary.repeatVisitsCount, 1);
    });

    test('deduplication: audit events do NOT inflate count when canonical visits exist', () {
      final visits = [
        buildVisit(
          id: 'visit_1',
          visitNumber: 1,
          startedAt: DateTime.utc(2026, 10, 10, 9, 0),
          completedAt: DateTime.utc(2026, 10, 10, 11, 0),
        ),
      ];

      final duplicateEvents = [
        ActivityEvent(
          id: 'evt_arrived_1',
          complaintId: 'cmp_test',
          type: ActivityEventType.arrived,
          actorId: 'tech_001',
          actorName: 'Aman',
          actorRole: 'Technician',
          timestamp: DateTime.utc(2026, 10, 10, 9, 0),
        ),
        ActivityEvent(
          id: 'evt_arrived_duplicate',
          complaintId: 'cmp_test',
          type: ActivityEventType.arrived,
          actorId: 'tech_001',
          actorName: 'Aman',
          actorRole: 'Technician',
          timestamp: DateTime.utc(2026, 10, 10, 9, 5),
        ),
      ];

      final summary = VisitSummary.from(
        complaint: buildComplaint(visitCount: 1),
        visits: visits,
        events: duplicateEvents,
      );

      // Canonical visits (1) takes strict precedence over duplicate event count (2)
      expect(summary.totalVisits, 1);
      expect(summary.isRepeat, isFalse);
      expect(summary.repeatVisitsCount, 0);
    });

    test('reopened complaints flag repeat status even with single visit', () {
      final visit = buildVisit(
        id: 'visit_1',
        visitNumber: 1,
        startedAt: DateTime.utc(2026, 10, 10, 9, 0),
        completedAt: DateTime.utc(2026, 10, 10, 10, 0),
      );

      final summary = VisitSummary.from(
        complaint: buildComplaint(visitCount: 1, reopenCount: 1),
        visits: [visit],
      );

      expect(summary.totalVisits, 1);
      expect(summary.isRepeat, isTrue);
      expect(summary.repeatVisitsCount, 0);
      expect(summary.reopenCount, 1);
      expect(summary.repeatStatusLabel, 'Reopened (1)');
    });

    test('ComplaintDetailState exposes visitSummary and derived getters accurately', () {
      final visit = buildVisit(
        id: 'visit_state_test',
        visitNumber: 1,
        startedAt: DateTime.utc(2026, 10, 15, 10, 0),
        completedAt: DateTime.utc(2026, 10, 15, 11, 30),
      );

      final state = ComplaintDetailState(
        status: ComplaintDetailStatus.data,
        complaint: buildComplaint(visitCount: 1),
        visits: [visit],
      );

      expect(state.visitSummary.totalVisits, 1);
      expect(state.lastVisitDate, DateTime.utc(2026, 10, 15, 11, 30));
      expect(state.repeatVisitsCount, 0);
    });
  });
}
