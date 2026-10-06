/// Lightweight Property model stub matching PRD Section 16 (Property Entity).
class Property {
  final String id;
  final String name;
  final String address;
  final bool isActive;
  final DateTime createdAt;

  const Property({
    required this.id,
    required this.name,
    required this.address,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Property.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return Property(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  Property copyWith({
    String? id,
    String? name,
    String? address,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Property(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Property &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          address == other.address &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(id, name, address, isActive);

  @override
  String toString() => 'Property(id: $id, name: $name, address: $address)';
}

/// Lightweight Unit model stub matching PRD Section 16 (Unit Entity).
class Unit {
  final String id;
  final String propertyId;
  final String unitNumber;
  final int floor;
  final String? tenantId;
  final String occupancyStatus;

  const Unit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.floor,
    this.tenantId,
    this.occupancyStatus = 'occupied',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'propertyId': propertyId,
    'unitNumber': unitNumber,
    'floor': floor,
    'tenantId': tenantId,
    'occupancyStatus': occupancyStatus,
  };

  factory Unit.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return Unit(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      propertyId: map['propertyId'] as String? ?? '',
      unitNumber: map['unitNumber'] as String? ?? '',
      floor: (map['floor'] as num?)?.toInt() ?? 0,
      tenantId: map['tenantId'] as String?,
      occupancyStatus: map['occupancyStatus'] as String? ?? 'occupied',
    );
  }

  Unit copyWith({
    String? id,
    String? propertyId,
    String? unitNumber,
    int? floor,
    String? tenantId,
    String? occupancyStatus,
  }) {
    return Unit(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      unitNumber: unitNumber ?? this.unitNumber,
      floor: floor ?? this.floor,
      tenantId: tenantId ?? this.tenantId,
      occupancyStatus: occupancyStatus ?? this.occupancyStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          propertyId == other.propertyId &&
          unitNumber == other.unitNumber &&
          floor == other.floor &&
          tenantId == other.tenantId &&
          occupancyStatus == other.occupancyStatus;

  @override
  int get hashCode =>
      Object.hash(id, propertyId, unitNumber, floor, tenantId, occupancyStatus);

  @override
  String toString() =>
      'Unit(id: $id, unitNumber: $unitNumber, floor: $floor, occupancyStatus: $occupancyStatus)';
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    return (value as dynamic).toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
