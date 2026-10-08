/// Operational status of a unit.
enum UnitStatus {
  vacant('vacant'),
  occupied('occupied'),
  unavailable('unavailable');

  const UnitStatus(this.value);

  final String value;

  static UnitStatus? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in values) {
      if (status.value == normalized || status.name == normalized) {
        return status;
      }
    }
    return null;
  }

  static UnitStatus fromValue(
    String? value, {
    UnitStatus fallback = UnitStatus.vacant,
  }) => tryFromValue(value) ?? fallback;
}
