import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app_shell.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/core/models/tenant.dart';
import 'package:grihsetu/core/models/user.dart';
import 'package:grihsetu/repositories/rent_repository.dart';
import 'package:grihsetu/screens/dashboard/operations_dashboard_screen.dart';
import 'package:grihsetu/screens/rent/rent_detail_screen.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/widgets/rent_follow_ups_due.dart';
import 'package:grihsetu/widgets/stat_tile.dart';

class TestFakeRentRepository implements RentRepository {
  TestFakeRentRepository({this.items = const [], this.shouldFail = false});

  final List<RentItem> items;
  final bool shouldFail;

  @override
  Future<List<RentItem>> list({
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? month,
    RentStatus? status,
  }) async {
    if (shouldFail) throw Exception('Failed to load rent items');
    return items;
  }

  @override
  Future<RentItem?> get(String id) async {
    return items.cast<RentItem?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );
  }

  @override
  Future<RentItem> addFollowUp(RentFollowUp followUp) async {
    throw UnimplementedError();
  }

  @override
  Future<RentItem> markPaid(PaymentRecord payment) async {
    throw UnimplementedError();
  }
}

void main() {
  group('Operations Dashboard Integration', () {
    final refTime = DateTime.utc(2026, 10, 6, 10, 0);

    RentItem sampleRentItem({
      required String id,
      required String tenantName,
      DateTime? nextFollowUpDate,
    }) {
      return RentItem(
        record: RentRecord(
          id: id,
          tenantId: 'tenant_$id',
          propertyId: 'prop_$id',
          unitId: 'unit_$id',
          month: 'October 2026',
          amountDue: 25000,
          dueDate: DateTime.utc(2026, 10, 5),
          status: RentStatus.due,
          nextFollowUpAt: nextFollowUpDate,
        ),
        tenant: Tenant(
          id: 'tenant_$id',
          name: tenantName,
          phone: '+91 98765 43210',
          propertyId: 'prop_$id',
          unitId: 'unit_$id',
        ),
        property: Property(
          id: 'prop_$id',
          name: 'Greenfield Residency',
          address: 'Gurugram',
          createdAt: DateTime(2025, 1, 1),
        ),
        unit: Unit(
          id: 'unit_$id',
          propertyId: 'prop_$id',
          unitNumber: 'A-201',
          floor: 2,
          occupancyStatus: 'occupied',
        ),
        followUps: [
          RentFollowUp(
            id: 'flw_$id',
            rentRecordId: id,
            method: FollowUpMethod.call,
            outcome: FollowUpOutcome.noAnswer,
            actor: 'Staff Member',
            timestamp: DateTime.utc(2026, 10, 5, 11, 0),
            nextFollowUpDate: nextFollowUpDate,
          ),
        ],
      );
    }

    testWidgets(
      'Operations staff role displays OperationsDashboardScreen on Overview destination',
      (tester) async {
        final fakeRepo = TestFakeRentRepository(
          items: [
            sampleRentItem(
              id: 'rent_1',
              tenantName: 'Kavita Das',
              nextFollowUpDate: DateTime.utc(2026, 10, 6),
            ),
          ],
        );

        final profile = AppUser(
          id: 'user_ops_1',
          email: 'ops@grihsetu.app',
          name: 'Ops Manager',
          role: UserRole.propertyOperations,
          createdAt: DateTime(2025, 1, 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AppShell(profile: profile, rentRepository: fakeRepo),
          ),
        );

        // Loading state finishes
        await tester.pumpAndSettle();

        expect(find.byType(OperationsDashboardScreen), findsOneWidget);
        expect(find.text('Overview'), findsWidgets);
        expect(find.byType(StatTile), findsWidgets);
        expect(find.byType(RentFollowUpsDue), findsOneWidget);
        expect(find.text('Kavita Das'), findsOneWidget);
      },
    );

    testWidgets(
      'Non-operations role (propertyOwner) does not expose operational dashboard',
      (tester) async {
        final fakeRepo = TestFakeRentRepository(
          items: [
            sampleRentItem(
              id: 'rent_owner_test',
              tenantName: 'Secret Tenant',
              nextFollowUpDate: DateTime.utc(2026, 10, 6),
            ),
          ],
        );

        final ownerProfile = AppUser(
          id: 'user_owner_1',
          email: 'owner@example.com',
          name: 'Building Owner',
          role: UserRole.propertyOwner,
          createdAt: DateTime(2025, 1, 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AppShell(profile: ownerProfile, rentRepository: fakeRepo),
          ),
        );

        await tester.pumpAndSettle();

        // Does not show operations dashboard or operational follow-ups
        expect(find.byType(OperationsDashboardScreen), findsNothing);
        expect(find.text('Secret Tenant'), findsNothing);
        expect(find.text('Property Owner workspace'), findsOneWidget);
      },
    );

    testWidgets(
      'OperationsDashboardScreen shows error state and retries on failure',
      (tester) async {
        final failingRepo = TestFakeRentRepository(shouldFail: true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OperationsDashboardScreen(rentRepository: failingRepo),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining('Failed to load rent items'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping follow-up tile in dashboard navigates to RentDetailScreen',
      (tester) async {
        final item = sampleRentItem(
          id: 'rent_nav_1',
          tenantName: 'Navigating Tenant',
          nextFollowUpDate: DateTime.utc(2026, 10, 6),
        );

        final fakeRepo = TestFakeRentRepository(items: [item]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OperationsDashboardScreen(
                rentRepository: fakeRepo,
                now: refTime,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Navigating Tenant'), findsOneWidget);

        await tester.tap(find.text('Navigating Tenant'));
        await tester.pumpAndSettle();

        expect(find.byType(RentDetailScreen), findsOneWidget);
      },
    );
  });
}
