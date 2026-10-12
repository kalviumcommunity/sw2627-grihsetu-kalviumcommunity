import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/technician_assignment.dart';
import 'package:grihsetu/core/models/user.dart';
import 'package:grihsetu/services/technician_assignment_service.dart';

void main() {
  Complaint complaint({
    ComplaintStatus status = ComplaintStatus.open,
    String? currentTechnicianId,
    DateTime? firstAssignedAt,
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
    currentTechnicianId: currentTechnicianId,
    createdBy: 'actor-1',
    firstAssignedAt: firstAssignedAt,
  );

  AppUser profile({required UserRole role, bool isActive = true}) => AppUser(
    id: 'profile-1',
    name: 'Profile',
    email: 'profile@example.com',
    role: role,
    isActive: isActive,
    createdAt: null,
  );

  group('assignment policy', () {
    test(
      'allows the first assignment only for an unassigned OPEN complaint',
      () {
        expect(
          TechnicianAssignmentPolicy.validateInitialAssignment(
            complaint(),
            'tech-1',
          ),
          TechnicianAssignmentType.initialAssignment,
        );
      },
    );

    test(
      'rejects first assignment for an invalid status or assigned complaint',
      () {
        expect(
          () => TechnicianAssignmentPolicy.validateInitialAssignment(
            complaint(status: ComplaintStatus.inProgress),
            'tech-1',
          ),
          throwsA(
            isA<TechnicianAssignmentFailure>().having(
              (failure) => failure.code,
              'code',
              TechnicianAssignmentFailureCode.invalidStatus,
            ),
          ),
        );
        expect(
          () => TechnicianAssignmentPolicy.validateInitialAssignment(
            complaint(currentTechnicianId: 'tech-old'),
            'tech-1',
          ),
          throwsA(
            isA<TechnicianAssignmentFailure>().having(
              (failure) => failure.code,
              'code',
              TechnicianAssignmentFailureCode.conflict,
            ),
          ),
        );
      },
    );

    test('allows reassignment without resetting an in-progress status', () {
      final existing = complaint(
        status: ComplaintStatus.inProgress,
        currentTechnicianId: 'tech-old',
        firstAssignedAt: DateTime.utc(2026, 10, 1),
      );

      expect(
        TechnicianAssignmentPolicy.validateReassignment(existing, 'tech-new'),
        TechnicianAssignmentType.reassignment,
      );
      final updated = existing.copyWith(currentTechnicianId: 'tech-new');
      expect(updated.status, ComplaintStatus.inProgress);
      expect(updated.firstAssignedAt, existing.firstAssignedAt);
    });

    test('rejects same-technician, completed, and cancelled reassignments', () {
      expect(
        () => TechnicianAssignmentPolicy.validateReassignment(
          complaint(
            status: ComplaintStatus.assigned,
            currentTechnicianId: 'tech-old',
          ),
          'tech-old',
        ),
        throwsA(
          isA<TechnicianAssignmentFailure>().having(
            (failure) => failure.code,
            'code',
            TechnicianAssignmentFailureCode.sameTechnician,
          ),
        ),
      );
      for (final status in [
        ComplaintStatus.resolved,
        ComplaintStatus.closed,
        ComplaintStatus.cancelled,
      ]) {
        expect(
          () => TechnicianAssignmentPolicy.validateReassignment(
            complaint(status: status, currentTechnicianId: 'tech-old'),
            'tech-new',
          ),
          throwsA(
            isA<TechnicianAssignmentFailure>().having(
              (failure) => failure.code,
              'code',
              TechnicianAssignmentFailureCode.invalidStatus,
            ),
          ),
        );
      }
    });

    test('accepts only active technician targets and operational actors', () {
      expect(
        () => TechnicianAssignmentPolicy.validateActor(
          profile(role: UserRole.technician),
        ),
        throwsA(isA<TechnicianAssignmentFailure>()),
      );
      expect(
        () => TechnicianAssignmentPolicy.validateActor(
          profile(role: UserRole.propertyOperations),
        ),
        returnsNormally,
      );
      expect(
        () => TechnicianAssignmentPolicy.validateTechnician(
          profile(role: UserRole.propertyOperations),
        ),
        throwsA(isA<TechnicianAssignmentFailure>()),
      );
      expect(
        () => TechnicianAssignmentPolicy.validateTechnician(
          profile(role: UserRole.technician, isActive: false),
        ),
        throwsA(isA<TechnicianAssignmentFailure>()),
      );
      expect(
        () => TechnicianAssignmentPolicy.validateTechnician(
          profile(role: UserRole.technician),
        ),
        returnsNormally,
      );
    });
  });

  group('assignment persistence payloads', () {
    test('uses server timestamps and preserves the previous technician', () {
      final history = TechnicianAssignmentFirestorePayloads.history(
        complaintId: 'complaint-1',
        previousTechnicianId: 'tech-old',
        newTechnicianId: 'tech-new',
        actorId: 'actor-1',
        assignmentType: TechnicianAssignmentType.reassignment,
        operationId: 'operation-1',
        reason: 'Coverage change',
      );
      final audit = TechnicianAssignmentFirestorePayloads.audit(
        complaintId: 'complaint-1',
        actorId: 'actor-1',
        previousTechnicianId: 'tech-old',
        newTechnicianId: 'tech-new',
        assignmentType: TechnicianAssignmentType.reassignment,
        operationId: 'operation-1',
      );

      expect(history['assignedAt'], isA<FieldValue>());
      expect(history['previousTechnicianId'], 'tech-old');
      expect(history['newTechnicianId'], 'tech-new');
      expect(history['assignmentType'], 'REASSIGNMENT');
      expect(audit['eventType'], technicianReassignedEventType);
      expect(
        audit['metadata'],
        containsPair('previousTechnicianId', 'tech-old'),
      );
      expect(audit['createdAt'], isA<FieldValue>());
    });

    test('initial audit explicitly stores a null previous technician', () {
      final audit = TechnicianAssignmentFirestorePayloads.audit(
        complaintId: 'complaint-1',
        actorId: 'actor-1',
        previousTechnicianId: null,
        newTechnicianId: 'tech-new',
        assignmentType: TechnicianAssignmentType.initialAssignment,
        operationId: 'operation-1',
      );

      expect(audit['eventType'], technicianAssignedEventType);
      expect(audit['metadata'], containsPair('previousTechnicianId', null));
    });
  });
}
