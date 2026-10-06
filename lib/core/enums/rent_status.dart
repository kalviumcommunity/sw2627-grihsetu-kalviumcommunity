/// Rent tracking statuses matching PRD Section 10 (FR-21).
///
/// Supported statuses:
/// `DUE`, `CONTACTED`, `PROMISED`, `OVERDUE`, `PAID`
enum RentStatus {
  due('due'),
  contacted('contacted'),
  promised('promised'),
  overdue('overdue'),
  paid('paid');

  const RentStatus(this.value);

  /// Stable machine-readable string suitable for Firebase/Firestore persistence.
  final String value;

  /// Human-readable display label for UI rendering.
  String get displayLabel => switch (this) {
    RentStatus.due => 'Due',
    RentStatus.contacted => 'Contacted',
    RentStatus.promised => 'Promised',
    RentStatus.overdue => 'Overdue',
    RentStatus.paid => 'Paid',
  };

  /// Parses a string value from Firestore or returns null if unmatched.
  static RentStatus? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in RentStatus.values) {
      if (status.value == normalized ||
          status.name.toLowerCase() == normalized) {
        return status;
      }
    }
    return null;
  }

  /// Parses a string value with a fallback default.
  static RentStatus fromValue(
    String? value, {
    RentStatus fallback = RentStatus.due,
  }) {
    return tryFromValue(value) ?? fallback;
  }
}

/// Helper extension on [RentStatus].
extension RentStatusLabel on RentStatus {
  /// Whether rent is pending collection or follow-up action.
  bool get isPendingAction =>
      this == RentStatus.due ||
      this == RentStatus.contacted ||
      this == RentStatus.promised ||
      this == RentStatus.overdue;

  /// Whether payment has been received in full.
  bool get isPaid => this == RentStatus.paid;

  /// Whether payment is past the due date without settlement.
  bool get isOverdue => this == RentStatus.overdue;
}
