/// Lifecycle status for a managed property.
enum PropertyStatus {
  active('active'),
  inactive('inactive');

  const PropertyStatus(this.value);

  final String value;

  static PropertyStatus? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in values) {
      if (status.value == normalized || status.name == normalized) {
        return status;
      }
    }
    return null;
  }

  static PropertyStatus fromValue(
    String? value, {
    PropertyStatus fallback = PropertyStatus.active,
  }) => tryFromValue(value) ?? fallback;
}
