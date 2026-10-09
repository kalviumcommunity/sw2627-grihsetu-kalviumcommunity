/// Status of a tenant directory record.
enum TenantStatus {
  pending('pending'),
  active('active'),
  ended('ended');

  const TenantStatus(this.value);

  final String value;

  static TenantStatus? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in values) {
      if (status.value == normalized || status.name == normalized) {
        return status;
      }
    }
    return null;
  }

  static TenantStatus fromValue(
    String? value, {
    TenantStatus fallback = TenantStatus.active,
  }) => tryFromValue(value) ?? fallback;
}
