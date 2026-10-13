import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/enums/complaint_audit_event_type.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/user_role.dart';
import '../core/models/complaint.dart';
import '../core/models/technician_assignment.dart';
import '../core/models/user.dart';
import 'auth_service.dart';
import 'complaint_audit_service.dart';

const String technicianAssignedEventType = 'TECHNICIAN_ASSIGNED';
const String technicianReassignedEventType = 'TECHNICIAN_REASSIGNED';

enum TechnicianAssignmentFailureCode {
  validation,
  unauthenticated,
  unauthorized,
  complaintNotFound,
  technicianNotFound,
  invalidTechnician,
  invalidStatus,
  sameTechnician,
  permissionDenied,
  network,
  conflict,
  malformedData,
  write,
  unknown,
}

/// Typed failure with safe messages for the assignment workflow.
class TechnicianAssignmentFailure implements Exception {
  const TechnicianAssignmentFailure(this.code, [this.details]);

  final TechnicianAssignmentFailureCode code;
  final String? details;

  String get message =>
      details ??
      switch (code) {
        TechnicianAssignmentFailureCode.validation => 'Please provide a valid complaint, technician, and operation request.',
        TechnicianAssignmentFailureCode.unauthenticated =>
          'You need to sign in before assigning a technician.',
        TechnicianAssignmentFailureCode.unauthorized =>
          'Only authorized operations staff can assign technicians.',
        TechnicianAssignmentFailureCode.complaintNotFound =>
          'The complaint could not be found.',
        TechnicianAssignmentFailureCode.technicianNotFound =>
          'The selected technician could not be found.',
        TechnicianAssignmentFailureCode.invalidTechnician =>
          'The selected user is not an active technician.',
        TechnicianAssignmentFailureCode.invalidStatus =>
          'The complaint is not in a status that allows this assignment.',
        TechnicianAssignmentFailureCode.sameTechnician =>
          'The complaint is already assigned to that technician.',
        TechnicianAssignmentFailureCode.permissionDenied =>
          'You do not have permission to assign this complaint.',
        TechnicianAssignmentFailureCode.network =>
          'Unable to reach the service. Check your connection and try again.',
        TechnicianAssignmentFailureCode.conflict => 'The complaint changed while it was being assigned. Refresh and try again.',
        TechnicianAssignmentFailureCode.malformedData =>
          'The complaint or assignment data could not be read safely.',
        TechnicianAssignmentFailureCode.write =>
          'Unable to save the technician assignment. Please try again.',
        TechnicianAssignmentFailureCode.unknown =>
          'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'TechnicianAssignmentFailure(${code.name})';
}

/// Pure assignment rules shared by the Firestore service and unit tests.
abstract final class TechnicianAssignmentPolicy {
  static void validateActor(AppUser actor) {
    if (!actor.isAuthorized || !actor.role.isOperationsStaff) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.unauthorized,
      );
    }
  }

  static void validateTechnician(AppUser technician) {
    if (!technician.isActive || technician.role != UserRole.technician) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.invalidTechnician,
      );
    }
  }

  static TechnicianAssignmentType validateInitialAssignment(
    Complaint complaint,
    String technicianId,
  ) {
    if (complaint.currentTechnicianId != null) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.conflict,
      );
    }
    if (complaint.status != ComplaintStatus.open) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.invalidStatus,
      );
    }
    if (technicianId.trim().isEmpty) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.validation,
      );
    }
    return TechnicianAssignmentType.initialAssignment;
  }

  static TechnicianAssignmentType validateReassignment(
    Complaint complaint,
    String technicianId,
  ) {
    final currentTechnicianId = complaint.currentTechnicianId;
    if (currentTechnicianId == null || currentTechnicianId.isEmpty) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.invalidStatus,
      );
    }
    if (currentTechnicianId == technicianId.trim()) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.sameTechnician,
      );
    }
    final allowed = {
      ComplaintStatus.assigned,
      ComplaintStatus.inProgress,
      ComplaintStatus.waitingForParts,
      ComplaintStatus.reopened,
    };
    if (!allowed.contains(complaint.status)) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.invalidStatus,
      );
    }
    if (technicianId.trim().isEmpty) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.validation,
      );
    }
    return TechnicianAssignmentType.reassignment;
  }
}

abstract final class TechnicianAssignmentFirestorePayloads {
  static Map<String, dynamic> history({
    required String complaintId,
    required String? previousTechnicianId,
    required String newTechnicianId,
    required String actorId,
    required TechnicianAssignmentType assignmentType,
    required String operationId,
    String? reason,
  }) => {
    'complaintId': complaintId,
    'previousTechnicianId': previousTechnicianId,
    'newTechnicianId': newTechnicianId,
    'assignedBy': actorId,
    'assignedAt': FieldValue.serverTimestamp(),
    'assignmentType': assignmentType.value,
    'operationId': operationId,
    if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
  };

  static Map<String, dynamic> audit({
    required String complaintId,
    required String actorId,
    required String? previousTechnicianId,
    required String newTechnicianId,
    required TechnicianAssignmentType assignmentType,
    required String operationId,
    UserRole? actorRole,
  }) => ComplaintAuditWriter.buildPayload(
    complaintId: complaintId,
    eventType: assignmentType == TechnicianAssignmentType.initialAssignment
        ? ComplaintAuditEventType.technicianAssigned
        : ComplaintAuditEventType.technicianReassigned,
    actorId: actorId,
    actorRole: actorRole?.value,
    details: {
      'previousTechnicianId': previousTechnicianId,
      'newTechnicianId': newTechnicianId,
      'assignmentType': assignmentType.value,
      'operationId': operationId,
    },
    schemaVersion: actorRole == null ? null : 1,
  );
}

/// Atomically changes complaint responsibility, appends history, and appends
/// the corresponding audit event.
class TechnicianAssignmentService {
  TechnicianAssignmentService({
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

  Future<Complaint> assignTechnician({
    required String complaintId,
    required String technicianId,
    String? reason,
    String? operationId,
  }) => _changeTechnician(
    complaintId: complaintId,
    technicianId: technicianId,
    reason: reason,
    operationId: operationId,
    isReassignment: false,
  );

  Future<Complaint> reassignTechnician({
    required String complaintId,
    required String newTechnicianId,
    String? reason,
    String? operationId,
  }) => _changeTechnician(
    complaintId: complaintId,
    technicianId: newTechnicianId,
    reason: reason,
    operationId: operationId,
    isReassignment: true,
  );

  Future<List<TechnicianAssignment>> getAssignmentHistory(
    String complaintId,
  ) async {
    final normalizedComplaintId = complaintId.trim();
    _validateId(normalizedComplaintId, 'Complaint ID');
    final user = _identity.currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.unauthenticated,
      );
    }

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.technicianAssignments)
          .where('complaintId', isEqualTo: normalizedComplaintId)
          .get();
      final history = snapshot.docs
          .map((doc) => TechnicianAssignment.fromMap(doc.data(), id: doc.id))
          .toList();
      history.sort((a, b) {
        final aTime = a.assignedAt;
        final bTime = b.assignedAt;
        if (aTime == null && bTime == null) return a.id.compareTo(b.id);
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        final result = aTime.compareTo(bTime);
        return result == 0 ? a.id.compareTo(b.id) : result;
      });
      return history;
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    } catch (error) {
      if (error is TechnicianAssignmentFailure) rethrow;
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.unknown,
      );
    }
  }

  Future<Complaint> _changeTechnician({
    required String complaintId,
    required String technicianId,
    required String? reason,
    required String? operationId,
    required bool isReassignment,
  }) async {
    final normalizedComplaintId = complaintId.trim();
    final normalizedTechnicianId = technicianId.trim();
    _validateId(normalizedComplaintId, 'Complaint ID');
    _validateId(normalizedTechnicianId, 'Technician ID');
    final user = _identity.currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.unauthenticated,
      );
    }

    final normalizedOperationId = operationId?.trim().isNotEmpty == true
        ? operationId!.trim()
        : _firestore
              .collection(FirestoreCollections.technicianAssignments)
              .doc()
              .id;
    _validateId(normalizedOperationId, 'Operation ID');
    final historyRef = _firestore
        .collection(FirestoreCollections.technicianAssignments)
        .doc('${normalizedComplaintId}_$normalizedOperationId');
    final auditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc('technician_${normalizedComplaintId}_$normalizedOperationId');
    final complaintRef = _firestore
        .collection(FirestoreCollections.complaints)
        .doc(normalizedComplaintId);
    final actorRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid);
    final technicianRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(normalizedTechnicianId);

    try {
      return await _firestore.runTransaction<Complaint>((transaction) async {
        // Every read is complete before the first write. Firestore may retry
        // this callback, so the stable refs above make the operation idempotent.
        final complaintSnapshot = await transaction.get(complaintRef);
        final actorSnapshot = await transaction.get(actorRef);
        final technicianSnapshot = await transaction.get(technicianRef);
        final historySnapshot = await transaction.get(historyRef);
        final auditSnapshot = await transaction.get(auditRef);

        if (!complaintSnapshot.exists || complaintSnapshot.data() == null) {
          throw const TechnicianAssignmentFailure(
            TechnicianAssignmentFailureCode.complaintNotFound,
          );
        }
        final complaintData = complaintSnapshot.data();
        if (complaintData == null) {
          throw const TechnicianAssignmentFailure(
            TechnicianAssignmentFailureCode.malformedData,
          );
        }
        final complaint = Complaint.fromMap(
          complaintData,
          id: complaintSnapshot.id,
        );
        if (!actorSnapshot.exists || actorSnapshot.data() == null) {
          throw const TechnicianAssignmentFailure(
            TechnicianAssignmentFailureCode.unauthorized,
          );
        }
        final actorProfile = _profileFromSnapshot(actorSnapshot);
        TechnicianAssignmentPolicy.validateActor(actorProfile);
        final actor = AuditActorContext.fromProfile(
          profile: actorProfile,
          authenticatedUid: user.uid,
        );
        if (!technicianSnapshot.exists || technicianSnapshot.data() == null) {
          throw const TechnicianAssignmentFailure(
            TechnicianAssignmentFailureCode.technicianNotFound,
          );
        }
        final technician = _profileFromSnapshot(technicianSnapshot);
        TechnicianAssignmentPolicy.validateTechnician(technician);

        if (historySnapshot.exists || auditSnapshot.exists) {
          if (!historySnapshot.exists || !auditSnapshot.exists) {
            throw const TechnicianAssignmentFailure(
              TechnicianAssignmentFailureCode.conflict,
            );
          }
          final historyData = historySnapshot.data();
          final storedAssignmentType = TechnicianAssignmentType.tryFromValue(
            historyData?['assignmentType'] as String?,
          );
          if (storedAssignmentType == null ||
              (isReassignment !=
                  (storedAssignmentType ==
                      TechnicianAssignmentType.reassignment))) {
            throw const TechnicianAssignmentFailure(
              TechnicianAssignmentFailureCode.conflict,
            );
          }
          final storedPreviousTechnicianId =
              historyData?['previousTechnicianId'] as String?;
          _verifyIdempotentPair(
            historyData,
            auditSnapshot.data(),
            complaintId: normalizedComplaintId,
            actorId: user.uid,
            previousTechnicianId: storedPreviousTechnicianId,
            newTechnicianId: normalizedTechnicianId,
            assignmentType: storedAssignmentType,
            operationId: normalizedOperationId,
          );
          return complaint;
        }

        final assignmentType = isReassignment
            ? TechnicianAssignmentPolicy.validateReassignment(
                complaint,
                normalizedTechnicianId,
              )
            : TechnicianAssignmentPolicy.validateInitialAssignment(
                complaint,
                normalizedTechnicianId,
              );
        final previousTechnicianId = complaint.currentTechnicianId;

        final nextStatus =
            assignmentType == TechnicianAssignmentType.initialAssignment
            ? ComplaintStatus.assigned
            : complaint.status;
        final complaintUpdate = <String, dynamic>{
          'currentTechnicianId': normalizedTechnicianId,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (assignmentType == TechnicianAssignmentType.initialAssignment) {
          complaintUpdate['status'] = nextStatus.value;
          if (complaint.firstAssignedAt == null) {
            complaintUpdate['firstAssignedAt'] = FieldValue.serverTimestamp();
          }
        }

        transaction.update(complaintRef, complaintUpdate);
        transaction.set(
          historyRef,
          TechnicianAssignmentFirestorePayloads.history(
            complaintId: normalizedComplaintId,
            previousTechnicianId: previousTechnicianId,
            newTechnicianId: normalizedTechnicianId,
            actorId: user.uid,
            assignmentType: assignmentType,
            operationId: normalizedOperationId,
            reason: reason,
          ),
        );
        _auditWriter.appendEventInTransaction(
          transaction,
          eventId: auditRef.id,
          complaintId: normalizedComplaintId,
          eventType:
              assignmentType == TechnicianAssignmentType.initialAssignment
              ? ComplaintAuditEventType.technicianAssigned
              : ComplaintAuditEventType.technicianReassigned,
          actor: actor,
          details: {
            'previousTechnicianId': previousTechnicianId,
            'newTechnicianId': normalizedTechnicianId,
            'assignmentType': assignmentType.value,
            'operationId': normalizedOperationId,
          },
          reason: reason,
          eventWasAbsent: !auditSnapshot.exists,
        );

        return complaint.copyWith(
          currentTechnicianId: normalizedTechnicianId,
          status: nextStatus,
        );
      });
    } on TechnicianAssignmentFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    } catch (_) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.write,
      );
    }
  }

  static AppUser _profileFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.malformedData,
      );
    }
    return AppUser.fromMap(data, id: snapshot.id);
  }

  static void _verifyIdempotentPair(
    Map<String, dynamic>? historyData,
    Map<String, dynamic>? auditData, {
    required String complaintId,
    required String actorId,
    required String? previousTechnicianId,
    required String newTechnicianId,
    required TechnicianAssignmentType assignmentType,
    required String operationId,
  }) {
    if (historyData == null || auditData == null) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.malformedData,
      );
    }
    final historyMatches =
        historyData['complaintId'] == complaintId &&
        historyData['previousTechnicianId'] == previousTechnicianId &&
        historyData['newTechnicianId'] == newTechnicianId &&
        historyData['assignedBy'] == actorId &&
        historyData['assignmentType'] == assignmentType.value &&
        historyData['operationId'] == operationId;
    final metadata = auditData['metadata'];
    final auditMetadata = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : const <String, dynamic>{};
    final auditMatches =
        auditData['complaintId'] == complaintId &&
        auditData['eventType'] ==
            (assignmentType == TechnicianAssignmentType.initialAssignment
                ? technicianAssignedEventType
                : technicianReassignedEventType) &&
        auditData['actorId'] == actorId &&
        auditMetadata['previousTechnicianId'] == previousTechnicianId &&
        auditMetadata['newTechnicianId'] == newTechnicianId &&
        auditMetadata['assignmentType'] == assignmentType.value &&
        auditMetadata['operationId'] == operationId;
    if (!historyMatches || !auditMatches) {
      throw const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.conflict,
      );
    }
  }

  static void _validateId(String value, String label) {
    if (value.isEmpty || value.contains('/') || value.length > 128) {
      throw TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.validation,
        '$label is invalid.',
      );
    }
  }

  TechnicianAssignmentFailure _fromFirebaseException(FirebaseException error) {
    return switch (error.code) {
      'unauthenticated' => const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.unauthenticated,
      ),
      'permission-denied' => const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.permissionDenied,
      ),
      'not-found' => const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.complaintNotFound,
      ),
      'unavailable' ||
      'deadline-exceeded' ||
      'resource-exhausted' => const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.network,
      ),
      'aborted' || 'failed-precondition' => const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.conflict,
      ),
      _ => const TechnicianAssignmentFailure(
        TechnicianAssignmentFailureCode.write,
      ),
    };
  }
}
