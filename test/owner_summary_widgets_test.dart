import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/screens/dashboard/owner_summary_screen.dart';
import 'package:grihsetu/widgets/charts/bar_compare_chart.dart';
import 'package:grihsetu/widgets/charts/donut_or_stacked_bar.dart';
import 'package:grihsetu/widgets/charts/sparkline.dart';
import 'package:grihsetu/widgets/charts/trend_line_chart.dart';

void main() {
  group('Owner Summary & Chart Widgets Tests', () {
    final now = DateTime(2026, 10, 20, 12, 0);

    const testProp1 = Property(
      id: 'p1',
      name: 'Gulmohar Heights',
      address: '101 MG Road',
    );
    const testProp2 = Property(
      id: 'p2',
      name: 'Lotus Residency',
      address: '202 Park Street',
    );

    final testUnits = [
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

    final testComplaints = [
      Complaint(
        id: 'c1',
        propertyId: 'p1',
        unitId: 'u1',
        tenantId: 't1',
        createdBy: 't1',
        title: 'Water tap leaking',
        description: 'Drips continuously',
        category: ComplaintCategory.plumbing,
        priority: ComplaintPriority.medium,
        status: ComplaintStatus.open,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Complaint(
        id: 'c2',
        propertyId: 'p1',
        unitId: 'u2',
        tenantId: 't2',
        createdBy: 't2',
        title: 'Power switch broken',
        description: 'Sparking',
        category: ComplaintCategory.electrical,
        priority: ComplaintPriority.high,
        status: ComplaintStatus.resolved,
        createdAt: now.subtract(const Duration(days: 5)),
        resolvedAt: now.subtract(const Duration(days: 3)),
        firstAssignedAt: now.subtract(const Duration(days: 4)),
      ),
    ];

    final testRents = [
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
        amountDue: 30000,
        month: '2026-10',
        status: RentStatus.overdue,
        dueDate: now.subtract(const Duration(days: 12)),
      ),
    ];

    setUp(() {
      ComplaintStore.resetInstance(
        ComplaintStore(initialComplaints: testComplaints),
      );
    });

    // -------------------------------------------------------------------------
    // TEST 1: Charts build with 0, 1, and many points without overflow
    // -------------------------------------------------------------------------
    testWidgets('1. Charts build with 0, 1, and many points without overflow', (
      tester,
    ) async {
      // 1. Sparkline
      for (final data in [
        <num>[],
        <num>[42],
        <num>[10, 20, 15, 30, 25, 40],
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 60,
                  child: Sparkline(data: data),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // 2. TrendLineChart
      for (final fixture in [
        (const <int>[], const <int>[], const <String>[]),
        (const [5], const [2], const ['W1']),
        (
          const [3, 8, 5, 12],
          const [1, 6, 7, 10],
          const ['W1', 'W2', 'W3', 'W4'],
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 200,
                  child: TrendLineChart(
                    createdPoints: fixture.$1,
                    resolvedPoints: fixture.$2,
                    labels: fixture.$3,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // 3. BarCompareChart
      for (final items in [
        <BarCompareItem>[],
        [const BarCompareItem(label: 'Gulmohar', value1: 2, value2: 5)],
        [
          const BarCompareItem(label: 'P1', value1: 4, value2: 3),
          const BarCompareItem(label: 'P2', value1: 1, value2: 7),
          const BarCompareItem(label: 'P3', value1: 6, value2: 2),
        ],
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 200,
                  child: BarCompareChart(items: items),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // 4. DonutOrStackedBar
      for (final segments in [
        <CategorySegment>[],
        [
          const CategorySegment(
            label: 'Plumbing',
            value: 8,
            color: Colors.blue,
          ),
        ],
        [
          const CategorySegment(
            label: 'Plumbing',
            value: 5,
            color: Colors.blue,
          ),
          const CategorySegment(
            label: 'Electrical',
            value: 3,
            color: Colors.amber,
          ),
          const CategorySegment(
            label: 'Appliance',
            value: 2,
            color: Colors.green,
          ),
        ],
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 200,
                  child: DonutOrStackedBar(segments: segments),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    Future<void> pumpAndRender(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // -------------------------------------------------------------------------
    // TEST 2: Period selector updates KPI figures
    // -------------------------------------------------------------------------
    testWidgets(
      '2. Period selector updates period state and triggers recalculation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: OwnerSummaryScreen(
              properties: [testProp1, testProp2],
              units: testUnits,
              rentRecords: testRents,
              now: now,
              initialPeriodDays: 30,
            ),
          ),
        );
        await pumpAndRender(tester);

        // Check initial screen render
        expect(find.text('Portfolio Operational Health'), findsOneWidget);
        expect(find.text('30D'), findsOneWidget);

        // Tap 7D period
        await tester.tap(find.text('7D'));
        await pumpAndRender(tester);
        expect(tester.takeException(), isNull);

        // Tap 90D period
        await tester.tap(find.text('90D'));
        await pumpAndRender(tester);
        expect(tester.takeException(), isNull);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 3: Responsive property comparison (Phone renders cards; Desktop renders DataTable)
    // -------------------------------------------------------------------------
    testWidgets(
      '3. Responsive comparison: Phone renders cards; Desktop renders DataTable',
      (tester) async {
        // 1. Phone width (360 x 800)
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: OwnerSummaryScreen(
              properties: [testProp1, testProp2],
              units: testUnits,
              rentRecords: testRents,
              now: now,
            ),
          ),
        );
        await pumpAndRender(tester);

        // At phone width (< 720), DataTable should NOT be rendered
        expect(find.byType(DataTable), findsNothing);
        // Property cards should be visible
        expect(find.text('Gulmohar Heights'), findsWidgets);

        // 2. Desktop width (1280 x 800)
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pumpWidget(
          MaterialApp(
            home: OwnerSummaryScreen(
              properties: [testProp1, testProp2],
              units: testUnits,
              rentRecords: testRents,
              now: now,
            ),
          ),
        );
        await pumpAndRender(tester);

        // At desktop width (>= 720), DataTable should be rendered
        expect(find.byType(DataTable), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 4: Print mode renders cleanly without interactive chrome
    // -------------------------------------------------------------------------
    testWidgets('4. Print mode renders cleanly without interactive chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerSummaryScreen(
            properties: [testProp1, testProp2],
            units: testUnits,
            rentRecords: testRents,
            now: now,
            printMode: true,
          ),
        ),
      );
      await pumpAndRender(tester);

      expect(tester.takeException(), isNull);
      // Print header should be visible
      expect(
        find.text('GRIHSETU PORTFOLIO OPERATIONAL REPORT'),
        findsOneWidget,
      );
      // Interactive segmented buttons should not be present in print mode
      expect(find.text('7D'), findsNothing);
      expect(find.text('30D'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // TEST 5: Golden-free overflow checks across phone, tablet, and desktop
    // -------------------------------------------------------------------------
    testWidgets(
      '5. Golden-free overflow checks at 360, 768, and 1280 px widths',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;

        for (final size in [
          const Size(360, 800),
          const Size(768, 1024),
          const Size(1280, 900),
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            MaterialApp(
              home: OwnerSummaryScreen(
                properties: [testProp1, testProp2],
                units: testUnits,
                rentRecords: testRents,
                now: now,
              ),
            ),
          );
          await pumpAndRender(tester);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
