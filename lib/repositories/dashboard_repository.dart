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
import '../utils/app_clock.dart';
import 'assignment_repository.dart';
import 'complaint_store.dart';

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardSnapshot &&
          listEquals(complaints, other.complaints) &&
          listEquals(rentRecords, other.rentRecords) &&
          listEquals(technicians, other.technicians) &&
          listEquals(properties, other.properties);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(complaints),
    Object.hashAll(rentRecords),
    Object.hashAll(technicians),
    Object.hashAll(properties),
  );
}

abstract class DashboardRepository {
  /// Loads all snapshot data for the operations dashboard.
  Future<DashboardSnapshot> load({DateTime? now});

  /// Streams real-time updates for the operations dashboard.
  ///
  /// Combines the complaint store stream, rent stream, and technician status
  /// into a reactive stream with [debounce] throttling and distinct-until-changed
  /// deduplication.
  Stream<DashboardSnapshot> watch({
    DateTime? now,
    Duration debounce = const Duration(milliseconds: 100),
  }) async* {
    yield await load(now: now);
  }
}

/// In-memory fixture-backed implementation of [DashboardRepository].
///
/// TODO: Implement FirestoreDashboardRepository backed by live Firestore streams and queries.
class InMemoryDashboardRepository implements DashboardRepository {
  InMemoryDashboardRepository({
    this.delay = Duration.zero,
    this.shouldFail = false,
    ComplaintStore? complaintStore,
    this.rentStream,
    this.technicianStream,
  }) : _complaintStore = complaintStore ?? ComplaintStore.instance;

  final Duration delay;
  bool shouldFail;
  final ComplaintStore _complaintStore;
  final Stream<List<RentRecord>>? rentStream;
  final Stream<List<TechnicianOption>>? technicianStream;

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
      if (c.reopenedAt != null) {
        events.add(
          ComplaintAuditEvent(
            id: 'evt_${c.id}_reopened',
            complaintId: c.id,
            eventType: ComplaintAuditEventType.complaintReopened,
            actorId: c.reopenedBy ?? 'usr_001',
            actorRole: UserRole.complaintOperations,
            timestamp: c.reopenedAt,
            details: {'reason': c.reopenReason ?? 'Issue recurred'},
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

    final effectiveNow = now ?? AppClock.nowDateTime;
    final complaints = List<Complaint>.from(
      _complaintStore.snapshot.isNotEmpty
          ? _complaintStore.snapshot
          : SampleFixtures.sampleComplaints,
    );
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

  @override
  Stream<DashboardSnapshot> watch({
    DateTime? now,
    Duration debounce = const Duration(milliseconds: 100),
  }) {
    late StreamController<DashboardSnapshot> controller;
    StreamSubscription<List<Complaint>>? complaintSub;
    StreamSubscription<List<RentRecord>>? rentSub;
    StreamSubscription<List<TechnicianOption>>? techSub;

    var currentComplaints = _complaintStore.snapshot.isNotEmpty
        ? _complaintStore.snapshot
        : List<Complaint>.from(SampleFixtures.sampleComplaints);
    var currentRent = List<RentRecord>.from(SampleFixtures.sampleRentRecords);
    var currentTechs = List<TechnicianOption>.from(defaultTechnicians);
    final properties = List<Property>.from(SampleFixtures.sampleProperties);

    void emitSnapshot() {
      if (controller.isClosed) return;
      final effectiveNow = now ?? AppClock.nowDateTime;
      final events = generateSampleEvents(currentComplaints);
      controller.add(
        DashboardSnapshot(
          complaints: List<Complaint>.unmodifiable(currentComplaints),
          rentRecords: List<RentRecord>.unmodifiable(currentRent),
          technicians: List<TechnicianOption>.unmodifiable(currentTechs),
          properties: List<Property>.unmodifiable(properties),
          events: List<ComplaintAuditEvent>.unmodifiable(events),
          lastUpdated: effectiveNow,
        ),
      );
    }

    controller = StreamController<DashboardSnapshot>(
      onListen: () {
        emitSnapshot();

        complaintSub = _complaintStore.watchAll().listen((complaints) {
          currentComplaints = complaints;
          emitSnapshot();
        }, onError: controller.addError);

        if (rentStream != null) {
          rentSub = rentStream!.listen((records) {
            currentRent = records;
            emitSnapshot();
          }, onError: controller.addError);
        }

        if (technicianStream != null) {
          techSub = technicianStream!.listen((techs) {
            currentTechs = techs;
            emitSnapshot();
          }, onError: controller.addError);
        }
      },
      onCancel: () {
        complaintSub?.cancel();
        rentSub?.cancel();
        techSub?.cancel();
      },
    );

    Stream<DashboardSnapshot> stream = controller.stream;
    if (debounce > Duration.zero) {
      stream = stream.debounce(debounce);
    }
    return stream.distinct();
  }
}

/// Extension providing debouncing on reactive streams without third-party packages.
extension StreamDebounceExtension<T> on Stream<T> {
  Stream<T> debounce(Duration duration, {bool emitInitial = true}) {
    if (duration <= Duration.zero) return this;
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? timer;
    T? pending;
    var hasPending = false;
    var hasEmittedFirst = false;

    controller = StreamController<T>(
      onListen: () {
        subscription = listen(
          (data) {
            if (emitInitial && !hasEmittedFirst) {
              hasEmittedFirst = true;
              controller.add(data);
              return;
            }
            pending = data;
            hasPending = true;
            timer?.cancel();
            timer = Timer(duration, () {
              if (hasPending && !controller.isClosed) {
                controller.add(pending as T);
                hasPending = false;
                pending = null;
              }
            });
          },
          onError: (Object err, StackTrace st) {
            if (!controller.isClosed) {
              controller.addError(err, st);
            }
          },
          onDone: () {
            timer?.cancel();
            if (hasPending && !controller.isClosed) {
              controller.add(pending as T);
            }
            if (!controller.isClosed) {
              controller.close();
            }
          },
        );
      },
      onCancel: () {
        timer?.cancel();
        subscription?.cancel();
      },
    );

    return controller.stream;
  }
}
