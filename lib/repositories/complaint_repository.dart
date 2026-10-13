import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/enums/complaint_priority.dart';
import '../core/enums/complaint_status.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';
import '../core/models/complaint_audit_event.dart';
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

  /// Streams updates for a single complaint.
  Stream<Complaint?> watchComplaint(String id);

  /// Loads a single complaint.
  Future<Complaint?> loadComplaint(String id);

  /// Streams audit events associated with a complaint.
  Stream<List<ComplaintAuditEvent>> watchAuditEvents(String complaintId);

  /// Loads all audit events for a complaint.
  Future<List<ComplaintAuditEvent>> loadAuditEvents(String complaintId);

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

    final event = ComplaintAuditEvent(
      id: auditRef.id,
      complaintId: complaintId,
      eventType: eventType,
      actorId: actorId,
      createdAt: DateTime.now(),
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
      eventType: 'PRIORITY_CHANGED',
      actorId: actorId,
      createdAt: DateTime.now(),
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
    final complaintRef = _firestore
        .collection(FirestoreCollections.complaints)
        .doc(complaintId.trim());
    final auditRef = _firestore
        .collection(FirestoreCollections.auditEvents)
        .doc();

    final event = ComplaintAuditEvent(
      id: auditRef.id,
      complaintId: complaintId,
      eventType: 'TECHNICIAN_ASSIGNED',
      actorId: actorId,
      createdAt: DateTime.now(),
      metadata: {
        'technicianId': technicianId,
        'reason': ?reason,
        'actorRole': ?role,
        'scheduledDate': ?scheduledDate?.toIso8601String(),
        'timeSlot': ?timeSlot,
      },
    );

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(complaintRef);
      if (!snap.exists) {
        throw const ComplaintFailure(ComplaintFailureCode.notFound);
      }
      final currentTech = snap.data()?['currentTechnicianId'] as String?;
      tx.update(complaintRef, {
        'currentTechnicianId': technicianId,
        'status': ComplaintStatus.assigned.value,
        'updatedAt': FieldValue.serverTimestamp(),
        if (currentTech == null)
          'firstAssignedAt': FieldValue.serverTimestamp(),
      });
      tx.set(auditRef, event.toFirestoreMap());
    });

    final updated = await loadComplaint(complaintId);
    return updated!;
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
  final Duration streamDelay;
  final StreamController<List<Complaint>> _controller =
      StreamController<List<Complaint>>.broadcast();
  final Map<String, StreamController<Complaint?>> _complaintControllers = {};
  final Map<String, StreamController<List<ComplaintAuditEvent>>>
  _auditControllers = {};

  void _seedDefaultEvents() {
    for (final c in _complaints) {
      if (!_auditEvents.containsKey(c.id)) {
        final events = <ComplaintAuditEvent>[
          ComplaintAuditEvent(
            id: '${c.id}_evt_created',
            complaintId: c.id,
            eventType: complaintCreatedEventType,
            actorId: c.createdBy,
            createdAt: c.createdAt ?? DateTime(2026, 10, 1, 10, 0),
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
              eventType: 'TECHNICIAN_ASSIGNED',
              actorId: 'usr_001',
              createdAt: c.firstAssignedAt,
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
              eventType: 'TECHNICIAN_ARRIVED',
              actorId: c.currentTechnicianId ?? 'usr_002',
              createdAt: visitDate,
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
              eventType: 'REPAIR_COMPLETED',
              actorId: c.currentTechnicianId ?? 'usr_002',
              createdAt: c.resolvedAt,
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
              eventType: 'TENANT_CONFIRMED',
              actorId: c.tenantId,
              createdAt: c.closedAt,
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
      eventType: complaintCreatedEventType,
      actorId: 'in_memory_user',
      createdAt: now,
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
      visitCount: current.visitCount,
      isRepeatVisit: current.isRepeatVisit,
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

    final event = ComplaintAuditEvent(
      id: '${complaintId}_evt_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: eventType,
      actorId: actorId,
      createdAt: now,
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
      visitCount: current.visitCount,
      isRepeatVisit: current.isRepeatVisit,
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
      eventType: 'PRIORITY_CHANGED',
      actorId: actorId,
      createdAt: now,
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
      visitCount: current.visitCount,
      isRepeatVisit: current.isRepeatVisit,
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
      eventType: isReassign ? 'TECHNICIAN_REASSIGNED' : 'TECHNICIAN_ASSIGNED',
      actorId: actorId,
      createdAt: now,
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
