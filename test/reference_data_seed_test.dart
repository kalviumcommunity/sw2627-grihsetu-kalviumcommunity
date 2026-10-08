import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app_shell.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/fixtures/sample_fixtures.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/screens/dev/reference_data_seed_screen.dart';
import 'package:grihsetu/services/reference_data_seed_service.dart';

class FakeReferenceDataSeedService implements ReferenceDataSeedService {
  EntitySeedSummary propertiesResult = const EntitySeedSummary(
    entityName: 'properties',
    createdIds: ['prop_001', 'prop_002'],
  );
  EntitySeedSummary unitsResult = const EntitySeedSummary(
    entityName: 'units',
    createdIds: ['unit_101', 'unit_204', 'unit_402'],
  );
  EntitySeedSummary tenantsResult = const EntitySeedSummary(
    entityName: 'tenants',
    createdIds: ['ten_001', 'ten_002', 'ten_003'],
  );

  Object? errorToThrow;
  bool seedAllCalled = false;
  bool seedPropertiesCalled = false;
  bool seedUnitsCalled = false;
  bool seedTenantsCalled = false;

  @override
  void verifyAuthorization(AppUser executor) {
    if (!executor.isAuthorized || !executor.role.isOperationsStaff) {
      throw const ReferenceDataSeedFailure(
        ReferenceDataSeedFailureCode.unauthorized,
      );
    }
  }

  @override
  Future<EntitySeedSummary> seedProperties({
    required AppUser executor,
    List<Property>? fixtures,
  }) async {
    seedPropertiesCalled = true;
    verifyAuthorization(executor);
    if (errorToThrow != null) throw errorToThrow!;
    return propertiesResult;
  }

  @override
  Future<EntitySeedSummary> seedUnits({
    required AppUser executor,
    List<Unit>? fixtures,
  }) async {
    seedUnitsCalled = true;
    verifyAuthorization(executor);
    if (errorToThrow != null) throw errorToThrow!;
    return unitsResult;
  }

  @override
  Future<EntitySeedSummary> seedTenants({
    required AppUser executor,
    List<Tenant>? fixtures,
  }) async {
    seedTenantsCalled = true;
    verifyAuthorization(executor);
    if (errorToThrow != null) throw errorToThrow!;
    return tenantsResult;
  }

  @override
  Future<ReferenceDataSeedResult> seedAll({required AppUser executor}) async {
    seedAllCalled = true;
    verifyAuthorization(executor);
    if (errorToThrow != null) throw errorToThrow!;
    return ReferenceDataSeedResult(
      properties: propertiesResult,
      units: unitsResult,
      tenants: tenantsResult,
    );
  }

  @override
  Future<ReferenceDataSeedResult> seedReferenceData({
    required AppUser executor,
  }) => seedAll(executor: executor);
}

void main() {
  group('ReferenceDataSeedService - Payloads', () {
    test(
      'buildPropertyPayload contains required fields and server timestamps',
      () {
        final sampleProp = SampleFixtures.sampleProperties.first;
        final payload = ReferenceDataSeedService.buildPropertyPayload(
          sampleProp,
        );

        expect(payload['id'], 'prop_001');
        expect(payload['name'], sampleProp.name);
        expect(payload['address'], sampleProp.address);
        expect(payload['status'], 'active');
        expect(payload['isActive'], isTrue);
        expect(payload['createdAt'], isA<FieldValue>());
        expect(payload['updatedAt'], isA<FieldValue>());
      },
    );

    test('buildUnitPayload contains required fields, relationships, and timestamps', () {
      final sampleUnit = SampleFixtures.sampleUnits.first;
      final payload = ReferenceDataSeedService.buildUnitPayload(sampleUnit);

      expect(payload['id'], 'unit_101');
      expect(payload['propertyId'], 'prop_001');
      expect(payload['unitNumber'], 'A-101');
      expect(payload['floor'], 1);
      expect(payload['occupancyStatus'], 'occupied');
      expect(payload['status'], 'occupied');
      expect(payload['tenantId'], 'ten_001');
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['updatedAt'], isA<FieldValue>());
    });

    test('buildTenantPayload contains required fields, relationships, and timestamps', () {
      final sampleTenant = SampleFixtures.sampleTenants.first;
      final payload = ReferenceDataSeedService.buildTenantPayload(sampleTenant);

      expect(payload['id'], 'ten_001');
      expect(payload['name'], 'Priya Patel');
      expect(payload['fullName'], 'Priya Patel');
      expect(payload['phone'], '+91 98765 43210');
      expect(payload['propertyId'], 'prop_001');
      expect(payload['unitId'], 'unit_101');
      expect(payload['isActive'], isTrue);
      expect(payload['status'], 'active');
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['updatedAt'], isA<FieldValue>());
    });
  });

  group('ReferenceDataSeedService - Relationships', () {
    test('validateRelationships passes for existing SampleFixtures', () {
      final errors = ReferenceDataSeedService.validateRelationships(
        properties: SampleFixtures.sampleProperties,
        units: SampleFixtures.sampleUnits,
        tenants: SampleFixtures.sampleTenants,
      );
      expect(errors, isEmpty);
    });

    test('validateRelationships catches invalid propertyId in unit', () {
      const invalidUnit = Unit(
        id: 'unit_bad',
        propertyId: 'nonexistent_prop',
        unitNumber: 'Z-999',
      );
      final errors = ReferenceDataSeedService.validateRelationships(
        properties: SampleFixtures.sampleProperties,
        units: [invalidUnit],
        tenants: const [],
      );
      expect(errors, isNotEmpty);
      expect(errors.first, contains('nonexistent property nonexistent_prop'));
    });

    test('validateRelationships catches invalid unitId in tenant', () {
      const invalidTenant = Tenant(
        id: 'ten_bad',
        fullName: 'Test Tenant',
        propertyId: 'prop_001',
        unitId: 'nonexistent_unit',
      );
      final errors = ReferenceDataSeedService.validateRelationships(
        properties: SampleFixtures.sampleProperties,
        units: SampleFixtures.sampleUnits,
        tenants: [invalidTenant],
      );
      expect(errors, isNotEmpty);
      expect(errors.first, contains('nonexistent unit nonexistent_unit'));
    });

    test('validateRelationships catches unit/property mismatch in tenant', () {
      const mismatchedTenant = Tenant(
        id: 'ten_mismatch',
        fullName: 'Mismatch Tenant',
        propertyId: 'prop_002', // Unit 101 belongs to prop_001, not prop_002
        unitId: 'unit_101',
      );
      final errors = ReferenceDataSeedService.validateRelationships(
        properties: SampleFixtures.sampleProperties,
        units: SampleFixtures.sampleUnits,
        tenants: [mismatchedTenant],
      );
      expect(errors, isNotEmpty);
      expect(errors.first, contains('does not match unit unit_101 propertyId'));
    });
  });

  group('ReferenceDataSeedService - Authorization', () {
    final service = FakeReferenceDataSeedService();

    test('allows propertyOperations and complaintOperations', () {
      const propOpsUser = AppUser(
        id: 'u1',
        name: 'Prop Ops',
        email: 'prop@grihsetu.com',
        role: UserRole.propertyOperations,
        createdAt: null,
      );
      const compOpsUser = AppUser(
        id: 'u2',
        name: 'Complaint Ops',
        email: 'complaint@grihsetu.com',
        role: UserRole.complaintOperations,
        createdAt: null,
      );

      expect(() => service.verifyAuthorization(propOpsUser), returnsNormally);
      expect(() => service.verifyAuthorization(compOpsUser), returnsNormally);
    });

    test('denies technician, propertyOwner, and tenant', () {
      const techUser = AppUser(
        id: 'u3',
        name: 'Technician',
        email: 'tech@grihsetu.com',
        role: UserRole.technician,
        createdAt: null,
      );
      const ownerUser = AppUser(
        id: 'u4',
        name: 'Owner',
        email: 'owner@grihsetu.com',
        role: UserRole.propertyOwner,
        createdAt: null,
      );
      const tenantUser = AppUser(
        id: 'u5',
        name: 'Tenant',
        email: 'tenant@grihsetu.com',
        role: UserRole.tenant,
        createdAt: null,
      );

      expect(
        () => service.verifyAuthorization(techUser),
        throwsA(isA<ReferenceDataSeedFailure>()),
      );
      expect(
        () => service.verifyAuthorization(ownerUser),
        throwsA(isA<ReferenceDataSeedFailure>()),
      );
      expect(
        () => service.verifyAuthorization(tenantUser),
        throwsA(isA<ReferenceDataSeedFailure>()),
      );
    });

    test('denies unassigned and inactive users', () {
      const unassignedUser = AppUser(
        id: 'u6',
        name: 'Unassigned',
        email: 'unassigned@grihsetu.com',
        role: null,
        createdAt: null,
      );
      const inactiveUser = AppUser(
        id: 'u7',
        name: 'Inactive',
        email: 'inactive@grihsetu.com',
        role: UserRole.propertyOperations,
        isActive: false,
        createdAt: null,
      );

      expect(
        () => service.verifyAuthorization(unassignedUser),
        throwsA(isA<ReferenceDataSeedFailure>()),
      );
      expect(
        () => service.verifyAuthorization(inactiveUser),
        throwsA(isA<ReferenceDataSeedFailure>()),
      );
    });
  });

  group('ReferenceDataSeedResult and EntitySeedSummary - Reporting', () {
    test('EntitySeedSummary counts and helpers', () {
      const summary = EntitySeedSummary(
        entityName: 'properties',
        createdIds: ['prop_001'],
        skippedIds: ['prop_002'],
      );
      expect(summary.createdCount, 1);
      expect(summary.skippedCount, 1);
      expect(summary.failedCount, 0);
      expect(summary.hasFailures, isFalse);
      expect(summary.totalProcessed, 2);
    });

    test('ReferenceDataSeedResult toStatusReport and totals', () {
      const result = ReferenceDataSeedResult(
        properties: EntitySeedSummary(
          entityName: 'properties',
          createdIds: ['prop_001'],
          skippedIds: ['prop_002'],
        ),
        units: EntitySeedSummary(
          entityName: 'units',
          createdIds: ['unit_101', 'unit_204'],
          skippedIds: ['unit_402'],
        ),
        tenants: EntitySeedSummary(
          entityName: 'tenants',
          createdIds: [],
          skippedIds: ['ten_001', 'ten_002', 'ten_003'],
        ),
      );

      expect(result.totalCreated, 3);
      expect(result.totalSkipped, 5);
      expect(result.totalFailed, 0);
      expect(result.isSuccess, isTrue);

      final report = result.toStatusReport();
      expect(report, contains('1 properties created (1 already existed)'));
      expect(report, contains('2 units created (1 already existed)'));
      expect(report, contains('0 tenants created (3 already existed)'));
    });
  });

  group('ReferenceDataSeedFailure - Mapping', () {
    test('maps Firebase permission-denied to user-safe message', () {
      final exception = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Internal raw security rules denied write to properties',
      );
      final failure = ReferenceDataSeedFailure.fromFirestoreException(
        exception,
      );

      expect(failure.code, ReferenceDataSeedFailureCode.permissionDenied);
      expect(failure.message, isNot(contains('Internal raw security rules')));
      expect(failure.message, contains('permission'));
    });

    test('maps Firebase unavailable to user-safe message', () {
      final exception = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      final failure = ReferenceDataSeedFailure.fromFirestoreException(
        exception,
      );

      expect(failure.code, ReferenceDataSeedFailureCode.serviceUnavailable);
      expect(failure.message, contains('temporarily unavailable'));
    });
  });

  group('AppShell Integration - Developer Tools Menu', () {
    testWidgets(
      'operations staff sees Seed reference data option in developer menu',
      (tester) async {
        const opsProfile = AppUser(
          id: 'u_ops',
          name: 'Ops Lead',
          email: 'ops@grihsetu.com',
          role: UserRole.propertyOperations,
          createdAt: null,
        );

        await tester.pumpWidget(
          const MaterialApp(home: AppShell(profile: opsProfile)),
        );

        final devButton = find.byTooltip('Developer tools');
        expect(devButton, findsOneWidget);
        await tester.tap(devButton);
        await tester.pumpAndSettle();

        expect(find.text('Seed reference data'), findsOneWidget);
      },
    );

    testWidgets(
      'technician does not see Seed reference data option in developer menu',
      (tester) async {
        const techProfile = AppUser(
          id: 'u_tech',
          name: 'Tech Worker',
          email: 'tech@grihsetu.com',
          role: UserRole.technician,
          createdAt: null,
        );

        await tester.pumpWidget(
          const MaterialApp(home: AppShell(profile: techProfile)),
        );

        final devButton = find.byTooltip('Developer tools');
        expect(devButton, findsOneWidget);
        await tester.tap(devButton);
        await tester.pumpAndSettle();

        expect(find.text('Seed reference data'), findsNothing);
      },
    );
  });

  group('ReferenceDataSeedScreen - UI', () {
    testWidgets('unauthorized user sees Access Restricted screen', (
      tester,
    ) async {
      const techProfile = AppUser(
        id: 'u_tech',
        name: 'Tech User',
        email: 'tech@grihsetu.com',
        role: UserRole.technician,
        createdAt: null,
      );

      await tester.pumpWidget(
        const MaterialApp(home: ReferenceDataSeedScreen(profile: techProfile)),
      );

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Seed All Reference Data'), findsNothing);
    });

    testWidgets('authorized operations staff sees Seed actions and banner', (
      tester,
    ) async {
      const opsProfile = AppUser(
        id: 'u_ops',
        name: 'Ops User',
        email: 'ops@grihsetu.com',
        role: UserRole.propertyOperations,
        createdAt: null,
      );

      await tester.pumpWidget(
        const MaterialApp(home: ReferenceDataSeedScreen(profile: opsProfile)),
      );

      expect(find.text('Deterministic Demo Reference Data'), findsOneWidget);
      expect(find.text('Seed All Reference Data'), findsOneWidget);
      expect(find.text('Seed Properties'), findsOneWidget);
      expect(find.text('Seed Units'), findsOneWidget);
      expect(find.text('Seed Tenants'), findsOneWidget);
    });

    testWidgets(
      'tapping Seed All Reference Data calls service and displays execution results',
      (tester) async {
        final fakeService = FakeReferenceDataSeedService();
        const opsProfile = AppUser(
          id: 'u_ops',
          name: 'Ops User',
          email: 'ops@grihsetu.com',
          role: UserRole.propertyOperations,
          createdAt: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ReferenceDataSeedScreen(
              profile: opsProfile,
              seedService: fakeService,
            ),
          ),
        );

        await tester.tap(find.text('Seed All Reference Data'));
        await tester.pumpAndSettle();

        expect(fakeService.seedAllCalled, isTrue);
        expect(find.text('Total Created'), findsOneWidget);
        expect(find.text('8'), findsOneWidget); // 2 props + 3 units + 3 tenants
        expect(find.text('prop_001'), findsOneWidget);
        expect(find.text('unit_101'), findsOneWidget);
        expect(find.text('ten_001'), findsOneWidget);
      },
    );

    testWidgets('displays friendly error banner on service failure', (
      tester,
    ) async {
      final fakeService = FakeReferenceDataSeedService()
        ..errorToThrow = const ReferenceDataSeedFailure(
          ReferenceDataSeedFailureCode.permissionDenied,
        );
      const opsProfile = AppUser(
        id: 'u_ops',
        name: 'Ops User',
        email: 'ops@grihsetu.com',
        role: UserRole.propertyOperations,
        createdAt: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReferenceDataSeedScreen(
            profile: opsProfile,
            seedService: fakeService,
          ),
        ),
      );

      await tester.tap(find.text('Seed All Reference Data'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Permission denied. You do not have permission to write reference data.',
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
