import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/enums/complaint_status.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';
import '../services/auth_service.dart';

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
  }) => {
    'complaintId': complaintId,
    'eventType': complaintCreatedEventType,
    'actorId': actorId,
    'createdAt': FieldValue.serverTimestamp(),
    'metadata': {'category': category, 'priority': priority},
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

    try {
      return await _firestore.runTransaction<Complaint>((transaction) async {
        // All reads occur before either write so retries remain transaction-safe.
        final existingComplaint = await transaction.get(complaintRef);
        final existingAudit = await transaction.get(auditRef);

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
          transaction.set(
            auditRef,
            ComplaintFirestorePayloads.auditForComplaintCreate(
              complaintId: existing.id,
              actorId: actorId,
              category: existing.category.value,
              priority: existing.priority.value,
            ),
          );
          return existing;
        }

        await _validateReferences(transaction, input);

        final complaintPayload = ComplaintFirestorePayloads.complaintForCreate(
          input,
          actorId,
        );
        transaction.set(complaintRef, complaintPayload);
        transaction.set(
          auditRef,
          ComplaintFirestorePayloads.auditForComplaintCreate(
            complaintId: complaintRef.id,
            actorId: actorId,
            category: input.category.value,
            priority: input.priority.value,
          ),
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
}

/// In-memory implementation of [ComplaintRepository] with reactive stream support.
///
/// Useful for widget previews, deterministic unit/widget tests, and local demo modes.
class InMemoryComplaintRepository implements ComplaintRepository {
  InMemoryComplaintRepository({
    List<Complaint>? initialComplaints,
    this.streamDelay = Duration.zero,
  }) : _complaints = List.of(
         initialComplaints ?? SampleFixtures.sampleComplaints,
       ) {
    _emit();
  }

  final List<Complaint> _complaints;
  final Duration streamDelay;
  final StreamController<List<Complaint>> _controller =
      StreamController<List<Complaint>>.broadcast();

  void _emit() {
    if (_controller.isClosed) return;
    final copy = List<Complaint>.from(_complaints);
    _sort(copy);
    _controller.add(copy);
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
      createdAt: DateTime.now(),
    );
    _complaints.add(complaint);
    _emit();
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

  void addComplaint(Complaint complaint) {
    _complaints.add(complaint);
    _emit();
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  void dispose() {
    _controller.close();
  }
}
