import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/enums/complaint_audit_event_type.dart';
import '../core/enums/complaint_category.dart';
import '../core/enums/user_role.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';
import '../core/models/complaint_audit_event.dart';
import '../core/models/property.dart';
import '../core/models/rent_record.dart';
import '../services/errors/app_failure.dart';
import '../services/errors/run_guarded.dart';
import 'assignment_repository.dart';

@immutable
class DashboardSnapshot {
  final List<Complaint> complaints;
  final List<RentRecord> rentRecords;
  final List<TechnicianOption> technicians;
  final List<Property> properties;
  final List<ComplaintAuditEvent> events;
  final DateTime lastUpdated;

  const DashboardSnapshot({
    required this.complaints,
    required this.rentRecords,
    required this.technicians,
    required this.properties,
    required this.events,
    required this.lastUpdated,
  });
}

abstract interface class DashboardRepository {
  /// Loads all snapshot data for the operations dashboard.
  Future<DashboardSnapshot> load({DateTime? now});
}

/// In-memory fixture-backed implementation of [DashboardRepository].
///
/// TODO: Implement FirestoreDashboardRepository backed by live Firestore streams and queries.
class InMemoryDashboardRepository implements DashboardRepository {
  InMemoryDashboardRepository({
    this.delay = Duration.zero,
    this.shouldFail = false,
  });

  final Duration delay;
  bool shouldFail;

  static final List<TechnicianOption> defaultTechnicians = [
    const TechnicianOption(
      id: 'usr_002',
      name: 'Aman Verma',
      phone: '+91 98765 00001',
      specialties: [ComplaintCategory.plumbing, ComplaintCategory.electrical],
      todayJobCount: 3,
      availability: TechnicianAvailability.onJob,
    ),
    const TechnicianOption(
      id: 'usr_004',
      name: 'Suresh Raina',
      phone: '+91 98765 00002',
      specialties: [ComplaintCategory.electrical, ComplaintCategory.appliance],
      todayJobCount: 1,
      availability: TechnicianAvailability.available,
    ),
    const TechnicianOption(
      id: 'usr_005',
      name: 'Dinesh Karthik',
      phone: '+91 98765 00003',
      specialties: [ComplaintCategory.structural, ComplaintCategory.cleaning],
      todayJobCount: 4,
      availability: TechnicianAvailability.onJob,
    ),
    const TechnicianOption(
      id: 'usr_006',
      name: 'Mohit Sharma',
      phone: '+91 98765 00004',
      specialties: [ComplaintCategory.security, ComplaintCategory.commonArea],
      todayJobCount: 0,
      availability: TechnicianAvailability.offDuty,
    ),
  ];

  static List<ComplaintAuditEvent> generateSampleEvents(
    List<Complaint> complaints,
  ) {
    final events = <ComplaintAuditEvent>[];
    for (final c in complaints) {
      events.add(
        ComplaintAuditEvent(
          id: 'evt_${c.id}_created',
          complaintId: c.id,
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: c.createdBy,
          actorRole: UserRole.complaintOperations,
          timestamp: c.createdAt,
          details: {'title': c.title},
        ),
      );
      if (c.firstAssignedAt != null) {
        events.add(
          ComplaintAuditEvent(
            id: 'evt_${c.id}_assigned',
            complaintId: c.id,
            eventType: ComplaintAuditEventType.technicianAssigned,
            actorId: 'usr_001',
            actorRole: UserRole.complaintOperations,
            timestamp: c.firstAssignedAt,
            details: {'technicianId': c.currentTechnicianId ?? 'usr_002'},
          ),
        );
      }
      if (c.resolvedAt != null) {
        events.add(
          ComplaintAuditEvent(
            id: 'evt_${c.id}_resolved',
            complaintId: c.id,
            eventType: ComplaintAuditEventType.complaintResolved,
            actorId: c.currentTechnicianId ?? 'usr_002',
            actorRole: UserRole.technician,
            timestamp: c.resolvedAt,
            details: {'status': 'resolved'},
          ),
        );
      }
    }
    // Sort descending by timestamp
    events.sort(
      (a, b) => (b.timestamp ?? DateTime(2000)).compareTo(
        a.timestamp ?? DateTime(2000),
      ),
    );
    return events.take(8).toList();
  }

  @override
  Future<DashboardSnapshot> load({DateTime? now}) => runGuarded(() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (shouldFail) {
      throw const UnavailableFailure(
        userMessage:
            'Failed to load dashboard data. Check your network connection.',
        retryable: true,
      );
    }

    final effectiveNow = now ?? DateTime.now();
    final complaints = List<Complaint>.from(SampleFixtures.sampleComplaints);
    final rentRecords = List<RentRecord>.from(SampleFixtures.sampleRentRecords);
    final properties = List<Property>.from(SampleFixtures.sampleProperties);
    final events = generateSampleEvents(complaints);

    return DashboardSnapshot(
      complaints: complaints,
      rentRecords: rentRecords,
      technicians: defaultTechnicians,
      properties: properties,
      events: events,
      lastUpdated: effectiveNow,
    );
  });
}
