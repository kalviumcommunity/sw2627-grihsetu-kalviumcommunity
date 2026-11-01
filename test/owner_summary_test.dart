import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/screens/dashboard/owner_summary_screen.dart';
import 'package:grihsetu/utils/owner_summary.dart';

void main() {
  group('OwnerSummary pure calculations', () {
    final now = DateTime(2026, 10, 15, 12, 0);

    const prop1 = Property(
      id: 'p1',
      name: 'Gulmohar Heights',
      address: '101 MG Road',
    );
    const prop2 = Property(
      id: 'p2',
      name: 'Lotus Residency',
      address: '202 Park Street',
    );

    final units = [
      const Unit(
        id: 'u1',
        propertyId: 'p1',
        unitNumber: '101',
        occupancyStatus: 'occupied',
      ),
      const Unit(
        id: 'u2',
        propertyId: 'p1',
        unitNumber: '102',
        occupancyStatus: 'occupied',
      ),
      const Unit(
        id: 'u3',
        propertyId: 'p2',
        unitNumber: '201',
        occupancyStatus: 'vacant',
      ),
    ];

    test('empty period handles zero data without crash or NaN', () {
      final summary = calculateOwnerSummary(
        properties: [prop1, prop2],
        units: units,
        complaints: const [],
        rentRecords: const [],
        periodDays: 30,
        now: now,
      );

      expect(summary.totalProperties, 2);
      expect(summary.totalUnits, 3);
      expect(summary.occupiedUnits, 2);
      expect(summary.occupancyRate, closeTo(66.67, 0.1));
      expect(summary.openComplaints, 0);
      expect(summary.resolvedInPeriod, 0);
      expect(summary.createdInPeriod, 0);
      expect(summary.slaPercent, isNull);
      expect(summary.avgFirstResponse, isNull);
      expect(summary.avgResolutionTime, isNull);
      expect(summary.totalRentDue, 0.0);
      expect(summary.collectionRate, 100.0);
      expect(summary.topProblemProperties, isEmpty);
      expect(summary.recurringIssues, isEmpty);
      expect(summary.technicianPerformance, isEmpty);
      expect(summary.highlights, isNotEmpty);
    });

    test(
      'period-over-period change computes correct deltas and directions',
      () {
        final complaints = <Complaint>[
          // Current 30-day window (2026-09-15 to 2026-10-15)
          Complaint(
            id: 'c1',
            propertyId: 'p1',
            unitId: 'u1',
            tenantId: 't1',
            createdBy: 't1',
            title: 'Leaky faucet',
            description: 'Water dripping',
            category: ComplaintCategory.plumbing,
            priority: ComplaintPriority.medium,
            status: ComplaintStatus.resolved,
            createdAt: now.subtract(const Duration(days: 10)),
            resolvedAt: now.subtract(const Duration(days: 8)),
            firstAssignedAt: now.subtract(const Duration(days: 9)),
          ),
          Complaint(
            id: 'c2',
            propertyId: 'p1',
            unitId: 'u1',
            tenantId: 't1',
            createdBy: 't1',
            title: 'Circuit breaker trip',
            description: 'Power cut',
            category: ComplaintCategory.electrical,
            priority: ComplaintPriority.high,
            status: ComplaintStatus.resolved,
            createdAt: now.subtract(const Duration(days: 5)),
            resolvedAt: now.subtract(const Duration(days: 3)),
            firstAssignedAt: now.subtract(const Duration(days: 4)),
          ),
          // Previous 30-day window (2026-08-16 to 2026-09-15)
          Complaint(
            id: 'c3',
            propertyId: 'p2',
            unitId: 'u3',
            tenantId: 't2',
            createdBy: 't2',
            title: 'AC cooling issue',
            description: 'Not cooling',
            category: ComplaintCategory.appliance,
            priority: ComplaintPriority.medium,
            status: ComplaintStatus.resolved,
            createdAt: now.subtract(const Duration(days: 40)),
            resolvedAt: now.subtract(const Duration(days: 35)),
            firstAssignedAt: now.subtract(const Duration(days: 38)),
          ),
        ];

        final rents = <RentRecord>[
          RentRecord(
            id: 'r1',
            propertyId: 'p1',
            unitId: 'u1',
            tenantId: 't1',
            amountDue: 25000,
            month: '2026-10',
            status: RentStatus.paid,
            dueDate: now.subtract(const Duration(days: 5)),
          ),
          RentRecord(
            id: 'r2',
            propertyId: 'p1',
            unitId: 'u2',
            tenantId: 't2',
            amountDue: 25000,
            month: '2026-10',
            status: RentStatus.overdue,
            dueDate: now.subtract(const Duration(days: 15)),
          ),
        ];

        final summary = calculateOwnerSummary(
          properties: [prop1, prop2],
          units: units,
          complaints: complaints,
          rentRecords: rents,
          periodDays: 30,
          now: now,
        );

        // Resolved in period: 2 current vs 1 previous -> +100%
        expect(summary.resolvedInPeriod, 2);
        expect(summary.resolvedDelta.current, 2.0);
        expect(summary.resolvedDelta.previous, 1.0);
        expect(summary.resolvedDelta.direction, ChangeDirection.better);

        // Rent collection: 25000 collected out of 50000 due -> 50%
        expect(summary.totalRentDue, 50000.0);
        expect(summary.totalRentCollected, 25000.0);
        expect(summary.collectionRate, 50.0);
        expect(summary.overdueRentCount, 1);
        expect(summary.overdueRentAmount, 25000.0);
      },
    );

    test(
      'highlight text templates produce coherent observations without AI',
      () {
        final summary = calculateOwnerSummary(
          properties: [prop1, prop2],
          units: units,
          complaints: const [],
          rentRecords: const [],
          periodDays: 30,
          now: now,
        );

        expect(summary.highlights, isNotEmpty);
        expect(
          summary.highlights.any((h) => h.toLowerCase().contains('occupancy')),
          isTrue,
        );
        expect(
          summary.highlights.any(
            (h) => h.toLowerCase().contains('0 open complaints'),
          ),
          isTrue,
        );
      },
    );

    test('plain text share format contains key portfolio metrics', () {
      final summary = calculateOwnerSummary(
        properties: [prop1, prop2],
        units: units,
        complaints: const [],
        rentRecords: const [],
        periodDays: 30,
        now: now,
      );

      final text = buildOwnerSummaryPlainText(summary);
      expect(text, contains('GRIHSETU PORTFOLIO OPERATIONAL SUMMARY'));
      expect(text, contains('Properties: 2'));
      expect(text, contains('Gulmohar Heights'));
      expect(text, contains('Lotus Residency'));
      expect(text, contains('Occupancy: 66.7%'));
      expect(text, contains('EXECUTIVE HIGHLIGHTS'));
    });
  });
}
