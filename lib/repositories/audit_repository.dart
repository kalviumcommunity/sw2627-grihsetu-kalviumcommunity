import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/models/complaint_audit_event.dart';
import '../services/auth_service.dart';

enum AuditRepositoryFailureCode {
  validation,
  unauthenticated,
  permissionDenied,
  network,
  malformedData,
  unknown,
}

class AuditRepositoryFailure implements Exception {
  const AuditRepositoryFailure(this.code, [this.details]);

  final AuditRepositoryFailureCode code;
  final String? details;

  @override
  String toString() => 'AuditRepositoryFailure(${code.name})';
}

abstract interface class ComplaintAuditRepository {
  Future<List<ComplaintAuditEvent>> getComplaintAuditTimeline(
    String complaintId,
  );
  Stream<List<ComplaintAuditEvent>> watchComplaintAuditTimeline(
    String complaintId,
  );
}

/// Read-only audit repository. There are deliberately no update/delete APIs.
class FirestoreComplaintAuditRepository implements ComplaintAuditRepository {
  FirestoreComplaintAuditRepository({
    FirebaseFirestore? firestore,
    AuthenticatedUserProvider? identity,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identity = identity ?? AuthService.firebase();

  final FirebaseFirestore _firestore;
  final AuthenticatedUserProvider _identity;

  @override
  Future<List<ComplaintAuditEvent>> getComplaintAuditTimeline(
    String complaintId,
  ) async {
    _validateComplaintId(complaintId);
    _requireSignedIn();
    try {
      final snapshot = await _query(complaintId.trim()).get();
      return _decode(snapshot.docs);
    } on AuditRepositoryFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _fromFirebase(error);
    } catch (_) {
      throw const AuditRepositoryFailure(AuditRepositoryFailureCode.unknown);
    }
  }

  @override
  Stream<List<ComplaintAuditEvent>> watchComplaintAuditTimeline(
    String complaintId,
  ) {
    _validateComplaintId(complaintId);
    _requireSignedIn();
    return _query(complaintId.trim()).snapshots().map((snapshot) {
      try {
        return _decode(snapshot.docs);
      } on AuditRepositoryFailure {
        rethrow;
      } catch (_) {
        throw const AuditRepositoryFailure(AuditRepositoryFailureCode.unknown);
      }
    });
  }

  Query<Map<String, dynamic>> _query(String complaintId) => _firestore
      .collection(FirestoreCollections.auditEvents)
      .where('complaintId', isEqualTo: complaintId)
      .orderBy('createdAt')
      .orderBy(FieldPath.documentId);

  List<ComplaintAuditEvent> _decode(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => docs
      .map((doc) {
        try {
          return ComplaintAuditEvent.fromMap(doc.data(), id: doc.id);
        } on FormatException catch (error) {
          throw AuditRepositoryFailure(
            AuditRepositoryFailureCode.malformedData,
            error.message,
          );
        }
      })
      .toList(growable: false);

  void _requireSignedIn() {
    final uid = _identity.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      throw const AuditRepositoryFailure(
        AuditRepositoryFailureCode.unauthenticated,
      );
    }
  }

  static void _validateComplaintId(String value) {
    final id = value.trim();
    if (id.isEmpty || id.contains('/') || id.length > 128) {
      throw const AuditRepositoryFailure(AuditRepositoryFailureCode.validation);
    }
  }

  static AuditRepositoryFailure _fromFirebase(FirebaseException error) =>
      switch (error.code) {
        'permission-denied' => const AuditRepositoryFailure(
          AuditRepositoryFailureCode.permissionDenied,
        ),
        'unauthenticated' => const AuditRepositoryFailure(
          AuditRepositoryFailureCode.unauthenticated,
        ),
        'unavailable' || 'deadline-exceeded' || 'resource-exhausted' =>
          const AuditRepositoryFailure(AuditRepositoryFailureCode.network),
        _ => const AuditRepositoryFailure(AuditRepositoryFailureCode.unknown),
      };
}
