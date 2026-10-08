import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/property.dart';
import '../core/models/tenant.dart';
import '../core/models/user.dart';

/// Error categories for reference-data seeding operations.
enum ReferenceDataSeedFailureCode {
  unauthorized,
  permissionDenied,
  serviceUnavailable,
  invalidRelationship,
  unknown,
}

/// Typed, user-safe failure returned by [ReferenceDataSeedService].
class ReferenceDataSeedFailure implements Exception {
  const ReferenceDataSeedFailure(this.code, [this.customMessage]);

  final ReferenceDataSeedFailureCode code;
  final String? customMessage;

  String get message =>
      customMessage ??
      switch (code) {
        ReferenceDataSeedFailureCode.unauthorized =>
          'Only authorized operations staff can seed reference data.',
        ReferenceDataSeedFailureCode.permissionDenied => 'Permission denied. You do not have permission to write reference data.',
        ReferenceDataSeedFailureCode.serviceUnavailable => 'Firestore service is temporarily unavailable. Check your network connection.',
        ReferenceDataSeedFailureCode.invalidRelationship =>
          'Sample reference data has invalid relationships.',
        ReferenceDataSeedFailureCode.unknown =>
          'An unexpected error occurred while seeding reference data.',
      };

  static ReferenceDataSeedFailure fromFirestoreException(
    FirebaseException exception,
  ) {
    return ReferenceDataSeedFailure(_firestoreCode(exception.code));
  }

  @override
  String toString() => 'ReferenceDataSeedFailure(${code.name}): $message';
}

ReferenceDataSeedFailureCode _firestoreCode(String code) => switch (code) {
  'permission-denied' => ReferenceDataSeedFailureCode.permissionDenied,
  'unavailable' ||
  'deadline-exceeded' ||
  'aborted' ||
  'resource-exhausted' => ReferenceDataSeedFailureCode.serviceUnavailable,
  _ => ReferenceDataSeedFailureCode.unknown,
};

/// Itemized seed results for a single reference-data entity collection.
class EntitySeedSummary {
  const EntitySeedSummary({
    required this.entityName,
    this.createdIds = const [],
    this.skippedIds = const [],
    this.failedIds = const [],
  });

  final String entityName;
  final List<String> createdIds;
  final List<String> skippedIds;
  final List<String> failedIds;

  int get createdCount => createdIds.length;
  int get skippedCount => skippedIds.length;
  int get failedCount => failedIds.length;
  int get totalProcessed => createdCount + skippedCount + failedCount;
  bool get hasFailures => failedIds.isNotEmpty;
  bool get isAllSkipped =>
      createdCount == 0 && skippedCount > 0 && failedCount == 0;
}

/// Overall result of a reference-data seed run across all entities.
class ReferenceDataSeedResult {
  const ReferenceDataSeedResult({
    required this.properties,
    required this.units,
    required this.tenants,
    this.errorMessage,
  });

  final EntitySeedSummary properties;
  final EntitySeedSummary units;
  final EntitySeedSummary tenants;
  final String? errorMessage;

  bool get isSuccess =>
      errorMessage == null &&
      !properties.hasFailures &&
      !units.hasFailures &&
      !tenants.hasFailures;

  int get totalCreated =>
      properties.createdCount + units.createdCount + tenants.createdCount;

  int get totalSkipped =>
      properties.skippedCount + units.skippedCount + tenants.skippedCount;

  int get totalFailed =>
      properties.failedCount + units.failedCount + tenants.failedCount;

  /// Summary description suitable for status feedback.
  String toStatusReport() => [
    '${properties.createdCount} properties created (${properties.skippedCount} already existed)',
    '${units.createdCount} units created (${units.skippedCount} already existed)',
    '${tenants.createdCount} tenants created (${tenants.skippedCount} already existed)',
  ].join('\n');
}

/// Service responsible for seeding deterministic sample reference data
/// (properties, units, tenants) into Cloud Firestore.
///
/// Guarded to authorized internal operations staff only.
/// Deterministic IDs prevent duplicate document creation and never overwrite
/// existing records.
class ReferenceDataSeedService {
  ReferenceDataSeedService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Verifies that the caller has an active, trusted operations role.
  void verifyAuthorization(AppUser executor) {
    if (!executor.isAuthorized || !executor.role.isOperationsStaff) {
      throw const ReferenceDataSeedFailure(
        ReferenceDataSeedFailureCode.unauthorized,
      );
    }
  }

  /// Builds a Firestore write payload for a [Property].
  ///
  /// Uses [FieldValue.serverTimestamp()] for [createdAt] and [updatedAt].
  /// Preserves both modern `status` and legacy `isActive` fields.
  static Map<String, dynamic> buildPropertyPayload(Property property) => {
    'id': property.id,
    'name': property.name,
    'address': property.addressDetails?.toMap() ?? property.address,
    'status': property.status.value,
    'isActive': property.isActive,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Builds a Firestore write payload for a [Unit].
  ///
  /// Uses [FieldValue.serverTimestamp()] for [createdAt] and [updatedAt].
  /// Preserves both modern `status` and legacy `occupancyStatus` / `tenantId` fields.
  static Map<String, dynamic> buildUnitPayload(Unit unit) => {
    'id': unit.id,
    'propertyId': unit.propertyId,
    'unitNumber': unit.unitNumber,
    if (unit.floor != null) 'floor': unit.floor,
    'status': unit.status.value,
    'occupancyStatus': unit.occupancyStatus,
    if (unit.tenantId != null) 'tenantId': unit.tenantId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Builds a Firestore write payload for a [Tenant].
  ///
  /// Uses [FieldValue.serverTimestamp()] for [createdAt] and [updatedAt].
  /// Preserves both modern `fullName` and legacy `name`, `status`, and `isActive` fields.
  static Map<String, dynamic> buildTenantPayload(Tenant tenant) => {
    'id': tenant.id,
    'name': tenant.name,
    'fullName': tenant.fullName,
    if (tenant.phone != null) 'phone': tenant.phone,
    if (tenant.email != null) 'email': tenant.email,
    if (tenant.propertyId != null) 'propertyId': tenant.propertyId,
    if (tenant.unitId != null) 'unitId': tenant.unitId,
    'status': tenant.status.value,
    'isActive': tenant.isActive,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Validates relational consistency across reference data fixtures.
  ///
  /// Ensures all units reference known properties, and all tenants reference
  /// valid units and properties.
  static List<String> validateRelationships({
    List<Property>? properties,
    List<Unit>? units,
    List<Tenant>? tenants,
  }) {
    final props = properties ?? SampleFixtures.sampleProperties;
    final uns = units ?? SampleFixtures.sampleUnits;
    final tens = tenants ?? SampleFixtures.sampleTenants;
    final errors = <String>[];
    final propertyIds = props.map((p) => p.id).toSet();
    final unitMap = {for (final u in uns) u.id: u};

    for (final unit in uns) {
      if (!propertyIds.contains(unit.propertyId)) {
        errors.add(
          'Unit ${unit.id} references nonexistent property ${unit.propertyId}',
        );
      }
    }

    for (final tenant in tens) {
      if (tenant.propertyId != null &&
          !propertyIds.contains(tenant.propertyId)) {
        errors.add(
          'Tenant ${tenant.id} references nonexistent property ${tenant.propertyId}',
        );
      }
      if (tenant.unitId != null) {
        final assignedUnit = unitMap[tenant.unitId];
        if (assignedUnit == null) {
          errors.add(
            'Tenant ${tenant.id} references nonexistent unit ${tenant.unitId}',
          );
        } else if (tenant.propertyId != null &&
            assignedUnit.propertyId != tenant.propertyId) {
          errors.add(
            'Tenant ${tenant.id} propertyId (${tenant.propertyId}) does not match '
            'unit ${tenant.unitId} propertyId (${assignedUnit.propertyId})',
          );
        }
      }
    }
    return errors;
  }

  /// Seeds sample properties into the `properties` collection.
  Future<EntitySeedSummary> seedProperties({
    required AppUser executor,
    List<Property>? fixtures,
  }) async {
    verifyAuthorization(executor);

    final items = fixtures ?? SampleFixtures.sampleProperties;
    final createdIds = <String>[];
    final skippedIds = <String>[];
    final failedIds = <String>[];

    try {
      for (final prop in items) {
        final docRef = _firestore
            .collection(FirestoreCollections.properties)
            .doc(prop.id);
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          skippedIds.add(prop.id);
        } else {
          final payload = buildPropertyPayload(prop);
          await docRef.set(payload);
          createdIds.add(prop.id);
        }
      }
      return EntitySeedSummary(
        entityName: 'properties',
        createdIds: createdIds,
        skippedIds: skippedIds,
        failedIds: failedIds,
      );
    } on ReferenceDataSeedFailure {
      rethrow;
    } on FirebaseException catch (e) {
      throw ReferenceDataSeedFailure.fromFirestoreException(e);
    } catch (_) {
      throw const ReferenceDataSeedFailure(
        ReferenceDataSeedFailureCode.unknown,
      );
    }
  }

  /// Seeds sample units into the `units` collection.
  Future<EntitySeedSummary> seedUnits({
    required AppUser executor,
    List<Unit>? fixtures,
  }) async {
    verifyAuthorization(executor);

    final items = fixtures ?? SampleFixtures.sampleUnits;
    final createdIds = <String>[];
    final skippedIds = <String>[];
    final failedIds = <String>[];

    try {
      for (final unit in items) {
        final docRef = _firestore
            .collection(FirestoreCollections.units)
            .doc(unit.id);
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          skippedIds.add(unit.id);
        } else {
          final payload = buildUnitPayload(unit);
          await docRef.set(payload);
          createdIds.add(unit.id);
        }
      }
      return EntitySeedSummary(
        entityName: 'units',
        createdIds: createdIds,
        skippedIds: skippedIds,
        failedIds: failedIds,
      );
    } on ReferenceDataSeedFailure {
      rethrow;
    } on FirebaseException catch (e) {
      throw ReferenceDataSeedFailure.fromFirestoreException(e);
    } catch (_) {
      throw const ReferenceDataSeedFailure(
        ReferenceDataSeedFailureCode.unknown,
      );
    }
  }

  /// Seeds sample tenants into the `tenants` collection.
  Future<EntitySeedSummary> seedTenants({
    required AppUser executor,
    List<Tenant>? fixtures,
  }) async {
    verifyAuthorization(executor);

    final items = fixtures ?? SampleFixtures.sampleTenants;
    final createdIds = <String>[];
    final skippedIds = <String>[];
    final failedIds = <String>[];

    try {
      for (final tenant in items) {
        final docRef = _firestore
            .collection(FirestoreCollections.tenants)
            .doc(tenant.id);
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          skippedIds.add(tenant.id);
        } else {
          final payload = buildTenantPayload(tenant);
          await docRef.set(payload);
          createdIds.add(tenant.id);
        }
      }
      return EntitySeedSummary(
        entityName: 'tenants',
        createdIds: createdIds,
        skippedIds: skippedIds,
        failedIds: failedIds,
      );
    } on ReferenceDataSeedFailure {
      rethrow;
    } on FirebaseException catch (e) {
      throw ReferenceDataSeedFailure.fromFirestoreException(e);
    } catch (_) {
      throw const ReferenceDataSeedFailure(
        ReferenceDataSeedFailureCode.unknown,
      );
    }
  }

  /// Seeds all reference data in dependency order: properties -> units -> tenants.
  Future<ReferenceDataSeedResult> seedAll({required AppUser executor}) async {
    verifyAuthorization(executor);

    final relationshipErrors = validateRelationships();
    if (relationshipErrors.isNotEmpty) {
      throw ReferenceDataSeedFailure(
        ReferenceDataSeedFailureCode.invalidRelationship,
        relationshipErrors.join('; '),
      );
    }

    final propSummary = await seedProperties(executor: executor);
    final unitSummary = await seedUnits(executor: executor);
    final tenantSummary = await seedTenants(executor: executor);

    return ReferenceDataSeedResult(
      properties: propSummary,
      units: unitSummary,
      tenants: tenantSummary,
    );
  }

  /// Convenience alias matching the ticket specification.
  Future<ReferenceDataSeedResult> seedReferenceData({
    required AppUser executor,
  }) => seedAll(executor: executor);
}
