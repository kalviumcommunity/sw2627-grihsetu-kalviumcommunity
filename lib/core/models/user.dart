import '../enums/user_role.dart';

/// Lightweight User model stub matching PRD Section 16 (User Entity).
///
/// Represents internal operators, technicians, and other system actors.
class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    required this.createdAt,
  });

  /// Serializes model to a Firestore-friendly Map.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.value,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Constructs an [AppUser] from a Firestore/JSON map.
  factory AppUser.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return AppUser(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: UserRole.fromValue(map['role'] as String?),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
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
