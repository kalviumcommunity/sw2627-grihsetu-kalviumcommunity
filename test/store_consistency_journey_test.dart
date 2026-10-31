import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_audit_event_type.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/complaint_audit_event.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/services/errors/app_failure.dart';
import 'package:grihsetu/utils/app_clock.dart';
import 'package:grihsetu/utils/attention_rules.dart';
import 'package:grihsetu/utils/complaint_query.dart';
import 'package:grihsetu/utils/consistency_rules.dart';
import 'package:grihsetu/utils/property_metrics.dart';

void main() {
  group('Store writes hardening & End-to-end journey', () {
    late SteppingClock clock;
    late ComplaintStore store;

    const testProperty = Property(
      id: 'prop_j',
      name: 'Journey Heights',
      address: '100 Audit Trail Way',
    );

    final sampleUnits = [
      const Unit(
        id: 'unit_j_1',
        propertyId: 'prop_j',
        unitNumber: '101',
        occupancyStatus: 'occupied',
      ),
    ];

    final rentRecord = RentRecord(
      id: 'rent_j_1',
      tenantId: 'ten_j_1',
      propertyId: 'prop_j',
      unitId: 'unit_j_1',
      month: 'October 2026',
      amountDue: 22000.0,
      dueDate: DateTime(2026, 10, 5),
      status: RentStatus.paid,
    );

    setUp(() {
      clock = SteppingClock(
        DateTime(2026, 10, 10, 8, 0),
        step: const Duration(minutes: 30),
      );
      AppClock.current = clock;
      store = ComplaintStore(
        initialComplaints: const [],
        initialEvents: const {},
        clock: clock,
      );
      ComplaintStore.instance = store;
    });

    tearDown(() {
      ComplaintStore.resetInstance();
      AppClock.reset();
    });

    test('stale write returns ConflictFailure when version does not match', () {
      final initialTime = clock.now();
      const complaintId = 'cmp_concurrency';

      // 1. Initial write
      store.transactionWrite(
        complaintId: complaintId,
        mutation: (_) => Complaint(
          id: complaintId,
          tenantId: 'ten_1',
          propertyId: 'prop_j',
          unitId: 'unit_1',
          title: 'Concurrency test',
          description: 'Version test',
          category: ComplaintCategory.plumbing,
          priority: ComplaintPriority.medium,
          status: ComplaintStatus.open,
          createdBy: 'usr_1',
          createdAt: initialTime,
        ),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_init',
            complaintId: complaintId,
            eventType: ComplaintAuditEventType.complaintCreated,
            actorId: 'usr_1',
            timestamp: initialTime,
          ),
        ],
      );

      final versionAfterFirstWrite = store.getVersion(complaintId);
      expect(versionAfterFirstWrite, 2);

      // 2. Stale write with expectedVersion: 1 must fail with ConflictFailure
      expect(
        () => store.transactionWrite(
          complaintId: complaintId,
          expectedVersion: 1, // Stale! Current version is 2
          mutation: (curr) =>
              curr!.copyWith(description: 'Stale update that should conflict'),
        ),
        throwsA(isA<ConflictFailure>()),
      );

      // Verify state was not modified
      expect(store.getById(complaintId)!.description, 'Version test');
    });

    test('double submit with idempotency key is idempotent', () {
      final t = clock.now();
      const complaintId = 'cmp_idempotent';
      const idempotencyKey = 'key_submit_unique_123';

      Complaint buildComplaint() => Complaint(
        id: complaintId,
        tenantId: 'ten_1',
        propertyId: 'prop_j',
        unitId: 'unit_1',
        title: 'Idempotency title',
        description: 'Description',
        category: ComplaintCategory.electrical,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.open,
        createdBy: 'usr_1',
        createdAt: t,
      );

      // 1. First submit
      final firstResult = store.transactionWrite(
        complaintId: complaintId,
        idempotencyKey: idempotencyKey,
        mutation: (_) => buildComplaint(),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_create_1',
            complaintId: complaintId,
            eventType: ComplaintAuditEventType.complaintCreated,
            actorId: 'usr_1',
            timestamp: t,
          ),
        ],
      );

      expect(store.snapshot.length, 1);
      expect(store.getEvents(complaintId).length, 1);

      // 2. Second submit with same idempotency key
      final secondResult = store.transactionWrite(
        complaintId: complaintId,
        idempotencyKey: idempotencyKey,
        mutation: (_) => buildComplaint(),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_create_dup',
            complaintId: complaintId,
            eventType: ComplaintAuditEventType.complaintCreated,
            actorId: 'usr_1',
            timestamp: clock.now(),
          ),
        ],
      );

      expect(secondResult.id, firstResult.id);
      expect(store.snapshot.length, 1);
      // Still only one event!
      expect(store.getEvents(complaintId).length, 1);
    });

    test('End-to-end journey: create -> assign -> accept -> arrive -> inspect -> repair -> resolve -> confirm -> close -> reopen', () {
      const cmpId = 'cmp_journey_001';
      final rentRecords = [rentRecord];

      void assertAllScreensAgree({
        required ComplaintStatus expectedStatus,
        required String? expectedTechnicianId,
        required int expectedVisits,
        required int expectedReopens,
      }) {
        // 1. List snapshot
        final allComplaints = store.snapshot;
        expect(allComplaints.length, 1);
        final complaint = allComplaints.first;
        expect(complaint.status, expectedStatus);
        expect(complaint.currentTechnicianId, expectedTechnicianId);
        expect(complaint.visitCount, expectedVisits);
        expect(complaint.reopenCount, expectedReopens);

        // 2. Detail
        final detail = store.getById(cmpId);
        expect(detail, isNotNull);
        expect(detail!.status, expectedStatus);

        // 3. Search count by filter
        final statusFilter = ComplaintFilter(statuses: {expectedStatus});
        expect(applyFilter(allComplaints, statusFilter).length, 1);

        // 4. Dashboard attention rules
        final attention = analyzeAttention(
          complaints: allComplaints,
          rentRecords: rentRecords,
          now: clock.now(),
        );
        for (final item in attention.items.where(
          (item) => item.matchedComplaints.any((match) => match.id == cmpId),
        )) {
          expect(item.targetFilter, isNotNull);
          expect(
            applyFilter(allComplaints, item.targetFilter!).map((c) => c.id),
            contains(cmpId),
          );
        }

        // 5. Property summary
        final summary = calculatePropertySummary(
          property: testProperty,
          units: sampleUnits,
          complaints: allComplaints,
          rentRecords: rentRecords,
          periodDays: 30,
          now: clock.now(),
        );
        expect(summary.totalUnits, 1);
        expect(summary.occupiedUnits, 1);
        expect(summary.collectionRate, 100.0);
        expect(rentRecords.single.propertyId, complaint.propertyId);
        expect(rentRecords.single.unitId, complaint.unitId);
        expect(rentRecords.single.tenantId, complaint.tenantId);
        expect(rentRecords.single.status, RentStatus.paid);

        if (expectedStatus.isActive) {
          expect(summary.openComplaints, 1);
        } else if (expectedStatus == ComplaintStatus.resolved ||
            expectedStatus == ComplaintStatus.closed) {
          expect(summary.resolvedInPeriod, 1);
        }

        // 6. Consistency rules must return 0 violations
        final violations = ConsistencyRules.validateComplaint(
          complaint,
          store.getEvents(cmpId),
        );
        expect(
          violations,
          isEmpty,
          reason:
              'Violations found: ${violations.map((v) => "${v.rule}: ${v.detail}").join(", ")}',
        );
      }

      // Step 1: CREATE
      final tCreate = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (_) => Complaint(
          id: cmpId,
          tenantId: 'ten_j_1',
          propertyId: testProperty.id,
          unitId: 'unit_j_1',
          title: 'Kitchen sink pipe burst',
          description: 'Water spraying inside cabinet',
          category: ComplaintCategory.plumbing,
          priority: ComplaintPriority.urgent,
          status: ComplaintStatus.open,
          createdBy: 'ten_j_1',
          createdAt: tCreate,
        ),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_01_create',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.complaintCreated,
            actorId: 'ten_j_1',
            timestamp: tCreate,
            details: {'category': 'plumbing', 'priority': 'urgent'},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.open,
        expectedTechnicianId: null,
        expectedVisits: 0,
        expectedReopens: 0,
      );

      // Step 2: ASSIGN
      final tAssign = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) => c!.copyWith(
          status: ComplaintStatus.assigned,
          currentTechnicianId: 'tech_aman',
          firstAssignedAt: tAssign,
        ),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_02_assign',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.technicianAssigned,
            actorId: 'usr_staff_riya',
            timestamp: tAssign,
            details: {'newTechnicianId': 'tech_aman'},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.assigned,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 0,
        expectedReopens: 0,
      );

      // Step 3: ACCEPT
      final tAccept = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) => c!,
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_03_accept',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.technicianAccepted,
            actorId: 'tech_aman',
            timestamp: tAccept,
            details: {'accepted': true},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.assigned,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 0,
        expectedReopens: 0,
      );

      // Step 4: ARRIVE
      final tArrive = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) =>
            c!.copyWith(status: ComplaintStatus.inProgress, visitCount: 1),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_04_arrive',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.technicianArrived,
            actorId: 'tech_aman',
            timestamp: tArrive,
            details: {'visitNumber': 1},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.inProgress,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 1,
        expectedReopens: 0,
      );

      // Step 5: INSPECT
      final tInspect = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) => c!,
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_05_inspect',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.inspectionStarted,
            actorId: 'tech_aman',
            timestamp: tInspect,
            details: {'notes': 'Found fractured PVC coupling'},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.inProgress,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 1,
        expectedReopens: 0,
      );

      // Step 6: REPAIR
      final tRepair = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) => c!,
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_06_repair',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.repairStarted,
            actorId: 'tech_aman',
            timestamp: tRepair,
            details: {'notes': 'Fitting new PVC junction pipe'},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.inProgress,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 1,
        expectedReopens: 0,
      );

      // Step 7: RESOLVE
      final tResolve = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) =>
            c!.copyWith(status: ComplaintStatus.resolved, resolvedAt: tResolve),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_07_resolve',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.complaintResolved,
            actorId: 'tech_aman',
            timestamp: tResolve,
            details: {'outcome': 'repaired'},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.resolved,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 1,
        expectedReopens: 0,
      );

      // Step 8: TENANT CONFIRM
      final tConfirm = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) => c!,
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_08_confirm',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.tenantNotified,
            actorId: 'ten_j_1',
            timestamp: tConfirm,
            details: {'confirmedWorking': true},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.resolved,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 1,
        expectedReopens: 0,
      );

      // Step 9: CLOSE
      final tClose = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) => c!.copyWith(
          status: ComplaintStatus.closed,
          closedAt: tClose,
          closedBy: 'usr_staff_riya',
        ),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_09_close',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.complaintClosed,
            actorId: 'usr_staff_riya',
            timestamp: tClose,
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.closed,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 1,
        expectedReopens: 0,
      );

      // Step 10: REOPEN
      final tReopen = clock.now();
      store.transactionWrite(
        complaintId: cmpId,
        mutation: (c) => c!.copyWith(
          status: ComplaintStatus.reopened,
          reopenedAt: tReopen,
          reopenedBy: 'ten_j_1',
          reopenReason: 'Small drip still visible under high pressure',
          reopenCount: 1,
        ),
        newEvents: [
          ComplaintAuditEvent(
            id: 'evt_10_reopen',
            complaintId: cmpId,
            eventType: ComplaintAuditEventType.complaintReopened,
            actorId: 'ten_j_1',
            timestamp: tReopen,
            details: {'reason': 'Small drip still visible'},
          ),
        ],
      );
      assertAllScreensAgree(
        expectedStatus: ComplaintStatus.reopened,
        expectedTechnicianId: 'tech_aman',
        expectedVisits: 1,
        expectedReopens: 1,
      );
    });
  });
}
