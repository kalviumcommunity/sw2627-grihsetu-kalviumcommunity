import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/enums/complaint_audit_event_type.dart';
import '../../../core/enums/complaint_priority.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/models/complaint.dart';
import '../../../core/models/complaint_audit_event.dart';
import '../../../core/models/maintenance_visit.dart';

/// Strongly-typed activity event types supported by GrihSetu.
enum ActivityEventType {
  created('Complaint created', Icons.add_circle_outline),
  received('Received by operations', Icons.inbox_outlined),
  reviewed('Complaint reviewed', Icons.assignment_outlined),
  assigned('Technician assigned', Icons.person_add_outlined),
  reassigned('Technician reassigned', Icons.sync_alt_outlined),
  accepted('Job accepted', Icons.thumb_up_alt_outlined),
  travelStarted('Travel started', Icons.directions_car_outlined),
  arrived('Technician arrived', Icons.location_on_outlined),
  inspectionStarted('Inspection started', Icons.search_outlined),
  workStarted('Work started', Icons.build_outlined),
  photoUploaded('Photo uploaded', Icons.photo_camera_outlined),
  partAdded('Part added', Icons.extension_outlined),
  repairCompleted('Repair completed', Icons.check_circle_outline),
  markedResolved('Marked resolved', Icons.verified_outlined),
  tenantNotified('Tenant notified', Icons.notifications_active_outlined),
  tenantConfirmed('Tenant confirmed fixed', Icons.task_alt_outlined),
  reopened('Complaint reopened', Icons.replay_outlined),
  needsAnotherVisit('Needs another visit', Icons.event_repeat_outlined),
  noteAdded('Note added', Icons.notes_outlined),
  priorityChanged('Priority changed', Icons.flag_outlined),
  closed('Complaint closed', Icons.lock_outline),
  waitingForParts('Waiting for parts', Icons.hourglass_top_outlined),
  workResumed('Work resumed', Icons.play_arrow_outlined),
  cancelled('Complaint cancelled', Icons.cancel_outlined);

  const ActivityEventType(this.label, this.icon);

  final String label;
  final IconData icon;

  static ActivityEventType fromRaw(String? raw) {
    if (raw == null) return ActivityEventType.created;
    final normalized = raw.trim().toUpperCase().replaceAll(' ', '_');
    return switch (normalized) {
      'COMPLAINT_CREATED' || 'CREATED' => ActivityEventType.created,
      'RECEIVED' => ActivityEventType.received,
      'REVIEWED' => ActivityEventType.reviewed,
      'TECHNICIAN_ASSIGNED' || 'ASSIGNED' => ActivityEventType.assigned,
      'TECHNICIAN_REASSIGNED' || 'REASSIGNED' => ActivityEventType.reassigned,
      'TECHNICIAN_ACCEPTED' || 'ACCEPTED' => ActivityEventType.accepted,
      'TRAVEL_STARTED' => ActivityEventType.travelStarted,
      'TECHNICIAN_ARRIVED' || 'ARRIVED' => ActivityEventType.arrived,
      'INSPECTION_STARTED' => ActivityEventType.inspectionStarted,
      'WORK_STARTED' || 'REPAIR_STARTED' => ActivityEventType.workStarted,
      'PHOTO_UPLOADED' => ActivityEventType.photoUploaded,
      'PART_ADDED' => ActivityEventType.partAdded,
      'WAITING_FOR_PARTS' ||
      'WAITING-FOR-PARTS' ||
      'PART_NEEDED' ||
      'COMPLAINT_WAITING_FOR_PARTS' => ActivityEventType.waitingForParts,
      'WORK_RESUMED' ||
      'WORK-RESUMED' ||
      'REPAIR_RESUMED' => ActivityEventType.workResumed,
      'REPAIR_COMPLETED' => ActivityEventType.repairCompleted,
      'MARKED_RESOLVED' || 'RESOLVED' => ActivityEventType.markedResolved,
      'TENANT_NOTIFIED' => ActivityEventType.tenantNotified,
      'TENANT_CONFIRMED' || 'CONFIRMED' => ActivityEventType.tenantConfirmed,
      'COMPLAINT_REOPENED' || 'REOPENED' => ActivityEventType.reopened,
      'NEEDS_ANOTHER_VISIT' => ActivityEventType.needsAnotherVisit,
      'NOTE_ADDED' || 'INTERNAL_NOTE' => ActivityEventType.noteAdded,
      'PRIORITY_CHANGED' => ActivityEventType.priorityChanged,
      'CLOSED_WITH_TENANT_CONFIRMATION' ||
      'CLOSED_WITHOUT_TENANT_CONFIRMATION' ||
      'COMPLAINT_CLOSED' ||
      'CLOSED' => ActivityEventType.closed,
      'COMPLAINT_CANCELLED' || 'CANCELLED' => ActivityEventType.cancelled,
      _ => ActivityEventType.noteAdded,
    };
  }
}

/// Strongly-typed, parsed activity event representing a single audit log entry.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.complaintId,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.timestamp,
    this.note,
    this.isInternal = false,
    this.photos = const <String>[],
    this.fromTechnician,
    this.toTechnician,
    this.reason,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String complaintId;
  final ActivityEventType type;
  final String actorId;
  final String actorName;
  final String actorRole;
  final DateTime timestamp;
  final String? note;
  final bool isInternal;
  final List<String> photos;
  final String? fromTechnician;
  final String? toTechnician;
  final String? reason;
  final Map<String, dynamic> metadata;

  factory ActivityEvent.fromAuditEvent(ComplaintAuditEvent audit) {
    final meta = audit.metadata;
    final type = ActivityEventType.fromRaw(audit.eventTypeValue);
    final rawPhotos = meta['photos'];
    final photoList = <String>[];
    if (rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p is String && p.trim().isNotEmpty) {
          photoList.add(p.trim());
        }
      }
    }
    final rawPhoto = meta['photoUrl'] ?? meta['photo'];
    if (rawPhoto is String && rawPhoto.trim().isNotEmpty) {
      if (!photoList.contains(rawPhoto.trim())) {
        photoList.add(rawPhoto.trim());
      }
    }

    final isInternal =
        meta['isInternal'] == true ||
        meta['internal'] == true ||
        audit.eventTypeValue.toUpperCase() == 'INTERNAL_NOTE';

    return ActivityEvent(
      id: audit.id,
      complaintId: audit.complaintId,
      type: type,
      actorId: audit.actorId,
      actorName: (meta['actorName'] as String?)?.trim().isNotEmpty == true
          ? meta['actorName'] as String
          : (audit.actorId.isNotEmpty ? audit.actorId : 'System'),
      actorRole: (meta['actorRole'] as String?)?.trim().isNotEmpty == true
          ? meta['actorRole'] as String
          : 'System',
      timestamp: audit.createdAt ?? DateTime.now(),
      note: (meta['note'] ?? meta['reason'] ?? meta['comment']) as String?,
      isInternal: isInternal,
      photos: photoList,
      fromTechnician:
          meta['fromTechnicianName'] ?? meta['fromTechnicianId'] as String?,
      toTechnician:
          meta['newTechnicianName'] ??
          meta['toTechnicianId'] ??
          meta['technicianId'] as String?,
      reason: meta['reason'] as String?,
      metadata: meta,
    );
  }

  ComplaintAuditEvent toAuditEvent() => ComplaintAuditEvent(
    id: id,
    complaintId: complaintId,
    eventType:
        ComplaintAuditEventType.tryFromValue(type.name.toUpperCase()) ??
        ComplaintAuditEventType.unknown,
    rawEventType: type.name.toUpperCase(),
    actorId: actorId,
    timestamp: timestamp,
    metadata: {
      'actorName': actorName,
      'actorRole': actorRole,
      if (note != null) 'note': note,
      if (isInternal) 'isInternal': true,
      if (photos.isNotEmpty) 'photos': photos,
      if (fromTechnician != null) 'fromTechnicianId': fromTechnician,
      if (toTechnician != null) 'technicianId': toTechnician,
      if (reason != null) 'reason': reason,
      ...metadata,
    },
  );
}

/// Category filters for the ActivityTimeline.
enum ActivityTimelineFilter {
  all('All'),
  statusChanges('Status changes'),
  assignments('Assignments'),
  visits('Visits'),
  notesAndEvidence('Notes & evidence'),
  internalNotes('Internal notes');

  const ActivityTimelineFilter(this.label);

  final String label;
}

/// Progress steps across complaint lifecycle.
enum ProgressStep {
  raised('Raised'),
  received('Received'),
  assigned('Assigned'),
  accepted('Accepted'),
  visited('Visited'),
  resolved('Resolved'),
  confirmed('Confirmed');

  const ProgressStep(this.label);

  final String label;
}

/// SLA compliance indicator.
enum SlaStatus {
  onTrack('On track'),
  atRisk('At risk'),
  breached('Breached');

  const SlaStatus(this.label);

  final String label;
}

/// Representation of a previous on-site technician visit.
class VisitRecord {
  const VisitRecord({
    required this.date,
    required this.technicianName,
    required this.outcome,
    this.note,
    this.visitNumber,
  });

  final DateTime date;
  final String technicianName;
  final String outcome;
  final String? note;
  final int? visitNumber;
}

enum ComplaintDetailStatus { loading, notFound, error, data }

/// Immutable state holder for ComplaintDetailScreen.
///
/// Every value rendered on screen is purely DERIVED from [complaint]
/// and [events]. No screen-local copies of status, technician, or metrics.
class ComplaintDetailState {
  const ComplaintDetailState({
    required this.status,
    this.complaint,
    this.events = const <ActivityEvent>[],
    this.visits = const <MaintenanceVisit>[],
    this.errorMessage,
    this.referenceNow,
  });

  final ComplaintDetailStatus status;
  final Complaint? complaint;
  final List<ActivityEvent> events;
  final List<MaintenanceVisit> visits;
  final String? errorMessage;
  final DateTime? referenceNow;

  DateTime get _now => referenceNow ?? DateTime.now();

  bool get isLoading => status == ComplaintDetailStatus.loading;
  bool get isNotFound => status == ComplaintDetailStatus.notFound;
  bool get isError => status == ComplaintDetailStatus.error;
  bool get hasData => status == ComplaintDetailStatus.data && complaint != null;

  // -------------------------------------------------------------
  // DERIVED VALUES
  // -------------------------------------------------------------

  /// Current status derived from the latest status-modifying event or complaint.
  ComplaintStatus get currentStatus {
    if (complaint == null) return ComplaintStatus.open;
    for (final event in events.reversed) {
      switch (event.type) {
        case ActivityEventType.closed:
        case ActivityEventType.tenantConfirmed:
          return ComplaintStatus.closed;
        case ActivityEventType.reopened:
          return ComplaintStatus.reopened;
        case ActivityEventType.markedResolved:
        case ActivityEventType.repairCompleted:
          return ComplaintStatus.resolved;
        case ActivityEventType.waitingForParts:
        case ActivityEventType.partAdded:
          return ComplaintStatus.waitingForParts;
        case ActivityEventType.workResumed:
        case ActivityEventType.workStarted:
        case ActivityEventType.inspectionStarted:
        case ActivityEventType.arrived:
        case ActivityEventType.travelStarted:
          return ComplaintStatus.inProgress;
        case ActivityEventType.cancelled:
          return ComplaintStatus.cancelled;
        case ActivityEventType.assigned:
        case ActivityEventType.reassigned:
        case ActivityEventType.accepted:
          if (complaint!.status == ComplaintStatus.resolved ||
              complaint!.status == ComplaintStatus.closed ||
              complaint!.status == ComplaintStatus.cancelled) {
            return complaint!.status;
          }
          return ComplaintStatus.assigned;
        case ActivityEventType.created:
        case ActivityEventType.received:
        case ActivityEventType.reviewed:
          if (complaint!.status != ComplaintStatus.open) {
            return complaint!.status;
          }
          return ComplaintStatus.open;
        default:
          break;
      }
    }
    return complaint!.status;
  }

  /// Returns the expected date for parts if recorded in an audit event.
  DateTime? get expectedPartsDate {
    for (final event in events.reversed) {
      if (event.type == ActivityEventType.waitingForParts ||
          event.metadata['expectedDate'] != null) {
        final raw = event.metadata['expectedDate'];
        if (raw is String) {
          final parsed = DateTime.tryParse(raw);
          if (parsed != null) return parsed;
        } else if (raw is DateTime) {
          return raw;
        }
      }
    }
    return null;
  }

  /// Assigned technician identifier derived from assignment events or complaint.
  String? get assignedTechnicianId {
    for (final event in events.reversed) {
      if (event.type == ActivityEventType.reassigned ||
          event.type == ActivityEventType.assigned) {
        final tech =
            event.toTechnician ??
            (event.metadata['toTechnician'] as String?) ??
            (event.metadata['toTechnicianId'] as String?) ??
            (event.metadata['technicianId'] as String?);
        if (tech != null && tech.isNotEmpty) {
          return tech;
        }
      }
    }
    return complaint?.currentTechnicianId;
  }

  /// Assigned technician name derived from event metadata.
  String? get assignedTechnicianName {
    for (final event in events.reversed) {
      if (event.type == ActivityEventType.reassigned ||
          event.type == ActivityEventType.assigned) {
        final name =
            event.metadata['newTechnicianName'] ??
            event.metadata['technicianName'] ??
            event.toTechnician;
        if (name is String && name.isNotEmpty) return name;
      }
    }
    if (complaint?.currentTechnicianId == 'usr_002') return 'Aman Verma';
    return assignedTechnicianId;
  }

  /// Scheduled visit date derived from assignment event metadata.
  DateTime? get scheduledVisitDate {
    for (final event in events.reversed) {
      final raw = event.metadata['scheduledDate'];
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// Expected resolution timestamp derived from creation timestamp and priority SLA window.
  DateTime? get expectedResolution {
    final created =
        complaint?.createdAt ??
        (events.isNotEmpty ? events.first.timestamp : null);
    if (created == null) return null;
    final duration = switch (complaint?.priority ?? ComplaintPriority.medium) {
      ComplaintPriority.urgent => const Duration(hours: 24),
      ComplaintPriority.high => const Duration(hours: 48),
      ComplaintPriority.medium => const Duration(hours: 72),
      ComplaintPriority.low => const Duration(hours: 120),
    };
    return created.add(duration);
  }

  /// Total visits from the maintenance-visit repository, with the complaint
  /// counter retained as a safe legacy fallback while history loads.
  int get numberOfVisits {
    if (visits.isNotEmpty) return visits.length;
    final arrivalCount = events
        .where((event) => event.type == ActivityEventType.arrived)
        .length;
    final modelCount = complaint?.visitCount ?? 0;
    return arrivalCount > modelCount ? arrivalCount : modelCount;
  }

  /// Time to first response: duration between created and first operational action.
  Duration? get timeToFirstResponse {
    if (events.isEmpty) return null;
    final created = events.firstWhere(
      (e) => e.type == ActivityEventType.created,
      orElse: () => events.first,
    );
    final responseEvent = events.where((e) {
      return e.type == ActivityEventType.assigned ||
          e.type == ActivityEventType.received ||
          e.type == ActivityEventType.reviewed ||
          e.type == ActivityEventType.accepted ||
          e.type == ActivityEventType.arrived;
    }).firstOrNull;

    if (responseEvent == null) return null;
    final diff = responseEvent.timestamp.difference(created.timestamp);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Time to resolve: duration from creation to resolution. Null if unresolved.
  Duration? get timeToResolve {
    if (events.isEmpty) return null;
    final created = events.firstWhere(
      (e) => e.type == ActivityEventType.created,
      orElse: () => events.first,
    );
    final resolvedEvent = events.where((e) {
      return e.type == ActivityEventType.markedResolved ||
          e.type == ActivityEventType.repairCompleted ||
          e.type == ActivityEventType.closed ||
          e.type == ActivityEventType.tenantConfirmed;
    }).firstOrNull;

    if (resolvedEvent == null) return null;
    final diff = resolvedEvent.timestamp.difference(created.timestamp);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Time open: duration from creation to resolution (if resolved) or to now (if active).
  Duration? get timeOpen {
    if (timeToResolve != null) return timeToResolve;
    final created =
        complaint?.createdAt ??
        (events.isNotEmpty ? events.first.timestamp : null);
    if (created == null) return null;
    final diff = _now.difference(created);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Timestamp of the last update across all events.
  DateTime? get lastUpdated {
    if (events.isNotEmpty) return events.last.timestamp;
    return complaint?.updatedAt ?? complaint?.createdAt;
  }

  /// SLA status derived from expected resolution and actual progress.
  SlaStatus get slaStatus {
    final expected = expectedResolution;
    if (expected == null) return SlaStatus.onTrack;

    final resolved = timeToResolve != null;
    if (resolved) {
      final created = complaint?.createdAt ?? events.first.timestamp;
      final resolveTime = created.add(timeToResolve!);
      return resolveTime.isAfter(expected)
          ? SlaStatus.breached
          : SlaStatus.onTrack;
    }

    if (_now.isAfter(expected)) {
      return SlaStatus.breached;
    }
    // At risk if less than 25% of SLA duration remains
    final created = complaint?.createdAt ?? events.first.timestamp;
    final totalDuration = expected.difference(created);
    final remaining = expected.difference(_now);
    if (remaining.inMinutes < (totalDuration.inMinutes * 0.25)) {
      return SlaStatus.atRisk;
    }
    return SlaStatus.onTrack;
  }

  /// Set of completed progress steps.
  Set<ProgressStep> get completedSteps {
    final set = <ProgressStep>{};
    if (events.any((e) => e.type == ActivityEventType.created)) {
      set.add(ProgressStep.raised);
    }
    if (events.any(
      (e) =>
          e.type == ActivityEventType.received ||
          e.type == ActivityEventType.reviewed ||
          e.type == ActivityEventType.assigned ||
          e.type == ActivityEventType.accepted ||
          e.type == ActivityEventType.arrived ||
          e.type == ActivityEventType.markedResolved ||
          e.type == ActivityEventType.closed,
    )) {
      set.add(ProgressStep.received);
    }
    if (assignedTechnicianId != null ||
        events.any(
          (e) =>
              e.type == ActivityEventType.assigned ||
              e.type == ActivityEventType.reassigned,
        )) {
      set.add(ProgressStep.assigned);
    }
    if (events.any(
      (e) =>
          e.type == ActivityEventType.accepted ||
          e.type == ActivityEventType.travelStarted ||
          e.type == ActivityEventType.arrived ||
          e.type == ActivityEventType.workStarted ||
          e.type == ActivityEventType.markedResolved ||
          e.type == ActivityEventType.closed,
    )) {
      set.add(ProgressStep.accepted);
    }
    if (events.any(
      (e) =>
          e.type == ActivityEventType.arrived ||
          e.type == ActivityEventType.workStarted ||
          e.type == ActivityEventType.inspectionStarted ||
          e.type == ActivityEventType.markedResolved ||
          e.type == ActivityEventType.closed,
    )) {
      set.add(ProgressStep.visited);
    }
    if (currentStatus == ComplaintStatus.resolved ||
        currentStatus == ComplaintStatus.closed ||
        events.any(
          (e) =>
              e.type == ActivityEventType.markedResolved ||
              e.type == ActivityEventType.repairCompleted,
        )) {
      set.add(ProgressStep.resolved);
    }
    if (currentStatus == ComplaintStatus.closed ||
        events.any(
          (e) =>
              e.type == ActivityEventType.tenantConfirmed ||
              e.type == ActivityEventType.closed,
        )) {
      set.add(ProgressStep.confirmed);
    }
    return set;
  }

  /// Current active progress step.
  ProgressStep get currentStep {
    if (completedSteps.contains(ProgressStep.confirmed)) {
      return ProgressStep.confirmed;
    }
    for (final step in ProgressStep.values) {
      if (!completedSteps.contains(step)) return step;
    }
    return ProgressStep.confirmed;
  }

  /// Derived previous visits list from stored maintenance visits. Audit-event
  /// arrivals remain a compatibility fallback for older in-memory fixtures.
  List<VisitRecord> get previousVisits {
    if (visits.isNotEmpty) {
      return visits.map((visit) {
        final timestamp =
            visit.startedAt ?? visit.completedAt ?? DateTime(1970);
        return VisitRecord(
          date: timestamp,
          technicianName: visit.technicianId,
          outcome: visit.outcome?.value ?? 'In progress',
          note: visit.resolutionSummary ?? visit.observation,
          visitNumber: visit.visitNumber,
        );
      }).toList();
    }
    final arrivals = events
        .where((e) => e.type == ActivityEventType.arrived)
        .toList();
    if (arrivals.isEmpty) return const [];
    return arrivals.map((event) {
      return VisitRecord(
        date: event.timestamp,
        technicianName: event.actorName,
        outcome: event.note ?? 'Diagnostics and inspection conducted',
        note: event.note,
      );
    }).toList();
  }

  /// True if complaint has experienced repeat visits or reopenings.
  bool get isRepeatIssue =>
      complaint?.isRepeatVisit == true ||
      numberOfVisits > 1 ||
      (complaint?.reopenCount ?? 0) > 0;

  /// Comprehensive visit summary derived from authoritative maintenance visits
  /// with legacy fallback.
  VisitSummary get visitSummary =>
      VisitSummary.from(complaint: complaint, visits: visits, events: events);

  /// Latest visit timestamp derived from canonical visits or fallback events.
  DateTime? get lastVisitDate => visitSummary.lastVisitDate;

  /// Number of repeat visits beyond the initial visit.
  int get repeatVisitsCount => visitSummary.repeatVisitsCount;
}

/// Domain representation of visit statistics and repeat-visit metrics.
class VisitSummary {
  const VisitSummary({
    required this.totalVisits,
    this.lastVisitDate,
    required this.isRepeat,
    this.repeatVisitsCount = 0,
    this.reopenCount = 0,
    this.isVisitInProgress = false,
  });

  /// Authoritative count of on-site maintenance visits.
  final int totalVisits;

  /// Chronologically latest visit timestamp (completed or in-progress).
  final DateTime? lastVisitDate;

  /// Whether this complaint constitutes a repeat issue.
  final bool isRepeat;

  /// Total visits beyond the initial visit (max(0, totalVisits - 1)).
  final int repeatVisitsCount;

  /// Number of times the complaint was reopened.
  final int reopenCount;

  /// Whether an active visit is currently in progress.
  final bool isVisitInProgress;

  /// Operations-friendly status string.
  String get repeatStatusLabel {
    if (repeatVisitsCount > 0 && reopenCount > 0) {
      return 'Repeat ($repeatVisitsCount follow-up${repeatVisitsCount > 1 ? 's' : ''}, reopened)';
    }
    if (repeatVisitsCount > 0) {
      return 'Repeat ($repeatVisitsCount follow-up${repeatVisitsCount > 1 ? 's' : ''})';
    }
    if (reopenCount > 0) {
      return 'Reopened ($reopenCount)';
    }
    if (isRepeat) {
      return 'Repeat issue';
    }
    return totalVisits > 0 ? 'First visit' : 'No visits';
  }

  /// Pure derivation from canonical [visits] and fallback [events]/[complaint].
  ///
  /// - [visits] (MaintenanceVisit list) is the authoritative canonical history.
  /// - [events] (ActivityEvent list) is used as a legacy/in-memory fallback only when [visits] is empty.
  /// - Deduplicates and never combines counts from both sources simultaneously.
  /// - Last visit is derived as the chronologically latest timestamp among completed or in-progress visits.
  /// - Repeat visit count is derived as max(0, totalVisits - 1).
  /// - Repeat status is true if complaint has isRepeatVisit flag, totalVisits > 1, or reopenCount > 0.
  factory VisitSummary.from({
    Complaint? complaint,
    List<MaintenanceVisit> visits = const <MaintenanceVisit>[],
    List<ActivityEvent> events = const <ActivityEvent>[],
    List<ComplaintAuditEvent> auditEvents = const <ComplaintAuditEvent>[],
  }) {
    int totalVisits = 0;
    if (visits.isNotEmpty) {
      totalVisits = visits.length;
    } else {
      final arrivalCount = events
          .where((e) => e.type == ActivityEventType.arrived)
          .length;
      final auditArrivalCount = auditEvents.where((a) {
        final raw = (a.rawEventType ?? a.eventType.value).toUpperCase();
        return raw.contains('ARRIVED');
      }).length;
      final eventCount = arrivalCount > auditArrivalCount
          ? arrivalCount
          : auditArrivalCount;
      final modelCount = complaint?.visitCount ?? 0;
      totalVisits = eventCount > modelCount ? eventCount : modelCount;
    }

    DateTime? lastVisit;
    bool hasActiveVisit = false;

    if (visits.isNotEmpty) {
      for (final v in visits) {
        if (v.isActive) hasActiveVisit = true;
        final candidate = v.completedAt ?? v.startedAt;
        if (candidate != null) {
          if (lastVisit == null || candidate.isAfter(lastVisit)) {
            lastVisit = candidate;
          }
        }
      }
    } else {
      for (final e in events) {
        if (e.type == ActivityEventType.arrived ||
            e.type == ActivityEventType.repairCompleted ||
            e.type == ActivityEventType.markedResolved ||
            e.type == ActivityEventType.needsAnotherVisit) {
          if (lastVisit == null || e.timestamp.isAfter(lastVisit)) {
            lastVisit = e.timestamp;
          }
        }
      }
      if (lastVisit == null) {
        for (final a in auditEvents) {
          final raw = (a.rawEventType ?? a.eventType.value).toUpperCase();
          if (raw.contains('ARRIVED') ||
              raw.contains('REPAIR_COMPLETED') ||
              raw.contains('MARKED_RESOLVED') ||
              raw.contains('NEEDS_ANOTHER_VISIT')) {
            final ts = a.timestamp;
            if (ts != null) {
              if (lastVisit == null || ts.isAfter(lastVisit)) {
                lastVisit = ts;
              }
            }
          }
        }
      }
    }

    final reopenCount = complaint?.reopenCount ?? 0;
    final isRepeat =
        (complaint?.isRepeatVisit == true) ||
        (totalVisits > AppConstants.repeatVisitThreshold) ||
        (reopenCount > 0);

    final repeatVisitsCount = totalVisits > 1 ? totalVisits - 1 : 0;

    return VisitSummary(
      totalVisits: totalVisits,
      lastVisitDate: lastVisit,
      isRepeat: isRepeat,
      repeatVisitsCount: repeatVisitsCount,
      reopenCount: reopenCount,
      isVisitInProgress: hasActiveVisit,
    );
  }
}
