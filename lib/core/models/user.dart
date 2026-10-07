import '../enums/user_role.dart';

/// Firestore-backed application user profile.
///
/// Firebase Authentication owns identity. This model represents the
/// application-side profile stored in `users/{uid}`. A profile can exist
/// without a role while it waits for trusted assignment; that state is not
/// authorized.
class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole? role;
  final bool isActive;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.isActive = true,
    required this.createdAt,
    this.phoneNumber,
    this.updatedAt,
  });

  /// Firebase UID is the canonical profile identifier.
  String get uid => id;

  /// A profile without a trusted role must never be used for authorization.
  bool get isAuthorized => isActive && role != null;

  /// Serializes model to a Firestore-friendly Map.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    if (role != null) 'role': role!.value,
    'isActive': isActive,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  /// Constructs an [AppUser] from a Firestore/JSON map.
  factory AppUser.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final roleValue = map['role'];
    return AppUser(
      id: id.isNotEmpty
          ? id
          : _stringValue(map['uid']) ?? _stringValue(map['id']) ?? '',
      name: _stringValue(map['displayName']) ?? _stringValue(map['name']) ?? '',
      email: _stringValue(map['email']) ?? '',
      role: roleValue is String ? UserRole.tryFromValue(roleValue) : null,
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      phoneNumber: _stringValue(map['phoneNumber']),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
    String? phoneNumber,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          role == other.role &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(id, name, email, role, isActive);

  @override
  String toString() =>
      'AppUser(id: $id, name: $name, role: ${role.displayLabel}, isActive: $isActive)';
}

/// Null-safe role helpers for profiles that have not been assigned yet.
extension NullableUserRoleLabel on UserRole? {
  String get displayLabel => switch (this) {
    null => 'Unassigned',
    final role => role.displayLabel,
  };

  bool get isOperationsStaff =>
      this == UserRole.propertyOperations ||
      this == UserRole.complaintOperations;

  bool get isTechnician => this == UserRole.technician;
}

String? _stringValue(Object? value) => value is String ? value : null;

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    // Interoperable with Cloud Firestore Timestamp (has .toDate() method)
    return (value as dynamic).toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
