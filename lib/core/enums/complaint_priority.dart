/// Priority levels for a complaint matching PRD Section 10 (FR-05).
enum ComplaintPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  const ComplaintPriority(this.value);

  /// Stable machine-readable string suitable for Firebase/Firestore persistence.
  final String value;

  /// Human-readable display label for UI rendering.
  String get displayLabel => switch (this) {
    ComplaintPriority.low => 'Low',
    ComplaintPriority.medium => 'Medium',
    ComplaintPriority.high => 'High',
    ComplaintPriority.urgent => 'Urgent',
  };

  /// Parses a string value from Firestore or returns null if unmatched.
  static ComplaintPriority? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final priority in ComplaintPriority.values) {
      if (priority.value == normalized ||
          priority.name.toLowerCase() == normalized) {
        return priority;
      }
    }
    return null;
  }

  /// Parses a string value with a fallback default.
  static ComplaintPriority fromValue(
    String? value, {
    ComplaintPriority fallback = ComplaintPriority.medium,
  }) {
    return tryFromValue(value) ?? fallback;
  }
}

/// Helper extension on [ComplaintPriority].
extension ComplaintPriorityLabel on ComplaintPriority {
  /// Indicates if the complaint requires critical/immediate attention.
  bool get isUrgent => this == ComplaintPriority.urgent;

  /// Indicates elevated attention (high or urgent).
  bool get isHighOrUrgent =>
      this == ComplaintPriority.high || this == ComplaintPriority.urgent;
}
