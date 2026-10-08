import '../../core/models/property.dart';
import '../../core/models/tenant.dart';
import '../../repositories/property_repository.dart';

/// UI-only supplemental fields absent from the persisted domain entities.
class TenantBrowseData {
  const TenantBrowseData({
    required this.tenant,
    required this.leaseStart,
    required this.isPrimary,
    required this.recentComplaints,
  });

  final Tenant tenant;
  final DateTime leaseStart;
  final bool isPrimary;
  final int recentComplaints;
}

class PropertyBrowseData {
  const PropertyBrowseData({
    required this.property,
    required this.locality,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.openComplaints,
    required this.units,
  });

  final Property property;
  final String locality;
  final int totalUnits;
  final int occupiedUnits;
  final int openComplaints;
  final List<UnitBrowseData> units;
}

class UnitBrowseData {
  const UnitBrowseData({
    required this.unit,
    required this.tenants,
    required this.openComplaints,
    required this.repeatComplaints,
  });

  final Unit unit;
  final List<TenantBrowseData> tenants;
  final int openComplaints;
  final int repeatComplaints;

  bool get isOccupied =>
      unit.occupancyStatus.toLowerCase() == 'occupied' && unit.tenantId != null;
  String get residentLabel => tenants.isEmpty
      ? 'Vacant'
      : tenants.map((item) => item.tenant.name).join(', ');
}

Future<List<PropertyBrowseData>> loadPropertyDirectory(
  PropertyRepository repository,
) async {
  final properties = await repository.getProperties();
  final entries = await Future.wait(
    properties.map((property) async {
      final unitsFuture = repository.getUnits(property.id);
      final complaintsFuture = repository.getComplaints(
        propertyId: property.id,
      );
      final units = await unitsFuture;
      final complaints = await complaintsFuture;
      final unitEntries = await Future.wait(
        units.map((unit) async {
          final tenantsFuture = repository.getTenants(unit.id);
          final unitComplaintsFuture = repository.getComplaints(
            unitId: unit.id,
          );
          final tenants = await tenantsFuture;
          final unitComplaints = await unitComplaintsFuture;
          final tenantData = tenants
              .asMap()
              .entries
              .map((entry) {
                final tenant = entry.value;
                final complaintsForTenant = unitComplaints
                    .where((item) => item.tenantId == tenant.id)
                    .toList();
                return TenantBrowseData(
                  tenant: tenant,
                  leaseStart: DateTime(2025, 1 + (entry.key % 12), 1),
                  isPrimary: entry.key == 0,
                  recentComplaints: complaintsForTenant
                      .where(
                        (item) => item.createdAt.isAfter(
                          DateTime.now().subtract(const Duration(days: 90)),
                        ),
                      )
                      .length,
                );
              })
              .toList(growable: false);
          return UnitBrowseData(
            unit: unit,
            tenants: tenantData,
            openComplaints: unitComplaints.where(isOpenComplaint).length,
            repeatComplaints: unitComplaints
                .where((item) => item.isRepeatVisit)
                .length,
          );
        }),
      );
      final addressParts = property.address
          .split(',')
          .map((part) => part.trim())
          .toList();
      final locality = addressParts.length > 1
          ? addressParts.skip(1).join(', ')
          : property.address;
      return PropertyBrowseData(
        property: property,
        locality: locality,
        totalUnits: units.length,
        occupiedUnits: units
            .where(
              (unit) =>
                  unit.occupancyStatus.toLowerCase() == 'occupied' &&
                  unit.tenantId != null,
            )
            .length,
        openComplaints: complaints.where(isOpenComplaint).length,
        units: unitEntries,
      );
    }),
  );
  return entries;
}

T? firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
