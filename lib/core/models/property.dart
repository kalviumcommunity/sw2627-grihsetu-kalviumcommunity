import '../enums/property_status.dart';
import '../enums/unit_status.dart';
import '../utils/firestore_values.dart';

/// A property/building that provides location context for operational data.
///
/// The document ID is the canonical property ID; it is intentionally omitted
/// from [toMap] so the same value cannot drift from the Firestore document ID.
/// [addressDetails] is the preferred structured representation. The string
/// [address] remains supported because it is the address shape in the MVP PRD
/// and in existing GrihSetu fixtures.
class Property {
  final String id;
  final String name;
  final String address;
  final PropertyAddress? addressDetails;
  final PropertyStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Property({
    required this.id,
    required this.name,
    required this.address,
    PropertyStatus? status,
    bool? isActive,
    this.addressDetails,
    this.createdAt,
    this.updatedAt,
  }) : status =
           status ??
           (isActive == false
               ? PropertyStatus.inactive
               : PropertyStatus.active);

  /// Compatibility getter for the PRD's original `isActive` field.
  bool get isActive => status == PropertyStatus.active;

  /// Returns model-level required-field errors before a repository write.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('name is required');
    if (address.trim().isEmpty && addressDetails?.display.isEmpty != false) {
      errors.add('address is required');
    }
    return errors;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': addressDetails?.toMap() ?? address,
    'status': status.value,
    if (createdAt != null) 'createdAt': timestampFromDateTime(createdAt),
    if (updatedAt != null) 'updatedAt': timestampFromDateTime(updatedAt),
  };

  factory Property.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final rawAddress = map['address'];
    final addressDetails = rawAddress is Map
        ? PropertyAddress.fromMap(Map<String, dynamic>.from(rawAddress))
        : null;
    return Property(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      address: rawAddress is String
          ? rawAddress
          : addressDetails?.display ?? '',
      addressDetails: addressDetails,
      status:
          PropertyStatus.tryFromValue(map['status'] as String?) ??
          (map['isActive'] == false
              ? PropertyStatus.inactive
              : PropertyStatus.active),
      createdAt: dateTimeFromFirestore(map['createdAt']),
      updatedAt: dateTimeFromFirestore(map['updatedAt']),
    );
  }

  Property copyWith({
    String? id,
    String? name,
    String? address,
    PropertyAddress? addressDetails,
    PropertyStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Property(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    addressDetails: addressDetails ?? this.addressDetails,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Property &&
          id == other.id &&
          name == other.name &&
          address == other.address &&
          addressDetails == other.addressDetails &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    address,
    addressDetails,
    status,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Property(id: $id, name: $name, status: ${status.value})';
}

/// Structured address fields for properties. All fields are optional so the
/// MVP can gradually enrich existing string addresses without a migration.
class PropertyAddress {
  final String? line1;
  final String? line2;
  final String? locality;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  const PropertyAddress({
    this.line1,
    this.line2,
    this.locality,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  Map<String, dynamic> toMap() => {
    if (line1 != null) 'line1': line1,
    if (line2 != null) 'line2': line2,
    if (locality != null) 'locality': locality,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (postalCode != null) 'postalCode': postalCode,
    if (country != null) 'country': country,
  };

  factory PropertyAddress.fromMap(Map<String, dynamic> map) => PropertyAddress(
    line1: map['line1'] as String?,
    line2: map['line2'] as String?,
    locality: map['locality'] as String?,
    city: map['city'] as String?,
    state: map['state'] as String?,
    postalCode: map['postalCode'] as String?,
    country: map['country'] as String?,
  );

  String get display => [
    line1,
    line2,
    locality,
    city,
    state,
    postalCode,
    country,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyAddress &&
          line1 == other.line1 &&
          line2 == other.line2 &&
          locality == other.locality &&
          city == other.city &&
          state == other.state &&
          postalCode == other.postalCode &&
          country == other.country;

  @override
  int get hashCode =>
      Object.hash(line1, line2, locality, city, state, postalCode, country);
}

/// A unit belongs to exactly one property through [propertyId].
class Unit {
  final String id;
  final String propertyId;
  final String unitNumber;
  final int? floor;
  final String occupancyStatus;
  final UnitStatus? _explicitStatus;
  final String? tenantId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Unit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    this.floor,
    UnitStatus? status,
    this.occupancyStatus = 'vacant',
    this.tenantId,
    this.createdAt,
    this.updatedAt,
  }) : _explicitStatus = status;

  /// Compatibility getter for the PRD's original `occupancyStatus` field.
  UnitStatus get status =>
      _explicitStatus ?? UnitStatus.fromValue(occupancyStatus);

  /// Returns model-level required-field errors before a repository write.
  List<String> validate() {
    final errors = <String>[];
    if (propertyId.trim().isEmpty) errors.add('propertyId is required');
    if (unitNumber.trim().isEmpty) errors.add('unitNumber is required');
    return errors;
  }

  Map<String, dynamic> toMap() => {
    'propertyId': propertyId,
    'unitNumber': unitNumber,
    if (floor != null) 'floor': floor,
    'status': status.value,
    // `tenantId` is read for compatibility with the PRD's original fixture
    // shape, but is intentionally not persisted by new writes. A unit may
    // have multiple tenants over time; tenant/assignment records own that
    // relationship rather than this denormalized display hint.
    if (createdAt != null) 'createdAt': timestampFromDateTime(createdAt),
    if (updatedAt != null) 'updatedAt': timestampFromDateTime(updatedAt),
  };

  factory Unit.fromMap(Map<String, dynamic> map, {String id = ''}) => Unit(
    id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
    propertyId: map['propertyId'] as String? ?? '',
    unitNumber: map['unitNumber'] as String? ?? '',
    floor: (map['floor'] as num?)?.toInt(),
    status: UnitStatus.tryFromValue(
      (map['status'] ?? map['occupancyStatus']) as String?,
    ),
    occupancyStatus: map['occupancyStatus'] as String? ?? 'vacant',
    tenantId: map['tenantId'] as String?,
    createdAt: dateTimeFromFirestore(map['createdAt']),
    updatedAt: dateTimeFromFirestore(map['updatedAt']),
  );

  Unit copyWith({
    String? id,
    String? propertyId,
    String? unitNumber,
    int? floor,
    UnitStatus? status,
    String? occupancyStatus,
    String? tenantId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Unit(
    id: id ?? this.id,
    propertyId: propertyId ?? this.propertyId,
    unitNumber: unitNumber ?? this.unitNumber,
    floor: floor ?? this.floor,
    status: status ?? _explicitStatus,
    occupancyStatus: occupancyStatus ?? this.occupancyStatus,
    tenantId: tenantId ?? this.tenantId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unit &&
          id == other.id &&
          propertyId == other.propertyId &&
          unitNumber == other.unitNumber &&
          floor == other.floor &&
          status == other.status &&
          tenantId == other.tenantId;

  @override
  int get hashCode =>
      Object.hash(id, propertyId, unitNumber, floor, status, tenantId);

  @override
  String toString() =>
      'Unit(id: $id, unitNumber: $unitNumber, status: ${status.value})';
}
