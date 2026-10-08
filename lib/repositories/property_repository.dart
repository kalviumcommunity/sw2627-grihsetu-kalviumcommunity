import '../core/enums/complaint_status.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';
import '../core/models/property.dart';
import '../core/models/tenant.dart';

abstract interface class PropertyRepository {
  Future<List<Property>> getProperties();
  Future<List<Unit>> getUnits(String propertyId);
  Future<List<Tenant>> getTenants(String unitId);
  Future<List<Complaint>> getComplaints({
    String? propertyId,
    String? unitId,
    String? tenantId,
  });
}

class InMemoryPropertyRepository implements PropertyRepository {
  InMemoryPropertyRepository({
    this.loadingDelay = const Duration(milliseconds: 180),
  });

  final Duration loadingDelay;

  static const List<Unit> _extraUnits = [
    Unit(
      id: 'unit_307',
      propertyId: 'prop_001',
      unitNumber: 'C-307',
      floor: 3,
      occupancyStatus: 'vacant',
    ),
    Unit(
      id: 'unit_105',
      propertyId: 'prop_001',
      unitNumber: 'A-105',
      floor: 1,
      occupancyStatus: 'vacant',
    ),
    Unit(
      id: 'unit_505',
      propertyId: 'prop_002',
      unitNumber: 'C-505',
      floor: 5,
      occupancyStatus: 'vacant',
    ),
  ];

  @override
  Future<List<Property>> getProperties() async {
    await Future<void>.delayed(loadingDelay);
    return SampleFixtures.sampleProperties
        .where((item) => item.isActive)
        .toList(growable: false);
  }

  @override
  Future<List<Unit>> getUnits(String propertyId) async {
    await Future<void>.delayed(loadingDelay);
    return [
      ...SampleFixtures.sampleUnits.where(
        (item) => item.propertyId == propertyId,
      ),
      ..._extraUnits.where((item) => item.propertyId == propertyId),
    ]..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
  }

  @override
  Future<List<Tenant>> getTenants(String unitId) async {
    await Future<void>.delayed(loadingDelay);
    return SampleFixtures.sampleTenants
        .where((item) => item.unitId == unitId && item.isActive)
        .toList(growable: false);
  }

  @override
  Future<List<Complaint>> getComplaints({
    String? propertyId,
    String? unitId,
    String? tenantId,
  }) async {
    await Future<void>.delayed(loadingDelay);
    return SampleFixtures.sampleComplaints
        .where((item) {
          if (propertyId != null && item.propertyId != propertyId) return false;
          if (unitId != null && item.unitId != unitId) return false;
          if (tenantId != null && item.tenantId != tenantId) return false;
          return true;
        })
        .toList(growable: false);
  }
}

bool isOpenComplaint(Complaint complaint) => !{
  ComplaintStatus.resolved,
  ComplaintStatus.closed,
  ComplaintStatus.cancelled,
}.contains(complaint.status);
