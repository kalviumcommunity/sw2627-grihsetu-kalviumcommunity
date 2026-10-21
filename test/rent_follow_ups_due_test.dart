import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/core/models/tenant.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/widgets/empty_state.dart';
import 'package:grihsetu/widgets/rent_follow_ups_due.dart';

void main() {
  group('RentFollowUpsDue & prepareRentFollowUpsDue', () {
    final refTime = DateTime.utc(2026, 10, 6, 12, 0);

    RentItem createItem({
      required String id,
      required String tenantName,
      String propertyName = 'Palm Grove',
      String unitNumber = '101',
      RentStatus status = RentStatus.due,
      DateTime? nextFollowUpDate,
      List<RentFollowUp> followUps = const [],
      List<PaymentRecord> payments = const [],
      double amountDue = 20000.0,
      DateTime? dueDate,
    }) {
      return RentItem(
        record: RentRecord(
          id: id,
          tenantId: 'tenant_$id',
          propertyId: 'prop_$id',
          unitId: 'unit_$id',
          month: 'October 2026',
          amountDue: amountDue,
          dueDate: dueDate ?? DateTime.utc(2026, 10, 5),
          status: status,
          nextFollowUpAt: nextFollowUpDate,
        ),
        tenant: Tenant(
          id: 'tenant_$id',
          name: tenantName,
          phone: '+91 99999 11111',
          propertyId: 'prop_$id',
          unitId: 'unit_$id',
        ),
        property: Property(
          id: 'prop_$id',
          name: propertyName,
          address: 'Main Street',
          createdAt: DateTime(2025, 1, 1),
        ),
        unit: Unit(
          id: 'unit_$id',
          propertyId: 'prop_$id',
          unitNumber: unitNumber,
          floor: 1,
          occupancyStatus: 'occupied',
        ),
        followUps: followUps,
        payments: payments,
      );
    }

    test(
      'prepareRentFollowUpsDue distinguishes overdue vs due today correctly',
      () {
        final overdueItem = createItem(
          id: 'r1',
          tenantName: 'Overdue Tenant',
          nextFollowUpDate: DateTime.utc(
            2026,
            10,
            4,
          ), // 2 days before refTime (Oct 6)
        );

        final dueTodayItem = createItem(
          id: 'r2',
          tenantName: 'Due Today Tenant',
          nextFollowUpDate: DateTime.utc(
            2026,
            10,
            6,
          ), // Same day as refTime (Oct 6)
        );

        final upcomingItem = createItem(
          id: 'r3',
          tenantName: 'Upcoming Tenant',
          nextFollowUpDate: DateTime.utc(2026, 10, 8), // Future
        );

        final prepared = prepareRentFollowUpsDue(
          [dueTodayItem, upcomingItem, overdueItem],
          now: refTime,
          dueAndOverdueOnly: true,
        );

        // Upcoming is excluded when dueAndOverdueOnly is true
        expect(prepared.length, 2);

        // Overdue item is sorted first
        expect(prepared.first.id, 'r1');
        expect(prepared.first.isOverdue, isTrue);
        expect(prepared.first.daysOverdue, 2);
        expect(prepared.first.statusLabel, '2d overdue');

        // Due today item is sorted second
        expect(prepared[1].id, 'r2');
        expect(prepared[1].isOverdue, isFalse);
        expect(prepared[1].daysOverdue, 0);
        expect(prepared[1].statusLabel, 'Due today');
      },
    );

    test('prepareRentFollowUpsDue excludes paid records and zero balances', () {
      final paidByStatus = createItem(
        id: 'paid_1',
        tenantName: 'Paid Tenant 1',
        status: RentStatus.paid,
        nextFollowUpDate: DateTime.utc(2026, 10, 5),
      );

      final paidBySettlement = createItem(
        id: 'paid_2',
        tenantName: 'Paid Tenant 2',
        amountDue: 20000.0,
        payments: [
          PaymentRecord(
            id: 'pay_1',
            rentRecordId: 'paid_2',
            amount: 20000.0,
            date: DateTime.utc(2026, 10, 4),
            mode: PaymentMode.upi,
            actor: 'Staff',
          ),
        ],
        nextFollowUpDate: DateTime.utc(2026, 10, 5),
      );

      final activeItem = createItem(
        id: 'active_1',
        tenantName: 'Active Tenant',
        nextFollowUpDate: DateTime.utc(2026, 10, 5),
      );

      final prepared = prepareRentFollowUpsDue([
        paidByStatus,
        paidBySettlement,
        activeItem,
      ], now: refTime);

      expect(prepared.length, 1);
      expect(prepared.single.id, 'active_1');
    });

    test(
      'prepareRentFollowUpsDue excludes records without scheduled next date',
      () {
        final itemWithoutDate = createItem(
          id: 'no_date',
          tenantName: 'No Date Tenant',
          nextFollowUpDate: null,
        );

        final prepared = prepareRentFollowUpsDue([
          itemWithoutDate,
        ], now: refTime);
        expect(prepared, isEmpty);
      },
    );

    testWidgets(
      'renders due items, property context, and handles tap callback',
      (tester) async {
        RentFollowUpDueItem? selectedItem;

        final items = [
          RentFollowUpDueItem(
            id: 'item_1',
            rentRecordId: 'rent_101',
            tenantName: 'Sanjay Gupta',
            propertyContext: 'Sunrise Heights • Unit 302',
            dueDate: DateTime(2026, 10, 6),
            isOverdue: false,
            statusLabel: 'Due today',
          ),
          RentFollowUpDueItem(
            id: 'item_2',
            rentRecordId: 'rent_102',
            tenantName: 'Priya Mehta',
            propertyContext: 'Green Acres • Unit 105',
            dueDate: DateTime(2026, 10, 3),
            isOverdue: true,
            daysOverdue: 3,
            statusLabel: '3d overdue',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RentFollowUpsDue(
                items: items,
                onItemTap: (item) => selectedItem = item,
              ),
            ),
          ),
        );

        expect(find.text('Sanjay Gupta'), findsOneWidget);
        expect(find.text('Sunrise Heights • Unit 302'), findsOneWidget);
        expect(find.text('Due today'), findsOneWidget);

        expect(find.text('Priya Mehta'), findsOneWidget);
        expect(find.text('Green Acres • Unit 105'), findsOneWidget);
        expect(find.text('3d overdue'), findsOneWidget);

        // Tap first item
        await tester.tap(find.text('Sanjay Gupta'));
        await tester.pumpAndSettle();

        expect(selectedItem, isNotNull);
        expect(selectedItem!.rentRecordId, 'rent_101');
      },
    );

    testWidgets('renders empty state when items list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RentFollowUpsDue(
              items: [],
              emptyTitle: 'No follow-ups due',
              emptyMessage: 'All rent follow-ups are up to date.',
            ),
          ),
        ),
      );

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No follow-ups due'), findsOneWidget);
      expect(find.text('All rent follow-ups are up to date.'), findsOneWidget);
    });

    testWidgets(
      'missing optional values do not display "null" or fabricated data',
      (tester) async {
        final itemWithNoContext = RentFollowUpDueItem(
          id: 'no_ctx',
          rentRecordId: 'rent_999',
          tenantName: 'Anita Roy',
          propertyContext: null,
          propertyName: null,
          unitNumber: null,
          dueDate: DateTime(2026, 10, 6),
          isOverdue: false,
          statusLabel: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: RentFollowUpsDue(items: [itemWithNoContext])),
          ),
        );

        expect(find.text('Anita Roy'), findsOneWidget);
        expect(find.textContaining('null'), findsNothing);
      },
    );
  });
}
