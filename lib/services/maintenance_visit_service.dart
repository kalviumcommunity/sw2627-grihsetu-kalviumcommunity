import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/enums/complaint_audit_event_type.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/maintenance_visit_outcome.dart';
import '../core/enums/user_role.dart';
import '../core/models/complaint.dart';
import '../core/models/maintenance_visit.dart';
import '../core/models/user.dart';
import 'auth_service.dart';
import 'complaint_audit_service.dart';

enum MaintenanceVisitFailureCode {
  validation,
  unauthenticated,
  unauthorized,
  complaintNotFound,
  visitNotFound,
  invalidStatus,
  duplicateActiveVisit,
  alreadyCompleted,
  missingCompletionInformation,
  unsupportedOutcome,
  malformedData,
  permissionDenied,
  network,
  conflict,
  write,
  unknown,
}

class MaintenanceVisitFailure implements Exception {
  const MaintenanceVisitFailure(this.code, [this.details]);

  final MaintenanceVisitFailureCode code;
  final String? details;

  String get message =>
      details ??
      switch (code) {
        MaintenanceVisitFailureCode.validation =>
          'Please provide a valid complaint and visit request.',
        MaintenanceVisitFailureCode.unauthenticated =>
          'You need to sign in before recording a maintenance visit.',
        MaintenanceVisitFailureCode.unauthorized =>
          'Only the currently assigned technician can record this visit.',
        MaintenanceVisitFailureCode.complaintNotFound =>
          'The complaint could not be found.',
        MaintenanceVisitFailureCode.visitNotFound =>
          'The maintenance visit could not be found.',
        MaintenanceVisitFailureCode.invalidStatus =>
          'The complaint is not in a state that allows this visit.',
        MaintenanceVisitFailureCode.duplicateActiveVisit =>
          'This complaint already has an active maintenance visit.',
        MaintenanceVisitFailureCode.alreadyCompleted =>
          'This maintenance visit has already been completed.',
        MaintenanceVisitFailureCode.missingCompletionInformation => 'Observation, action taken, outcome, and follow-up status are required.',
        MaintenanceVisitFailureCode.unsupportedOutcome =>
          'The selected visit outcome is not supported.',
        MaintenanceVisitFailureCode.malformedData =>
          'The complaint, visit, or audit data could not be read safely.',
        MaintenanceVisitFailureCode.permissionDenied =>
          'You do not have permission to record this visit.',
        MaintenanceVisitFailureCode.network =>
          'Unable to reach the service. Check your connection and try again.',
        MaintenanceVisitFailureCode.conflict => 'The complaint changed while this visit was being saved. Refresh and try again.',
        MaintenanceVisitFailureCode.write =>
          'Unable to save the maintenance visit. Please try again.',
        MaintenanceVisitFailureCode.unknown =>
          'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'MaintenanceVisitFailure(${code.name})';
}

/// Pure transition and input validation shared by the Firestore workflow and
/// tests. The mapping follows PRD FR-12 and does not introduce statuses.
abstract final class MaintenanceVisitPolicy {
  static const allowedStartStatuses = <ComplaintStatus>{
    ComplaintStatus.assigned,
    ComplaintStatus.inProgress,
    ComplaintStatus.waitingForParts,
    ComplaintStatus.reopened,
  };

  static void validateStart({
    required Complaint complaint,
    required String actorId,
    required bool hasActiveVisit,
  }) {
    if (actorId.trim().isEmpty || complaint.id.trim().isEmpty) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.validation,
      );
    }
    if (complaint.currentTechnicianId != actorId.trim()) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.unauthorized,
      );
    }
    if (!allowedStartStatuses.contains(complaint.status)) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.invalidStatus,
      );
    }
    if (hasActiveVisit) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.duplicateActiveVisit,
      );
    }
  }

  static ComplaintStatus statusForOutcome(MaintenanceVisitOutcome outcome) {
    return switch (outcome) {
      MaintenanceVisitOutcome.resolved => ComplaintStatus.resolved,
      MaintenanceVisitOutcome.unresolved => ComplaintStatus.inProgress,
      MaintenanceVisitOutcome.waitingForParts =>
        ComplaintStatus.waitingForParts,
    };
  }

  static void validateCompletion({
    required String observation,
    required String actionTaken,
    required MaintenanceVisitOutcome? outcome,
    required bool isResolved,
    required bool followUpRequired,
    String? followUpNotes,
  }) {
    if (observation.trim().isEmpty || actionTaken.trim().isEmpty) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.missingCompletionInformation,
      );
    }
    if (outcome == null) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.unsupportedOutcome,
      );
    }
    if (isResolved != (outcome == MaintenanceVisitOutcome.resolved)) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.unsupportedOutcome,
        'Resolution status does not match the selected visit outcome.',
      );
    }
    if (followUpRequired &&
        (followUpNotes == null || followUpNotes.trim().isEmpty)) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.missingCompletionInformation,
        'Follow-up notes are required when follow-up is requested.',
      );
    }
  }
}

abstract final class MaintenanceVisitFirestorePayloads {
  static Map<String, dynamic> start({
    required String complaintId,
    required String technicianId,
    required int visitNumber,
    required String operationId,
  }) => {
    'complaintId': complaintId,
    'technicianId': technicianId,
    'visitNumber': visitNumber,
    'startedAt': FieldValue.serverTimestamp(),
    'completedAt': null,
    'observation': null,
    'actionTaken': null,
    'outcome': null,
    'isResolved': false,
    'followUpRequired': false,
    'followUpNotes': null,
    'resolutionSummary': null,
    'operationId': operationId,
  };

  static Map<String, dynamic> completion({
    required String observation,
    required String actionTaken,
    required MaintenanceVisitOutcome outcome,
    required bool isResolved,
    required bool followUpRequired,
    String? followUpNotes,
    String? resolutionSummary,
  }) => {
    'completedAt': FieldValue.serverTimestamp(),
    'observation': observation.trim(),
    'actionTaken': actionTaken.trim(),
    'outcome': outcome.value,
    'isResolved': isResolved,
    'followUpRequired': followUpRequired,
    'followUpNotes': _clean(followUpNotes),
    'resolutionSummary': _clean(resolutionSummary),
  };

  static String? _clean(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

/// Atomic start/complete workflow for assigned technician visits.
class MaintenanceVisitService {
  MaintenanceVisitService({
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

  /// Starts a visit atomically with the complaint counter, active visit link,
  /// complaint status, and audit events.
  ///
  /// Callers should persist and reuse [operationId] when retrying a request
  /// whose response was lost. Without it, a new logical operation is assumed.
  Future<MaintenanceVisit> startMaintenanceVisit({
    required String complaintId,
    String? operationId,
  }) async {
    final actorId = _requireUid();
    final normalizedComplaintId = _validId(complaintId, 'Complaint ID');
    final normalizedOperationId =
        operationId == null || operationId.trim().isEmpty
        ? null
        : _validId(operationId, 'Operation ID');
    final visitId = normalizedOperationId == null
        ? _firestore.collection(FirestoreCollections.maintenanceVisits).doc().id
        : _validId(
            'mv_${normalizedComplaintId}_$normalizedOperationId',
            'Visit ID',
          );
    final visitRef = _firestore
        .collection(FirestoreCollections.maintenanceVisits)
        .doc(visitId);
    final complaintRef = _firestore
        .collection(FirestoreCollections.complaints)
        .doc(normalizedComplaintId);
    final actorRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(actorId);
    final startedAuditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc('${visitId}_started');
    final startedStatusAuditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc('${visitId}_started_status');

    // Firestore's Flutter Transaction API reads documents, not queries. This
    // preflight supports legacy complaints whose visitCount was not initialized;
    // the complaint document remains the concurrency lock for all new starts.
    late final QuerySnapshot<Map<String, dynamic>> historicalVisits;
    try {
      historicalVisits = await _firestore
          .collection(FirestoreCollections.maintenanceVisits)
          .where('complaintId', isEqualTo: normalizedComplaintId)
          .get();
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    }
    var historicalMaxVisitNumber = 0;
    String? legacyActiveVisitId;
    for (final document in historicalVisits.docs) {
      final visit = _decodeVisit(document);
      if (visit.visitNumber > historicalMaxVisitNumber) {
        historicalMaxVisitNumber = visit.visitNumber;
      }
      if (visit.isActive) {
        if (legacyActiveVisitId != null && legacyActiveVisitId != document.id) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.malformedData,
            'More than one active maintenance visit exists for this complaint.',
          );
        }
        legacyActiveVisitId = document.id;
      }
    }

    try {
      return await _firestore.runTransaction<MaintenanceVisit>((
        transaction,
      ) async {
        final complaintSnapshot = await transaction.get(complaintRef);
        final actorSnapshot = await transaction.get(actorRef);
        final existingVisitSnapshot = await transaction.get(visitRef);
        final complaintData = complaintSnapshot.data();
        if (!complaintSnapshot.exists || complaintData == null) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.complaintNotFound,
          );
        }
        final complaint = Complaint.fromMap(
          complaintData,
          id: complaintSnapshot.id,
        );
        final actor = _actorFromSnapshot(actorSnapshot, actorId);
        _validateTechnicianActor(actor);

        DocumentSnapshot<Map<String, dynamic>>? activeVisitSnapshot;
        if (complaint.activeVisitId != null &&
            complaint.activeVisitId!.trim().isNotEmpty &&
            complaint.activeVisitId != visitRef.id) {
          activeVisitSnapshot = await transaction.get(
            _firestore
                .collection(FirestoreCollections.maintenanceVisits)
                .doc(complaint.activeVisitId),
          );
        }
        final startedAuditSnapshot = await transaction.get(startedAuditRef);
        final startedStatusAuditSnapshot = await transaction.get(
          startedStatusAuditRef,
        );

        final existingVisit = existingVisitSnapshot.exists
            ? _decodeVisit(existingVisitSnapshot)
            : null;
        if (existingVisit != null) {
          if (normalizedOperationId != null &&
              existingVisit.operationId == normalizedOperationId &&
              existingVisit.complaintId == normalizedComplaintId &&
              existingVisit.technicianId == actorId &&
              existingVisit.isActive &&
              complaint.activeVisitId == existingVisit.id) {
            _requireExistingAudit(
              startedAuditSnapshot,
              startedStatusAuditSnapshot,
              requiredStatusAudit:
                  complaint.status != ComplaintStatus.assigned &&
                  complaint.status != ComplaintStatus.reopened,
            );
            return existingVisit;
          }
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.conflict,
            'This operation ID is already associated with another visit.',
          );
        }

        final activeVisit = activeVisitSnapshot == null
            ? null
            : _decodeVisit(activeVisitSnapshot);
        final hasActiveVisit =
            complaint.activeVisitId != null ||
            activeVisit != null ||
            legacyActiveVisitId != null;
        if (complaint.activeVisitId != null &&
            activeVisitSnapshot != null &&
            !activeVisitSnapshot.exists) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.malformedData,
            'The complaint references a missing active visit.',
          );
        }
        MaintenanceVisitPolicy.validateStart(
          complaint: complaint,
          actorId: actorId,
          hasActiveVisit: hasActiveVisit,
        );

        final visitNumber =
            (complaint.visitCount > historicalMaxVisitNumber
                ? complaint.visitCount
                : historicalMaxVisitNumber) +
            1;
        final operation = normalizedOperationId ?? visitId;
        transaction.set(
          visitRef,
          MaintenanceVisitFirestorePayloads.start(
            complaintId: normalizedComplaintId,
            technicianId: actorId,
            visitNumber: visitNumber,
            operationId: operation,
          ),
        );
        transaction.update(complaintRef, {
          'visitCount': visitNumber,
          'isRepeatVisit': visitNumber > 1,
          'activeVisitId': visitId,
          'status': ComplaintStatus.inProgress.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final actorContext = AuditActorContext.fromProfile(
          profile: actor,
          authenticatedUid: actorId,
        );
        _auditWriter.appendEventInTransaction(
          transaction,
          eventId: startedAuditRef.id,
          complaintId: normalizedComplaintId,
          eventType: ComplaintAuditEventType.visitStarted,
          actor: actorContext,
          details: {
            'visitId': visitId,
            'visitNumber': visitNumber,
            'technicianId': actorId,
            'previousStatus': complaint.status.value,
            'newStatus': ComplaintStatus.inProgress.value,
            'operationId': operation,
          },
          previousValue: complaint.status.value,
          newValue: ComplaintStatus.inProgress.value,
          eventWasAbsent: !startedAuditSnapshot.exists,
        );
        if (complaint.status != ComplaintStatus.inProgress) {
          _auditWriter.appendEventInTransaction(
            transaction,
            eventId: startedStatusAuditRef.id,
            complaintId: normalizedComplaintId,
            eventType: ComplaintAuditEventType.complaintStatusChanged,
            actor: actorContext,
            details: {
              'visitId': visitId,
              'visitNumber': visitNumber,
              'previousStatus': complaint.status.value,
              'newStatus': ComplaintStatus.inProgress.value,
            },
            previousValue: complaint.status.value,
            newValue: ComplaintStatus.inProgress.value,
            eventWasAbsent: !startedStatusAuditSnapshot.exists,
          );
        }

        return MaintenanceVisit(
          id: visitId,
          complaintId: normalizedComplaintId,
          technicianId: actorId,
          visitNumber: visitNumber,
          startedAt: null,
          completedAt: null,
          observation: null,
          actionTaken: null,
          outcome: null,
          isResolved: false,
          followUpRequired: false,
          followUpNotes: null,
          resolutionSummary: null,
          operationId: operation,
        );
      });
    } on MaintenanceVisitFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    } on FormatException catch (error) {
      throw MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.malformedData,
        error.message,
      );
    } catch (_) {
      throw const MaintenanceVisitFailure(MaintenanceVisitFailureCode.write);
    }
  }

  /// Completes an active visit atomically with the complaint status and audit.
  Future<MaintenanceVisit> completeMaintenanceVisit({
    required String complaintId,
    required String visitId,
    required String observation,
    required String actionTaken,
    required MaintenanceVisitOutcome? outcome,
    required bool isResolved,
    required bool followUpRequired,
    String? followUpNotes,
    String? resolutionSummary,
  }) async {
    final actorId = _requireUid();
    final normalizedComplaintId = _validId(complaintId, 'Complaint ID');
    final normalizedVisitId = _validId(visitId, 'Visit ID');
    MaintenanceVisitPolicy.validateCompletion(
      observation: observation,
      actionTaken: actionTaken,
      outcome: outcome,
      isResolved: isResolved,
      followUpRequired: followUpRequired,
      followUpNotes: followUpNotes,
    );
    final complaintRef = _firestore
        .collection(FirestoreCollections.complaints)
        .doc(normalizedComplaintId);
    final visitRef = _firestore
        .collection(FirestoreCollections.maintenanceVisits)
        .doc(normalizedVisitId);
    final actorRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(actorId);
    final completedAuditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc('${normalizedVisitId}_completed');
    final completedStatusAuditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc('${normalizedVisitId}_completed_status');
    final followUpAuditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc('${normalizedVisitId}_follow_up');

    try {
      return await _firestore.runTransaction<MaintenanceVisit>((
        transaction,
      ) async {
        final complaintSnapshot = await transaction.get(complaintRef);
        final visitSnapshot = await transaction.get(visitRef);
        final actorSnapshot = await transaction.get(actorRef);
        final completedAuditSnapshot = await transaction.get(completedAuditRef);
        final completedStatusAuditSnapshot = await transaction.get(
          completedStatusAuditRef,
        );
        final followUpAuditSnapshot = await transaction.get(followUpAuditRef);
        final complaintData = complaintSnapshot.data();
        if (!complaintSnapshot.exists || complaintData == null) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.complaintNotFound,
          );
        }
        if (!visitSnapshot.exists || visitSnapshot.data() == null) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.visitNotFound,
          );
        }
        final complaint = Complaint.fromMap(
          complaintData,
          id: complaintSnapshot.id,
        );
        final visit = _decodeVisit(visitSnapshot);
        final actor = _actorFromSnapshot(actorSnapshot, actorId);
        _validateTechnicianActor(actor);
        if (visit.complaintId != normalizedComplaintId) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.conflict,
            'The visit does not belong to this complaint.',
          );
        }
        if (!visit.isActive || visit.completedAt != null) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.alreadyCompleted,
          );
        }
        if (complaint.activeVisitId != normalizedVisitId) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.conflict,
            'The visit is not the complaint\'s active visit.',
          );
        }
        if (complaint.currentTechnicianId != actorId ||
            visit.technicianId != actorId ||
            !MaintenanceVisitPolicy.allowedStartStatuses.contains(
              complaint.status,
            )) {
          throw const MaintenanceVisitFailure(
            MaintenanceVisitFailureCode.unauthorized,
          );
        }

        final nextStatus = MaintenanceVisitPolicy.statusForOutcome(outcome!);
        final actorContext = AuditActorContext.fromProfile(
          profile: actor,
          authenticatedUid: actorId,
        );
        transaction.update(
          visitRef,
          MaintenanceVisitFirestorePayloads.completion(
            observation: observation,
            actionTaken: actionTaken,
            outcome: outcome,
            isResolved: isResolved,
            followUpRequired: followUpRequired,
            followUpNotes: followUpNotes,
            resolutionSummary: resolutionSummary,
          ),
        );
        final complaintUpdate = <String, dynamic>{
          'activeVisitId': FieldValue.delete(),
          'status': nextStatus.value,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (nextStatus == ComplaintStatus.resolved &&
            complaint.resolvedAt == null) {
          complaintUpdate['resolvedAt'] = FieldValue.serverTimestamp();
        }
        transaction.update(complaintRef, complaintUpdate);

        _auditWriter.appendEventInTransaction(
          transaction,
          eventId: completedAuditRef.id,
          complaintId: normalizedComplaintId,
          eventType: ComplaintAuditEventType.visitCompleted,
          actor: actorContext,
          details: {
            'visitId': normalizedVisitId,
            'visitNumber': visit.visitNumber,
            'technicianId': actorId,
            'previousStatus': complaint.status.value,
            'newStatus': nextStatus.value,
            'outcome': outcome.value,
            'isResolved': isResolved,
            'followUpRequired': followUpRequired,
          },
          previousValue: complaint.status.value,
          newValue: nextStatus.value,
          eventWasAbsent: !completedAuditSnapshot.exists,
        );
        if (complaint.status != nextStatus) {
          _auditWriter.appendEventInTransaction(
            transaction,
            eventId: completedStatusAuditRef.id,
            complaintId: normalizedComplaintId,
            eventType: ComplaintAuditEventType.complaintStatusChanged,
            actor: actorContext,
            details: {
              'visitId': normalizedVisitId,
              'visitNumber': visit.visitNumber,
              'previousStatus': complaint.status.value,
              'newStatus': nextStatus.value,
              'outcome': outcome.value,
            },
            previousValue: complaint.status.value,
            newValue: nextStatus.value,
            eventWasAbsent: !completedStatusAuditSnapshot.exists,
          );
        }
        if (followUpRequired) {
          _auditWriter.appendEventInTransaction(
            transaction,
            eventId: followUpAuditRef.id,
            complaintId: normalizedComplaintId,
            eventType: ComplaintAuditEventType.followUpRequested,
            actor: actorContext,
            details: {
              'visitId': normalizedVisitId,
              'visitNumber': visit.visitNumber,
              'followUpNotes': followUpNotes!.trim(),
              'outcome': outcome.value,
            },
            eventWasAbsent: !followUpAuditSnapshot.exists,
          );
        }

        return MaintenanceVisit(
          id: visit.id,
          complaintId: visit.complaintId,
          technicianId: visit.technicianId,
          visitNumber: visit.visitNumber,
          startedAt: visit.startedAt,
          completedAt: null,
          observation: observation.trim(),
          actionTaken: actionTaken.trim(),
          outcome: outcome,
          isResolved: isResolved,
          followUpRequired: followUpRequired,
          followUpNotes: MaintenanceVisitFirestorePayloads._clean(
            followUpNotes,
          ),
          resolutionSummary: MaintenanceVisitFirestorePayloads._clean(
            resolutionSummary,
          ),
          operationId: visit.operationId,
        );
      });
    } on MaintenanceVisitFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    } on FormatException catch (error) {
      throw MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.malformedData,
        error.message,
      );
    } catch (_) {
      throw const MaintenanceVisitFailure(MaintenanceVisitFailureCode.write);
    }
  }

  Future<List<MaintenanceVisit>> getMaintenanceVisits(
    String complaintId,
  ) async {
    final normalizedId = _validId(complaintId, 'Complaint ID');
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.maintenanceVisits)
          .where('complaintId', isEqualTo: normalizedId)
          .get();
      final visits = snapshot.docs.map(_decodeVisit).toList()
        ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));
      return visits;
    } on FirebaseException catch (error) {
      throw _fromFirebaseException(error);
    } on FormatException catch (error) {
      throw MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.malformedData,
        error.message,
      );
    }
  }

  String _requireUid() {
    final uid = _identity.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.unauthenticated,
      );
    }
    return uid;
  }

  static AppUser _actorFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.unauthorized,
      );
    }
    final actor = AppUser.fromMap(data, id: snapshot.id);
    if (actor.id != uid) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.unauthorized,
      );
    }
    return actor;
  }

  static void _validateTechnicianActor(AppUser actor) {
    if (!actor.isAuthorized || actor.role != UserRole.technician) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.unauthorized,
      );
    }
  }

  static MaintenanceVisit _decodeVisit(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.malformedData,
      );
    }
    return MaintenanceVisit.fromMap(data, id: snapshot.id);
  }

  static void _requireExistingAudit(
    DocumentSnapshot<Map<String, dynamic>> startedAudit,
    DocumentSnapshot<Map<String, dynamic>> statusAudit, {
    required bool requiredStatusAudit,
  }) {
    if (!startedAudit.exists || (requiredStatusAudit && !statusAudit.exists)) {
      throw const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.malformedData,
        'The visit exists without its required audit event.',
      );
    }
  }

  static String _validId(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.contains('/') ||
        normalized.length > 128) {
      throw MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.validation,
        '$label is invalid.',
      );
    }
    return normalized;
  }

  static MaintenanceVisitFailure _fromFirebaseException(
    FirebaseException error,
  ) {
    return switch (error.code) {
      'permission-denied' => const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.permissionDenied,
      ),
      'not-found' => const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.complaintNotFound,
      ),
      'aborted' || 'failed-precondition' => const MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.conflict,
      ),
      'unavailable' || 'deadline-exceeded' || 'resource-exhausted' =>
        const MaintenanceVisitFailure(MaintenanceVisitFailureCode.network),
      _ => MaintenanceVisitFailure(
        MaintenanceVisitFailureCode.write,
        error.message,
      ),
    };
  }
}
