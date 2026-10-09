import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_collections.dart';
import '../../core/fixtures/sample_fixtures.dart';
import '../../core/models/complaint.dart';
import '../../repositories/property_repository.dart';

/// Lightweight helper to resolve human-readable property names and unit numbers
/// without incurring N+1 Firestore reads on every stream update.
class ComplaintReferenceResolver {
  ComplaintReferenceResolver({
    this.propertyRepository,
    this.firestore,
    Map<String, String>? initialPropertyNames,
    Map<String, String>? initialUnitNumbers,
  }) : _propertyNames = Map<String, String>.from(
         initialPropertyNames ?? _defaultPropertyNames,
       ),
       _unitNumbers = Map<String, String>.from(
         initialUnitNumbers ?? _defaultUnitNumbers,
       );

  final PropertyRepository? propertyRepository;
  final FirebaseFirestore? firestore;
  final Map<String, String> _propertyNames;
  final Map<String, String> _unitNumbers;
  final Set<String> _attemptedPropertyIds = {};
  final Set<String> _attemptedUnitIds = {};

  static final Map<String, String> _defaultPropertyNames = {
    for (final p in SampleFixtures.sampleProperties) p.id: p.name,
  };

  static final Map<String, String> _defaultUnitNumbers = {
    for (final u in SampleFixtures.sampleUnits) u.id: u.unitNumber,
  };

  /// Returns the human-readable property name, or the [propertyId] as a graceful fallback.
  String getPropertyName(String propertyId) {
    final trimmed = propertyId.trim();
    if (trimmed.isEmpty) return 'Unknown property';
    return _propertyNames[trimmed] ?? trimmed;
  }

  /// Returns the human-readable unit number, or the [unitId] as a graceful fallback.
  String getUnitNumber(String unitId) {
    final trimmed = unitId.trim();
    if (trimmed.isEmpty) return 'Unknown unit';
    return _unitNumbers[trimmed] ?? trimmed;
  }

  /// Formats location string: e.g. "Green Valley Heights · Unit A-101".
  String formatLocation({required String propertyId, required String unitId}) {
    final prop = getPropertyName(propertyId);
    final unit = getUnitNumber(unitId);
    return '$prop · Unit $unit';
  }

  /// Resolves any missing property and unit references in batch.
  ///
  /// Guarantees at most 1 read per unknown ID across the resolver's lifecycle.
  Future<bool> resolveForComplaints(Iterable<Complaint> complaints) async {
    final missingProperties = <String>{};
    final missingUnits = <String>{};

    for (final c in complaints) {
      final pId = c.propertyId.trim();
      if (pId.isNotEmpty &&
          !_propertyNames.containsKey(pId) &&
          !_attemptedPropertyIds.contains(pId)) {
        missingProperties.add(pId);
      }

      final uId = c.unitId.trim();
      if (uId.isNotEmpty &&
          !_unitNumbers.containsKey(uId) &&
          !_attemptedUnitIds.contains(uId)) {
        missingUnits.add(uId);
      }
    }

    if (missingProperties.isEmpty && missingUnits.isEmpty) {
      return false;
    }

    _attemptedPropertyIds.addAll(missingProperties);
    _attemptedUnitIds.addAll(missingUnits);

    var hasNewData = false;

    // 1. Try repository if available
    final repo = propertyRepository;
    if (repo != null) {
      try {
        final props = await repo.getProperties();
        for (final p in props) {
          _propertyNames[p.id] = p.name;
        }
        for (final pId in missingProperties) {
          try {
            final units = await repo.getUnits(pId);
            for (final u in units) {
              _unitNumbers[u.id] = u.unitNumber;
            }
          } catch (_) {
            // Graceful fallback to IDs
          }
        }
        hasNewData = true;
      } catch (_) {
        // Fallback to Firestore or ID strings
      }
    }

    // 2. Try Firestore for any still-missing references
    final store = firestore;
    if (store != null) {
      for (final pId in missingProperties) {
        if (!_propertyNames.containsKey(pId)) {
          try {
            final doc = await store
                .collection(FirestoreCollections.properties)
                .doc(pId)
                .get();
            if (doc.exists) {
              final data = doc.data();
              final name = data?['name'] as String?;
              if (name != null && name.isNotEmpty) {
                _propertyNames[pId] = name;
                hasNewData = true;
              }
            }
          } catch (_) {
            // Ignore failure, ID is used as fallback
          }
        }
      }

      for (final uId in missingUnits) {
        if (!_unitNumbers.containsKey(uId)) {
          try {
            final doc = await store
                .collection(FirestoreCollections.units)
                .doc(uId)
                .get();
            if (doc.exists) {
              final data = doc.data();
              final num = data?['unitNumber'] as String?;
              if (num != null && num.isNotEmpty) {
                _unitNumbers[uId] = num;
                hasNewData = true;
              }
            }
          } catch (_) {
            // Ignore failure, ID is used as fallback
          }
        }
      }
    }

    return hasNewData;
  }
}
