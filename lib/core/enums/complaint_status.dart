/// Lifecycle statuses for a complaint matching PRD Section 9.
///
/// Workflow:
/// `OPEN` -> `ASSIGNED` -> `IN_PROGRESS` -> `RESOLVED` -> `CLOSED`
///
/// Additional operational states:
/// `WAITING_FOR_PARTS`, `REOPENED`, `CANCELLED`
enum ComplaintStatus {
  open('open'),
  assigned('assigned'),
  inProgress('in_progress'),
  waitingForParts('waiting_for_parts'),
  resolved('resolved'),
  closed('closed'),
  reopened('reopened'),
  cancelled('cancelled');

  const ComplaintStatus(this.value);

  /// Stable machine-readable string suitable for Firebase/Firestore persistence.
  final String value;

  /// Human-readable display label for UI rendering.
  String get displayLabel => switch (this) {
    ComplaintStatus.open => 'Open',
    ComplaintStatus.assigned => 'Assigned',
    ComplaintStatus.inProgress => 'In Progress',
    ComplaintStatus.waitingForParts => 'Waiting for Parts',
    ComplaintStatus.resolved => 'Resolved',
    ComplaintStatus.closed => 'Closed',
    ComplaintStatus.reopened => 'Reopened',
    ComplaintStatus.cancelled => 'Cancelled',
  };

  /// Parses a string value from Firestore or returns null if unmatched.
  static ComplaintStatus? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in ComplaintStatus.values) {
      if (status.value == normalized ||
          status.name.toLowerCase() == normalized) {
        return status;
      }
    }
    return null;
  }

  /// Parses a string value with a fallback default.
  static ComplaintStatus fromValue(
    String? value, {
    ComplaintStatus fallback = ComplaintStatus.open,
  }) {
    return tryFromValue(value) ?? fallback;
  }
}

/// Domain helpers for complaint lifecycle and status checks (PRD FR-18).
extension ComplaintStatusLabel on ComplaintStatus {
  /// According to PRD FR-18, a complaint is unresolved if it is not
  /// resolved, closed, or cancelled.
  bool get isUnresolved =>
      this != ComplaintStatus.resolved &&
      this != ComplaintStatus.closed &&
      this != ComplaintStatus.cancelled;

  /// Whether the complaint has reached a terminal resolved or closed state.
  bool get isResolvedOrClosed =>
      this == ComplaintStatus.resolved || this == ComplaintStatus.closed;

  /// Whether active field work is underway.
  bool get isFieldWorkActive =>
      this == ComplaintStatus.inProgress ||
      this == ComplaintStatus.waitingForParts;
}
