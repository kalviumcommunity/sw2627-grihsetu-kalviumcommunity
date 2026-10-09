import '../core/models/models.dart';
import '../core/utils/firestore_values.dart';

/// Repository boundary for the existing `users/{uid}` profile documents.
///
/// Authentication and trusted role assignment remain owned by [AuthService].
/// This contract is deliberately read-only until a dedicated profile-edit
/// workflow can enforce the existing GRIH-007 field restrictions.
abstract interface class UserProfileRepository {
  Future<AppUser?> getByUid(String uid);

  Stream<AppUser?> watchByUid(String uid);
}

/// Contract for property reference data.
abstract interface class PropertyRepository {
  Future<Property?> getById(String propertyId);

  Stream<Property?> watchById(String propertyId);

  Stream<List<Property>> watchAll({bool includeInactive = false});

  /// Returns the generated Firestore document ID.
  Future<String> create(Property property);

  Future<void> update(Property property);
}

/// Contract for units stored in the top-level `units` collection.
abstract interface class UnitRepository {
  Future<Unit?> getById(String unitId);

  Stream<List<Unit>> watchForProperty(String propertyId);

  Future<String> create(Unit unit);

  Future<void> update(Unit unit);
}

/// Contract for tenant directory records.
abstract interface class TenantRepository {
  Future<Tenant?> getById(String tenantId);

  Stream<List<Tenant>> watchForProperty(String propertyId);

  Stream<List<Tenant>> watchForUnit(String unitId);

  Future<String> create(Tenant tenant);

  Future<void> update(Tenant tenant);
}

/// Shared payload rules for future Firestore repository implementations.
///
/// These helpers keep server timestamps and model fields consistent without
/// claiming that this issue has implemented full CRUD or security policy.
abstract final class FirestoreRepositoryPayloads {
  static Map<String, dynamic> forCreate(Map<String, dynamic> model) {
    final data = Map<String, dynamic>.from(model)
      ..remove('createdAt')
      ..remove('updatedAt');
    return withServerCreateTimestamps(data);
  }

  static Map<String, dynamic> forUpdate(Map<String, dynamic> model) {
    final data = Map<String, dynamic>.from(model)
      ..remove('createdAt')
      ..remove('updatedAt');
    return withServerUpdateTimestamp(data);
  }
}
