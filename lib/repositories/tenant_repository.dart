import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/tenant.dart';
import '../services/errors/app_failure.dart';
import '../services/errors/run_guarded.dart';
import 'reference_data_repositories.dart';

export 'reference_data_repositories.dart' show TenantRepository;

/// In-memory implementation of [TenantRepository] seeded with [SampleFixtures].
class InMemoryTenantRepository implements TenantRepository {
  InMemoryTenantRepository({
    this.simulatedDelay = Duration.zero,
    this.debugSimulateFailure = false,
    List<Tenant>? initialTenants,
  }) : _tenants = {
         for (final t in initialTenants ?? SampleFixtures.sampleTenants)
           t.id: t,
       };

  final Duration simulatedDelay;
  bool debugSimulateFailure;
  final Map<String, Tenant> _tenants;

  Future<void> _checkDelayAndFailure() async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }
    if (debugSimulateFailure) {
      throw const UnavailableFailure(
        userMessage: 'Tenant service temporarily unavailable. Please retry.',
        retryable: true,
      );
    }
  }

  @override
  Future<Tenant?> getById(String tenantId) => runGuarded(() async {
    await _checkDelayAndFailure();
    return _tenants[tenantId];
  });

  @override
  Stream<List<Tenant>> watchForProperty(String propertyId) async* {
    await _checkDelayAndFailure();
    yield _tenants.values
        .where((t) => t.propertyId == propertyId)
        .toList(growable: false);
  }

  @override
  Stream<List<Tenant>> watchForUnit(String unitId) async* {
    await _checkDelayAndFailure();
    yield _tenants.values
        .where((t) => t.unitId == unitId)
        .toList(growable: false);
  }

  @override
  Future<String> create(Tenant tenant) => runGuarded(() async {
    await _checkDelayAndFailure();
    _tenants[tenant.id] = tenant;
    return tenant.id;
  });

  @override
  Future<void> update(Tenant tenant) => runGuarded(() async {
    await _checkDelayAndFailure();
    _tenants[tenant.id] = tenant;
  });
}

/// Firestore-backed implementation of [TenantRepository] matching PRD and
/// REPOSITORY_CONTRACTS.md specifications.
class FirestoreTenantRepository implements TenantRepository {
  FirestoreTenantRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<Tenant?> getById(String tenantId) => runGuarded(() async {
    final doc = await _firestore
        .collection(FirestoreCollections.tenants)
        .doc(tenantId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return Tenant.fromMap(doc.data()!, id: doc.id);
  });

  @override
  Stream<List<Tenant>> watchForProperty(String propertyId) {
    return _firestore
        .collection(FirestoreCollections.tenants)
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => Tenant.fromMap(d.data(), id: d.id))
              .toList(growable: false),
        );
  }

  @override
  Stream<List<Tenant>> watchForUnit(String unitId) {
    return _firestore
        .collection(FirestoreCollections.tenants)
        .where('unitId', isEqualTo: unitId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => Tenant.fromMap(d.data(), id: d.id))
              .toList(growable: false),
        );
  }

  @override
  Future<String> create(Tenant tenant) => runGuarded(() async {
    final validationErrors = tenant.validate();
    if (validationErrors.isNotEmpty) {
      throw ValidationFailure(
        userMessage: 'Invalid tenant: ${validationErrors.join(", ")}',
      );
    }
    final ref = _firestore.collection(FirestoreCollections.tenants).doc();
    final data = FirestoreRepositoryPayloads.forCreate(tenant.toMap());
    await ref.set(data);
    return ref.id;
  });

  @override
  Future<void> update(Tenant tenant) => runGuarded(() async {
    final validationErrors = tenant.validate();
    if (validationErrors.isNotEmpty) {
      throw ValidationFailure(
        userMessage: 'Invalid tenant: ${validationErrors.join(", ")}',
      );
    }
    final ref = _firestore
        .collection(FirestoreCollections.tenants)
        .doc(tenant.id);
    final data = FirestoreRepositoryPayloads.forUpdate(tenant.toMap());
    await ref.update(data);
  });
}
