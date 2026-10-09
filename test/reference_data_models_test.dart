import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/repositories/repositories.dart';

void main() {
  group('reference data models', () {
    test('property supports structured addresses and Timestamp dates', () {
      final createdAt = DateTime.utc(2026, 10, 8, 9, 30);
      final property = Property(
        id: 'property-1',
        name: 'Shanti Heights',
        address: '12 Park Avenue',
        addressDetails: const PropertyAddress(
          line1: '12 Park Avenue',
          city: 'Gurugram',
          country: 'India',
        ),
        status: PropertyStatus.active,
        createdAt: createdAt,
      );

      final map = property.toMap();
      expect(map['status'], 'active');
      expect(map['address'], isA<Map<String, dynamic>>());
      expect(map['createdAt'], isA<Timestamp>());

      final restored = Property.fromMap(map, id: property.id);
      expect(restored.id, property.id);
      expect(restored.addressDetails?.city, 'Gurugram');
      expect(restored.createdAt, createdAt);
    });

    test('unit reads legacy occupancyStatus but writes canonical status', () {
      const unit = Unit(
        id: 'unit-1',
        propertyId: 'property-1',
        unitNumber: 'A-101',
        occupancyStatus: 'occupied',
      );

      expect(unit.status, UnitStatus.occupied);
      expect(unit.toMap(), containsPair('status', 'occupied'));
      expect(unit.toMap(), isNot(contains('tenantId')));
    });

    test(
      'tenant supports an unassigned record and validates relationships',
      () {
        const unassigned = Tenant(id: 'tenant-1', fullName: 'Priya Patel');
        expect(unassigned.validate(), isEmpty);
        expect(unassigned.toMap(), isNot(contains('propertyId')));

        const invalid = Tenant(
          id: 'tenant-2',
          fullName: 'Rajesh Kumar',
          unitId: 'unit-1',
        );
        expect(
          invalid.validate(),
          contains('propertyId is required when unitId is assigned'),
        );
      },
    );
  });

  test('repository payload helpers reserve timestamps for Firestore', () {
    final create = FirestoreRepositoryPayloads.forCreate({
      'name': 'Shanti Heights',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    expect(create['createdAt'], isA<FieldValue>());
    expect(create['updatedAt'], isA<FieldValue>());

    final update = FirestoreRepositoryPayloads.forUpdate({
      'name': 'Shanti Heights II',
      'createdAt': Timestamp.now(),
    });
    expect(update['createdAt'], isNull);
    expect(update['updatedAt'], isA<FieldValue>());
  });
}
