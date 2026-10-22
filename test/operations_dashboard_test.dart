import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/dashboard_repository.dart';
import 'package:grihsetu/screens/complaints/search/complaint_search_screen.dart';
import 'package:grihsetu/screens/dashboard/attention_card.dart';
import 'package:grihsetu/screens/dashboard/operations_dashboard_screen.dart';
import 'package:grihsetu/utils/attention_rules.dart';
import 'package:grihsetu/utils/dashboard_metrics.dart';

void main() {
  final testNow = DateTime(2026, 10, 21, 14, 0);

  Complaint createComplaint({
    required String id,
    ComplaintStatus status = ComplaintStatus.open,
    ComplaintPriority priority = ComplaintPriority.medium,
    ComplaintCategory category = ComplaintCategory.plumbing,
    String? technicianId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    int visitCount = 0,
    String propertyId = 'prop_001',
    String unitId = 'unit_101',
  }) {
    final created = createdAt ?? testNow.subtract(const Duration(hours: 5));
    return Complaint(
      id: id,
      title: 'Complaint $id',
      description: 'Description for $id',
      category: category,
      priority: priority,
      status: status,
      currentTechnicianId: technicianId,
      createdBy: 'usr_001',
      createdAt: created,
      updatedAt: updatedAt ?? created,
      resolvedAt: resolvedAt,
      visitCount: visitCount,
      propertyId: propertyId,
      unitId: unitId,
      tenantId: 'ten_001',
    );
  }

  RentRecord createRentRecord({
    required String id,
    RentStatus status = RentStatus.overdue,
    double amount = 20000,
    DateTime? dueDate,
  }) {
    return RentRecord(
      id: id,
      tenantId: 'ten_001',
      propertyId: 'prop_001',
      unitId: 'unit_101',
      month: 'October 2026',
      amountDue: amount,
      dueDate: dueDate ?? testNow.subtract(const Duration(days: 10)),
      status: status,
    );
  }

  group('Operations Dashboard - GRIH-038 Tests', () {
    // -------------------------------------------------------------------------
    // TEST 1: attention_rules triggers and boundaries
    // -------------------------------------------------------------------------
    test('1. attention_rules triggers and boundary conditions', () {
      // Boundary 1: Unassigned at <= 3h is NOT included (groups with 0 are hidden)
      final cRecent = createComplaint(
        id: 'c_recent',
        createdAt: testNow.subtract(const Duration(hours: 3)),
        status: ComplaintStatus.open,
        technicianId: null,
      );
      final analysisRecent = analyzeAttention(
        complaints: [cRecent],
        rentRecords: [],
        now: testNow,
      );
      expect(
        analysisRecent.items.any((i) => i.type == AttentionType.unassigned),
        isFalse,
        reason: 'Unassigned < 4h must not be in attention items',
      );

      // Boundary 2: Unassigned at 5h (> 4h) is AMBER
      final cAmber = createComplaint(
        id: 'c_amber',
        createdAt: testNow.subtract(const Duration(hours: 5)),
        status: ComplaintStatus.open,
        technicianId: null,
      );
      final analysisAmber = analyzeAttention(
        complaints: [cAmber],
        rentRecords: [],
        now: testNow,
      );
      final itemAmber = analysisAmber.items.firstWhere(
        (i) => i.type == AttentionType.unassigned,
      );
      expect(itemAmber.severity, AttentionSeverity.amber);
      expect(itemAmber.count, 1);

      // Boundary 3: Unassigned at 25h (> 24h) is URGENT
      final cUrgent = createComplaint(
        id: 'c_urgent',
        createdAt: testNow.subtract(const Duration(hours: 25)),
        status: ComplaintStatus.open,
        technicianId: null,
      );
      final analysisUrgent = analyzeAttention(
        complaints: [cUrgent],
        rentRecords: [],
        now: testNow,
      );
      final itemUrgent = analysisUrgent.items.firstWhere(
        (i) => i.type == AttentionType.unassigned,
      );
      expect(itemUrgent.severity, AttentionSeverity.urgent);
      expect(itemUrgent.count, 1);

      // Overdue rent trigger
      final rentOverdue = createRentRecord(
        id: 'r_1',
        status: RentStatus.overdue,
      );
      final analysisRent = analyzeAttention(
        complaints: [],
        rentRecords: [rentOverdue],
        now: testNow,
      );
      expect(analysisRent.items.length, 1);
      final rentItem = analysisRent.items.first;
      expect(rentItem.type, AttentionType.overdueRent);
      expect(rentItem.severity, AttentionSeverity.urgent);
      expect(rentItem.count, 1);
      expect(rentItem.subtitle, contains('20,000'));
    });

    // -------------------------------------------------------------------------
    // TEST 2: Ordering by severity then age
    // -------------------------------------------------------------------------
    test('2. ordering by severity then age', () {
      // Create:
      // - an urgent item aged 10h (e.g. reopened complaint 10h ago)
      // - an urgent item aged 30h (e.g. unassigned 30h ago)
      // - an amber item aged 50h (e.g. waiting for parts 50h ago)
      // - an amber item aged 6h (e.g. unassigned 6h ago)
      final cReopened = createComplaint(
        id: 'c_reopened',
        status: ComplaintStatus.reopened,
        updatedAt: testNow.subtract(const Duration(hours: 10)),
      );
      final cUnassignedUrgent = createComplaint(
        id: 'c_unassigned_urgent',
        status: ComplaintStatus.open,
        technicianId: null,
        createdAt: testNow.subtract(const Duration(hours: 30)),
      );
      final cPartsAmber = createComplaint(
        id: 'c_parts_amber',
        status: ComplaintStatus.waitingForParts,
        updatedAt: testNow.subtract(const Duration(hours: 50)),
      );
      final cUnassignedAmber = createComplaint(
        id: 'c_unassigned_amber',
        status: ComplaintStatus.open,
        technicianId: null,
        createdAt: testNow.subtract(const Duration(hours: 6)),
      );

      final analysis = analyzeAttention(
        complaints: [
          cPartsAmber,
          cUnassignedAmber,
          cReopened,
          cUnassignedUrgent,
        ],
        rentRecords: [],
        now: testNow,
      );

      // All urgent items must precede amber items
      final severities = analysis.items.map((i) => i.severity).toList();
      final firstAmberIndex = severities.indexOf(AttentionSeverity.amber);
      final lastUrgentIndex = severities.lastIndexOf(AttentionSeverity.urgent);

      expect(
        lastUrgentIndex < firstAmberIndex,
        isTrue,
        reason: 'All urgent items must be ordered before amber items',
      );

      // Within urgent items: oldest age (cUnassignedUrgent: 30h) before newer (cReopened: 10h)
      final urgentItems = analysis.items
          .where((i) => i.severity == AttentionSeverity.urgent)
          .toList();
      for (int i = 0; i < urgentItems.length - 1; i++) {
        expect(
          urgentItems[i].oldestAge >= urgentItems[i + 1].oldestAge,
          isTrue,
        );
      }

      // Within amber items: oldest age (cPartsAmber: 50h) before newer (cUnassignedAmber: 6h)
      final amberItems = analysis.items
          .where((i) => i.severity == AttentionSeverity.amber)
          .toList();
      for (int i = 0; i < amberItems.length - 1; i++) {
        expect(amberItems[i].oldestAge >= amberItems[i + 1].oldestAge, isTrue);
      }
    });

    // -------------------------------------------------------------------------
    // TEST 3: dashboard_metrics
    // -------------------------------------------------------------------------
    test('3. dashboard_metrics calculation', () {
      final startOfToday = DateTime(testNow.year, testNow.month, testNow.day);

      final c1 = createComplaint(
        id: 'c_open_1',
        status: ComplaintStatus.open,
        createdAt: testNow.subtract(const Duration(hours: 4)),
      );
      final c2 = createComplaint(
        id: 'c_open_2',
        status: ComplaintStatus.inProgress,
        createdAt: testNow.subtract(const Duration(hours: 3)),
        updatedAt: testNow.subtract(const Duration(hours: 2)),
      );
      final cResolvedToday = createComplaint(
        id: 'c_res_today',
        status: ComplaintStatus.resolved,
        createdAt: testNow.subtract(const Duration(hours: 6)),
        updatedAt: testNow.subtract(const Duration(hours: 1)),
        resolvedAt: startOfToday.add(const Duration(hours: 2)),
      );

      final metrics = calculateTodayMetrics(
        complaints: [c1, c2, cResolvedToday],
        now: testNow,
      );

      expect(metrics.open.value, '2'); // c1 and c2 are open/inProgress
      expect(metrics.resolvedToday.value, '1'); // cResolvedToday
      expect(metrics.slaPercent.value, '100%'); // 1/1 resolved within expected
      expect(metrics.avgFirstResponse.value.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 4: The all-clear state when there is nothing to show
    // -------------------------------------------------------------------------
    testWidgets('4. the all-clear state when there is nothing to show', (
      tester,
    ) async {
      final customSnapshot = DashboardSnapshot(
        complaints: [],
        rentRecords: [],
        technicians: [],
        properties: [],
        events: [],
        lastUpdated: testNow,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OperationsDashboardScreen(
            dashboardRepository: _MockDashboardRepository(customSnapshot),
            referenceNow: testNow,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header summary
      expect(find.text('All clear. Nothing needs attention.'), findsOneWidget);
      // Check All clear card
      expect(find.text('All clear'), findsOneWidget);
      expect(
        find.text('Nothing needs immediate human intervention.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 5: Tapping an attention card opens search screen with the right filter
    // -------------------------------------------------------------------------
    testWidgets(
      '5. tapping an attention card opens search screen with the right initial filter',
      (tester) async {
        // Create an unassigned complaint aged 6 hours
        final unassignedComplaint = createComplaint(
          id: 'cmp_unassigned',
          status: ComplaintStatus.open,
          technicianId: null,
          createdAt: testNow.subtract(const Duration(hours: 6)),
        );

        final snapshot = DashboardSnapshot(
          complaints: [unassignedComplaint],
          rentRecords: [],
          technicians: [],
          properties: [],
          events: [],
          lastUpdated: testNow,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: OperationsDashboardScreen(
              dashboardRepository: _MockDashboardRepository(snapshot),
              complaintRepository: InMemoryComplaintRepository(),
              referenceNow: testNow,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify AttentionCard is displayed
        final attentionCardFinder = find.widgetWithText(
          AttentionCard,
          'Unassigned complaints',
        );
        expect(attentionCardFinder, findsOneWidget);

        // Tap the card
        await tester.tap(attentionCardFinder);
        await tester.pumpAndSettle();

        // Verify ComplaintSearchScreen is pushed
        expect(find.byType(ComplaintSearchScreen), findsOneWidget);
        final searchWidget = tester.widget<ComplaintSearchScreen>(
          find.byType(ComplaintSearchScreen),
        );

        // Verify the pre-filtered initial filter
        expect(searchWidget.initial, isNotNull);
        expect(searchWidget.initial!.statuses, contains(ComplaintStatus.open));
        expect(searchWidget.initial!.technicianId, 'unassigned');
      },
    );
  });
}

class _MockDashboardRepository implements DashboardRepository {
  final DashboardSnapshot snapshot;

  _MockDashboardRepository(this.snapshot);

  @override
  Future<DashboardSnapshot> load({DateTime? now}) async {
    return snapshot;
  }
}
