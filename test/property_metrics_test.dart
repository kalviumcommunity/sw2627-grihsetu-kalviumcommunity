import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/utils/property_metrics.dart';

void main() {
  group('PropertyMetrics', () {
    final now = DateTime(2026, 10, 15, 12, 0);

    const testProperty = Property(
      id: 'prop_test',
      name: 'Test Property',
      address: '123 Test St',
    );

    final sampleUnits = [
      const Unit(
        id: 'u1',
        propertyId: 'prop_test',
        unitNumber: '101',
        occupancyStatus: 'occupied',
      ),
      const Unit(
        id: 'u2',
        propertyId: 'prop_test',
        unitNumber: '102',
        occupancyStatus: 'occupied',
      ),
      const Unit(
        id: 'u3',
        propertyId: 'prop_test',
        unitNumber: '103',
        occupancyStatus: 'vacant',
      ),
    ];

    test(
      'empty period produces null averages, zero counts, and 100% health score',
      () {
        final summary = calculatePropertySummary(
          property: testProperty,
          units: sampleUnits,
          complaints: const [],
          rentRecords: const [],
          periodDays: 30,
          now: now,
        );

        expect(summary.totalUnits, 3);
        expect(summary.occupiedUnits, 2);
        expect(summary.openComplaints, 0);
        expect(summary.resolvedInPeriod, 0);
        expect(summary.createdInPeriod, 0);
        expect(summary.avgFirstResponse, isNull);
        expect(summary.avgResolutionTime, isNull);
        expect(summary.slaPercent, isNull);
        expect(summary.repeatVisits, 0);
        expect(summary.recurringIssues, 0);
        expect(summary.reopenedCount, 0);
        expect(summary.waitingForPartsCount, 0);
        expect(summary.unassignedCount, 0);
        expect(summary.overdueRentCount, 0);
        expect(summary.overdueRentAmount, 0.0);
        expect(summary.collectionRate, 100.0);
        expect(summary.trendBuckets.length, 6);
        expect(summary.trendBuckets.every((b) => b == 0), isTrue);
        expect(summary.healthScore, 1.0);
      },
    );

    test('boundary dates at period edges are correctly partitioned', () {
      final periodStart = now.subtract(const Duration(days: 30));

      final justBeforeStart = Complaint(
        id: 'c_before',
        tenantId: 't1',
        propertyId: 'prop_test',
        unitId: 'u1',
        title: 'Before window',
        description: 'Before',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.medium,
        status: ComplaintStatus.open,
        createdBy: 'usr_1',
        createdAt: periodStart.subtract(const Duration(minutes: 1)),
      );

      final exactlyAtStart = Complaint(
        id: 'c_start',
        tenantId: 't1',
        propertyId: 'prop_test',
        unitId: 'u1',
        title: 'At start window',
        description: 'At start',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.medium,
        status: ComplaintStatus.resolved,
        createdBy: 'usr_1',
        createdAt: periodStart,
        resolvedAt: periodStart.add(const Duration(hours: 2)),
      );

      final exactlyAtEnd = Complaint(
        id: 'c_end',
        tenantId: 't1',
        propertyId: 'prop_test',
        unitId: 'u1',
        title: 'At end window',
        description: 'At end',
        category: ComplaintCategory.electrical,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.open,
        createdBy: 'usr_1',
        createdAt: now,
      );

      final afterEnd = Complaint(
        id: 'c_after',
        tenantId: 't1',
        propertyId: 'prop_test',
        unitId: 'u1',
        title: 'After end window',
        description: 'After end',
        category: ComplaintCategory.electrical,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.open,
        createdBy: 'usr_1',
        createdAt: now.add(const Duration(minutes: 5)),
      );

      final summary = calculatePropertySummary(
        property: testProperty,
        units: sampleUnits,
        complaints: [justBeforeStart, exactlyAtStart, exactlyAtEnd, afterEnd],
        rentRecords: const [],
        periodDays: 30,
        now: now,
      );

      // exactlyAtStart and exactlyAtEnd were created in the 30-day window [periodStart, now]
      expect(summary.createdInPeriod, 2);
      // c_before, c_end, and c_after are all currently open
      expect(summary.openComplaints, 3);
    });

    test('SLA percentage math correctly counts within SLA vs breached', () {
      // Urgent: 24h SLA. High: 48h SLA.
      final c1WithinSla = Complaint(
        id: 'c1',
        tenantId: 't1',
        propertyId: 'prop_test',
        unitId: 'u1',
        title: 'Urgent within SLA',
        description: 'Fixed in 10h (SLA is 24h)',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.urgent,
        status: ComplaintStatus.resolved,
        createdBy: 'usr_1',
        createdAt: now.subtract(const Duration(days: 5)),
        resolvedAt: now
            .subtract(const Duration(days: 5))
            .add(const Duration(hours: 10)),
      );

      final c2WithinSla = Complaint(
        id: 'c2',
        tenantId: 't1',
        propertyId: 'prop_test',
        unitId: 'u1',
        title: 'High within SLA',
        description: 'Fixed in 30h (SLA is 48h)',
        category: ComplaintCategory.electrical,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.resolved,
        createdBy: 'usr_1',
        createdAt: now.subtract(const Duration(days: 4)),
        resolvedAt: now
            .subtract(const Duration(days: 4))
            .add(const Duration(hours: 30)),
      );

      final c3BreachedSla = Complaint(
        id: 'c3',
        tenantId: 't1',
        propertyId: 'prop_test',
        unitId: 'u1',
        title: 'Urgent breached SLA',
        description: 'Fixed in 36h (SLA is 24h)',
        category: ComplaintCategory.appliance,
        priority: ComplaintPriority.urgent,
        status: ComplaintStatus.resolved,
        createdBy: 'usr_1',
        createdAt: now.subtract(const Duration(days: 3)),
        resolvedAt: now
            .subtract(const Duration(days: 3))
            .add(const Duration(hours: 36)),
      );

      final summary = calculatePropertySummary(
        property: testProperty,
        units: sampleUnits,
        complaints: [c1WithinSla, c2WithinSla, c3BreachedSla],
        rentRecords: const [],
        periodDays: 30,
        now: now,
      );

      expect(summary.resolvedInPeriod, 3);
      // 2 out of 3 resolved within SLA => 66.7%
      expect(summary.slaPercent, closeTo(66.7, 0.1));
    });

    test('rent collection calculations correctly compute overdue and collection rate', () {
      final rent1 = RentRecord(
        id: 'r1',
        tenantId: 't1',
        propertyId: 'prop_test',
        unitId: 'u1',
        month: 'October 2026',
        amountDue: 20000.0,
        dueDate: now.subtract(const Duration(days: 5)),
        status: RentStatus.paid,
      );

      final rent2 = RentRecord(
        id: 'r2',
        tenantId: 't2',
        propertyId: 'prop_test',
        unitId: 'u2',
        month: 'October 2026',
        amountDue: 30000.0,
        dueDate: now.subtract(const Duration(days: 2)),
        status: RentStatus.overdue,
      );

      final summary = calculatePropertySummary(
        property: testProperty,
        units: sampleUnits,
        complaints: const [],
        rentRecords: [rent1, rent2],
        periodDays: 30,
        now: now,
      );

      expect(summary.overdueRentCount, 1);
      expect(summary.overdueRentAmount, 30000.0);
      // 20,000 paid out of 50,000 total = 40.0%
      expect(summary.collectionRate, 40.0);
    });
  });
}
