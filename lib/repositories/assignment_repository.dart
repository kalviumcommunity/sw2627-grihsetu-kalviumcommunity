import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/enums/complaint_category.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/user_role.dart';
import '../core/models/complaint.dart';
import '../services/errors/app_failure.dart';
import '../services/errors/run_guarded.dart';
import '../utils/app_clock.dart';
import '../utils/assignment_validators.dart';
import '../widgets/audit_timeline.dart';
import 'complaint_store.dart';

/// Availability state for a technician.
enum TechnicianAvailability {
  available('Available'),
  onJob('On a job'),
  offDuty('Off duty');

  const TechnicianAvailability(this.label);

  final String label;
}

/// UI-ready technician model with workload, specialty, and visit history.
class TechnicianOption {
  const TechnicianOption({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialties,
    required this.todayJobCount,
    required this.availability,
    this.previousVisitsToUnit = 0,
    this.isBestMatch = false,
  });

  final String id;
  final String name;
  final String phone;
  final List<ComplaintCategory> specialties;
  final int todayJobCount;
  final TechnicianAvailability availability;
  final int previousVisitsToUnit;
  final bool isBestMatch;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  bool matchesCategory(ComplaintCategory category) =>
      specialties.contains(category);

  TechnicianOption copyWith({
    String? id,
    String? name,
    String? phone,
    List<ComplaintCategory>? specialties,
    int? todayJobCount,
    TechnicianAvailability? availability,
    int? previousVisitsToUnit,
    bool? isBestMatch,
  }) => TechnicianOption(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    specialties: specialties ?? this.specialties,
    todayJobCount: todayJobCount ?? this.todayJobCount,
    availability: availability ?? this.availability,
    previousVisitsToUnit: previousVisitsToUnit ?? this.previousVisitsToUnit,
    isBestMatch: isBestMatch ?? this.isBestMatch,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TechnicianOption &&
          id == other.id &&
          todayJobCount == other.todayJobCount &&
          availability == other.availability &&
          isBestMatch == other.isBestMatch;

  @override
  int get hashCode => Object.hash(id, todayJobCount, availability, isBestMatch);
}

/// Request parameters for an assignment or reassignment.
class AssignmentRequest {
  const AssignmentRequest({
    required this.complaint,
    required this.selectedTechnician,
    this.isReassignment = false,
    this.previousTechnician,
    this.reason,
    this.reasonNote,
    this.visitDate,
    this.slot,
    this.note,
    this.actorName = 'Staff Operations',
    this.actorRole = 'Operations Staff',
  });

  final Complaint complaint;
  final TechnicianOption selectedTechnician;
  final bool isReassignment;
  final TechnicianOption? previousTechnician;
  final ReassignmentReason? reason;
  final String? reasonNote;
  final DateTime? visitDate;
  final AssignmentSlot? slot;
  final String? note;
  final String actorName;
  final String actorRole;
}

/// Assignment operation result containing updated complaint and generated audit event.
class AssignmentResult {
  const AssignmentResult({
    required this.updatedComplaint,
    required this.auditEvent,
    required this.assignedTechnician,
  });

  final Complaint updatedComplaint;
  final AuditEvent auditEvent;
  final TechnicianOption assignedTechnician;
}

/// Abstract contract for technician assignment workflow.
abstract interface class AssignmentRepository {
  Future<List<TechnicianOption>> loadTechnicians(Complaint c);
  Future<AssignmentResult> assign(AssignmentRequest r);
}

/// Technician picker backed by the authoritative Firebase user profiles.
///
/// The assignment sheet only prepares a selection result; the complaint
/// repository performs the atomic complaint/history/audit write afterwards.
/// Using document IDs here is important because Firebase UIDs, rather than
/// demo fixture IDs such as `usr_002`, are stored in `currentTechnicianId`.
class FirestoreTechnicianDirectoryRepository
    extends InMemoryAssignmentRepository {
  FirestoreTechnicianDirectoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      super(simulatedDelay: Duration.zero);

  final FirebaseFirestore _firestore;

  @override
  Future<List<TechnicianOption>> loadTechnicians(Complaint complaint) =>
      runGuarded(() async {
        final snapshot = await _firestore
            .collection(FirestoreCollections.users)
            .where('role', isEqualTo: UserRole.technician.value)
            .get();
        final technicians = snapshot.docs
            .where((document) => document.data()['isActive'] != false)
            .map(
              (document) => TechnicianDirectoryMapper.fromFirestore(
                document.id,
                document.data(),
              ),
            )
            .toList();
        technicians.sort((a, b) => a.name.compareTo(b.name));
        return technicians;
      });
}

abstract final class TechnicianDirectoryMapper {
  static TechnicianOption fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    final rawSpecialties = data['specialties'];
    final specialties = rawSpecialties is Iterable
        ? rawSpecialties
              .whereType<String>()
              .map(ComplaintCategory.tryFromValue)
              .whereType<ComplaintCategory>()
              .toList()
        : <ComplaintCategory>[];
    final rawAvailability = data['availability'] as String?;
    final availability = switch (rawAvailability?.trim().toLowerCase()) {
      'on_job' || 'on job' => TechnicianAvailability.onJob,
      'off_duty' || 'off duty' => TechnicianAvailability.offDuty,
      _ => TechnicianAvailability.available,
    };
    final name = (data['displayName'] ?? data['name']) as String?;
    final phone = (data['phoneNumber'] ?? data['phone']) as String?;

    return TechnicianOption(
      id: uid,
      name: name?.trim().isNotEmpty == true ? name!.trim() : 'Technician',
      phone: phone?.trim() ?? '',
      specialties: specialties.isEmpty
          ? List.unmodifiable(ComplaintCategory.values)
          : List.unmodifiable(specialties),
      todayJobCount: (data['todayJobCount'] as num?)?.toInt() ?? 0,
      availability: availability,
    );
  }
}

/// In-memory implementation of [AssignmentRepository] backed by realistic seed fixtures.
class InMemoryAssignmentRepository implements AssignmentRepository {
  InMemoryAssignmentRepository({
    this.simulatedDelay = const Duration(milliseconds: 60),
    this.simulateFailure = false,
    ComplaintStore? store,
  }) : _store = store ?? ComplaintStore.instance;

  final Duration simulatedDelay;
  bool simulateFailure;
  final ComplaintStore _store;

  // Internal catalog of available technician fixtures.
  final List<TechnicianOption> _technicians = [
    const TechnicianOption(
      id: 'usr_002',
      name: 'Aman Verma',
      phone: '+91 98111 22334',
      specialties: [ComplaintCategory.electrical, ComplaintCategory.appliance],
      todayJobCount: 2,
      availability: TechnicianAvailability.available,
    ),
    const TechnicianOption(
      id: 'tech_002',
      name: 'Ramesh Meena',
      phone: '+91 98765 01234',
      specialties: [ComplaintCategory.plumbing, ComplaintCategory.structural],
      todayJobCount: 1,
      availability: TechnicianAvailability.available,
    ),
    const TechnicianOption(
      id: 'tech_003',
      name: 'Suresh Patel',
      phone: '+91 98234 56789',
      specialties: [ComplaintCategory.plumbing, ComplaintCategory.electrical],
      todayJobCount: 4,
      availability: TechnicianAvailability.onJob,
    ),
    const TechnicianOption(
      id: 'tech_004',
      name: 'Kavita Sundaram',
      phone: '+91 97654 32109',
      specialties: [ComplaintCategory.appliance, ComplaintCategory.electrical],
      todayJobCount: 3,
      availability: TechnicianAvailability.available,
    ),
    const TechnicianOption(
      id: 'tech_005',
      name: 'Dinesh Rawat',
      phone: '+91 96543 21098',
      specialties: [ComplaintCategory.structural, ComplaintCategory.cleaning],
      todayJobCount: 6,
      availability: TechnicianAvailability.available,
    ),
    const TechnicianOption(
      id: 'tech_006',
      name: 'Mohit Chawla',
      phone: '+91 95432 10987',
      specialties: [ComplaintCategory.security, ComplaintCategory.electrical],
      todayJobCount: 0,
      availability: TechnicianAvailability.offDuty,
    ),
  ];

  @override
  Future<List<TechnicianOption>> loadTechnicians(Complaint complaint) =>
      runGuarded(() async {
        if (simulatedDelay > Duration.zero) {
          await Future<void>.delayed(simulatedDelay);
        }
        if (simulateFailure) {
          throw const UnavailableFailure(
            userMessage: 'Simulated network error while fetching technicians.',
            retryable: true,
          );
        }

        // Determine unit visit history:
        // If unit is unit_101 or unit_204, simulate repeat visits for demonstration.
        final list = _technicians.map((t) {
          var visits = 0;
          if (complaint.unitId == 'unit_101' && t.id == 'tech_002') {
            visits = 2;
          } else if (complaint.unitId == 'unit_204' && t.id == 'usr_002') {
            visits = 1;
          }
          return t.copyWith(previousVisitsToUnit: visits);
        }).toList();

        // Identify candidate for "Best match":
        // Matches category, is available or on-job (not off duty), and has least todayJobCount.
        final matchingCandidates = list
            .where(
              (t) =>
                  t.matchesCategory(complaint.category) &&
                  t.availability != TechnicianAvailability.offDuty,
            )
            .toList();

        String? bestMatchId;
        if (matchingCandidates.isNotEmpty) {
          matchingCandidates.sort((a, b) {
            final loadComp = a.todayJobCount.compareTo(b.todayJobCount);
            if (loadComp != 0) return loadComp;
            // Prefer available over on-job
            return a.availability.index.compareTo(b.availability.index);
          });
          bestMatchId = matchingCandidates.first.id;
        }

        final enriched = list.map((t) {
          return t.copyWith(isBestMatch: t.id == bestMatchId);
        }).toList();

        // Sort by best fit:
        // 1. Best match first
        // 2. Specialty match
        // 3. Availability (available < onJob < offDuty)
        // 4. Least busy (todayJobCount)
        enriched.sort((a, b) {
          if (a.isBestMatch && !b.isBestMatch) return -1;
          if (!a.isBestMatch && b.isBestMatch) return 1;

          final aMatch = a.matchesCategory(complaint.category);
          final bMatch = b.matchesCategory(complaint.category);
          if (aMatch && !bMatch) return -1;
          if (!aMatch && bMatch) return 1;

          final availComp = a.availability.index.compareTo(
            b.availability.index,
          );
          if (availComp != 0) return availComp;

          return a.todayJobCount.compareTo(b.todayJobCount);
        });

        return enriched;
      });

  @override
  Future<AssignmentResult> assign(
    AssignmentRequest request,
  ) => runGuarded(() async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }
    if (simulateFailure) {
      throw const UnavailableFailure(
        userMessage: 'Simulated failure during assignment write.',
        retryable: true,
      );
    }

    // TODO: Firestore integration will use [TechnicianAssignmentService] to
    // atomically write complaint update, technician_assignments record,
    // and auditEvents log.

    final complaint = request.complaint;
    final tech = request.selectedTechnician;
    final now = AppClock.nowDateTime;

    // If status is open, advance to assigned; otherwise retain active status.
    final nextStatus = complaint.status == ComplaintStatus.open
        ? ComplaintStatus.assigned
        : complaint.status;

    final updated = complaint.copyWith(
      currentTechnicianId: tech.id,
      status: nextStatus,
      firstAssignedAt: complaint.firstAssignedAt ?? now,
      updatedAt: now,
    );

    // Update canonical complaint store so list, detail, queue, and dashboard update in sync
    _store.addOrUpdate(updated);

    // Build user-facing audit timeline event.
    final String title;
    final StringBuffer noteBuffer = StringBuffer();

    if (request.isReassignment) {
      final prevName =
          request.previousTechnician?.name ?? 'previous technician';
      title = 'Technician reassigned';
      noteBuffer.write(
        'Reassigned from $prevName to ${tech.name}. Reason: ${request.reason?.label ?? "Not specified"}.',
      );
      if (request.reasonNote != null && request.reasonNote!.trim().isNotEmpty) {
        noteBuffer.write(' Details: ${request.reasonNote!.trim()}');
      }
    } else {
      title = 'Technician assigned';
      noteBuffer.write(
        'Assigned to ${tech.name} (${tech.specialties.map((s) => s.displayLabel).join(", ")}).',
      );
    }

    if (request.visitDate != null) {
      final slotLabel = request.slot != null ? ' (${request.slot!.label})' : '';
      noteBuffer.write(
        ' Scheduled visit for ${request.visitDate!.day}/${request.visitDate!.month}/${request.visitDate!.year}$slotLabel.',
      );
    }

    if (request.note != null && request.note!.trim().isNotEmpty) {
      noteBuffer.write(' Note: "${request.note!.trim()}"');
    }

    // Stub notification (skipped if model not present).
    // TODO: Send push notification to technician ${tech.id} and tenant ${complaint.tenantId}.

    final auditEvent = AuditEvent(
      title: title,
      actor: request.actorName,
      role: request.actorRole,
      timestamp: now,
      note: noteBuffer.toString(),
      tone: AuditTone.accent,
    );

    return AssignmentResult(
      updatedComplaint: updated,
      auditEvent: auditEvent,
      assignedTechnician: tech,
    );
  });
}
