import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_audit_event_type.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/maintenance_visit_outcome.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/fixtures/sample_fixtures.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/property_repository.dart';
import 'package:grihsetu/repositories/rent_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_view_models.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/services/reference_data_seed_service.dart';

void main() {
  group('GRIH-048 Deterministic Demo Dataset Tests', () {
    // 1. Demo property Green Heights and Unit A-204
    test('1. Demo dataset contains Green Heights property and Unit A-204', () {
      final greenHeights = SampleFixtures.sampleProperties.firstWhere(
        (p) => p.name == 'Green Heights',
        orElse: () => throw StateError('Green Heights property not found'),
      );
      expect(greenHeights.id, 'prop_003');
      expect(greenHeights.address, contains('Gurugram'));
      expect(greenHeights.isActive, isTrue);

      final unitA204 = SampleFixtures.sampleUnits.firstWhere(
        (u) => u.propertyId == greenHeights.id && u.unitNumber == 'A-204',
        orElse: () => throw StateError('Unit A-204 not found in Green Heights'),
      );
      expect(unitA204.id, 'unit_gh_204');
      expect(unitA204.floor, 2);
      expect(unitA204.occupancyStatus, 'occupied');
    });

    // 2. Unit is linked to intended property and tenant
    test('2. Unit A-204 is linked to Green Heights and assigned tenant', () {
      final unit = SampleFixtures.demoUnitA204;
      final property = SampleFixtures.demoGreenHeights;
      final tenant = SampleFixtures.demoTenant;

      expect(unit.propertyId, property.id);
      expect(unit.tenantId, tenant.id);
      expect(tenant.propertyId, property.id);
      expect(tenant.unitId, unit.id);
      expect(tenant.name, 'Kabir Mehta');
      expect(tenant.phone, isNotEmpty);
      expect(tenant.isActive, isTrue);
    });

    // 3. Three internal roles exist using canonical UserRole definitions
    test(
      '3. Three internal staff roles exist using canonical UserRole enums',
      () {
        final users = SampleFixtures.sampleUsers;
        expect(users.length, greaterThanOrEqualTo(3));

        final propOps = users.firstWhere(
          (u) => u.role == UserRole.propertyOperations,
        );
        expect(propOps.role?.value, 'property_operations');
        expect(propOps.isAuthorized, isTrue);
        expect(propOps.name, 'Vikram Malhotra');

        final complaintOps = users.firstWhere(
          (u) => u.role == UserRole.complaintOperations,
        );
        expect(complaintOps.role?.value, 'complaint_operations');
        expect(complaintOps.isAuthorized, isTrue);
        expect(complaintOps.name, 'Riya Sharma');

        final technician = users.firstWhere(
          (u) => u.role == UserRole.technician,
        );
        expect(technician.role?.value, 'technician');
        expect(technician.isAuthorized, isTrue);
        expect(technician.name, 'Aman Verma');

        // Verify domain helper methods
        expect(propOps.role?.isOperationsStaff, isTrue);
        expect(complaintOps.role?.isOperationsStaff, isTrue);
        expect(technician.role?.isOperationsStaff, isFalse);
        expect(technician.role?.isTechnician, isTrue);
      },
    );

    // 4. Complaint relationships point to valid tenant/property/unit records
    test('4. Demo complaints reference valid property, unit, tenant, and technician', () {
      final propertyIds = SampleFixtures.sampleProperties
          .map((p) => p.id)
          .toSet();
      final unitMap = {for (final u in SampleFixtures.sampleUnits) u.id: u};
      final tenantMap = {for (final t in SampleFixtures.sampleTenants) t.id: t};
      final technicianIds = SampleFixtures.sampleUsers
          .where((u) => u.role == UserRole.technician)
          .map((u) => u.id)
          .toSet();

      final demoComplaints = SampleFixtures.sampleComplaints.where(
        (c) => c.propertyId == 'prop_003',
      );
      expect(demoComplaints, isNotEmpty);

      for (final c in demoComplaints) {
        expect(
          propertyIds.contains(c.propertyId),
          isTrue,
          reason: 'Complaint ${c.id} propertyId ${c.propertyId} must exist',
        );
        expect(
          unitMap.containsKey(c.unitId),
          isTrue,
          reason: 'Complaint ${c.id} unitId ${c.unitId} must exist',
        );
        expect(
          unitMap[c.unitId]?.propertyId,
          c.propertyId,
          reason: 'Unit ${c.unitId} must belong to property ${c.propertyId}',
        );
        expect(
          tenantMap.containsKey(c.tenantId),
          isTrue,
          reason: 'Complaint ${c.id} tenantId ${c.tenantId} must exist',
        );
        expect(
          tenantMap[c.tenantId]?.propertyId,
          c.propertyId,
          reason:
              'Tenant ${c.tenantId} must belong to property ${c.propertyId}',
        );
        expect(
          tenantMap[c.tenantId]?.unitId,
          c.unitId,
          reason: 'Tenant ${c.tenantId} must be assigned to unit ${c.unitId}',
        );

        if (c.currentTechnicianId != null) {
          expect(
            technicianIds.contains(c.currentTechnicianId),
            isTrue,
            reason:
                'Technician ${c.currentTechnicianId} must be a valid technician',
          );
        }
      }
    });

    // 5. Repeat-visit or reopened complaint scenario
    test('5. Demo contains consistent repeat-visit and reopened complaint scenario', () {
      final complaint = SampleFixtures.demoReopenedComplaint;

      expect(complaint.propertyId, 'prop_003');
      expect(complaint.unitId, 'unit_gh_204');
      expect(complaint.tenantId, 'ten_004');
      expect(complaint.status, ComplaintStatus.reopened);
      expect(complaint.visitCount, 2);
      expect(complaint.isRepeatVisit, isTrue);
      expect(complaint.reopenCount, 1);
      expect(complaint.reopenReason, isNotNull);
      expect(complaint.reopenReason, contains('Recurring leakage'));

      // Check chronological consistency
      expect(complaint.createdAt, isNotNull);
      expect(complaint.firstAssignedAt, isNotNull);
      expect(complaint.resolvedAt, isNotNull);
      expect(complaint.closedAt, isNotNull);
      expect(complaint.reopenedAt, isNotNull);

      expect(complaint.firstAssignedAt!.isAfter(complaint.createdAt!), isTrue);
      expect(complaint.resolvedAt!.isAfter(complaint.firstAssignedAt!), isTrue);
      expect(complaint.closedAt!.isAfter(complaint.resolvedAt!), isTrue);
      expect(complaint.reopenedAt!.isAfter(complaint.closedAt!), isTrue);

      // Verify maintenance visit history in InMemoryComplaintRepository
      final repo = InMemoryComplaintRepository();
      final visits = repo.loadMaintenanceVisits(complaint.id);
      expect(visits, completion(hasLength(2)));

      // Verify visit details
      final visitsList = SampleFixtures.sampleMaintenanceVisits
          .where((v) => v.complaintId == complaint.id)
          .toList();
      expect(visitsList.length, 2);

      final visit1 = visitsList[0];
      expect(visit1.visitNumber, 1);
      expect(visit1.outcome, MaintenanceVisitOutcome.waitingForParts);
      expect(visit1.isResolved, isFalse);
      expect(visit1.followUpRequired, isTrue);

      final visit2 = visitsList[1];
      expect(visit2.visitNumber, 2);
      expect(visit2.outcome, MaintenanceVisitOutcome.resolved);
      expect(visit2.isResolved, isTrue);
      expect(visit2.followUpRequired, isFalse);

      // Verify timeline audit events include reopened
      final auditEvents = repo.loadAuditEvents(complaint.id);
      expect(
        auditEvents,
        completion(
          contains(
            predicate<dynamic>(
              (e) => e.eventType == ComplaintAuditEventType.complaintReopened,
            ),
          ),
        ),
      );
    });

    // 6. Rent record with linked follow-up history entry
    test('6. Rent record for Green Heights A-204 has linked follow-up history entry', () async {
      final rentRecord = SampleFixtures.demoRentRecord;

      expect(rentRecord.propertyId, 'prop_003');
      expect(rentRecord.unitId, 'unit_gh_204');
      expect(rentRecord.tenantId, 'ten_004');
      expect(rentRecord.month, 'October 2026');
      expect(rentRecord.amountDue, 35000.0);
      expect(rentRecord.status, RentStatus.promised);
      expect(rentRecord.lastFollowUpAt, isNotNull);
      expect(rentRecord.nextFollowUpAt, isNotNull);

      // Verify in-memory repository integration
      final rentRepo = InMemoryRentRepository(simulatedDelay: Duration.zero);
      final item = await rentRepo.get(rentRecord.id);

      expect(item, isNotNull);
      expect(item!.property.name, 'Green Heights');
      expect(item.unit.unitNumber, 'A-204');
      expect(item.tenant.name, 'Kabir Mehta');
      expect(item.followUps, isNotEmpty);

      final followUp = item.followUps.first;
      expect(followUp.rentRecordId, rentRecord.id);
      expect(followUp.outcome, FollowUpOutcome.promisedToPay);
      expect(followUp.actor, 'Vikram Malhotra');
      expect(followUp.promisedAmount, 35000.0);
      expect(followUp.promisedDate, DateTime(2026, 10, 8));
      expect(followUp.note, contains('Kabir Mehta'));
    });

    // 7. Stable IDs and idempotent relational validation
    test(
      '7. Fixture IDs are stable, unique, and pass relationship validation',
      () {
        // Validate unique IDs within each entity list
        final propIds = SampleFixtures.sampleProperties
            .map((p) => p.id)
            .toList();
        expect(
          propIds.toSet().length,
          propIds.length,
          reason: 'Duplicate property IDs',
        );

        final unitIds = SampleFixtures.sampleUnits.map((u) => u.id).toList();
        expect(
          unitIds.toSet().length,
          unitIds.length,
          reason: 'Duplicate unit IDs',
        );

        final tenantIds = SampleFixtures.sampleTenants
            .map((t) => t.id)
            .toList();
        expect(
          tenantIds.toSet().length,
          tenantIds.length,
          reason: 'Duplicate tenant IDs',
        );

        final complaintIds = SampleFixtures.sampleComplaints
            .map((c) => c.id)
            .toList();
        expect(
          complaintIds.toSet().length,
          complaintIds.length,
          reason: 'Duplicate complaint IDs',
        );

        final rentIds = SampleFixtures.sampleRentRecords
            .map((r) => r.id)
            .toList();
        expect(
          rentIds.toSet().length,
          rentIds.length,
          reason: 'Duplicate rent IDs',
        );

        // ReferenceDataSeedService relationship validator must pass with zero errors
        final relationshipErrors =
            ReferenceDataSeedService.validateRelationships(
              properties: SampleFixtures.sampleProperties,
              units: SampleFixtures.sampleUnits,
              tenants: SampleFixtures.sampleTenants,
            );
        expect(
          relationshipErrors,
          isEmpty,
          reason: 'Relational consistency failed',
        );
      },
    );

    // 8. Compatibility with existing fixture consumers
    test('8. Existing fixture consumers and resolvers remain compatible', () {
      // First items in collections remain unchanged for existing tests
      expect(SampleFixtures.sampleProperties.first.id, 'prop_001');
      expect(SampleFixtures.sampleProperties.first.name, 'Shanti Heights');
      expect(SampleFixtures.sampleUnits.first.id, 'unit_101');
      expect(SampleFixtures.sampleUnits.first.unitNumber, 'A-101');
      expect(SampleFixtures.sampleTenants.first.id, 'ten_001');
      expect(SampleFixtures.sampleTenants.first.name, 'Priya Patel');
      expect(SampleFixtures.sampleComplaints.first.id, 'cmp_1001');
      expect(SampleFixtures.sampleRentRecords.first.id, 'rnt_3001');

      // ComplaintReferenceResolver resolves Green Heights and A-204
      final resolver = ComplaintReferenceResolver();
      expect(resolver.getPropertyName('prop_003'), 'Green Heights');
      expect(resolver.getUnitNumber('unit_gh_204'), 'A-204');

      // InMemoryPropertyRepository exposes Green Heights and A-204
      final propRepo = InMemoryPropertyRepository(loadingDelay: Duration.zero);
      expect(
        propRepo.getProperties().then((list) => list.map((p) => p.name)),
        completion(contains('Green Heights')),
      );
      expect(
        propRepo
            .getUnits('prop_003')
            .then((list) => list.map((u) => u.unitNumber)),
        completion(contains('A-204')),
      );
      expect(
        propRepo
            .getTenants('unit_gh_204')
            .then((list) => list.map((t) => t.name)),
        completion(contains('Kabir Mehta')),
      );
    });
  });
}
