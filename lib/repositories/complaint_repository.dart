import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/enums/complaint_audit_event_type.dart';
import '../core/enums/complaint_priority.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/maintenance_visit_outcome.dart';
import '../core/enums/user_role.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';
import '../core/models/complaint_audit_event.dart';
import '../core/models/maintenance_visit.dart';
import '../core/models/user.dart';
import '../services/auth_service.dart';
import '../services/complaint_audit_service.dart';
import '../services/maintenance_visit_service.dart';
import '../services/technician_assignment_service.dart';
import '../screens/technician/visit/visit_models.dart';
import '../utils/visit_validators.dart';

const String complaintCreatedEventType = 'COMPLAINT_CREATED';

/// Canonical server-write payloads shared by the repository and tests.
abstract final class ComplaintFirestorePayloads {
  static Map<String, dynamic> complaintForCreate(
    CreateComplaintInput input,
    String actorId,
  ) => {
    'tenantId': input.tenantId.trim(),
    'propertyId': input.propertyId.trim(),
    'unitId': input.unitId.trim(),
    'title': input.title.trim(),
    'description': input.description.trim(),
    'category': input.category.value,
    'priority': input.priority.value,
    'status': ComplaintStatus.open.value,
    'visitCount': 0,
    'isRepeatVisit': false,
    'reopenCount': 0,
    'createdBy': actorId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Map<String, dynamic> auditForComplaintCreate({
    required String complaintId,
    required String actorId,
    required String category,
    required String priority,
    UserRole? actorRole,
  }) => {
    ...ComplaintAuditWriter.buildPayload(
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.complaintCreated,
      actorId: actorId,
      actorRole: actorRole?.value,
      details: {'category': category, 'priority': priority},
      schemaVersion: actorRole == null ? null : 1,
    ),
  };
}

enum ComplaintFailureCode {
  validation,
  unauthenticated,
  permissionDenied,
  notFound,
  network,
  conflict,
  malformedData,
  write,
  unknown,
}

/// Typed, user-safe complaint workflow failure.
class ComplaintFailure implements Exception {
  const ComplaintFailure(this.code, [this.details]);

  final ComplaintFailureCode code;
  final String? details;

  String get message =>
      details ??
      switch (code) {
        ComplaintFailureCode.validation =>
          'Please check the complaint details.',
        ComplaintFailureCode.unauthenticated =>
          'You need to sign in before submitting a complaint.',
        ComplaintFailureCode.permissionDenied =>
          'You do not have permission to access or submit complaints.',
        ComplaintFailureCode.notFound =>
          'The selected property, unit, or tenant could not be found.',
        ComplaintFailureCode.network =>
          'Unable to reach the service. Check your connection and try again.',
        ComplaintFailureCode.conflict =>
          'This complaint submission conflicts with an existing record.',
        ComplaintFailureCode.malformedData =>
          'The complaint data could not be read safely.',
        ComplaintFailureCode.write =>
          'Unable to submit the complaint. Please try again.',
        ComplaintFailureCode.unknown =>
          'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'ComplaintFailure(${code.name})';
}

class ComplaintValidationException extends ComplaintFailure {
  const ComplaintValidationException(String message)
    : super(ComplaintFailureCode.validation, message);
}

class ComplaintAuthenticationException extends ComplaintFailure {
  const ComplaintAuthenticationException()
    : super(ComplaintFailureCode.unauthenticated);
}

class ComplaintPermissionException extends ComplaintFailure {
  const ComplaintPermissionException()
    : super(ComplaintFailureCode.permissionDenied);
}

class ComplaintNotFoundException extends ComplaintFailure {
  const ComplaintNotFoundException([String? message])
    : super(ComplaintFailureCode.notFound, message);
}

class ComplaintWriteException extends ComplaintFailure {
  const ComplaintWriteException([String? message])
    : super(ComplaintFailureCode.write, message);
}

/// Application boundary for complaint operations.
abstract interface class ComplaintRepository {
  Future<Complaint> createComplaint(CreateComplaintInput input);

  Stream<List<Complaint>> watchComplaints({
    String? propertyId,
    String? unitId,
    String? tenantId,
  });

  /// Streams updates for a single complaint.
  Stream<Complaint?> watchComplaint(String id);

  /// Loads a single complaint.
  Future<Complaint?> loadComplaint(String id);

  /// Streams audit events associated with a complaint.
  Stream<List<ComplaintAuditEvent>> watchAuditEvents(String complaintId);

  /// Loads all audit events for a complaint.
  Future<List<ComplaintAuditEvent>> loadAuditEvents(String complaintId);

  /// Streams every stored maintenance visit for a complaint in visit-number
  /// order. This is the authoritative source for visit history; audit events
  /// remain the source for workflow activity.
  Stream<List<MaintenanceVisit>> watchMaintenanceVisits(String complaintId) =>
      Stream<List<MaintenanceVisit>>.value(const <MaintenanceVisit>[]);

  /// Loads every stored maintenance visit for a complaint.
  Future<List<MaintenanceVisit>> loadMaintenanceVisits(String complaintId) =>
      Future<List<MaintenanceVisit>>.value(const <MaintenanceVisit>[]);

  /// Appends an audit event to a complaint's history.
  Future<void> appendAuditEvent(ComplaintAuditEvent event);

  /// Transitions a complaint to a new status and appends an audit event.
  Future<Complaint> updateComplaintStatus(
    String complaintId,
    ComplaintStatus newStatus, {
    required String actorId,
    String? note,
    String? role,
    Map<String, dynamic>? metadata,
  });

  /// Updates complaint priority and appends an audit event.
  Future<Complaint> updateComplaintPriority(
    String complaintId,
    ComplaintPriority newPriority, {
    required String actorId,
    String? reason,
  });

  /// Assigns or reassigns a technician to a complaint and appends an audit event.
  Future<Complaint> assignComplaintTechnician(
    String complaintId,
    String technicianId, {
    required String actorId,
    String? reason,
    String? role,
    DateTime? scheduledDate,
    String? timeSlot,
  });

  /// Streams active complaints assigned to [technicianId].
  Stream<List<Complaint>> watchAssignedComplaints({
    required String technicianId,
  });

  /// Advances the technician visit workflow step and appends an audit event.
  Future<Complaint> advanceVisitStep(
    String complaintId,
    VisitWorkflowStep step, {
    required String actorId,
    String? role,
    String? note,
    List<String>? photos,
  });

  /// Appends a visit evidence photo event.
  Future<void> addVisitPhoto(
    String complaintId, {
    required String photoUrl,
    required String group,
    required String actorId,
    String? role,
  });

  /// Appends a part used event.
  Future<void> addPart(
    String complaintId,
    VisitPartInput part, {
    required String actorId,
    String? role,
  });

  /// Completes a visit as resolved and appends completion audit events.
  Future<Complaint> completeVisit(
    String complaintId,
    VisitCompletionInput completion, {
    required String actorId,
    String? role,
  });

  /// Flags a visit as needing a follow-up and appends audit events.
  Future<Complaint> requestFollowUpVisit(
    String complaintId,
    FollowUpRequestInput request, {
    required String actorId,
    String? role,
  });

  /// Transitions a complaint to a new status according to [change] and appends an audit event.
  Future<Complaint> changeStatus(StatusChange change);
}

/// Input payload for changing a complaint status with full audit details.
class StatusChange {
  const StatusChange({
    required this.complaintId,
    required this.to,
    required this.actor,
    this.reason,
    this.note,
    this.parts,
    this.expectedDate,
    this.role,
    this.tenantConfirmed,
    this.photos = const <String>[],
  });

  final String complaintId;
  final ComplaintStatus to;
  final String actor;
  final String? reason;
  final String? note;
  final List<Map<String, dynamic>>? parts;
  final DateTime? expectedDate;
  final String? role;
  final bool? tenantConfirmed;
  final List<String> photos;
}

/// Deterministically sorts a technician's assigned complaints for field workflow:
/// 1. Urgent priority
/// 2. High priority
/// 3. In-progress field work (in_progress, waiting_for_parts)
/// 4. Other active complaints (medium, low)
///
/// Within each tier, items are sorted by oldest outstanding work first
/// ([Complaint.createdAt] ascending), with nullable timestamps and ID as tie-breakers.
void sortTechnicianQueue(List<Complaint> complaints) {
  complaints.sort((a, b) {
    int rank(Complaint c) {
      if (c.priority == ComplaintPriority.urgent) return 0;
      if (c.priority == ComplaintPriority.high) return 1;
      if (c.status.isFieldWorkActive) return 2;
      if (c.priority == ComplaintPriority.medium) return 3;
      return 4;
    }

    final rankA = rank(a);
    final rankB = rank(b);
    if (rankA != rankB) return rankA.compareTo(rankB);

    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime != null && bTime != null) {
      final comp = aTime.compareTo(bTime);
      if (comp != 0) return comp;
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }

    return a.id.compareTo(b.id);
  });
}

/// Firestore implementation for atomic complaint + initial audit creation and live streams.
class FirestoreComplaintRepository implements ComplaintRepository {
  FirestoreComplaintRepository({
    FirebaseFirestore? firestore,
    AuthenticatedUserProvider? identity,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identity = identity ?? AuthService.firebase();

  final FirebaseFirestore _firestore;
  final AuthenticatedUserProvider _identity;
  late final ComplaintAuditWriter _auditWriter = ComplaintAuditWriter(
    firestore: _firestore,
    identity: _identity,
  );
  late final MaintenanceVisitService _visitService = MaintenanceVisitService(
    firestore: _firestore,
    identity: _identity,
  );

  @override
  Stream<List<Complaint>> watchComplaints({
    String? propertyId,
    String? unitId,
    String? tenantId,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      FirestoreCollections.complaints,
    );

    final pId = propertyId?.trim();
    if (pId != null && pId.isNotEmpty) {
      query = query.where('propertyId', isEqualTo: pId);
    }
    final uId = unitId?.trim();
    if (uId != null && uId.isNotEmpty) {
      query = query.where('unitId', isEqualTo: uId);
    }
    final tId = tenantId?.trim();
    if (tId != null && tId.isNotEmpty) {
      query = query.where('tenantId', isEqualTo: tId);
    }

    return query.snapshots().map((snapshot) {
      final complaints = snapshot.docs.map((doc) {
        return Complaint.fromMap(doc.data(), id: doc.id);
      }).toList();

      complaints.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) {
          return b.id.compareTo(a.id);
        }
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        final comp = bTime.compareTo(aTime);
        if (comp != 0) return comp;
        return b.id.compareTo(a.id);
      });

      return complaints;
    });
  }

  @override
  Stream<List<Complaint>> watchAssignedComplaints({
    required String technicianId,
  }) {
    final tid = technicianId.trim();
    if (tid.isEmpty) {
      throw const ComplaintValidationException(
        'Technician ID cannot be empty.',
      );
    }

    final query = _firestore
        .collection(FirestoreCollections.complaints)
        .where('currentTechnicianId', isEqualTo: tid)
        .where('status', whereIn: ComplaintStatus.activeStatusValues);

    return query.snapshots().map((snapshot) {
      final complaints = snapshot.docs.map((doc) {
        return Complaint.fromMap(doc.data(), id: doc.id);
      }).toList();

      sortTechnicianQueue(complaints);
      return complaints;
    });
  }

  @override
  Future<Complaint> createComplaint(CreateComplaintInput input) async {
    final user = _identity.currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      throw const ComplaintAuthenticationException();
    }

    final validationErrors = input.validate();
    if (validationErrors.isNotEmpty) {
      throw ComplaintValidationException(validationErrors.join(' '));
    }

    final requestedId = input.submissionId?.trim();
    if (requestedId != null &&
        requestedId.isNotEmpty &&
        requestedId.contains('/')) {
      throw const ComplaintValidationException('Submission ID is invalid.');
    }

    final complaintRef = _firestore
        .collection(FirestoreCollections.complaints)
        .doc(requestedId == null || requestedId.isEmpty ? null : requestedId);
    final auditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc('${complaintRef.id}_created');
    final actorId = user.uid;
    final actorRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(actorId);

    try {
      return await _firestore.runTransaction<Complaint>((transaction) async {
        // All reads occur before either write so retries remain transaction-safe.
        final existingComplaint = await transaction.get(complaintRef);
        final existingAudit = await transaction.get(auditRef);
        final actorSnapshot = await transaction.get(actorRef);

        if (!actorSnapshot.exists || actorSnapshot.data() == null) {
          throw const ComplaintPermissionException();
        }
        final actorProfile = AppUser.fromMap(
          actorSnapshot.data()!,
          id: actorSnapshot.id,
        );
        final actor = AuditActorContext.fromProfile(
          profile: actorProfile,
          authenticatedUid: actorId,
        );

        if (existingComplaint.exists) {
          final existingData = existingComplaint.data();
          if (existingData == null) {
            throw const ComplaintFailure(ComplaintFailureCode.malformedData);
          }
          final existing = Complaint.fromMap(
            existingData,
            id: existingComplaint.id,
          );
          if (existing.createdBy != actorId) {
            throw const ComplaintFailure(ComplaintFailureCode.conflict);
          }
          if (existingAudit.exists) {
            final auditData = existingAudit.data();
            if (auditData == null ||
                auditData['complaintId'] != existing.id ||
                auditData['eventType'] != complaintCreatedEventType ||
                auditData['actorId'] != actorId) {
              throw const ComplaintFailure(ComplaintFailureCode.malformedData);
            }
            return existing;
          }

          // Repairs an interrupted legacy pair while keeping the same IDs.
          _auditWriter.appendEventInTransaction(
            transaction,
            complaintId: existing.id,
            eventId: auditRef.id,
            eventType: ComplaintAuditEventType.complaintCreated,
            actor: actor,
            details: {
              'category': existing.category.value,
              'priority': existing.priority.value,
            },
            eventWasAbsent: !existingAudit.exists,
          );
          return existing;
        }

        await _validateReferences(transaction, input);

        final complaintPayload = ComplaintFirestorePayloads.complaintForCreate(
          input,
          actorId,
        );
        transaction.set(complaintRef, complaintPayload);
        _auditWriter.appendEventInTransaction(
          transaction,
          complaintId: complaintRef.id,
          eventId: auditRef.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actor: actor,
          details: {
            'category': input.category.value,
            'priority': input.priority.value,
          },
          eventWasAbsent: !existingAudit.exists,
        );

        // Server timestamps are unresolved until Firestore acknowledges the
        // write, so this result intentionally carries nullable dates.
        return Complaint(
          id: complaintRef.id,
          tenantId: input.tenantId.trim(),
          propertyId: input.propertyId.trim(),
          unitId: input.unitId.trim(),
          title: input.title.trim(),
          description: input.description.trim(),
          category: input.category,
          priority: input.priority,
          status: ComplaintStatus.open,
          createdBy: actorId,
        );
      });
    } on ComplaintFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    } catch (error) {
      throw ComplaintWriteException(error.toString());
    }
  }

  Future<void> _validateReferences(
    Transaction transaction,
    CreateComplaintInput input,
  ) async {
    final propertyRef = _firestore
        .collection(FirestoreCollections.properties)
        .doc(input.propertyId.trim());
    final unitRef = _firestore
        .collection(FirestoreCollections.units)
        .doc(input.unitId.trim());
    final tenantRef = _firestore
        .collection(FirestoreCollections.tenants)
        .doc(input.tenantId.trim());

    final propertySnapshot = await transaction.get(propertyRef);
    final unitSnapshot = await transaction.get(unitRef);
    final tenantSnapshot = await transaction.get(tenantRef);
    if (!propertySnapshot.exists ||
        !unitSnapshot.exists ||
        !tenantSnapshot.exists) {
      throw const ComplaintNotFoundException();
    }

    final unitData = unitSnapshot.data();
    final tenantData = tenantSnapshot.data();
    if (unitData == null || tenantData == null) {
      throw const ComplaintFailure(ComplaintFailureCode.malformedData);
    }
    if (unitData['propertyId'] != input.propertyId.trim()) {
      throw const ComplaintValidationException(
        'The selected unit does not belong to the selected property.',
      );
    }
    if (tenantData['propertyId'] != input.propertyId.trim() ||
        tenantData['unitId'] != input.unitId.trim()) {
      throw const ComplaintValidationException(
        'The selected tenant is not assigned to the selected unit.',
      );
    }
  }

  ComplaintFailure _fromFirebaseException(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => const ComplaintPermissionException(),
      'not-found' => const ComplaintNotFoundException(),
      'unavailable' ||
      'deadline-exceeded' ||
      'aborted' ||
      'resource-exhausted' => const ComplaintFailure(
        ComplaintFailureCode.network,
      ),
      _ => const ComplaintWriteException(),
    };
  }

  @override
  Stream<Complaint?> watchComplaint(String id) {
    return _firestore
        .collection(FirestoreCollections.complaints)
        .doc(id.trim())
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? Complaint.fromMap(doc.data()!, id: doc.id) : null,
        );
  }

  @override
  Future<Complaint?> loadComplaint(String id) async {
    final doc = await _firestore
        .collection(FirestoreCollections.complaints)
        .doc(id.trim())
        .get();
    return doc.exists ? Complaint.fromMap(doc.data()!, id: doc.id) : null;
  }

  @override
  Stream<List<ComplaintAuditEvent>> watchAuditEvents(String complaintId) {
    return _firestore
        .collection(FirestoreCollections.auditEvents)
        .where('complaintId', isEqualTo: complaintId.trim())
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs.map((doc) {
            return ComplaintAuditEvent.fromMap(doc.data(), id: doc.id);
          }).toList();
          events.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(0);
            final bTime = b.createdAt ?? DateTime(0);
            return aTime.compareTo(bTime);
          });
          return events;
        });
  }

  @override
  Future<List<ComplaintAuditEvent>> loadAuditEvents(String complaintId) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.auditEvents)
        .where('complaintId', isEqualTo: complaintId.trim())
        .get();
    final events = snapshot.docs.map((doc) {
      return ComplaintAuditEvent.fromMap(doc.data(), id: doc.id);
    }).toList();
    events.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(0);
      final bTime = b.createdAt ?? DateTime(0);
      return aTime.compareTo(bTime);
    });
    return events;
  }

  @override
  Stream<List<MaintenanceVisit>> watchMaintenanceVisits(String complaintId) {
    return _visitService.watchMaintenanceVisits(complaintId);
  }

  @override
  Future<List<MaintenanceVisit>> loadMaintenanceVisits(String complaintId) {
    return _visitService.getMaintenanceVisits(complaintId);
  }

  @override
  Future<void> appendAuditEvent(ComplaintAuditEvent event) async {
    final ref = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc(event.id.isNotEmpty ? event.id : null);
    await ref.set(event.toFirestoreMap());
  }

  @override
  Future<Complaint> updateComplaintStatus(
    String complaintId,
    ComplaintStatus newStatus, {
    required String actorId,
    String? note,
    String? role,
    Map<String, dynamic>? metadata,
  }) async {
    final complaintRef = _firestore
        .collection(FirestoreCollections.complaints)
        .doc(complaintId.trim());
    final auditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc();

    final eventType = switch (newStatus) {
      ComplaintStatus.open => 'COMPLAINT_OPENED',
      ComplaintStatus.assigned => 'TECHNICIAN_ASSIGNED',
      ComplaintStatus.inProgress => 'WORK_STARTED',
      ComplaintStatus.waitingForParts => 'PART_NEEDED',
      ComplaintStatus.resolved => 'REPAIR_COMPLETED',
      ComplaintStatus.closed => 'COMPLAINT_CLOSED',
      ComplaintStatus.reopened => 'COMPLAINT_REOPENED',
      ComplaintStatus.cancelled => 'COMPLAINT_CANCELLED',
    };

    final eventTypeEnum = switch (newStatus) {
      ComplaintStatus.open => ComplaintAuditEventType.complaintCreated,
      ComplaintStatus.assigned => ComplaintAuditEventType.technicianAssigned,
      ComplaintStatus.inProgress => ComplaintAuditEventType.visitStarted,
      ComplaintStatus.waitingForParts =>
        ComplaintAuditEventType.complaintWaitingForParts,
      ComplaintStatus.resolved => ComplaintAuditEventType.complaintResolved,
      ComplaintStatus.closed => ComplaintAuditEventType.complaintClosed,
      ComplaintStatus.reopened => ComplaintAuditEventType.complaintReopened,
      ComplaintStatus.cancelled => ComplaintAuditEventType.complaintCancelled,
    };

    final event = ComplaintAuditEvent(
      id: auditRef.id,
      complaintId: complaintId,
      eventType: eventTypeEnum,
      rawEventType: eventType,
      actorId: actorId,
      timestamp: DateTime.now(),
      metadata: {
        'status': newStatus.value,
        'note': ?note,
        'actorRole': ?role,
        ...?metadata,
      },
    );

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(complaintRef);
      if (!snap.exists) {
        throw const ComplaintFailure(ComplaintFailureCode.notFound);
      }
      tx.update(complaintRef, {
        'status': newStatus.value,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == ComplaintStatus.resolved)
          'resolvedAt': FieldValue.serverTimestamp(),
        if (newStatus == ComplaintStatus.closed)
          'closedAt': FieldValue.serverTimestamp(),
        if (newStatus == ComplaintStatus.reopened)
          'reopenCount': FieldValue.increment(1),
      });
      tx.set(auditRef, event.toFirestoreMap());
    });

    final updated = await loadComplaint(complaintId);
    return updated!;
  }

  @override
  Future<Complaint> updateComplaintPriority(
    String complaintId,
    ComplaintPriority newPriority, {
    required String actorId,
    String? reason,
  }) async {
    final complaintRef = _firestore
        .collection(FirestoreCollections.complaints)
        .doc(complaintId.trim());
    final auditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc();

    final event = ComplaintAuditEvent(
      id: auditRef.id,
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.priorityChanged,
      actorId: actorId,
      timestamp: DateTime.now(),
      metadata: {'priority': newPriority.value, 'reason': ?reason},
    );

    await _firestore.runTransaction((tx) async {
      tx.update(complaintRef, {
        'priority': newPriority.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(auditRef, event.toFirestoreMap());
    });

    final updated = await loadComplaint(complaintId);
    return updated!;
  }

  @override
  Future<Complaint> assignComplaintTechnician(
    String complaintId,
    String technicianId, {
    required String actorId,
    String? reason,
    String? role,
    DateTime? scheduledDate,
    String? timeSlot,
  }) async {
    final current = await loadComplaint(complaintId.trim());
    if (current == null) {
      throw const ComplaintFailure(ComplaintFailureCode.notFound);
    }
    final service = TechnicianAssignmentService(
      firestore: _firestore,
      identity: _identity,
    );
    try {
      if (current.currentTechnicianId == null ||
          current.currentTechnicianId!.trim().isEmpty) {
        return await service.assignTechnician(
          complaintId: current.id,
          technicianId: technicianId,
          reason: reason,
        );
      }
      return await service.reassignTechnician(
        complaintId: current.id,
        newTechnicianId: technicianId,
        reason: reason,
      );
    } on TechnicianAssignmentFailure catch (error) {
      throw ComplaintFailure(ComplaintFailureCode.write, error.message);
    }
  }

  @override
  Future<Complaint> advanceVisitStep(
    String complaintId,
    VisitWorkflowStep step, {
    required String actorId,
    String? role,
    String? note,
    List<String>? photos,
  }) async {
    final normalizedComplaintId = _validId(complaintId, 'Complaint ID');
    final authenticatedActorId = _requireActorId(actorId);

    try {
      // Accepting a job is the user-facing start of the visit. The atomic
      // service creates the visit, links it to the complaint, and records the
      // canonical VISIT_STARTED event before the step event is appended.
      if (step == VisitWorkflowStep.accepted) {
        await _visitService.startMaintenanceVisit(
          complaintId: normalizedComplaintId,
        );
      }

      final eventType = switch (step) {
        VisitWorkflowStep.accepted =>
          ComplaintAuditEventType.technicianAccepted,
        VisitWorkflowStep.travelling => ComplaintAuditEventType.travelStarted,
        VisitWorkflowStep.arrived => ComplaintAuditEventType.technicianArrived,
        VisitWorkflowStep.inspection =>
          ComplaintAuditEventType.inspectionStarted,
        VisitWorkflowStep.repairing => ComplaintAuditEventType.repairStarted,
        // Completion is submitted through completeVisit so required fields
        // and the outcome cannot be bypassed.
        VisitWorkflowStep.completed => throw const ComplaintValidationException(
          'Complete the visit using the completion form.',
        ),
      };

      await _appendVisitAuditEvent(
        complaintId: normalizedComplaintId,
        actorId: authenticatedActorId,
        eventType: eventType,
        metadata: {
          'step': step.name,
          'note': note ?? 'Step advanced to ${step.label}',
          if (photos != null && photos.isNotEmpty) 'photos': photos,
        },
      );
      return (await loadComplaint(normalizedComplaintId))!;
    } on ComplaintFailure {
      rethrow;
    } on MaintenanceVisitFailure catch (error) {
      throw ComplaintFailure(switch (error.code) {
        MaintenanceVisitFailureCode.unauthenticated =>
          ComplaintFailureCode.unauthenticated,
        MaintenanceVisitFailureCode.unauthorized =>
          ComplaintFailureCode.permissionDenied,
        MaintenanceVisitFailureCode.complaintNotFound =>
          ComplaintFailureCode.notFound,
        MaintenanceVisitFailureCode.validation ||
        MaintenanceVisitFailureCode.invalidStatus ||
        MaintenanceVisitFailureCode.duplicateActiveVisit ||
        MaintenanceVisitFailureCode.conflict => ComplaintFailureCode.conflict,
        _ => ComplaintFailureCode.write,
      }, error.message);
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    }
  }

  @override
  Future<void> addVisitPhoto(
    String complaintId, {
    required String photoUrl,
    required String group,
    required String actorId,
    String? role,
  }) async {
    final normalizedComplaintId = _validId(complaintId, 'Complaint ID');
    final normalizedUrl = photoUrl.trim();
    final normalizedGroup = group.trim().toLowerCase();
    if (normalizedUrl.isEmpty ||
        !{'before', 'after'}.contains(normalizedGroup)) {
      throw const ComplaintValidationException('Photo evidence is invalid.');
    }
    await _appendVisitAuditEvent(
      complaintId: normalizedComplaintId,
      actorId: _requireActorId(actorId),
      eventType: ComplaintAuditEventType.photoUploaded,
      metadata: {
        'photoUrl': normalizedUrl,
        'group': normalizedGroup,
        'note': 'Photo uploaded ($normalizedGroup evidence)',
      },
    );
  }

  @override
  Future<void> addPart(
    String complaintId,
    VisitPartInput part, {
    required String actorId,
    String? role,
  }) async {
    final normalizedComplaintId = _validId(complaintId, 'Complaint ID');
    final nameError = VisitValidators.validatePartName(part.name);
    final quantityError = VisitValidators.validatePartQuantity(part.quantity);
    final costError = VisitValidators.validatePartCost(part.cost);
    if (nameError != null || quantityError != null || costError != null) {
      throw ComplaintValidationException(
        nameError ?? quantityError ?? costError ?? 'Part is invalid.',
      );
    }
    await _appendVisitAuditEvent(
      complaintId: normalizedComplaintId,
      actorId: _requireActorId(actorId),
      eventType: ComplaintAuditEventType.partAdded,
      metadata: {
        'name': part.name.trim(),
        'quantity': part.quantity,
        if (part.cost != null) 'cost': part.cost,
        'note': 'Part added: ${part.name.trim()} (x${part.quantity})',
      },
    );
  }

  @override
  Future<Complaint> completeVisit(
    String complaintId,
    VisitCompletionInput completion, {
    required String actorId,
    String? role,
  }) async {
    final normalizedComplaintId = _validId(complaintId, 'Complaint ID');
    final actor = _requireActorId(actorId);
    try {
      // Persist part entries before completion because the completion form
      // submits them as one input object rather than calling addPart itself.
      for (final part in completion.parts) {
        await addPart(normalizedComplaintId, part, actorId: actor, role: role);
      }
      await _visitService.completeMaintenanceVisit(
        complaintId: normalizedComplaintId,
        visitId: await _activeVisitId(normalizedComplaintId),
        observation: completion.whatWasFound,
        actionTaken: completion.whatWasRepaired,
        outcome: MaintenanceVisitOutcome.resolved,
        isResolved: true,
        followUpRequired: false,
        resolutionSummary: completion.tenantResolutionNotes,
      );
      return (await loadComplaint(normalizedComplaintId))!;
    } on MaintenanceVisitFailure catch (error) {
      throw ComplaintFailure(ComplaintFailureCode.write, error.message);
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    }
  }

  @override
  Future<Complaint> requestFollowUpVisit(
    String complaintId,
    FollowUpRequestInput request, {
    required String actorId,
    String? role,
  }) async {
    final normalizedComplaintId = _validId(complaintId, 'Complaint ID');
    _requireActorId(actorId);
    final followUpNotes = [
      request.reason.label,
      request.otherReasonDetails,
      request.details,
      if (request.suggestedDate != null)
        'Suggested date: ${request.suggestedDate!.toIso8601String()}',
      if (request.suggestedSlot != null)
        'Suggested slot: ${request.suggestedSlot}',
      if (request.partsToBring.isNotEmpty)
        'Parts to bring: ${request.partsToBring.join(', ')}',
    ].whereType<String>().where((item) => item.trim().isNotEmpty).join('\n');
    try {
      await _visitService.completeMaintenanceVisit(
        complaintId: normalizedComplaintId,
        visitId: await _activeVisitId(normalizedComplaintId),
        observation: request.details,
        actionTaken: 'Follow-up required: ${request.reason.label}',
        outcome: request.reason == FollowUpReason.partNotAvailable
            ? MaintenanceVisitOutcome.waitingForParts
            : MaintenanceVisitOutcome.unresolved,
        isResolved: false,
        followUpRequired: true,
        followUpNotes: followUpNotes,
        resolutionSummary: request.details,
      );
      return (await loadComplaint(normalizedComplaintId))!;
    } on MaintenanceVisitFailure catch (error) {
      throw ComplaintFailure(ComplaintFailureCode.write, error.message);
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    }
  }

  String _requireActorId(String actorId) {
    final authenticatedId = _identity.currentUser?.uid.trim();
    final requestedId = actorId.trim();
    if (authenticatedId == null || authenticatedId.isEmpty) {
      throw const ComplaintAuthenticationException();
    }
    if (requestedId.isEmpty || requestedId != authenticatedId) {
      throw const ComplaintPermissionException();
    }
    return authenticatedId;
  }

  Future<String> _activeVisitId(String complaintId) async {
    final complaint = await loadComplaint(complaintId);
    final visitId = complaint?.activeVisitId?.trim();
    if (visitId == null || visitId.isEmpty) {
      throw const ComplaintFailure(
        ComplaintFailureCode.conflict,
        'There is no active maintenance visit for this complaint.',
      );
    }
    return visitId;
  }

  Future<void> _appendVisitAuditEvent({
    required String complaintId,
    required String actorId,
    required ComplaintAuditEventType eventType,
    required Map<String, dynamic> metadata,
  }) async {
    await _firestore.runTransaction<void>((transaction) async {
      final complaintRef = _firestore
          .collection(FirestoreCollections.complaints)
          .doc(complaintId);
      final actorRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(actorId);
      final complaintSnapshot = await transaction.get(complaintRef);
      final actorSnapshot = await transaction.get(actorRef);
      final complaintData = complaintSnapshot.data();
      if (!complaintSnapshot.exists || complaintData == null) {
        throw const ComplaintNotFoundException();
      }
      final activeVisitId = (complaintData['activeVisitId'] as String?)?.trim();
      if (activeVisitId == null || activeVisitId.isEmpty) {
        throw const ComplaintFailure(
          ComplaintFailureCode.conflict,
          'There is no active maintenance visit for this complaint.',
        );
      }
      final visitSnapshot = await transaction.get(
        _firestore
            .collection(FirestoreCollections.maintenanceVisits)
            .doc(activeVisitId),
      );
      final visitData = visitSnapshot.data();
      if (!visitSnapshot.exists ||
          visitData == null ||
          visitData['technicianId'] != actorId ||
          visitData['completedAt'] != null) {
        throw const ComplaintPermissionException();
      }
      final actorProfile = _actorProfile(actorSnapshot, actorId);
      final actor = AuditActorContext.fromProfile(
        profile: actorProfile,
        authenticatedUid: actorId,
      );
      final auditRef = _firestore
          .collection(FirestoreCollections.auditEvents)
          .doc();
      _auditWriter.appendEventInTransaction(
        transaction,
        eventId: auditRef.id,
        complaintId: complaintId,
        eventType: eventType,
        actor: actor,
        details: {
          'visitId': activeVisitId,
          'technicianId': actorId,
          ...metadata,
        },
      );
    });
  }

  @override
  Future<Complaint> changeStatus(StatusChange change) async {
    // TODO: Implement Firestore persistence for changeStatus
    return updateComplaintStatus(
      change.complaintId,
      change.to,
      actorId: change.actor,
      note: change.note,
      role: change.role,
      metadata: {
        if (change.reason != null) 'reason': change.reason,
        if (change.parts != null) 'parts': change.parts,
        if (change.expectedDate != null)
          'expectedDate': change.expectedDate!.toIso8601String(),
        if (change.tenantConfirmed != null)
          'tenantConfirmed': change.tenantConfirmed,
        if (change.photos.isNotEmpty) 'photos': change.photos,
      },
    );
  }

  static AppUser _actorProfile(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String actorId,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const ComplaintPermissionException();
    }
    final profile = AppUser.fromMap(data, id: snapshot.id);
    if (profile.id != actorId ||
        !profile.isAuthorized ||
        profile.role != UserRole.technician) {
      throw const ComplaintPermissionException();
    }
    return profile;
  }

  static String _validId(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.contains('/') ||
        normalized.length > 128) {
      throw ComplaintValidationException('$label is invalid.');
    }
    return normalized;
  }
}

/// In-memory implementation of [ComplaintRepository] with reactive stream support.
///
/// Useful for widget previews, deterministic unit/widget tests, and local demo modes.
class InMemoryComplaintRepository implements ComplaintRepository {
  InMemoryComplaintRepository({
    List<Complaint>? initialComplaints,
    Map<String, List<ComplaintAuditEvent>>? initialAuditEvents,
    this.streamDelay = Duration.zero,
  }) : _complaints = List.of(
         initialComplaints ?? SampleFixtures.sampleComplaints,
       ),
       _auditEvents = initialAuditEvents != null
           ? Map.from(initialAuditEvents)
           : <String, List<ComplaintAuditEvent>>{} {
    _seedDefaultEvents();
    _emit();
  }

  final List<Complaint> _complaints;
  final Map<String, List<ComplaintAuditEvent>> _auditEvents;
  final Map<String, List<MaintenanceVisit>> _maintenanceVisits = {};
  final Duration streamDelay;
  bool simulateFailure = false;
  Duration operationDelay = Duration.zero;
  final StreamController<List<Complaint>> _controller =
      StreamController<List<Complaint>>.broadcast();
  final Map<String, StreamController<Complaint?>> _complaintControllers = {};
  final Map<String, StreamController<List<ComplaintAuditEvent>>>
  _auditControllers = {};
  final Map<String, StreamController<List<MaintenanceVisit>>>
  _visitControllers = {};

  void _seedDefaultEvents() {
    for (final c in _complaints) {
      _seedDefaultVisits(c);
      if (!_auditEvents.containsKey(c.id)) {
        final events = <ComplaintAuditEvent>[
          ComplaintAuditEvent(
            id: '${c.id}_evt_created',
            complaintId: c.id,
            eventType: ComplaintAuditEventType.complaintCreated,
            actorId: c.createdBy,
            timestamp: c.createdAt ?? DateTime(2026, 10, 1, 10, 0),
            metadata: {
              'category': c.category.displayLabel,
              'priority': c.priority.displayLabel,
              'actorName': 'Tenant',
              'actorRole': 'Tenant',
              'note': 'Complaint raised by resident.',
            },
          ),
        ];
        if (c.firstAssignedAt != null && c.currentTechnicianId != null) {
          events.add(
            ComplaintAuditEvent(
              id: '${c.id}_evt_assigned',
              complaintId: c.id,
              eventType: ComplaintAuditEventType.technicianAssigned,
              actorId: 'usr_001',
              timestamp: c.firstAssignedAt,
              metadata: {
                'technicianId': c.currentTechnicianId,
                'actorName': 'Riya Sharma',
                'actorRole': 'Operations Staff',
                'newTechnicianName': 'Aman Verma',
              },
            ),
          );
        }
        if (c.status == ComplaintStatus.inProgress ||
            c.status == ComplaintStatus.waitingForParts ||
            c.visitCount > 0) {
          final visitDate = (c.firstAssignedAt ?? c.createdAt ?? DateTime.now())
              .add(const Duration(hours: 4));
          events.add(
            ComplaintAuditEvent(
              id: '${c.id}_evt_arrived',
              complaintId: c.id,
              eventType: ComplaintAuditEventType.unknown,
              rawEventType: 'TECHNICIAN_ARRIVED',
              actorId: c.currentTechnicianId ?? 'usr_002',
              timestamp: visitDate,
              metadata: {
                'actorName': 'Aman Verma',
                'actorRole': 'Technician',
                'note': 'Technician arrived at unit for diagnostics.',
              },
            ),
          );
        }
        if (c.resolvedAt != null) {
          events.add(
            ComplaintAuditEvent(
              id: '${c.id}_evt_resolved',
              complaintId: c.id,
              eventType: ComplaintAuditEventType.complaintResolved,
              rawEventType: 'REPAIR_COMPLETED',
              actorId: c.currentTechnicianId ?? 'usr_002',
              timestamp: c.resolvedAt,
              metadata: {
                'actorName': 'Aman Verma',
                'actorRole': 'Technician',
                'note': 'Issue resolved and tested working.',
              },
            ),
          );
        }
        if (c.closedAt != null) {
          events.add(
            ComplaintAuditEvent(
              id: '${c.id}_evt_closed',
              complaintId: c.id,
              eventType: ComplaintAuditEventType.complaintClosed,
              rawEventType: 'TENANT_CONFIRMED',
              actorId: c.tenantId,
              timestamp: c.closedAt,
              metadata: {
                'actorName': 'Tenant',
                'actorRole': 'Tenant',
                'note': 'Verified fixed, closing complaint.',
              },
            ),
          );
        }
        _auditEvents[c.id] = events;
      }
    }
  }

  void _seedDefaultVisits(Complaint complaint) {
    if (_maintenanceVisits.containsKey(complaint.id) ||
        complaint.visitCount == 0) {
      return;
    }
    final startedAt =
        complaint.firstAssignedAt ??
        complaint.createdAt ??
        DateTime(2026, 10, 1);
    _maintenanceVisits[complaint.id] = List.generate(complaint.visitCount, (
      index,
    ) {
      final completed =
          complaint.status == ComplaintStatus.resolved ||
          complaint.status == ComplaintStatus.closed;
      return MaintenanceVisit(
        id: '${complaint.id}_legacy_visit_${index + 1}',
        complaintId: complaint.id,
        technicianId: complaint.currentTechnicianId ?? 'usr_002',
        visitNumber: index + 1,
        startedAt: startedAt.add(Duration(days: index)),
        completedAt: completed
            ? startedAt.add(Duration(days: index, hours: 2))
            : null,
        observation: completed ? 'Legacy visit record' : null,
        actionTaken: completed ? 'Legacy visit record' : null,
        outcome: completed ? MaintenanceVisitOutcome.resolved : null,
        isResolved: completed,
        followUpRequired: false,
        followUpNotes: null,
        resolutionSummary: completed ? 'Imported legacy visit' : null,
        operationId: '${complaint.id}_legacy_visit_${index + 1}',
      );
    });
  }

  /// Seeds an external or test complaint and emits updates.
  void seedComplaint(Complaint complaint) {
    final index = _complaints.indexWhere((c) => c.id == complaint.id);
    if (index == -1) {
      _complaints.add(complaint);
    } else {
      _complaints[index] = complaint;
    }
    _emit();
    _emitComplaint(complaint.id);
  }

  void _emit() {
    if (_controller.isClosed) return;
    final copy = List<Complaint>.from(_complaints);
    _sort(copy);
    _controller.add(copy);
  }

  void _emitComplaint(String id) {
    final complaint = _complaints.where((c) => c.id == id).firstOrNull;
    if (_complaintControllers.containsKey(id) &&
        !_complaintControllers[id]!.isClosed) {
      _complaintControllers[id]!.add(complaint);
    }
  }

  void _emitAudit(String complaintId) {
    final events = List<ComplaintAuditEvent>.from(
      _auditEvents[complaintId] ?? <ComplaintAuditEvent>[],
    );
    events.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(0);
      final bTime = b.createdAt ?? DateTime(0);
      return aTime.compareTo(bTime);
    });
    if (_auditControllers.containsKey(complaintId) &&
        !_auditControllers[complaintId]!.isClosed) {
      _auditControllers[complaintId]!.add(events);
    }
  }

  static void _sort(List<Complaint> list) {
    list.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return b.id.compareTo(a.id);
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      final comp = bTime.compareTo(aTime);
      if (comp != 0) return comp;
      return b.id.compareTo(a.id);
    });
  }

  @override
  Future<Complaint> createComplaint(CreateComplaintInput input) async {
    final validationErrors = input.validate();
    if (validationErrors.isNotEmpty) {
      throw ComplaintValidationException(validationErrors.join(' '));
    }
    final id = input.submissionId?.trim().isNotEmpty == true
        ? input.submissionId!.trim()
        : 'complaint_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final complaint = Complaint(
      id: id,
      tenantId: input.tenantId.trim(),
      propertyId: input.propertyId.trim(),
      unitId: input.unitId.trim(),
      title: input.title.trim(),
      description: input.description.trim(),
      category: input.category,
      priority: input.priority,
      status: ComplaintStatus.open,
      createdBy: 'in_memory_user',
      createdAt: now,
    );
    _complaints.add(complaint);

    final initialEvent = ComplaintAuditEvent(
      id: '${id}_evt_created',
      complaintId: id,
      eventType: ComplaintAuditEventType.complaintCreated,
      actorId: 'in_memory_user',
      timestamp: now,
      metadata: {
        'category': input.category.displayLabel,
        'priority': input.priority.displayLabel,
        'actorName': 'Tenant',
        'actorRole': 'Tenant',
      },
    );
    _auditEvents[id] = [initialEvent];

    _emit();
    _emitComplaint(id);
    _emitAudit(id);
    return complaint;
  }

  @override
  Stream<List<Complaint>> watchComplaints({
    String? propertyId,
    String? unitId,
    String? tenantId,
  }) {
    List<Complaint> filter(List<Complaint> list) {
      return list.where((item) {
        if (propertyId != null &&
            propertyId.trim().isNotEmpty &&
            item.propertyId != propertyId.trim()) {
          return false;
        }
        if (unitId != null &&
            unitId.trim().isNotEmpty &&
            item.unitId != unitId.trim()) {
          return false;
        }
        if (tenantId != null &&
            tenantId.trim().isNotEmpty &&
            item.tenantId != tenantId.trim()) {
          return false;
        }
        return true;
      }).toList();
    }

    late final StreamController<List<Complaint>> controller;
    StreamSubscription<List<Complaint>>? sub;

    controller = StreamController<List<Complaint>>(
      onListen: () {
        void sendInitial() {
          if (!controller.isClosed) {
            final initial = List<Complaint>.from(_complaints);
            _sort(initial);
            controller.add(filter(initial));
          }
        }

        if (streamDelay > Duration.zero) {
          Future<void>.delayed(streamDelay, sendInitial);
        } else {
          scheduleMicrotask(sendInitial);
        }

        sub = _controller.stream.listen(
          (data) {
            if (!controller.isClosed) {
              controller.add(filter(data));
            }
          },
          onError: (Object err, StackTrace st) {
            if (!controller.isClosed) {
              controller.addError(err, st);
            }
          },
        );
      },
      onCancel: () {
        sub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Stream<Complaint?> watchComplaint(String id) {
    if (!_complaintControllers.containsKey(id) ||
        _complaintControllers[id]!.isClosed) {
      _complaintControllers[id] = StreamController<Complaint?>.broadcast();
    }
    final streamController = _complaintControllers[id]!;
    scheduleMicrotask(() {
      final complaint = _complaints.where((c) => c.id == id).firstOrNull;
      if (!streamController.isClosed) {
        streamController.add(complaint);
      }
    });
    return streamController.stream;
  }

  @override
  Future<Complaint?> loadComplaint(String id) async {
    if (streamDelay > Duration.zero) {
      await Future<void>.delayed(streamDelay);
    }
    return _complaints.where((c) => c.id == id).firstOrNull;
  }

  @override
  Stream<List<ComplaintAuditEvent>> watchAuditEvents(String complaintId) {
    if (!_auditControllers.containsKey(complaintId) ||
        _auditControllers[complaintId]!.isClosed) {
      _auditControllers[complaintId] =
          StreamController<List<ComplaintAuditEvent>>.broadcast();
    }
    final streamController = _auditControllers[complaintId]!;
    scheduleMicrotask(() {
      final events = List<ComplaintAuditEvent>.from(
        _auditEvents[complaintId] ?? <ComplaintAuditEvent>[],
      );
      events.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(0);
        final bTime = b.createdAt ?? DateTime(0);
        return aTime.compareTo(bTime);
      });
      if (!streamController.isClosed) {
        streamController.add(events);
      }
    });
    return streamController.stream;
  }

  @override
  Future<List<ComplaintAuditEvent>> loadAuditEvents(String complaintId) async {
    if (streamDelay > Duration.zero) {
      await Future<void>.delayed(streamDelay);
    }
    final events = List<ComplaintAuditEvent>.from(
      _auditEvents[complaintId] ?? <ComplaintAuditEvent>[],
    );
    events.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(0);
      final bTime = b.createdAt ?? DateTime(0);
      return aTime.compareTo(bTime);
    });
    return events;
  }

  @override
  Stream<List<MaintenanceVisit>> watchMaintenanceVisits(String complaintId) {
    if (!_visitControllers.containsKey(complaintId) ||
        _visitControllers[complaintId]!.isClosed) {
      _visitControllers[complaintId] =
          StreamController<List<MaintenanceVisit>>.broadcast();
    }
    final controller = _visitControllers[complaintId]!;
    scheduleMicrotask(() {
      if (!controller.isClosed) controller.add(_sortedVisits(complaintId));
    });
    return controller.stream;
  }

  @override
  Future<List<MaintenanceVisit>> loadMaintenanceVisits(String complaintId) {
    return Future<List<MaintenanceVisit>>.value(_sortedVisits(complaintId));
  }

  List<MaintenanceVisit> _sortedVisits(String complaintId) {
    final visits = List<MaintenanceVisit>.from(
      _maintenanceVisits[complaintId] ?? const <MaintenanceVisit>[],
    );
    visits.sort((a, b) {
      final numberComparison = a.visitNumber.compareTo(b.visitNumber);
      return numberComparison != 0 ? numberComparison : a.id.compareTo(b.id);
    });
    return visits;
  }

  void _emitVisits(String complaintId) {
    final controller = _visitControllers[complaintId];
    if (controller != null && !controller.isClosed) {
      controller.add(_sortedVisits(complaintId));
    }
  }

  @override
  Future<void> appendAuditEvent(ComplaintAuditEvent event) async {
    final list = _auditEvents.putIfAbsent(event.complaintId, () => []);
    list.add(event);
    _emitAudit(event.complaintId);
  }

  @override
  Future<Complaint> updateComplaintStatus(
    String complaintId,
    ComplaintStatus newStatus, {
    required String actorId,
    String? note,
    String? role,
    Map<String, dynamic>? metadata,
  }) async {
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) {
      throw const ComplaintFailure(ComplaintFailureCode.notFound);
    }

    final current = _complaints[index];
    final now = DateTime.now();
    final updated = Complaint(
      id: current.id,
      tenantId: current.tenantId,
      propertyId: current.propertyId,
      unitId: current.unitId,
      title: current.title,
      description: current.description,
      category: current.category,
      priority: current.priority,
      status: newStatus,
      currentTechnicianId: current.currentTechnicianId,
      activeVisitId: current.activeVisitId,
      visitCount: current.visitCount,
      reopenCount: newStatus == ComplaintStatus.reopened
          ? current.reopenCount + 1
          : current.reopenCount,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      firstAssignedAt: current.firstAssignedAt,
      resolvedAt: newStatus == ComplaintStatus.resolved
          ? now
          : current.resolvedAt,
      closedAt: newStatus == ComplaintStatus.closed ? now : current.closedAt,
      updatedAt: now,
    );
    _complaints[index] = updated;

    final eventType = switch (newStatus) {
      ComplaintStatus.open => 'COMPLAINT_OPENED',
      ComplaintStatus.assigned => 'TECHNICIAN_ASSIGNED',
      ComplaintStatus.inProgress => 'WORK_STARTED',
      ComplaintStatus.waitingForParts => 'PART_NEEDED',
      ComplaintStatus.resolved => 'REPAIR_COMPLETED',
      ComplaintStatus.closed => 'TENANT_CONFIRMED',
      ComplaintStatus.reopened => 'COMPLAINT_REOPENED',
      ComplaintStatus.cancelled => 'COMPLAINT_CANCELLED',
    };

    final eventTypeEnum = switch (newStatus) {
      ComplaintStatus.open => ComplaintAuditEventType.complaintCreated,
      ComplaintStatus.assigned => ComplaintAuditEventType.technicianAssigned,
      ComplaintStatus.inProgress => ComplaintAuditEventType.visitStarted,
      ComplaintStatus.waitingForParts =>
        ComplaintAuditEventType.complaintWaitingForParts,
      ComplaintStatus.resolved => ComplaintAuditEventType.complaintResolved,
      ComplaintStatus.closed => ComplaintAuditEventType.complaintClosed,
      ComplaintStatus.reopened => ComplaintAuditEventType.complaintReopened,
      ComplaintStatus.cancelled => ComplaintAuditEventType.complaintCancelled,
    };

    final event = ComplaintAuditEvent(
      id: '${complaintId}_evt_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: eventTypeEnum,
      rawEventType: eventType,
      actorId: actorId,
      timestamp: now,
      metadata: {
        'status': newStatus.value,
        'note': ?note,
        'actorRole': ?role,
        ...?metadata,
      },
    );

    await appendAuditEvent(event);
    _emit();
    _emitComplaint(complaintId);
    return updated;
  }

  @override
  Future<Complaint> updateComplaintPriority(
    String complaintId,
    ComplaintPriority newPriority, {
    required String actorId,
    String? reason,
  }) async {
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) {
      throw const ComplaintFailure(ComplaintFailureCode.notFound);
    }

    final current = _complaints[index];
    final now = DateTime.now();
    final updated = Complaint(
      id: current.id,
      tenantId: current.tenantId,
      propertyId: current.propertyId,
      unitId: current.unitId,
      title: current.title,
      description: current.description,
      category: current.category,
      priority: newPriority,
      status: current.status,
      currentTechnicianId: current.currentTechnicianId,
      activeVisitId: current.activeVisitId,
      visitCount: current.visitCount,
      reopenCount: current.reopenCount,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      firstAssignedAt: current.firstAssignedAt,
      resolvedAt: current.resolvedAt,
      closedAt: current.closedAt,
      updatedAt: now,
    );
    _complaints[index] = updated;

    final event = ComplaintAuditEvent(
      id: '${complaintId}_evt_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.priorityChanged,
      actorId: actorId,
      timestamp: now,
      metadata: {
        'priority': newPriority.value,
        'reason': ?reason,
        'actorRole': 'Operations Staff',
      },
    );

    await appendAuditEvent(event);
    _emit();
    _emitComplaint(complaintId);
    return updated;
  }

  @override
  Future<Complaint> assignComplaintTechnician(
    String complaintId,
    String technicianId, {
    required String actorId,
    String? reason,
    String? role,
    DateTime? scheduledDate,
    String? timeSlot,
  }) async {
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) {
      throw const ComplaintFailure(ComplaintFailureCode.notFound);
    }

    final current = _complaints[index];
    final now = DateTime.now();
    final isReassign =
        current.currentTechnicianId != null &&
        current.currentTechnicianId!.isNotEmpty &&
        current.currentTechnicianId != technicianId;

    final updated = Complaint(
      id: current.id,
      tenantId: current.tenantId,
      propertyId: current.propertyId,
      unitId: current.unitId,
      title: current.title,
      description: current.description,
      category: current.category,
      priority: current.priority,
      status: ComplaintStatus.assigned,
      currentTechnicianId: technicianId,
      activeVisitId: current.activeVisitId,
      visitCount: current.visitCount,
      reopenCount: current.reopenCount,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      firstAssignedAt: current.firstAssignedAt ?? now,
      resolvedAt: current.resolvedAt,
      closedAt: current.closedAt,
      updatedAt: now,
    );
    _complaints[index] = updated;

    final event = ComplaintAuditEvent(
      id: '${complaintId}_evt_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: isReassign
          ? ComplaintAuditEventType.technicianReassigned
          : ComplaintAuditEventType.technicianAssigned,
      rawEventType: isReassign
          ? 'TECHNICIAN_REASSIGNED'
          : 'TECHNICIAN_ASSIGNED',
      actorId: actorId,
      timestamp: now,
      metadata: {
        'technicianId': technicianId,
        'fromTechnicianId': current.currentTechnicianId,
        'toTechnicianId': technicianId,
        'reason': ?reason,
        'actorRole': ?role,
        'scheduledDate': ?scheduledDate?.toIso8601String(),
        'timeSlot': ?timeSlot,
      },
    );

    await appendAuditEvent(event);
    _emit();
    _emitComplaint(complaintId);
    return updated;
  }

  @override
  Stream<List<Complaint>> watchAssignedComplaints({
    required String technicianId,
  }) {
    final tid = technicianId.trim();
    if (tid.isEmpty) {
      throw const ComplaintValidationException(
        'Technician ID cannot be empty.',
      );
    }

    List<Complaint> filter(List<Complaint> list) {
      return list.where((item) {
        if (item.currentTechnicianId != tid) return false;
        if (!item.status.isActive) return false;
        return true;
      }).toList();
    }

    late final StreamController<List<Complaint>> controller;
    StreamSubscription<List<Complaint>>? sub;

    controller = StreamController<List<Complaint>>(
      onListen: () {
        void sendInitial() {
          if (!controller.isClosed) {
            final initial = filter(_complaints);
            sortTechnicianQueue(initial);
            controller.add(initial);
          }
        }

        if (streamDelay > Duration.zero) {
          Future<void>.delayed(streamDelay, sendInitial);
        } else {
          scheduleMicrotask(sendInitial);
        }

        sub = _controller.stream.listen(
          (data) {
            if (!controller.isClosed) {
              final filtered = filter(data);
              sortTechnicianQueue(filtered);
              controller.add(filtered);
            }
          },
          onError: (Object err, StackTrace st) {
            if (!controller.isClosed) {
              controller.addError(err, st);
            }
          },
        );
      },
      onCancel: () {
        sub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<Complaint> advanceVisitStep(
    String complaintId,
    VisitWorkflowStep step, {
    required String actorId,
    String? role,
    String? note,
    List<String>? photos,
  }) async {
    if (simulateFailure) {
      throw const ComplaintWriteException(
        'Simulated repository write failure.',
      );
    }
    if (operationDelay > Duration.zero) {
      await Future<void>.delayed(operationDelay);
    }

    final index = _complaints.indexWhere((c) => c.id == complaintId.trim());
    if (index == -1) {
      throw const ComplaintNotFoundException('Complaint not found.');
    }

    final current = _complaints[index];
    final now = DateTime.now();
    var activeVisitId = current.activeVisitId;
    var visitCount = current.visitCount;
    if (step == VisitWorkflowStep.accepted &&
        (activeVisitId == null || activeVisitId.trim().isEmpty)) {
      visitCount += 1;
      activeVisitId = '${current.id}_visit_$visitCount';
      _maintenanceVisits
          .putIfAbsent(current.id, () => [])
          .add(
            MaintenanceVisit(
              id: activeVisitId,
              complaintId: current.id,
              technicianId: actorId,
              visitNumber: visitCount,
              startedAt: now,
              completedAt: null,
              observation: null,
              actionTaken: null,
              outcome: null,
              isResolved: false,
              followUpRequired: false,
              followUpNotes: null,
              resolutionSummary: null,
              operationId: activeVisitId,
            ),
          );
      _emitVisits(current.id);
    }

    ComplaintStatus newStatus = current.status;
    if (step == VisitWorkflowStep.inspection ||
        step == VisitWorkflowStep.repairing) {
      newStatus = ComplaintStatus.inProgress;
    }

    final updated = Complaint(
      id: current.id,
      tenantId: current.tenantId,
      propertyId: current.propertyId,
      unitId: current.unitId,
      title: current.title,
      description: current.description,
      category: current.category,
      priority: current.priority,
      status: newStatus,
      currentTechnicianId: current.currentTechnicianId ?? actorId,
      activeVisitId: activeVisitId,
      visitCount: visitCount,
      reopenCount: current.reopenCount,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      firstAssignedAt: current.firstAssignedAt ?? now,
      resolvedAt: current.resolvedAt,
      closedAt: current.closedAt,
      updatedAt: now,
    );
    _complaints[index] = updated;

    final event = ComplaintAuditEvent(
      id: '${complaintId}_evt_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: step == VisitWorkflowStep.inspection
          ? ComplaintAuditEventType.visitStarted
          : ComplaintAuditEventType.unknown,
      rawEventType: step.auditEventName,
      actorId: actorId,
      timestamp: now,
      metadata: {
        'step': step.name,
        'actorRole': role ?? 'technician',
        'note': note ?? 'Step advanced to ${step.label}',
        if (photos != null && photos.isNotEmpty) 'photos': photos,
      },
    );

    await appendAuditEvent(event);
    _emit();
    _emitComplaint(complaintId);
    return updated;
  }

  @override
  Future<void> addVisitPhoto(
    String complaintId, {
    required String photoUrl,
    required String group,
    required String actorId,
    String? role,
  }) async {
    if (simulateFailure) {
      throw const ComplaintWriteException(
        'Simulated repository write failure.',
      );
    }
    if (operationDelay > Duration.zero) {
      await Future<void>.delayed(operationDelay);
    }

    final now = DateTime.now();
    final event = ComplaintAuditEvent(
      id: '${complaintId}_photo_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.unknown,
      rawEventType: 'PHOTO_UPLOADED',
      actorId: actorId,
      timestamp: now,
      metadata: {
        'photoUrl': photoUrl,
        'group': group,
        'actorRole': role ?? 'technician',
        'note': 'Photo uploaded ($group evidence)',
      },
    );

    await appendAuditEvent(event);
    _emitComplaint(complaintId);
  }

  @override
  Future<void> addPart(
    String complaintId,
    VisitPartInput part, {
    required String actorId,
    String? role,
  }) async {
    if (simulateFailure) {
      throw const ComplaintWriteException(
        'Simulated repository write failure.',
      );
    }
    if (operationDelay > Duration.zero) {
      await Future<void>.delayed(operationDelay);
    }

    final now = DateTime.now();
    final event = ComplaintAuditEvent(
      id: '${complaintId}_part_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.unknown,
      rawEventType: 'PART_ADDED',
      actorId: actorId,
      timestamp: now,
      metadata: {
        'name': part.name,
        'quantity': part.quantity,
        if (part.cost != null) 'cost': part.cost,
        'actorRole': role ?? 'technician',
        'note': 'Part added: ${part.name} (x${part.quantity})',
      },
    );

    await appendAuditEvent(event);
    _emitComplaint(complaintId);
  }

  @override
  Future<Complaint> completeVisit(
    String complaintId,
    VisitCompletionInput completion, {
    required String actorId,
    String? role,
  }) async {
    if (simulateFailure) {
      throw const ComplaintWriteException(
        'Simulated repository write failure.',
      );
    }
    if (operationDelay > Duration.zero) {
      await Future<void>.delayed(operationDelay);
    }

    final index = _complaints.indexWhere((c) => c.id == complaintId.trim());
    if (index == -1) {
      throw const ComplaintNotFoundException('Complaint not found.');
    }

    final current = _complaints[index];
    final now = DateTime.now();

    var activeVisitId = current.activeVisitId;
    var visitCount = current.visitCount;
    if (activeVisitId == null || activeVisitId.trim().isEmpty) {
      // The in-memory adapter supports the legacy completion form being
      // opened directly in previews/tests. Production Firestore completion
      // still requires an explicitly started active visit.
      visitCount += 1;
      activeVisitId = '${current.id}_visit_$visitCount';
      _maintenanceVisits
          .putIfAbsent(current.id, () => [])
          .add(
            MaintenanceVisit(
              id: activeVisitId,
              complaintId: current.id,
              technicianId: actorId,
              visitNumber: visitCount,
              startedAt: now,
              completedAt: null,
              observation: null,
              actionTaken: null,
              outcome: null,
              isResolved: false,
              followUpRequired: false,
              followUpNotes: null,
              resolutionSummary: null,
              operationId: activeVisitId,
            ),
          );
    }
    _replaceInMemoryVisit(
      complaintId: current.id,
      visitId: activeVisitId,
      technicianId: actorId,
      completedAt: now,
      observation: completion.whatWasFound,
      actionTaken: completion.whatWasRepaired,
      outcome: MaintenanceVisitOutcome.resolved,
      isResolved: true,
      resolutionSummary: completion.tenantResolutionNotes,
    );

    final updated = Complaint(
      id: current.id,
      tenantId: current.tenantId,
      propertyId: current.propertyId,
      unitId: current.unitId,
      title: current.title,
      description: current.description,
      category: current.category,
      priority: current.priority,
      status: ComplaintStatus.resolved,
      currentTechnicianId: current.currentTechnicianId ?? actorId,
      activeVisitId: null,
      visitCount: visitCount,
      reopenCount: current.reopenCount,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      firstAssignedAt: current.firstAssignedAt ?? now,
      resolvedAt: now,
      closedAt: current.closedAt,
      updatedAt: now,
    );
    _complaints[index] = updated;

    for (final part in completion.parts) {
      await addPart(complaintId, part, actorId: actorId, role: role);
    }

    final repairCompletedEvent = ComplaintAuditEvent(
      id: '${complaintId}_evt_repaired_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.complaintResolved,
      rawEventType: 'REPAIR_COMPLETED',
      actorId: actorId,
      timestamp: now,
      metadata: {
        'whatWasFound': completion.whatWasFound,
        'whatWasRepaired': completion.whatWasRepaired,
        'additionalWorkRecommended': completion.additionalWorkRecommended,
        if (completion.additionalWorkNotes != null)
          'additionalWorkNotes': completion.additionalWorkNotes,
        'actorRole': role ?? 'technician',
        'note': completion.whatWasRepaired,
      },
    );
    await appendAuditEvent(repairCompletedEvent);

    final markedResolvedEvent = ComplaintAuditEvent(
      id: '${complaintId}_evt_resolved_${now.millisecondsSinceEpoch + 1}',
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.complaintResolved,
      rawEventType: 'MARKED_RESOLVED',
      actorId: actorId,
      timestamp: now.add(const Duration(milliseconds: 1)),
      metadata: {
        'resolutionNotes': completion.tenantResolutionNotes,
        'actorRole': role ?? 'technician',
        'note': 'Marked resolved: ${completion.tenantResolutionNotes}',
      },
    );
    await appendAuditEvent(markedResolvedEvent);

    final tenantNotifiedEvent = ComplaintAuditEvent(
      id: '${complaintId}_evt_tenant_notified_${now.millisecondsSinceEpoch + 2}',
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.unknown,
      rawEventType: 'TENANT_NOTIFIED',
      actorId: actorId,
      timestamp: now.add(const Duration(milliseconds: 2)),
      metadata: {
        'actorRole': role ?? 'technician',
        'note': 'Tenant notified to confirm resolution or reopen.',
      },
    );
    await appendAuditEvent(tenantNotifiedEvent);

    _emit();
    _emitComplaint(complaintId);
    return updated;
  }

  void _replaceInMemoryVisit({
    required String complaintId,
    required String visitId,
    required String technicianId,
    required DateTime completedAt,
    required String observation,
    required String actionTaken,
    required MaintenanceVisitOutcome outcome,
    required bool isResolved,
    String? followUpNotes,
    String? resolutionSummary,
  }) {
    final visits = _maintenanceVisits.putIfAbsent(complaintId, () => []);
    final index = visits.indexWhere((visit) => visit.id == visitId);
    if (index == -1) return;
    final current = visits[index];
    visits[index] = MaintenanceVisit(
      id: current.id,
      complaintId: current.complaintId,
      technicianId: current.technicianId.isEmpty
          ? technicianId
          : current.technicianId,
      visitNumber: current.visitNumber,
      startedAt: current.startedAt,
      completedAt: completedAt,
      observation: observation.trim(),
      actionTaken: actionTaken.trim(),
      outcome: outcome,
      isResolved: isResolved,
      followUpRequired: followUpNotes != null,
      followUpNotes: followUpNotes,
      resolutionSummary: resolutionSummary,
      operationId: current.operationId,
    );
    _emitVisits(complaintId);
  }

  @override
  Future<Complaint> requestFollowUpVisit(
    String complaintId,
    FollowUpRequestInput request, {
    required String actorId,
    String? role,
  }) async {
    if (simulateFailure) {
      throw const ComplaintWriteException(
        'Simulated repository write failure.',
      );
    }
    if (operationDelay > Duration.zero) {
      await Future<void>.delayed(operationDelay);
    }

    final index = _complaints.indexWhere((c) => c.id == complaintId.trim());
    if (index == -1) {
      throw const ComplaintNotFoundException('Complaint not found.');
    }

    final current = _complaints[index];
    final now = DateTime.now();
    var activeVisitId = current.activeVisitId;
    var visitCount = current.visitCount;
    if (activeVisitId == null || activeVisitId.trim().isEmpty) {
      visitCount += 1;
      activeVisitId = '${current.id}_visit_$visitCount';
      _maintenanceVisits
          .putIfAbsent(current.id, () => [])
          .add(
            MaintenanceVisit(
              id: activeVisitId,
              complaintId: current.id,
              technicianId: actorId,
              visitNumber: visitCount,
              startedAt: now,
              completedAt: null,
              observation: null,
              actionTaken: null,
              outcome: null,
              isResolved: false,
              followUpRequired: false,
              followUpNotes: null,
              resolutionSummary: null,
              operationId: activeVisitId,
            ),
          );
    }
    _replaceInMemoryVisit(
      complaintId: current.id,
      visitId: activeVisitId,
      technicianId: actorId,
      completedAt: now,
      observation: request.details,
      actionTaken: 'Follow-up required: ${request.reason.label}',
      outcome: request.reason == FollowUpReason.partNotAvailable
          ? MaintenanceVisitOutcome.waitingForParts
          : MaintenanceVisitOutcome.unresolved,
      isResolved: false,
      followUpNotes: request.details,
      resolutionSummary: request.details,
    );

    final updated = Complaint(
      id: current.id,
      tenantId: current.tenantId,
      propertyId: current.propertyId,
      unitId: current.unitId,
      title: current.title,
      description: current.description,
      category: current.category,
      priority: current.priority,
      status: ComplaintStatus.assigned,
      currentTechnicianId: current.currentTechnicianId ?? actorId,
      activeVisitId: null,
      visitCount: visitCount,
      reopenCount: current.reopenCount,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      firstAssignedAt: current.firstAssignedAt ?? now,
      resolvedAt: null,
      closedAt: null,
      updatedAt: now,
    );
    _complaints[index] = updated;

    final followUpEvent = ComplaintAuditEvent(
      id: '${complaintId}_evt_followup_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.followUpRequested,
      rawEventType: 'NEEDS_ANOTHER_VISIT',
      actorId: actorId,
      timestamp: now,
      metadata: {
        'reason': request.reason.label,
        if (request.otherReasonDetails != null)
          'otherReasonDetails': request.otherReasonDetails,
        'details': request.details,
        if (request.suggestedDate != null)
          'suggestedDate': request.suggestedDate!.toIso8601String(),
        if (request.suggestedSlot != null)
          'suggestedSlot': request.suggestedSlot,
        if (request.partsToBring.isNotEmpty)
          'partsToBring': request.partsToBring,
        'flaggedForStaff': true,
        'actorRole': role ?? 'technician',
        'note':
            'Needs another visit: ${request.reason.label} - ${request.details}',
      },
    );
    await appendAuditEvent(followUpEvent);

    _emit();
    _emitComplaint(complaintId);
    return updated;
  }

  @override
  Future<Complaint> changeStatus(StatusChange change) async {
    if (simulateFailure) {
      throw const ComplaintFailure(
        ComplaintFailureCode.network,
        'Simulated network failure',
      );
    }
    if (operationDelay > Duration.zero) {
      await Future<void>.delayed(operationDelay);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    final index = _complaints.indexWhere((c) => c.id == change.complaintId);
    if (index == -1) {
      throw const ComplaintFailure(ComplaintFailureCode.notFound);
    }

    final current = _complaints[index];
    final now = DateTime.now();

    final isReopen = change.to == ComplaintStatus.reopened;
    final updated = Complaint(
      id: current.id,
      tenantId: current.tenantId,
      propertyId: current.propertyId,
      unitId: current.unitId,
      title: current.title,
      description: current.description,
      category: current.category,
      priority: current.priority,
      status: change.to,
      currentTechnicianId: current.currentTechnicianId,
      activeVisitId: current.activeVisitId,
      visitCount: isReopen ? current.visitCount + 1 : current.visitCount,
      isRepeatVisit: isReopen ? true : current.isRepeatVisit,
      reopenCount: isReopen ? current.reopenCount + 1 : current.reopenCount,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      firstAssignedAt: current.firstAssignedAt,
      resolvedAt: change.to == ComplaintStatus.resolved
          ? now
          : current.resolvedAt,
      closedAt: change.to == ComplaintStatus.closed ? now : current.closedAt,
      updatedAt: now,
    );
    _complaints[index] = updated;

    final (rawType, eventTypeEnum) = switch (change.to) {
      ComplaintStatus.waitingForParts => (
        'waiting-for-parts',
        ComplaintAuditEventType.complaintWaitingForParts,
      ),
      ComplaintStatus.inProgress
          when current.status == ComplaintStatus.waitingForParts =>
        ('work-resumed', ComplaintAuditEventType.visitStarted),
      ComplaintStatus.inProgress => (
        'WORK_STARTED',
        ComplaintAuditEventType.visitStarted,
      ),
      ComplaintStatus.reopened => (
        'reopened',
        ComplaintAuditEventType.complaintReopened,
      ),
      ComplaintStatus.closed => (
        change.tenantConfirmed == true
            ? 'closed_with_tenant_confirmation'
            : 'closed_without_tenant_confirmation',
        ComplaintAuditEventType.complaintClosed,
      ),
      ComplaintStatus.cancelled => (
        'cancelled',
        ComplaintAuditEventType.complaintCancelled,
      ),
      ComplaintStatus.resolved => (
        'REPAIR_COMPLETED',
        ComplaintAuditEventType.complaintResolved,
      ),
      ComplaintStatus.assigned => (
        'TECHNICIAN_ASSIGNED',
        ComplaintAuditEventType.technicianAssigned,
      ),
      ComplaintStatus.open => (
        'COMPLAINT_OPENED',
        ComplaintAuditEventType.complaintCreated,
      ),
    };

    final eventMeta = <String, dynamic>{
      'status': change.to.value,
      'actorRole': change.role ?? 'User',
      if (change.note != null && change.note!.isNotEmpty) 'note': change.note,
      if (change.reason != null && change.reason!.isNotEmpty)
        'reason': change.reason,
      if (change.parts != null && change.parts!.isNotEmpty)
        'parts': change.parts,
      if (change.expectedDate != null)
        'expectedDate': change.expectedDate!.toIso8601String(),
      if (change.tenantConfirmed != null)
        'tenantConfirmed': change.tenantConfirmed,
      if (change.photos.isNotEmpty) 'photos': change.photos,
    };

    final event = ComplaintAuditEvent(
      id: '${change.complaintId}_evt_${now.millisecondsSinceEpoch}',
      complaintId: change.complaintId,
      eventType: eventTypeEnum,
      rawEventType: rawType,
      actorId: change.actor,
      timestamp: now,
      metadata: eventMeta,
    );

    await appendAuditEvent(event);
    _emit();
    _emitComplaint(change.complaintId);
    return updated;
  }

  void addComplaint(Complaint complaint) {
    _complaints.add(complaint);
    _emit();
    _emitComplaint(complaint.id);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  void dispose() {
    _controller.close();
    for (final c in _complaintControllers.values) {
      c.close();
    }
    for (final c in _auditControllers.values) {
      c.close();
    }
  }
}
