import '../enums/complaint_status.dart';

/// Domain error raised when a complaint attempts to skip a lifecycle step.
class InvalidComplaintTransition implements Exception {
  const InvalidComplaintTransition(this.from, this.to);

  final ComplaintStatus from;
  final ComplaintStatus to;

  String get message =>
      'Complaint cannot transition from ${from.displayLabel} to ${to.displayLabel}.';

  @override
  String toString() =>
      'InvalidComplaintTransition(${from.value} -> ${to.value})';
}

/// The only source of truth for complaint status transitions.
///
/// The matrix mirrors PRD Section 9 and FR-12/FR-15. In particular, closure
/// is only possible after resolution and cancellation is terminal.
abstract final class ComplaintTransitionGuard {
  static const Map<ComplaintStatus, Set<ComplaintStatus>> transitions = {
    ComplaintStatus.open: {ComplaintStatus.assigned, ComplaintStatus.cancelled},
    ComplaintStatus.assigned: {
      ComplaintStatus.inProgress,
      ComplaintStatus.cancelled,
    },
    ComplaintStatus.inProgress: {
      ComplaintStatus.waitingForParts,
      ComplaintStatus.resolved,
    },
    ComplaintStatus.waitingForParts: {
      ComplaintStatus.inProgress,
      ComplaintStatus.cancelled,
    },
    ComplaintStatus.resolved: {
      ComplaintStatus.closed,
      ComplaintStatus.reopened,
    },
    ComplaintStatus.closed: {ComplaintStatus.reopened},
    ComplaintStatus.reopened: {
      ComplaintStatus.assigned,
      ComplaintStatus.inProgress,
      ComplaintStatus.cancelled,
    },
    ComplaintStatus.cancelled: <ComplaintStatus>{},
  };

  static bool canTransition(ComplaintStatus from, ComplaintStatus to) {
    return from != to && (transitions[from]?.contains(to) ?? false);
  }

  static void validateTransition(ComplaintStatus from, ComplaintStatus to) {
    if (!canTransition(from, to)) {
      throw InvalidComplaintTransition(from, to);
    }
  }
}
