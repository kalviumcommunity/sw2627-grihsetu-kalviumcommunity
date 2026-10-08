import '../enums/tenant_status.dart';
import '../utils/firestore_values.dart';

/// A tenant directory record, distinct from a Firebase Auth user profile.
///
/// [propertyId] and [unitId] are nullable to support an unassigned tenant
/// record. When [unitId] is present, [propertyId] must also be present. A
/// tenant can later receive a new record/assignment for occupancy history;
/// this model does not pretend that one tenant is permanently tied to one unit.
class Tenant {
  final String id;
  final String? _nameInput;
  final String? _fullNameInput;
  final TenantStatus? _explicitStatus;
  final bool? _legacyIsActive;
  final String? phone;
  final String? email;
  final String? propertyId;
  final String? unitId;
  final String? linkedUserId;
  final DateTime? occupancyStart;
  final DateTime? occupancyEnd;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Tenant({
    required this.id,
    String? name,
    String? fullName,
    this.phone,
    this.email,
    this.propertyId,
    this.unitId,
    this.linkedUserId,
    this.occupancyStart,
    this.occupancyEnd,
    TenantStatus? status,
    bool? isActive,
    this.createdAt,
    this.updatedAt,
  }) : _nameInput = name,
       _fullNameInput = fullName,
       _explicitStatus = status,
       _legacyIsActive = isActive;

  String get fullName => (_fullNameInput ?? _nameInput ?? '').trim();

  /// Compatibility alias for the PRD's original `name` field.
  String get name => fullName;

  TenantStatus get status =>
      _explicitStatus ??
      (_legacyIsActive == false ? TenantStatus.ended : TenantStatus.active);

  /// Compatibility getter for the PRD's original `isActive` field.
  bool get isActive => status == TenantStatus.active;

  /// Returns model-level relationship errors before a repository write.
  List<String> validate() {
    final errors = <String>[];
    if (fullName.isEmpty) errors.add('fullName is required');
    if (unitId != null && propertyId == null) {
      errors.add('propertyId is required when unitId is assigned');
    }
    if (occupancyEnd != null &&
        occupancyStart != null &&
        occupancyEnd!.isBefore(occupancyStart!)) {
      errors.add('occupancyEnd cannot be before occupancyStart');
    }
    return errors;
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (propertyId != null) 'propertyId': propertyId,
    if (unitId != null) 'unitId': unitId,
    if (linkedUserId != null) 'linkedUserId': linkedUserId,
    if (occupancyStart != null)
      'occupancyStart': timestampFromDateTime(occupancyStart),
    if (occupancyEnd != null)
      'occupancyEnd': timestampFromDateTime(occupancyEnd),
    'status': status.value,
    if (createdAt != null) 'createdAt': timestampFromDateTime(createdAt),
    if (updatedAt != null) 'updatedAt': timestampFromDateTime(updatedAt),
  };

  factory Tenant.fromMap(Map<String, dynamic> map, {String id = ''}) => Tenant(
    id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
    fullName: (map['fullName'] ?? map['name']) as String?,
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    propertyId: map['propertyId'] as String?,
    unitId: map['unitId'] as String?,
    linkedUserId: map['linkedUserId'] as String?,
    occupancyStart: dateTimeFromFirestore(map['occupancyStart']),
    occupancyEnd: dateTimeFromFirestore(map['occupancyEnd']),
    status:
        TenantStatus.tryFromValue(map['status'] as String?) ??
        (map['isActive'] == false ? TenantStatus.ended : TenantStatus.active),
    createdAt: dateTimeFromFirestore(map['createdAt']),
    updatedAt: dateTimeFromFirestore(map['updatedAt']),
  );

  Tenant copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? propertyId,
    String? unitId,
    String? linkedUserId,
    DateTime? occupancyStart,
    DateTime? occupancyEnd,
    TenantStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Tenant(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    propertyId: propertyId ?? this.propertyId,
    unitId: unitId ?? this.unitId,
    linkedUserId: linkedUserId ?? this.linkedUserId,
    occupancyStart: occupancyStart ?? this.occupancyStart,
    occupancyEnd: occupancyEnd ?? this.occupancyEnd,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tenant &&
          id == other.id &&
          fullName == other.fullName &&
          phone == other.phone &&
          email == other.email &&
          propertyId == other.propertyId &&
          unitId == other.unitId &&
          status == other.status;

  @override
  int get hashCode =>
      Object.hash(id, fullName, phone, email, propertyId, unitId, status);

  @override
  String toString() => 'Tenant(id: $id, name: $fullName, unitId: $unitId)';
}
