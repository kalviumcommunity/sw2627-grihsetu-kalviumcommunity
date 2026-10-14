import '../../../core/models/complaint_audit_event.dart';
import '../../../utils/visit_validators.dart';

/// Completion input submitted when a technician resolves a visit.
class VisitCompletionInput {
  const VisitCompletionInput({
    required this.whatWasFound,
    required this.whatWasRepaired,
    this.parts = const [],
    this.noPartsUsed = false,
    this.additionalWorkRecommended = false,
    this.additionalWorkNotes,
    required this.tenantResolutionNotes,
    this.afterPhotos = const [],
  });

  final String whatWasFound;
  final String whatWasRepaired;
  final List<VisitPartInput> parts;
  final bool noPartsUsed;
  final bool additionalWorkRecommended;
  final String? additionalWorkNotes;
  final String tenantResolutionNotes;
  final List<String> afterPhotos;
}

/// Request input submitted when a visit cannot be resolved and requires another visit.
class FollowUpRequestInput {
  const FollowUpRequestInput({
    required this.reason,
    this.otherReasonDetails,
    required this.details,
    this.suggestedDate,
    this.suggestedSlot,
    this.partsToBring = const [],
    this.photos = const [],
  });

  final FollowUpReason reason;
  final String? otherReasonDetails;
  final String details;
  final DateTime? suggestedDate;
  final String? suggestedSlot;
  final List<String> partsToBring;
  final List<String> photos;
}

/// Read-only work log derived directly from audit events.
class VisitWorkLog {
  const VisitWorkLog({
    this.acceptedTime,
    this.travelStartTime,
    this.arrivalTime,
    this.inspectionStartTime,
    this.repairStartTime,
    this.completionTime,
  });

  final DateTime? acceptedTime;
  final DateTime? travelStartTime;
  final DateTime? arrivalTime;
  final DateTime? inspectionStartTime;
  final DateTime? repairStartTime;
  final DateTime? completionTime;

  /// Work start time is when inspection or repair began.
  DateTime? get workStartTime => inspectionStartTime ?? repairStartTime;

  /// Whether work on-site is currently active (arrived or in-progress, but not completed).
  bool get isOnSiteInProgress => arrivalTime != null && completionTime == null;

  /// Returns total on-site duration up to completion or [now].
  Duration totalOnSiteDuration([DateTime? now]) {
    if (arrivalTime == null) return Duration.zero;
    final end = completionTime ?? now ?? DateTime.now();
    final diff = end.difference(arrivalTime!);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Factory to derive the work log from a list of audit events.
  factory VisitWorkLog.fromEvents(List<ComplaintAuditEvent> events) {
    DateTime? accepted;
    DateTime? travel;
    DateTime? arrival;
    DateTime? inspection;
    DateTime? repair;
    DateTime? completed;

    for (final event in events) {
      final time = event.createdAt ?? event.timestamp;
      final raw = (event.rawEventType ?? event.eventType.name).toUpperCase();
      final note = (event.metadata['note'] ?? '').toString().toUpperCase();

      if (raw.contains('JOB_ACCEPTED') || note.contains('ACCEPTED')) {
        accepted ??= time;
      } else if (raw.contains('TRAVELL') || note.contains('TRAVELL')) {
        travel ??= time;
      } else if (raw.contains('ARRIVED') || note.contains('ARRIVED')) {
        arrival ??= time;
      } else if (raw.contains('INSPECTION') || note.contains('INSPECTION')) {
        inspection ??= time;
      } else if (raw.contains('REPAIR_STARTED') || note.contains('START REPAIR')) {
        repair ??= time;
      } else if (raw.contains('REPAIR_COMPLETED') ||
          raw.contains('MARKED_RESOLVED') ||
          raw.contains('NEEDS_ANOTHER_VISIT') ||
          note.contains('RESOLVED')) {
        completed ??= time;
      }
    }

    return VisitWorkLog(
      acceptedTime: accepted,
      travelStartTime: travel,
      arrivalTime: arrival,
      inspectionStartTime: inspection,
      repairStartTime: repair,
      completionTime: completed,
    );
  }
}

/// Represents a past visit record derived from audit events for UI history display.
class PreviousVisitSummary {
  const PreviousVisitSummary({
    required this.date,
    required this.technicianName,
    required this.outcome,
    this.notes,
  });

  final DateTime date;
  final String technicianName;
  final String outcome;
  final String? notes;

  static List<PreviousVisitSummary> deriveFromEvents(
    List<ComplaintAuditEvent> events,
  ) {
    final list = <PreviousVisitSummary>[];
    for (final event in events) {
      final raw = (event.rawEventType ?? event.eventType.name).toUpperCase();
      final time = event.createdAt ?? event.timestamp ?? DateTime.now();
      final tech = event.metadata['actorName']?.toString() ??
          event.metadata['technicianId']?.toString() ??
          'Technician';
      final note = event.metadata['note']?.toString();

      if (raw.contains('REPAIR_COMPLETED') || raw.contains('MARKED_RESOLVED')) {
        list.add(
          PreviousVisitSummary(
            date: time,
            technicianName: tech,
            outcome: 'Resolved',
            notes: note,
          ),
        );
      } else if (raw.contains('NEEDS_ANOTHER_VISIT')) {
        final reason = event.metadata['reason']?.toString() ?? 'Needs follow-up';
        list.add(
          PreviousVisitSummary(
            date: time,
            technicianName: tech,
            outcome: reason,
            notes: note,
          ),
        );
      }
    }
    return list;
  }
}

/// In-memory autosave draft for the visit completion form.
class VisitFormDraft {
  const VisitFormDraft({
    this.outcome = 'resolved',
    this.whatWasFound = '',
    this.whatWasRepaired = '',
    this.parts = const [],
    this.noPartsUsed = false,
    this.additionalWorkRecommended = false,
    this.additionalWorkNotes = '',
    this.tenantResolutionNotes = '',
    this.afterPhotos = const [],
    this.reason,
    this.otherReasonDetails = '',
    this.details = '',
    this.suggestedDate,
    this.suggestedSlot,
    this.partsToBring = const [],
  });

  final String outcome; // 'resolved' or 'needsAnotherVisit'
  final String whatWasFound;
  final String whatWasRepaired;
  final List<VisitPartInput> parts;
  final bool noPartsUsed;
  final bool additionalWorkRecommended;
  final String additionalWorkNotes;
  final String tenantResolutionNotes;
  final List<String> afterPhotos;
  final FollowUpReason? reason;
  final String otherReasonDetails;
  final String details;
  final DateTime? suggestedDate;
  final String? suggestedSlot;
  final List<String> partsToBring;

  bool get isDirty =>
      whatWasFound.isNotEmpty ||
      whatWasRepaired.isNotEmpty ||
      parts.isNotEmpty ||
      noPartsUsed ||
      additionalWorkRecommended ||
      additionalWorkNotes.isNotEmpty ||
      tenantResolutionNotes.isNotEmpty ||
      afterPhotos.isNotEmpty ||
      reason != null ||
      otherReasonDetails.isNotEmpty ||
      details.isNotEmpty ||
      partsToBring.isNotEmpty;
}

/// Global in-memory draft store so draft is preserved across navigation.
abstract final class VisitFormDraftStore {
  static final Map<String, VisitFormDraft> _drafts = {};

  static VisitFormDraft? get(String complaintId) => _drafts[complaintId];

  static void save(String complaintId, VisitFormDraft draft) {
    _drafts[complaintId] = draft;
  }

  static void clear(String complaintId) {
    _drafts.remove(complaintId);
  }
}

/// Derives the next actionable visit step from a complaint's audit trail.
VisitWorkflowStep? resolveNextVisitStepFromEvents(
  List<ComplaintAuditEvent> events,
  String statusValue,
) {
  if (statusValue == 'resolved' ||
      statusValue == 'closed' ||
      statusValue == 'cancelled') {
    return null;
  }

  bool hasAccepted = false;
  bool hasTravelling = false;
  bool hasArrived = false;
  bool hasInspection = false;
  bool hasRepairing = false;
  bool hasCompleted = false;

  for (final event in events) {
    final raw = (event.rawEventType ?? event.eventType.name).toUpperCase();
    final note = (event.metadata['note'] ?? '').toString().toUpperCase();

    if (raw.contains('JOB_ACCEPTED') ||
        raw.contains('TECHNICIAN_ACCEPTED') ||
        note.contains('ACCEPTED')) {
      hasAccepted = true;
    }
    if (raw.contains('TRAVELL') ||
        raw.contains('TRAVEL_STARTED') ||
        note.contains('TRAVELL')) {
      hasTravelling = true;
    }
    if (raw.contains('ARRIVED') || note.contains('ARRIVED')) {
      hasArrived = true;
    }
    if (raw.contains('INSPECTION') || note.contains('INSPECTION')) {
      hasInspection = true;
    }
    if (raw.contains('REPAIR_STARTED') ||
        raw.contains('WORK_STARTED') ||
        note.contains('START REPAIR')) {
      hasRepairing = true;
    }
    if (raw.contains('REPAIR_COMPLETED') ||
        raw.contains('MARKED_RESOLVED') ||
        raw.contains('NEEDS_ANOTHER_VISIT') ||
        raw.contains('VISIT_COMPLETED')) {
      hasCompleted = true;
    }
  }

  if (hasCompleted) return null;
  if (!hasAccepted) return VisitWorkflowStep.accepted;
  if (!hasTravelling) return VisitWorkflowStep.travelling;
  if (!hasArrived) return VisitWorkflowStep.arrived;
  if (!hasInspection) return VisitWorkflowStep.inspection;
  if (!hasRepairing) return VisitWorkflowStep.repairing;
  return VisitWorkflowStep.completed;
}

