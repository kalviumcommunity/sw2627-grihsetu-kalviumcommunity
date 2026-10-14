import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/maintenance_visit_outcome.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/maintenance_visit.dart';
import 'package:grihsetu/services/maintenance_visit_service.dart';

void main() {
  Complaint complaint({
    ComplaintStatus status = ComplaintStatus.assigned,
    String? activeVisitId,
    int visitCount = 0,
  }) => Complaint(
    id: 'complaint-1',
    tenantId: 'tenant-1',
    propertyId: 'property-1',
    unitId: 'unit-1',
    title: 'Leaking tap',
    description: 'The kitchen tap is leaking.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    status: status,
    currentTechnicianId: 'tech-1',
    activeVisitId: activeVisitId,
    visitCount: visitCount,
    createdBy: 'ops-1',
  );

  group('maintenance visit policy', () {
    test('first start is allowed for the assigned technician', () {
      expect(
        () => MaintenanceVisitPolicy.validateStart(
          complaint: complaint(),
          actorId: 'tech-1',
          hasActiveVisit: false,
        ),
        returnsNormally,
      );
    });

    test(
      'rejects an active visit, terminal complaint, and wrong technician',
      () {
        expect(
          () => MaintenanceVisitPolicy.validateStart(
            complaint: complaint(activeVisitId: 'visit-1'),
            actorId: 'tech-1',
            hasActiveVisit: true,
          ),
          throwsA(
            isA<MaintenanceVisitFailure>().having(
              (failure) => failure.code,
              'code',
              MaintenanceVisitFailureCode.duplicateActiveVisit,
            ),
          ),
        );
        expect(
          () => MaintenanceVisitPolicy.validateStart(
            complaint: complaint(status: ComplaintStatus.resolved),
            actorId: 'tech-1',
            hasActiveVisit: false,
          ),
          throwsA(isA<MaintenanceVisitFailure>()),
        );
        expect(
          () => MaintenanceVisitPolicy.validateStart(
            complaint: complaint(),
            actorId: 'tech-2',
            hasActiveVisit: false,
          ),
          throwsA(
            isA<MaintenanceVisitFailure>().having(
              (failure) => failure.code,
              'code',
              MaintenanceVisitFailureCode.unauthorized,
            ),
          ),
        );
      },
    );

    test('maps only documented outcomes to existing complaint statuses', () {
      expect(
        MaintenanceVisitPolicy.statusForOutcome(
          MaintenanceVisitOutcome.resolved,
        ),
        ComplaintStatus.resolved,
      );
      expect(
        MaintenanceVisitPolicy.statusForOutcome(
          MaintenanceVisitOutcome.unresolved,
        ),
        ComplaintStatus.inProgress,
      );
      expect(
        MaintenanceVisitPolicy.statusForOutcome(
          MaintenanceVisitOutcome.waitingForParts,
        ),
        ComplaintStatus.waitingForParts,
      );
    });

    test('requires completion details and matching resolution state', () {
      expect(
        () => MaintenanceVisitPolicy.validateCompletion(
          observation: '',
          actionTaken: 'Repaired',
          outcome: MaintenanceVisitOutcome.resolved,
          isResolved: true,
          followUpRequired: false,
        ),
        throwsA(isA<MaintenanceVisitFailure>()),
      );
      expect(
        () => MaintenanceVisitPolicy.validateCompletion(
          observation: 'Found leak',
          actionTaken: 'Repaired',
          outcome: MaintenanceVisitOutcome.unresolved,
          isResolved: true,
          followUpRequired: false,
        ),
        throwsA(
          isA<MaintenanceVisitFailure>().having(
            (failure) => failure.code,
            'code',
            MaintenanceVisitFailureCode.unsupportedOutcome,
          ),
        ),
      );
      expect(
        () => MaintenanceVisitPolicy.validateCompletion(
          observation: 'Needs a replacement part',
          actionTaken: 'Isolated the pipe',
          outcome: MaintenanceVisitOutcome.waitingForParts,
          isResolved: false,
          followUpRequired: true,
        ),
        throwsA(
          isA<MaintenanceVisitFailure>().having(
            (failure) => failure.code,
            'code',
            MaintenanceVisitFailureCode.missingCompletionInformation,
          ),
        ),
      );
    });
  });

  group('maintenance visit persistence payloads', () {
    test(
      'start payload allocates a server timestamp and blank active fields',
      () {
        final payload = MaintenanceVisitFirestorePayloads.start(
          complaintId: 'complaint-1',
          technicianId: 'tech-1',
          visitNumber: 1,
          operationId: 'op-1',
        );
        expect(payload['startedAt'], isA<FieldValue>());
        expect(payload['completedAt'], isNull);
        expect(payload['visitNumber'], 1);
        expect(payload['operationId'], 'op-1');
      },
    );

    test('completed visits deserialize and preserve historical fields', () {
      final visit = MaintenanceVisit.fromMap({
        'complaintId': 'complaint-1',
        'technicianId': 'tech-1',
        'visitNumber': 2,
        'startedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
        'completedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 1)),
        'observation': 'A worn seal',
        'actionTaken': 'Replaced seal',
        'outcome': 'resolved',
        'isResolved': true,
        'followUpRequired': false,
        'followUpNotes': null,
        'resolutionSummary': 'Tap no longer leaks',
        'operationId': 'op-2',
      }, id: 'visit-2');
      expect(visit.visitNumber, 2);
      expect(visit.outcome, MaintenanceVisitOutcome.resolved);
      expect(visit.isActive, isFalse);
      expect(visit.observation, 'A worn seal');
      expect(visit.resolutionSummary, 'Tap no longer leaks');
    });
  });
}
