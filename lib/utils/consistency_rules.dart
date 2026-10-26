import '../core/enums/complaint_audit_event_type.dart';
import '../core/enums/complaint_status.dart';
import '../core/models/complaint.dart';
import '../core/models/complaint_audit_event.dart';

/// Represents a single consistency violation in complaint state or audit history.
class Violation {
  const Violation({
    required this.rule,
    required this.complaintId,
    required this.detail,
  });

  /// The invariant rule name (e.g., 'event_order', 'status_matches_last_event').
  final String rule;

  /// The affected complaint ID.
  final String complaintId;

  /// Specific diagnostic information describing the violation.
  final String detail;

  @override
  String toString() =>
      'Violation(rule: $rule, complaintId: $complaintId, detail: $detail)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Violation &&
          runtimeType == other.runtimeType &&
          rule == other.rule &&
          complaintId == other.complaintId &&
          detail == other.detail;

  @override
  int get hashCode => Object.hash(rule, complaintId, detail);
}

/// Pure domain invariants over a complaint and its audit trail.
///
/// Ensures every screen (lists, detail, search, dashboard, property summary)
/// presents data that strictly aligns with the immutable audit log.
abstract final class ConsistencyRules {
  /// Extracts the complaint status implied by an audit event, or null if the
  /// event does not imply a status change.
  static ComplaintStatus? statusImpliedByEvent(ComplaintAuditEvent event) {
    if (event.eventType == ComplaintAuditEventType.complaintStatusChanged) {
      if (event.newValue is ComplaintStatus) {
        return event.newValue as ComplaintStatus;
      }
      return ComplaintStatus.tryFromValue(event.newValue?.toString()) ??
          ComplaintStatus.tryFromValue(event.details['status']?.toString()) ??
          ComplaintStatus.tryFromValue(event.details['newStatus']?.toString());
    }

    return switch (event.eventType) {
      ComplaintAuditEventType.complaintCreated => ComplaintStatus.open,
      ComplaintAuditEventType.technicianAssigned ||
      ComplaintAuditEventType.technicianReassigned => ComplaintStatus.assigned,
      ComplaintAuditEventType.technicianArrived ||
      ComplaintAuditEventType.inspectionStarted ||
      ComplaintAuditEventType.repairStarted ||
      ComplaintAuditEventType.visitStarted => ComplaintStatus.inProgress,
      ComplaintAuditEventType.complaintWaitingForParts =>
        ComplaintStatus.waitingForParts,
      ComplaintAuditEventType.complaintResolved => ComplaintStatus.resolved,
      ComplaintAuditEventType.complaintClosed => ComplaintStatus.closed,
      ComplaintAuditEventType.complaintReopened => ComplaintStatus.reopened,
      ComplaintAuditEventType.complaintCancelled => ComplaintStatus.cancelled,
      _ => null,
    };
  }

  /// Extracts the new technician ID assigned by an assignment or reassignment event.
  static String? technicianIdFromEvent(ComplaintAuditEvent event) {
    if (event.eventType != ComplaintAuditEventType.technicianAssigned &&
        event.eventType != ComplaintAuditEventType.technicianReassigned) {
      return null;
    }
    return event.details['newTechnicianId']?.toString() ??
        event.details['technicianId']?.toString() ??
        event.newValue?.toString();
  }

  /// Evaluates all invariants for a single [complaint] and its [events].
  ///
  /// Returns an empty list when all consistency invariants hold.
  static List<Violation> validateComplaint(
    Complaint complaint,
    List<ComplaintAuditEvent> events,
  ) {
    final violations = <Violation>[];

    // 1. Unique event IDs
    final seenEventIds = <String>{};
    for (final event in events) {
      if (event.id.isNotEmpty && !seenEventIds.add(event.id)) {
        violations.add(
          Violation(
            rule: 'unique_ids',
            complaintId: complaint.id,
            detail: 'Duplicate event ID: "${event.id}" found in audit history.',
          ),
        );
      }
    }

    // 2. Events in non-decreasing time order
    for (var i = 1; i < events.length; i++) {
      final prev = events[i - 1];
      final curr = events[i];
      if (prev.timestamp != null &&
          curr.timestamp != null &&
          curr.timestamp!.isBefore(prev.timestamp!)) {
        violations.add(
          Violation(
            rule: 'event_order',
            complaintId: complaint.id,
            detail:
                'Event "${curr.id}" (${curr.eventType.value} at ${curr.timestamp}) '
                'occurred before previous event "${prev.id}" (${prev.eventType.value} at ${prev.timestamp}).',
          ),
        );
      }
    }

    // 3. No event after cancelled
    var cancelledIndex = -1;
    for (var i = 0; i < events.length; i++) {
      if (events[i].eventType == ComplaintAuditEventType.complaintCancelled) {
        cancelledIndex = i;
        break;
      }
    }
    if (cancelledIndex != -1 && cancelledIndex < events.length - 1) {
      final subsequent = events[cancelledIndex + 1];
      violations.add(
        Violation(
          rule: 'no_events_after_cancelled',
          complaintId: complaint.id,
          detail:
              'Found event "${subsequent.id}" (${subsequent.eventType.value}) '
              'after complaint was cancelled at index $cancelledIndex.',
        ),
      );
    }

    // 4. Status equals status implied by the last status-changing event
    ComplaintAuditEvent? lastStatusEvent;
    ComplaintStatus? lastImpliedStatus;
    for (final event in events) {
      final implied = statusImpliedByEvent(event);
      if (implied != null) {
        lastStatusEvent = event;
        lastImpliedStatus = implied;
      }
    }
    if (lastStatusEvent != null && lastImpliedStatus != null) {
      if (complaint.status != lastImpliedStatus) {
        violations.add(
          Violation(
            rule: 'status_matches_last_event',
            complaintId: complaint.id,
            detail:
                'Complaint status is "${complaint.status.value}", but last '
                'status event "${lastStatusEvent.id}" (${lastStatusEvent.eventType.value}) '
                'implies "${lastImpliedStatus.value}".',
          ),
        );
      }
    }

    // 5. Assigned technician equals latest assign or reassign event
    ComplaintAuditEvent? lastAssignmentEvent;
    String? latestAssignedTechId;
    for (final event in events) {
      final techId = technicianIdFromEvent(event);
      if (techId != null) {
        lastAssignmentEvent = event;
        latestAssignedTechId = techId;
      }
    }
    if (lastAssignmentEvent != null) {
      if (complaint.currentTechnicianId != latestAssignedTechId) {
        violations.add(
          Violation(
            rule: 'technician_matches_assignment',
            complaintId: complaint.id,
            detail:
                'Complaint currentTechnicianId is "${complaint.currentTechnicianId}", '
                'but latest assignment event "${lastAssignmentEvent.id}" '
                'assigned "$latestAssignedTechId".',
          ),
        );
      }
    } else if (complaint.currentTechnicianId != null && events.isNotEmpty) {
      violations.add(
        Violation(
          rule: 'technician_matches_assignment',
          complaintId: complaint.id,
          detail:
              'Complaint has currentTechnicianId "${complaint.currentTechnicianId}" '
              'without any assignment audit event.',
        ),
      );
    }

    // 6. Resolved has a resolved event and a visit
    if (complaint.status == ComplaintStatus.resolved) {
      final hasResolvedEvent = events.any(
        (e) =>
            e.eventType == ComplaintAuditEventType.complaintResolved ||
            (e.eventType == ComplaintAuditEventType.complaintStatusChanged &&
                (e.newValue == 'resolved' ||
                    e.newValue == ComplaintStatus.resolved ||
                    e.details['status'] == 'resolved' ||
                    e.details['newStatus'] == 'resolved')),
      );
      if (!hasResolvedEvent && events.isNotEmpty) {
        violations.add(
          Violation(
            rule: 'resolved_has_event_and_visit',
            complaintId: complaint.id,
            detail: 'Complaint is marked resolved but missing a resolved audit event.',
          ),
        );
      }
      final hasVisit =
          complaint.visitCount > 0 ||
          events.any(
            (e) =>
                e.eventType == ComplaintAuditEventType.technicianArrived ||
                e.eventType == ComplaintAuditEventType.visitStarted ||
                e.eventType == ComplaintAuditEventType.visitCompleted,
          );
      if (!hasVisit) {
        violations.add(
          Violation(
            rule: 'resolved_has_event_and_visit',
            complaintId: complaint.id,
            detail: 'Complaint is marked resolved without any recorded visit count or visit audit event.',
          ),
        );
      }
    }

    // 7. Closed has a close event
    if (complaint.status == ComplaintStatus.closed) {
      final hasCloseEvent = events.any(
        (e) =>
            e.eventType == ComplaintAuditEventType.complaintClosed ||
            (e.eventType == ComplaintAuditEventType.complaintStatusChanged &&
                (e.newValue == 'closed' ||
                    e.newValue == ComplaintStatus.closed ||
                    e.details['status'] == 'closed' ||
                    e.details['newStatus'] == 'closed')),
      );
      if (!hasCloseEvent && events.isNotEmpty) {
        violations.add(
          Violation(
            rule: 'closed_has_close_event',
            complaintId: complaint.id,
            detail: 'Complaint is closed but missing a close audit event.',
          ),
        );
      }
    }

    // 8. Visit count equals the number of arrived events
    final arrivedEventCount = events
        .where((e) => e.eventType == ComplaintAuditEventType.technicianArrived)
        .length;
    if (events.isNotEmpty &&
        events.any(
          (e) =>
              e.eventType == ComplaintAuditEventType.technicianArrived ||
              e.eventType == ComplaintAuditEventType.visitStarted ||
              e.eventType == ComplaintAuditEventType.visitCompleted,
        )) {
      if (complaint.visitCount != arrivedEventCount) {
        violations.add(
          Violation(
            rule: 'visit_count_matches_arrived_events',
            complaintId: complaint.id,
            detail:
                'Complaint visitCount is ${complaint.visitCount}, but audit history has '
                '$arrivedEventCount technicianArrived events.',
          ),
        );
      }
    }

    // 9. Reopen count equals reopened events
    final reopenEventCount = events
        .where(
          (e) =>
              e.eventType == ComplaintAuditEventType.complaintReopened ||
              (e.eventType == ComplaintAuditEventType.complaintStatusChanged &&
                  (e.newValue == 'reopened' ||
                      e.newValue == ComplaintStatus.reopened ||
                      e.details['status'] == 'reopened' ||
                      e.details['newStatus'] == 'reopened')),
        )
        .length;
    if (events.isNotEmpty && complaint.reopenCount != reopenEventCount) {
      violations.add(
        Violation(
          rule: 'reopen_count_matches_reopened_events',
          complaintId: complaint.id,
          detail:
              'Complaint reopenCount is ${complaint.reopenCount}, but audit history has '
              '$reopenEventCount reopened events.',
        ),
      );
    }

    return violations;
  }

  /// Validates a list of complaints and their mapped audit events for consistency.
  static List<Violation> validateAll(
    Iterable<Complaint> complaints, {
    Map<String, List<ComplaintAuditEvent>>? eventsByComplaintId,
  }) {
    final violations = <Violation>[];
    final seenComplaintIds = <String>{};

    for (final c in complaints) {
      if (!seenComplaintIds.add(c.id)) {
        violations.add(
          Violation(
            rule: 'unique_ids',
            complaintId: c.id,
            detail: 'Duplicate complaint ID "${c.id}" in collection.',
          ),
        );
      }

      final events = eventsByComplaintId?[c.id] ?? const [];
      violations.addAll(validateComplaint(c, events));
    }

    return violations;
  }
}
