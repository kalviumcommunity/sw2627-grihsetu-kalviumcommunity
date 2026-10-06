/// Authoritative Firestore collection names matching PRD Section 16 (Data Entities).
abstract final class FirestoreCollections {
  /// User accounts and role definitions.
  static const String users = 'users';

  /// Residential properties and buildings.
  static const String properties = 'properties';

  /// Individual units / apartments within properties.
  static const String units = 'units';

  /// Tenant directory records.
  static const String tenants = 'tenants';

  /// Complaints and maintenance tickets.
  static const String complaints = 'complaints';

  /// Technician assignments and reassignments history.
  static const String technicianAssignments = 'technician_assignments';

  /// Field maintenance visit entries.
  static const String maintenanceVisits = 'maintenance_visits';

  /// Immutable audit events timeline.
  static const String auditEvents = 'audit_events';

  /// Monthly rent records.
  static const String rentRecords = 'rent_records';

  /// Rent follow-up interaction logs.
  static const String rentFollowUps = 'rent_follow_ups';
}
