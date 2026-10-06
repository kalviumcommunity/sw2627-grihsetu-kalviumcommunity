/// Represents the user roles in GrihSetu according to the PRD (FR-02 & Section 6).
///
/// Primary operational roles:
/// - [propertyOperations] - Manages properties and coordinates complaints.
/// - [complaintOperations] - Registers and coordinates tenant complaints.
/// - [technician] - Handles assigned field maintenance tasks.
///
/// Additional domain stakeholders:
/// - [propertyOwner] - Views property and operational reporting.
/// - [tenant] - Resident of a managed property unit.
enum UserRole {
  propertyOperations('property_operations'),
  complaintOperations('complaint_operations'),
  technician('technician'),
  propertyOwner('property_owner'),
  tenant('tenant');

  const UserRole(this.value);

  /// Stable machine-readable string suitable for Firebase/Firestore persistence.
  final String value;

  /// Human-readable label for UI rendering.
  String get displayLabel => switch (this) {
    UserRole.propertyOperations => 'Property Operations',
    UserRole.complaintOperations => 'Complaint Operations',
    UserRole.technician => 'Technician',
    UserRole.propertyOwner => 'Property Owner',
    UserRole.tenant => 'Tenant',
  };

  /// Parses a string value from Firestore or returns null if not found.
  static UserRole? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final role in UserRole.values) {
      if (role.value == normalized || role.name.toLowerCase() == normalized) {
        return role;
      }
    }
    return null;
  }

  /// Parses a string value with a fallback default.
  static UserRole fromValue(
    String? value, {
    UserRole fallback = UserRole.propertyOperations,
  }) {
    return tryFromValue(value) ?? fallback;
  }
}

/// Convenience extension providing domain role helpers.
extension UserRoleLabel on UserRole {
  /// Whether the user belongs to internal operational staff (Property or Complaint Ops).
  bool get isOperationsStaff =>
      this == UserRole.propertyOperations ||
      this == UserRole.complaintOperations;

  /// Whether the user is a field technician.
  bool get isTechnician => this == UserRole.technician;
}
