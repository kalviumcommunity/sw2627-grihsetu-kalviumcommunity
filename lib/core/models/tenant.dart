/// Lightweight Tenant model stub matching PRD Section 16 (Tenant Entity).
class Tenant {
  final String id;
  final String name;
  final String phone;
  final String propertyId;
  final String unitId;
  final bool isActive;

  const Tenant({
    required this.id,
    required this.name,
    required this.phone,
    required this.propertyId,
    required this.unitId,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'propertyId': propertyId,
    'unitId': unitId,
    'isActive': isActive,
  };

  factory Tenant.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return Tenant(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      propertyId: map['propertyId'] as String? ?? '',
      unitId: map['unitId'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Tenant copyWith({
    String? id,
    String? name,
    String? phone,
    String? propertyId,
    String? unitId,
    bool? isActive,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tenant &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          propertyId == other.propertyId &&
          unitId == other.unitId &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      Object.hash(id, name, phone, propertyId, unitId, isActive);

  @override
  String toString() =>
      'Tenant(id: $id, name: $name, phone: $phone, unitId: $unitId)';
}
