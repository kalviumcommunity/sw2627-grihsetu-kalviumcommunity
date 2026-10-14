/// Outcomes recorded when a technician completes a maintenance visit.
///
/// These values intentionally map only to statuses already defined by the
/// complaint lifecycle in the PRD. No new complaint status is introduced by
/// the visit workflow.
enum MaintenanceVisitOutcome {
  resolved('resolved'),
  unresolved('unresolved'),
  waitingForParts('waiting_for_parts');

  const MaintenanceVisitOutcome(this.value);

  final String value;

  static MaintenanceVisitOutcome? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final outcome in values) {
      if (outcome.value == normalized ||
          outcome.name.toLowerCase() == normalized) {
        return outcome;
      }
    }
    return null;
  }
}
