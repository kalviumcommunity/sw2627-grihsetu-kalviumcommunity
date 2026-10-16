import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/domain/complaint_transition_guard.dart';
import '../core/enums/complaint_audit_event_type.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/user_role.dart';
import '../core/models/complaint.dart';
import '../core/models/user.dart';
import 'auth_service.dart';
import 'complaint_audit_service.dart';

enum ComplaintLifecycleFailureCode {
  validation,
  unauthenticated,
  unauthorized,
  notFound,
  invalidTransition,
  missingReason,
  conflict,
  persistence,
}

class ComplaintLifecycleFailure implements Exception {
  const ComplaintLifecycleFailure(this.code, [this.details]);

  final ComplaintLifecycleFailureCode code;
  final String? details;

  String get message =>
      details ??
      switch (code) {
        ComplaintLifecycleFailureCode.validation =>
          'The lifecycle request is invalid.',
        ComplaintLifecycleFailureCode.unauthenticated =>
          'You need to sign in first.',
        ComplaintLifecycleFailureCode.unauthorized =>
          'You do not have permission for this action.',
        ComplaintLifecycleFailureCode.notFound =>
          'The complaint could not be found.',
        ComplaintLifecycleFailureCode.invalidTransition =>
          'That complaint status change is not allowed.',
        ComplaintLifecycleFailureCode.missingReason =>
          'A reason is required for this action.',
        ComplaintLifecycleFailureCode.conflict =>
          'The complaint changed. Refresh and try again.',
        ComplaintLifecycleFailureCode.persistence =>
          'Unable to save the complaint lifecycle change.',
      };
}

/// Atomic, authenticated close/reopen/cancel operations.
class ComplaintLifecycleService {
  ComplaintLifecycleService({
    FirebaseFirestore? firestore,
    AuthenticatedUserProvider? identity,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identity = identity ?? AuthService.firebase();

  final FirebaseFirestore _firestore;
  final AuthenticatedUserProvider _identity;

  Future<Complaint> closeComplaint({
    required String complaintId,
    String? operationId,
  }) => _transition(
    complaintId: complaintId,
    to: ComplaintStatus.closed,
    operationId: operationId,
  );

  Future<Complaint> reopenComplaint({
    required String complaintId,
    required String reason,
    String? operationId,
  }) => _transition(
    complaintId: complaintId,
    to: ComplaintStatus.reopened,
    reason: reason,
    operationId: operationId,
  );

  Future<Complaint> cancelComplaint({
    required String complaintId,
    required String reason,
    String? operationId,
  }) => _transition(
    complaintId: complaintId,
    to: ComplaintStatus.cancelled,
    reason: reason,
    operationId: operationId,
  );

  Future<Complaint> _transition({
    required String complaintId,
    required ComplaintStatus to,
    String? reason,
    String? operationId,
  }) async {
    final id = complaintId.trim();
    final actorId = _identity.currentUser?.uid.trim();
    if (id.isEmpty) {
      throw const ComplaintLifecycleFailure(
        ComplaintLifecycleFailureCode.validation,
      );
    }
    if (actorId == null || actorId.isEmpty) {
      throw const ComplaintLifecycleFailure(
        ComplaintLifecycleFailureCode.unauthenticated,
      );
    }
    final normalizedReason = reason?.trim();
    if ((to == ComplaintStatus.reopened || to == ComplaintStatus.cancelled) &&
        (normalizedReason == null || normalizedReason.isEmpty)) {
      throw const ComplaintLifecycleFailure(
        ComplaintLifecycleFailureCode.missingReason,
      );
    }

    final operation = operationId?.trim().isNotEmpty == true
        ? operationId!.trim()
        : _firestore.collection(FirestoreCollections.auditEvents).doc().id;
    final complaintRef = _firestore
        .collection(FirestoreCollections.complaints)
        .doc(id);
    final actorRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(actorId);
    final auditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc('lifecycle_${id}_$operation');
    final auditWriter = ComplaintAuditWriter(
      firestore: _firestore,
      identity: _identity,
    );

    try {
      return await _firestore.runTransaction<Complaint>((transaction) async {
        final complaintSnapshot = await transaction.get(complaintRef);
        final actorSnapshot = await transaction.get(actorRef);
        final auditSnapshot = await transaction.get(auditRef);
        if (!complaintSnapshot.exists || complaintSnapshot.data() == null) {
          throw const ComplaintLifecycleFailure(
            ComplaintLifecycleFailureCode.notFound,
          );
        }
        final actorData = actorSnapshot.data();
        if (!actorSnapshot.exists || actorData == null) {
          throw const ComplaintLifecycleFailure(
            ComplaintLifecycleFailureCode.unauthorized,
          );
        }
        final actor = AppUser.fromMap(actorData, id: actorSnapshot.id);
        final tenantConfirmation =
            actor.role == UserRole.tenant &&
            (to == ComplaintStatus.closed || to == ComplaintStatus.reopened);
        if (!actor.isAuthorized ||
            actor.role == null ||
            (!actor.role!.isOperationsStaff && !tenantConfirmation) ||
            actor.id != actorId) {
          throw const ComplaintLifecycleFailure(
            ComplaintLifecycleFailureCode.unauthorized,
          );
        }
        final complaint = Complaint.fromMap(
          complaintSnapshot.data()!,
          id: complaintSnapshot.id,
        );

        if (auditSnapshot.exists) {
          final existing = auditSnapshot.data();
          if (existing?['actorId'] == actorId &&
              existing?['eventType'] == _eventType(to).value) {
            return complaint;
          }
          throw const ComplaintLifecycleFailure(
            ComplaintLifecycleFailureCode.conflict,
          );
        }

        try {
          ComplaintTransitionGuard.validateTransition(complaint.status, to);
        } on InvalidComplaintTransition catch (error) {
          throw ComplaintLifecycleFailure(
            ComplaintLifecycleFailureCode.invalidTransition,
            error.message,
          );
        }
        if (to == ComplaintStatus.closed && complaint.activeVisitId != null) {
          throw const ComplaintLifecycleFailure(
            ComplaintLifecycleFailureCode.invalidTransition,
            'An active maintenance visit must be completed before closing.',
          );
        }

        final details = <String, dynamic>{
          'previousStatus': complaint.status.value,
          'newStatus': to.value,
          'operationId': operation,
        };
        if (normalizedReason != null) details['reason'] = normalizedReason;
        final update = <String, dynamic>{
          'status': to.value,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (to == ComplaintStatus.closed) {
          update['closedAt'] = FieldValue.serverTimestamp();
          update['closedBy'] = actorId;
        } else if (to == ComplaintStatus.reopened) {
          update['reopenCount'] = FieldValue.increment(1);
          update['reopenedAt'] = FieldValue.serverTimestamp();
          update['reopenedBy'] = actorId;
          update['reopenReason'] = normalizedReason;
        } else {
          update['cancelledAt'] = FieldValue.serverTimestamp();
          update['cancelledBy'] = actorId;
          update['cancellationReason'] = normalizedReason;
        }
        transaction.update(complaintRef, update);
        auditWriter.appendEventInTransaction(
          transaction,
          eventId: auditRef.id,
          complaintId: id,
          eventType: _eventType(to),
          actor: AuditActorContext.fromProfile(
            profile: actor,
            authenticatedUid: actorId,
          ),
          details: details,
          previousValue: complaint.status.value,
          newValue: to.value,
          reason: normalizedReason,
          eventWasAbsent: true,
        );
        return complaint.copyWith(status: to);
      });
    } on ComplaintLifecycleFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ComplaintLifecycleFailure(
        error.code == 'aborted' || error.code == 'failed-precondition'
            ? ComplaintLifecycleFailureCode.conflict
            : ComplaintLifecycleFailureCode.persistence,
        error.message,
      );
    }
  }

  static ComplaintAuditEventType _eventType(ComplaintStatus status) =>
      switch (status) {
        ComplaintStatus.closed => ComplaintAuditEventType.complaintClosed,
        ComplaintStatus.reopened => ComplaintAuditEventType.complaintReopened,
        ComplaintStatus.cancelled => ComplaintAuditEventType.complaintCancelled,
        _ => ComplaintAuditEventType.complaintStatusChanged,
      };
}
