/// Categories for complaints matching PRD Section 10 (FR-05).
enum ComplaintCategory {
  plumbing('plumbing'),
  electrical('electrical'),
  structural('structural'),
  appliance('appliance'),
  security('security'),
  cleaning('cleaning'),
  commonArea('common_area'),
  other('other');

  const ComplaintCategory(this.value);

  /// Stable machine-readable string suitable for Firebase/Firestore persistence.
  final String value;

  /// Human-readable display label for UI rendering.
  String get displayLabel => switch (this) {
    ComplaintCategory.plumbing => 'Plumbing',
    ComplaintCategory.electrical => 'Electrical',
    ComplaintCategory.structural => 'Structural',
    ComplaintCategory.appliance => 'Appliance',
    ComplaintCategory.security => 'Security',
    ComplaintCategory.cleaning => 'Cleaning',
    ComplaintCategory.commonArea => 'Common Area',
    ComplaintCategory.other => 'Other',
  };

  /// Parses a string value from Firestore or returns null if unmatched.
  static ComplaintCategory? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final category in ComplaintCategory.values) {
      if (category.value == normalized ||
          category.name.toLowerCase() == normalized) {
        return category;
      }
    }
    return null;
  }

  /// Parses a string value with a fallback default.
  static ComplaintCategory fromValue(
    String? value, {
    ComplaintCategory fallback = ComplaintCategory.other,
  }) {
    return tryFromValue(value) ?? fallback;
  }
}

/// Helper extension on [ComplaintCategory].
extension ComplaintCategoryLabel on ComplaintCategory {
  /// Whether this is a specialized technical trade (plumbing, electrical, structural, appliance).
  bool get isTechnicalTrade =>
      this == ComplaintCategory.plumbing ||
      this == ComplaintCategory.electrical ||
      this == ComplaintCategory.structural ||
      this == ComplaintCategory.appliance;
}
