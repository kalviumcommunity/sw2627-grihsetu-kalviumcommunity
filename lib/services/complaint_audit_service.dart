import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/enums/complaint_audit_event_type.dart';
import '../core/enums/user_role.dart';
import '../core/models/user.dart';
import 'auth_service.dart';

class AuditActorContext {
  const AuditActorContext({required this.actorId, required this.actorRole});

  final String actorId;
  final UserRole actorRole;

  factory AuditActorContext.fromProfile({
    required AppUser profile,
    required String authenticatedUid,
  }) {
    if (profile.id.trim().isEmpty ||
        profile.id != authenticatedUid ||
        !profile.isAuthorized ||
        profile.role == null) {
      throw const AuditWriteException(AuditWriteFailureCode.unauthorized);
    }
    return AuditActorContext(
      actorId: authenticatedUid,
      actorRole: profile.role!,
    );
  }
}

enum AuditWriteFailureCode {
  validation,
  unauthenticated,
  unauthorized,
  malformedData,
  permissionDenied,
  write,
}

class AuditWriteException implements Exception {
  const AuditWriteException(this.code, [this.details]);

  final AuditWriteFailureCode code;
  final String? details;

  @override
  String toString() => 'AuditWriteException(${code.name})';
}

/// Centralized audit payload builder and transaction staging service.
///
/// The caller owns the transaction so complaint/assignment reads and writes
/// stay in one atomic unit without a dependency cycle between repositories.
class ComplaintAuditWriter {
  ComplaintAuditWriter({
    FirebaseFirestore? firestore,
    AuthenticatedUserProvider? identity,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identity = identity ?? AuthService.firebase();

  final FirebaseFirestore _firestore;
  final AuthenticatedUserProvider _identity;

  String requireAuthenticatedUid() {
    final uid = _identity.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      throw const AuditWriteException(AuditWriteFailureCode.unauthenticated);
    }
    return uid;
  }

  /// Canonical Firestore payload used by the transaction writer and legacy
  /// payload adapters. It always uses a server timestamp.
  static Map<String, dynamic> buildPayload({
    required String complaintId,
    required ComplaintAuditEventType eventType,
    required String actorId,
    String? actorRole,
    required Map<String, dynamic> details,
    Object? previousValue,
    Object? newValue,
    String? reason,
    int? schemaVersion,
  }) {
    final payload = <String, dynamic>{
      'complaintId': complaintId,
      'eventType': eventType.value,
      'actorId': actorId,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': Map<String, dynamic>.unmodifiable(details),
    };
    if (actorRole != null) payload['actorRole'] = actorRole;
    if (schemaVersion != null) payload['schemaVersion'] = schemaVersion;
    if (previousValue != null) payload['previousValue'] = previousValue;
    if (newValue != null) payload['newValue'] = newValue;
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }
    return payload;
  }

  /// Stages a new audit document. Supply a stable [eventId] when the business
  /// operation has an idempotency key. The caller must read that document in
  /// the transaction before any writes and pass [eventWasAbsent] as true.
  DocumentReference<Map<String, dynamic>> appendEventInTransaction(
    Transaction transaction, {
    required String complaintId,
    required ComplaintAuditEventType eventType,
    required AuditActorContext actor,
    required Map<String, dynamic> details,
    String? eventId,
    Object? previousValue,
    Object? newValue,
    String? reason,
    int schemaVersion = 1,
    bool eventWasAbsent = true,
  }) {
    final complaint = _validId(complaintId, 'Complaint ID');
    final normalizedEventId = eventId == null
        ? null
        : _validId(eventId, 'Audit event ID');
    final authenticatedUid = requireAuthenticatedUid();
    if (actor.actorId != authenticatedUid ||
        actor.actorId.trim().isEmpty ||
        !actor.actorRole.value.isNotEmpty ||
        !eventWasAbsent ||
        eventType == ComplaintAuditEventType.unknown ||
        details.keys.any((key) => key.trim().isEmpty) ||
        schemaVersion < 1) {
      throw const AuditWriteException(AuditWriteFailureCode.validation);
    }

    final ref = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc(normalizedEventId);
    final payload = buildPayload(
      complaintId: complaint,
      eventType: eventType,
      actorId: actor.actorId,
      actorRole: actor.actorRole.value,
      details: details,
      previousValue: previousValue,
      newValue: newValue,
      reason: reason,
      schemaVersion: schemaVersion,
    );
    // cloud_firestore exposes transaction.set rather than transaction.create.
    // The explicit pre-read contract above prevents an existing event ID from
    // being silently overwritten.
    transaction.set(ref, payload);
    return ref;
  }

  static String _validId(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.contains('/') ||
        normalized.length > 128) {
      throw AuditWriteException(
        AuditWriteFailureCode.validation,
        '$label is invalid.',
      );
    }
    return normalized;
  }
}
