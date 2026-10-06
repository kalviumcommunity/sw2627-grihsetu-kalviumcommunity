import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/constants/constants.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/fixtures/sample_fixtures.dart';
import 'package:grihsetu/core/models/models.dart';

void main() {
  group('Complaint Model Tests', () {
    test('creates Complaint instance and maps to/from map correctly', () {
      final now = DateTime(2026, 10, 6, 12, 0);
      final complaint = Complaint(
        id: 'cmp_1',
        tenantId: 'ten_1',
        propertyId: 'prop_1',
        unitId: 'unit_1',
        title: 'Water leak',
        description: 'Bathroom pipe leakage',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.inProgress,
        visitCount: 2,
        createdBy: 'usr_ops',
        createdAt: now,
      );

      expect(complaint.isRepeatVisit, isTrue); // visitCount > 1
      expect(complaint.status.isUnresolved, isTrue);

      final map = complaint.toMap();
      expect(map['category'], 'plumbing');
      expect(map['priority'], 'high');
      expect(map['status'], 'in_progress');
      expect(map['isRepeatVisit'], isTrue);

      final restored = Complaint.fromMap(map, id: 'cmp_1');
      expect(restored.id, 'cmp_1');
      expect(restored.category, ComplaintCategory.plumbing);
      expect(restored.priority, ComplaintPriority.high);
      expect(restored.status, ComplaintStatus.inProgress);
      expect(restored.isRepeatVisit, isTrue);
    });
  });

  group('AppUser Model Tests', () {
    test('creates AppUser instance and maps to/from map correctly', () {
      final now = DateTime(2026, 1, 15);
      final user = AppUser(
        id: 'usr_1',
        name: 'Riya Sharma',
        email: 'riya@grihsetu.com',
        role: UserRole.complaintOperations,
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['role'], 'complaint_operations');

      final restored = AppUser.fromMap(map);
      expect(restored.id, 'usr_1');
      expect(restored.role, UserRole.complaintOperations);
      expect(restored.role.isOperationsStaff, isTrue);
    });
  });

  group('RentRecord Model Tests', () {
    test('creates RentRecord and verifies serialization', () {
      final dueDate = DateTime(2026, 10, 5);
      final rentRecord = RentRecord(
        id: 'rent_1',
        tenantId: 'ten_1',
        propertyId: 'prop_1',
        unitId: 'unit_1',
        month: 'October 2026',
        amountDue: 25000.0,
        dueDate: dueDate,
        status: RentStatus.overdue,
      );

      expect(rentRecord.status.isOverdue, isTrue);
      final map = rentRecord.toMap();
      expect(map['status'], 'overdue');

      final restored = RentRecord.fromMap(map);
      expect(restored.status, RentStatus.overdue);
      expect(restored.amountDue, 25000.0);
    });
  });

  group('Constants & Collections Tests', () {
    test('contains expected Firestore collections from PRD Section 16', () {
      expect(FirestoreCollections.users, 'users');
      expect(FirestoreCollections.complaints, 'complaints');
      expect(FirestoreCollections.properties, 'properties');
      expect(FirestoreCollections.units, 'units');
      expect(FirestoreCollections.tenants, 'tenants');
      expect(FirestoreCollections.maintenanceVisits, 'maintenance_visits');
      expect(
        FirestoreCollections.technicianAssignments,
        'technician_assignments',
      );
      expect(FirestoreCollections.auditEvents, 'audit_events');
      expect(FirestoreCollections.rentRecords, 'rent_records');
      expect(FirestoreCollections.rentFollowUps, 'rent_follow_ups');
    });

    test('AppConstants has proper configuration', () {
      expect(AppConstants.appName, 'GrihSetu');
      expect(AppConstants.repeatVisitThreshold, 1);
    });
  });

  group('Sample Fixtures Tests', () {
    test('fixtures are properly instantiated and non-empty', () {
      expect(SampleFixtures.sampleUsers, isNotEmpty);
      expect(SampleFixtures.sampleProperties, isNotEmpty);
      expect(SampleFixtures.sampleUnits, isNotEmpty);
      expect(SampleFixtures.sampleTenants, isNotEmpty);
      expect(SampleFixtures.sampleComplaints, isNotEmpty);
      expect(SampleFixtures.sampleRentRecords, isNotEmpty);
    });

    test('sample complaints contain repeat visit test case', () {
      final repeatComplaint = SampleFixtures.sampleComplaints.firstWhere(
        (c) => c.isRepeatVisit,
      );
      expect(repeatComplaint.visitCount, greaterThan(1));
    });
  });
}
