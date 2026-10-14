import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';

void main() {
  final validInput = CreateComplaintInput(
    title: 'Kitchen leak',
    description: 'Water is collecting below the sink.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    propertyId: 'property-1',
    unitId: 'unit-1',
    tenantId: 'tenant-1',
    submissionId: 'submission-1',
  );

  group('CreateComplaintInput', () {
    test('accepts a complete request', () {
      expect(validInput.validate(), isEmpty);
    });

    test('rejects blank required text and references', () {
      final invalid = CreateComplaintInput(
        title: '  ',
        description: '\n',
        category: ComplaintCategory.other,
        priority: ComplaintPriority.medium,
        propertyId: '',
        unitId: '  ',
        tenantId: '',
      );

      expect(invalid.validate(), hasLength(5));
      expect(invalid.validate(), contains('Complaint title is required.'));
      expect(invalid.validate(), contains('Tenant is required.'));
    });
  });

  group('Firestore complaint payloads', () {
    test('force OPEN and derive creator from the authenticated identity', () {
      final payload = ComplaintFirestorePayloads.complaintForCreate(
        validInput,
        'uid-42',
      );

      expect(payload['status'], 'open');
      expect(payload['createdBy'], 'uid-42');
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['updatedAt'], isA<FieldValue>());
      expect(payload, isNot(contains('id')));
    });

    test('creates a deterministic initial audit payload contract', () {
      final payload = ComplaintFirestorePayloads.auditForComplaintCreate(
        complaintId: 'submission-1',
        actorId: 'uid-42',
        category: 'plumbing',
        priority: 'high',
      );

      expect(payload['complaintId'], 'submission-1');
      expect(payload['eventType'], complaintCreatedEventType);
      expect(payload['actorId'], 'uid-42');
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['metadata'], containsPair('category', 'plumbing'));
    });
  });

  test('complaint model round-trips Firestore Timestamp dates', () {
    final createdAt = DateTime.utc(2026, 10, 9, 10, 15);
    final complaint = Complaint(
      id: 'complaint-1',
      tenantId: 'tenant-1',
      propertyId: 'property-1',
      unitId: 'unit-1',
      title: 'Kitchen leak',
      description: 'Water is collecting below the sink.',
      category: ComplaintCategory.plumbing,
      priority: ComplaintPriority.high,
      createdBy: 'uid-42',
      createdAt: createdAt,
    );

    final restored = Complaint.fromMap(
      complaint.toFirestoreMap(),
      id: complaint.id,
    );
    expect(restored.status, ComplaintStatus.open);
    expect(restored.createdBy, 'uid-42');
    expect(restored.createdAt, createdAt);
  });

  test('typed complaint failures expose safe user-facing messages', () {
    expect(
      const ComplaintAuthenticationException().message,
      contains('sign in'),
    );
    expect(
      const ComplaintPermissionException().message,
      contains('permission'),
    );
  });

  group('Complaint document mapping', () {
    test('Firestore document ID is treated as authoritative model ID', () {
      final docData = {
        'title': 'Power outage',
        'description': 'Main fuse tripped in apartment.',
        'propertyId': 'prop_001',
        'unitId': 'unit_101',
        'tenantId': 'ten_001',
        'category': 'electrical',
        'priority': 'urgent',
        'status': 'in_progress',
        'createdBy': 'user_abc',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 8, 12, 0)),
      };

      final complaint = Complaint.fromMap(docData, id: 'firestore_doc_999');
      expect(complaint.id, 'firestore_doc_999');
      expect(complaint.title, 'Power outage');
      expect(complaint.category, ComplaintCategory.electrical);
      expect(complaint.priority, ComplaintPriority.urgent);
      expect(complaint.status, ComplaintStatus.inProgress);
      expect(complaint.propertyId, 'prop_001');
      expect(complaint.unitId, 'unit_101');
      expect(complaint.tenantId, 'ten_001');
      expect(complaint.createdBy, 'user_abc');
      expect(complaint.createdAt, DateTime.utc(2026, 10, 8, 12, 0));
    });
  });

  group('Complaint repository stream', () {
    test('emits initial complaints and subsequent live updates', () async {
      final initialComplaint = Complaint(
        id: 'c_1',
        title: 'Initial issue',
        description: 'Details 1',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.medium,
        propertyId: 'prop_001',
        unitId: 'unit_101',
        tenantId: 'ten_001',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 1),
      );

      final repo = InMemoryComplaintRepository(
        initialComplaints: [initialComplaint],
      );

      final emissions = <List<Complaint>>[];
      final sub = repo.watchComplaints().listen(emissions.add);

      await pumpEventQueue();
      expect(emissions, hasLength(1));
      expect(emissions.first, hasLength(1));
      expect(emissions.first.first.id, 'c_1');

      final newComplaint = Complaint(
        id: 'c_2',
        title: 'Second issue',
        description: 'Details 2',
        category: ComplaintCategory.electrical,
        priority: ComplaintPriority.urgent,
        propertyId: 'prop_001',
        unitId: 'unit_101',
        tenantId: 'ten_001',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 2),
      );

      repo.addComplaint(newComplaint);
      await pumpEventQueue();

      expect(emissions, hasLength(2));
      expect(emissions.last, hasLength(2));
      // Predictable newest first order
      expect(emissions.last.first.id, 'c_2');
      expect(emissions.last.last.id, 'c_1');

      await sub.cancel();
      repo.dispose();
    });

    test('empty query results emit an empty list', () async {
      final repo = InMemoryComplaintRepository(initialComplaints: []);
      final stream = repo.watchComplaints();

      final first = await stream.first;
      expect(first, isEmpty);

      repo.dispose();
    });

    test('filters complaints by propertyId, unitId, and tenantId', () async {
      final c1 = Complaint(
        id: 'c_1',
        title: 'Prop 1 Unit 1',
        description: 'Issue 1',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.low,
        propertyId: 'prop_1',
        unitId: 'unit_1',
        tenantId: 'ten_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 1),
      );
      final c2 = Complaint(
        id: 'c_2',
        title: 'Prop 1 Unit 2',
        description: 'Issue 2',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.low,
        propertyId: 'prop_1',
        unitId: 'unit_2',
        tenantId: 'ten_2',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 2),
      );
      final c3 = Complaint(
        id: 'c_3',
        title: 'Prop 2 Unit 3',
        description: 'Issue 3',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.low,
        propertyId: 'prop_2',
        unitId: 'unit_3',
        tenantId: 'ten_3',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 3),
      );

      final repo = InMemoryComplaintRepository(initialComplaints: [c1, c2, c3]);

      final prop1Results = await repo
          .watchComplaints(propertyId: 'prop_1')
          .first;
      expect(prop1Results.map((c) => c.id), containsAll(['c_1', 'c_2']));
      expect(prop1Results.map((c) => c.id), isNot(contains('c_3')));

      final unit2Results = await repo.watchComplaints(unitId: 'unit_2').first;
      expect(unit2Results, hasLength(1));
      expect(unit2Results.first.id, 'c_2');

      final tenant3Results = await repo
          .watchComplaints(tenantId: 'ten_3')
          .first;
      expect(tenant3Results, hasLength(1));
      expect(tenant3Results.first.id, 'c_3');

      repo.dispose();
    });

    test('preserves all statuses including closed and cancelled', () async {
      final allStatuses = ComplaintStatus.values.map((status) {
        return Complaint(
          id: 'c_${status.name}',
          title: 'Issue ${status.displayLabel}',
          description: 'Desc',
          category: ComplaintCategory.other,
          priority: ComplaintPriority.medium,
          status: status,
          propertyId: 'prop_1',
          unitId: 'unit_1',
          tenantId: 'ten_1',
          createdBy: 'user_1',
          createdAt: DateTime.utc(2026, 10, 1),
        );
      }).toList();

      final repo = InMemoryComplaintRepository(initialComplaints: allStatuses);
      final results = await repo.watchComplaints().first;

      expect(results, hasLength(ComplaintStatus.values.length));
      for (final status in ComplaintStatus.values) {
        expect(results.any((c) => c.status == status), isTrue);
      }

      repo.dispose();
    });

    test(
      'stream errors propagate and do not silently fall back to fixtures',
      () async {
        final repo = InMemoryComplaintRepository(initialComplaints: []);
        final stream = repo.watchComplaints();

        var receivedError = false;
        final sub = stream.listen(
          (_) {},
          onError: (e) {
            receivedError = true;
          },
        );

        repo.emitError(const ComplaintFailure(ComplaintFailureCode.network));
        await pumpEventQueue();

        expect(receivedError, isTrue);

        await sub.cancel();
        repo.dispose();
      },
    );
  });

  group('Technician assigned complaints stream', () {
    test('rejects empty or whitespace technician identity', () {
      final repo = InMemoryComplaintRepository(initialComplaints: []);

      expect(
        () => repo.watchAssignedComplaints(technicianId: ''),
        throwsA(isA<ComplaintValidationException>()),
      );
      expect(
        () => repo.watchAssignedComplaints(technicianId: '   '),
        throwsA(isA<ComplaintValidationException>()),
      );

      repo.dispose();
    });

    test('filters by technicianId and excludes other technicians and terminal statuses', () async {
      const techA = 'tech_A';
      const techB = 'tech_B';

      final activeTechA = Complaint(
        id: 'c_active_a',
        title: 'Active Tech A',
        description: 'Desc',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.assigned,
        currentTechnicianId: techA,
        propertyId: 'prop_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 5),
      );

      final inProgressTechA = Complaint(
        id: 'c_prog_a',
        title: 'In Progress Tech A',
        description: 'Desc',
        category: ComplaintCategory.electrical,
        priority: ComplaintPriority.urgent,
        status: ComplaintStatus.inProgress,
        currentTechnicianId: techA,
        propertyId: 'prop_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 4),
      );

      final resolvedTechA = Complaint(
        id: 'c_res_a',
        title: 'Resolved Tech A',
        description: 'Desc',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.resolved,
        currentTechnicianId: techA,
        propertyId: 'prop_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 1),
      );

      final closedTechA = Complaint(
        id: 'c_closed_a',
        title: 'Closed Tech A',
        description: 'Desc',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.low,
        status: ComplaintStatus.closed,
        currentTechnicianId: techA,
        propertyId: 'prop_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 2),
      );

      final cancelledTechA = Complaint(
        id: 'c_canc_a',
        title: 'Cancelled Tech A',
        description: 'Desc',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.medium,
        status: ComplaintStatus.cancelled,
        currentTechnicianId: techA,
        propertyId: 'prop_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 3),
      );

      final activeTechB = Complaint(
        id: 'c_active_b',
        title: 'Active Tech B',
        description: 'Desc',
        category: ComplaintCategory.structural,
        priority: ComplaintPriority.urgent,
        status: ComplaintStatus.assigned,
        currentTechnicianId: techB,
        propertyId: 'prop_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 6),
      );

      final unassignedActive = Complaint(
        id: 'c_unassigned',
        title: 'Unassigned Active',
        description: 'Desc',
        category: ComplaintCategory.structural,
        priority: ComplaintPriority.urgent,
        status: ComplaintStatus.open,
        currentTechnicianId: null,
        propertyId: 'prop_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 7),
      );

      final repo = InMemoryComplaintRepository(
        initialComplaints: [
          activeTechA,
          inProgressTechA,
          resolvedTechA,
          closedTechA,
          cancelledTechA,
          activeTechB,
          unassignedActive,
        ],
      );

      final techAResults = await repo
          .watchAssignedComplaints(technicianId: techA)
          .first;

      expect(techAResults, hasLength(2));
      final ids = techAResults.map((c) => c.id).toList();
      expect(ids, containsAll(['c_active_a', 'c_prog_a']));
      expect(ids, isNot(contains('c_res_a')));
      expect(ids, isNot(contains('c_closed_a')));
      expect(ids, isNot(contains('c_canc_a')));
      expect(ids, isNot(contains('c_active_b')));
      expect(ids, isNot(contains('c_unassigned')));

      repo.dispose();
    });

    test('empty results emit an empty list', () async {
      final repo = InMemoryComplaintRepository(initialComplaints: []);
      final stream = repo.watchAssignedComplaints(technicianId: 'tech_none');

      final first = await stream.first;
      expect(first, isEmpty);

      repo.dispose();
    });

    test('stream updates reactively when new complaints are added', () async {
      const techId = 'tech_live';
      final repo = InMemoryComplaintRepository(initialComplaints: []);

      final emissions = <List<Complaint>>[];
      final sub = repo
          .watchAssignedComplaints(technicianId: techId)
          .listen(emissions.add);

      await pumpEventQueue();
      expect(emissions, hasLength(1));
      expect(emissions.first, isEmpty);

      final newAssigned = Complaint(
        id: 'c_live_1',
        title: 'New assignment',
        description: 'Details',
        category: ComplaintCategory.cleaning,
        priority: ComplaintPriority.medium,
        status: ComplaintStatus.assigned,
        currentTechnicianId: techId,
        propertyId: 'p_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 8),
      );

      repo.addComplaint(newAssigned);
      await pumpEventQueue();

      expect(emissions, hasLength(2));
      expect(emissions.last, hasLength(1));
      expect(emissions.last.first.id, 'c_live_1');

      await sub.cancel();
      repo.dispose();
    });

    test('stream errors propagate correctly', () async {
      final repo = InMemoryComplaintRepository(initialComplaints: []);
      final stream = repo.watchAssignedComplaints(technicianId: 'tech_err');

      var receivedError = false;
      final sub = stream.listen(
        (_) {},
        onError: (e) {
          receivedError = true;
        },
      );

      repo.emitError(const ComplaintFailure(ComplaintFailureCode.network));
      await pumpEventQueue();

      expect(receivedError, isTrue);

      await sub.cancel();
      repo.dispose();
    });

    test('deterministically sorts urgent -> high -> in-progress -> other active, and oldest date first', () async {
      const techId = 'tech_sort';

      final lowOther = Complaint(
        id: 'c_low_assigned',
        title: 'Low Assigned',
        description: 'Desc',
        category: ComplaintCategory.other,
        priority: ComplaintPriority.low,
        status: ComplaintStatus.assigned,
        currentTechnicianId: techId,
        propertyId: 'p_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 1),
      );

      final medOtherOld = Complaint(
        id: 'c_med_assigned_old',
        title: 'Medium Assigned Old',
        description: 'Desc',
        category: ComplaintCategory.other,
        priority: ComplaintPriority.medium,
        status: ComplaintStatus.assigned,
        currentTechnicianId: techId,
        propertyId: 'p_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 2),
      );

      final medOtherNew = Complaint(
        id: 'c_med_assigned_new',
        title: 'Medium Assigned New',
        description: 'Desc',
        category: ComplaintCategory.other,
        priority: ComplaintPriority.medium,
        status: ComplaintStatus.assigned,
        currentTechnicianId: techId,
        propertyId: 'p_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 5),
      );

      final inProgressLow = Complaint(
        id: 'c_prog_low',
        title: 'In Progress Low Priority',
        description: 'Desc',
        category: ComplaintCategory.other,
        priority: ComplaintPriority.low,
        status: ComplaintStatus.inProgress,
        currentTechnicianId: techId,
        propertyId: 'p_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 3),
      );

      final highAssigned = Complaint(
        id: 'c_high',
        title: 'High Assigned',
        description: 'Desc',
        category: ComplaintCategory.other,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.assigned,
        currentTechnicianId: techId,
        propertyId: 'p_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 4),
      );

      final urgentAssigned = Complaint(
        id: 'c_urgent',
        title: 'Urgent Assigned',
        description: 'Desc',
        category: ComplaintCategory.other,
        priority: ComplaintPriority.urgent,
        status: ComplaintStatus.assigned,
        currentTechnicianId: techId,
        propertyId: 'p_1',
        unitId: 'u_1',
        tenantId: 't_1',
        createdBy: 'user_1',
        createdAt: DateTime.utc(2026, 10, 6),
      );

      final repo = InMemoryComplaintRepository(
        initialComplaints: [
          lowOther,
          medOtherNew,
          medOtherOld,
          inProgressLow,
          highAssigned,
          urgentAssigned,
        ],
      );

      final results = await repo
          .watchAssignedComplaints(technicianId: techId)
          .first;

      final ids = results.map((c) => c.id).toList();
      expect(ids, [
        'c_urgent', // Tier 0: Urgent
        'c_high', // Tier 1: High
        'c_prog_low', // Tier 2: In-progress
        'c_med_assigned_old', // Tier 3: Medium (older: Oct 2)
        'c_med_assigned_new', // Tier 3: Medium (newer: Oct 5)
        'c_low_assigned', // Tier 4: Low
      ]);

      repo.dispose();
    });
  });
}
