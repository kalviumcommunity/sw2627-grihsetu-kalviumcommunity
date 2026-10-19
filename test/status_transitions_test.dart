import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/user_role.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/screens/complaints/detail/actions/close_sheet.dart';
import 'package:grihsetu/screens/complaints/detail/actions/waiting_for_parts_sheet.dart';
import 'package:grihsetu/utils/status_transitions.dart';
import 'package:grihsetu/widgets/complaint_chips.dart';

void main() {
  group('GRIH-029: Close, reopen, and waiting-for-parts action UI', () {
    // 1. allowedNext matrix for each role
    test('1. allowedNext matrix for each role', () {
      final now = DateTime(2026, 10, 19, 12, 0);
      final closedYesterday = now.subtract(const Duration(days: 1));

      // Technician
      expect(
        allowedNext(ComplaintStatus.inProgress, UserRole.technician),
        equals({ComplaintStatus.waitingForParts}),
      );
      expect(
        allowedNext(ComplaintStatus.waitingForParts, UserRole.technician),
        equals({ComplaintStatus.inProgress}),
      );
      for (final s in [
        ComplaintStatus.open,
        ComplaintStatus.assigned,
        ComplaintStatus.resolved,
        ComplaintStatus.closed,
        ComplaintStatus.reopened,
        ComplaintStatus.cancelled,
      ]) {
        expect(
          allowedNext(s, UserRole.technician),
          isEmpty,
          reason: 'Technician should not transition from ${s.name}',
        );
      }

      // Tenant
      expect(
        allowedNext(ComplaintStatus.resolved, UserRole.tenant),
        equals({ComplaintStatus.reopened}),
      );
      expect(
        allowedNext(
          ComplaintStatus.closed,
          UserRole.tenant,
          closedAt: closedYesterday,
          referenceNow: now,
        ),
        equals({ComplaintStatus.reopened}),
      );
      for (final s in [
        ComplaintStatus.open,
        ComplaintStatus.assigned,
        ComplaintStatus.inProgress,
        ComplaintStatus.waitingForParts,
        ComplaintStatus.reopened,
        ComplaintStatus.cancelled,
      ]) {
        expect(
          allowedNext(s, UserRole.tenant),
          isEmpty,
          reason: 'Tenant should not transition from ${s.name}',
        );
      }

      // Staff
      expect(
        allowedNext(ComplaintStatus.open, UserRole.staff),
        equals({ComplaintStatus.cancelled}),
      );
      expect(
        allowedNext(ComplaintStatus.assigned, UserRole.staff),
        equals({ComplaintStatus.cancelled}),
      );
      expect(
        allowedNext(ComplaintStatus.resolved, UserRole.staff),
        equals({ComplaintStatus.closed, ComplaintStatus.reopened}),
      );
      expect(
        allowedNext(
          ComplaintStatus.closed,
          UserRole.staff,
          closedAt: closedYesterday,
          referenceNow: now,
        ),
        equals({ComplaintStatus.reopened}),
      );
      for (final s in [
        ComplaintStatus.inProgress,
        ComplaintStatus.waitingForParts,
        ComplaintStatus.reopened,
        ComplaintStatus.cancelled,
      ]) {
        expect(
          allowedNext(s, UserRole.staff),
          isEmpty,
          reason: 'Staff should not transition from ${s.name}',
        );
      }

      // Owner has no actions
      for (final s in ComplaintStatus.values) {
        expect(
          allowedNext(s, UserRole.owner),
          isEmpty,
          reason: 'Owner has no actions from ${s.name}',
        );
      }

      // Terminal: Nothing leaves cancelled
      for (final r in UserRole.values) {
        expect(
          allowedNext(ComplaintStatus.cancelled, r),
          isEmpty,
          reason: 'Cancelled is terminal for ${r.name}',
        );
      }
    });

    // 2. the tenant reopen window (day 7 allowed, day 8 not)
    test('2. the tenant reopen window (day 7 allowed, day 8 not)', () {
      final now = DateTime(2026, 10, 19, 12, 0);

      // Day 7: allowed
      final closedDay7 = now.subtract(const Duration(days: 7));
      final allowedDay7 = allowedNext(
        ComplaintStatus.closed,
        UserRole.tenant,
        closedAt: closedDay7,
        referenceNow: now,
      );
      expect(allowedDay7, contains(ComplaintStatus.reopened));
      expect(
        whyNot(
          ComplaintStatus.closed,
          ComplaintStatus.reopened,
          UserRole.tenant,
          closedAt: closedDay7,
          referenceNow: now,
        ),
        isNull,
      );

      // Day 8: not allowed
      final closedDay8 = now.subtract(const Duration(days: 8));
      final allowedDay8 = allowedNext(
        ComplaintStatus.closed,
        UserRole.tenant,
        closedAt: closedDay8,
        referenceNow: now,
      );
      expect(allowedDay8, isEmpty);
      final reasonDay8 = whyNot(
        ComplaintStatus.closed,
        ComplaintStatus.reopened,
        UserRole.tenant,
        closedAt: closedDay8,
        referenceNow: now,
      );
      expect(reasonDay8, isNotNull);
      expect(reasonDay8, contains('Reopen window has expired'));
    });

    // 3. waiting-for-parts validation boundaries
    testWidgets('3. waiting-for-parts validation boundaries', (tester) async {
      final now = DateTime(2026, 10, 19, 12, 0);
      WaitingForPartsResult? submitted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaitingForPartsSheet(
              currentStatus: ComplaintStatus.inProgress,
              referenceNow: now,
              onSubmit: (result) async => submitted = result,
            ),
          ),
        ),
      );

      // 1. Submit without reason -> fails
      await tester.tap(find.byKey(const Key('confirm_waiting_button')));
      await tester.pump();
      expect(find.text('Please select a reason.'), findsOneWidget);
      expect(submitted, isNull);

      // 2. Select 'Other' without note >= 10 chars -> fails
      await tester.tap(find.byKey(const Key('waiting_reason_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('waiting_note_field')),
        'Short',
      );
      await tester.tap(find.byKey(const Key('confirm_waiting_button')));
      await tester.pump();
      expect(
        find.text('For "Other", note must be at least 10 characters.'),
        findsOneWidget,
      );
      expect(submitted, isNull);

      // 3. Fix note to >= 10 chars, but part name < 2 chars -> fails
      await tester.enterText(
        find.byKey(const Key('waiting_note_field')),
        'Needs custom bracket from metal workshop',
      );
      await tester.enterText(
        find.byKey(const Key('part_name_field_0')),
        'A', // 1 char < 2 chars
      );
      await tester.tap(find.byKey(const Key('confirm_waiting_button')));
      await tester.pump();
      expect(
        find.text('Part #1 name must be 2 to 60 characters.'),
        findsOneWidget,
      );

      // 4. Set valid part name (2-60 chars) and submit -> succeeds
      await tester.enterText(
        find.byKey(const Key('part_name_field_0')),
        'Custom Iron Bracket',
      );
      await tester.tap(find.byKey(const Key('confirm_waiting_button')));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.reason, equals('Other'));
      expect(submitted!.parts.first['name'], equals('Custom Iron Bracket'));
      expect(submitted!.parts.first['quantity'], equals(1));
    });

    // 4. close without tenant confirmation requires a reason
    testWidgets('4. close without tenant confirmation requires a reason', (
      tester,
    ) async {
      CloseResult? submitted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CloseSheet(
              initialTenantConfirmed: false,
              onSubmit: (result) async => submitted = result,
            ),
          ),
        ),
      );

      // Initial state: tenant not confirmed
      expect(find.text('Close without tenant confirmation'), findsOneWidget);

      // Proceed without reason -> fails
      await tester.tap(
        find.byKey(const Key('proceed_to_confirm_close_button')),
      );
      await tester.pump();
      expect(
        find.text(
          'When closing without tenant confirmation, a reason of at least 15 characters is required.',
        ),
        findsOneWidget,
      );
      expect(submitted, isNull);

      // Enter short reason (< 15 chars) -> fails
      await tester.enterText(
        find.byKey(const Key('close_reason_field')),
        'Too short',
      );
      await tester.tap(
        find.byKey(const Key('proceed_to_confirm_close_button')),
      );
      await tester.pump();
      expect(
        find.text(
          'When closing without tenant confirmation, a reason of at least 15 characters is required.',
        ),
        findsOneWidget,
      );

      // Enter valid reason >= 15 chars -> advances to confirm step
      await tester.enterText(
        find.byKey(const Key('close_reason_field')),
        'Tenant unresponsive for 5 days following inspection.',
      );
      await tester.tap(
        find.byKey(const Key('proceed_to_confirm_close_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirm close'), findsOneWidget);
      await tester.tap(find.byKey(const Key('final_confirm_close_button')));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.tenantConfirmed, isFalse);
      expect(
        submitted!.reason,
        equals('Tenant unresponsive for 5 days following inspection.'),
      );
    });

    // 5. after an action the badge, timeline and banner change together on the detail screen
    testWidgets(
      '5. after an action the badge, timeline and banner change together on the detail screen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime(2026, 10, 19, 12, 0);
        final initialComplaint = Complaint(
          id: 'comp_test_029',
          tenantId: 'usr_tenant',
          propertyId: 'prop_001',
          unitId: 'unit_101',
          title: 'Ceiling leak in bathroom',
          description: 'Water leaking continuously from above unit.',
          category: ComplaintCategory.plumbing,
          priority: ComplaintPriority.high,
          status: ComplaintStatus.inProgress,
          currentTechnicianId: 'usr_tech_01',
          createdBy: 'usr_tenant',
          createdAt: now.subtract(const Duration(hours: 5)),
        );

        final repository = InMemoryComplaintRepository(
          initialComplaints: [initialComplaint],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ComplaintDetailScreen(
              complaintId: initialComplaint.id,
              complaint: initialComplaint,
              complaintRepository: repository,
              userRole: UserRole.technician,
              referenceNow: now,
              currentUserId: 'usr_tech_01',
              currentUserName: 'Aman Verma',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial state verification: In Progress, no waiting banner
        expect(
          find.descendant(
            of: find.byType(ComplaintStatusChip),
            matching: find.text('In Progress'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('waiting_for_parts_banner')), findsNothing);

        // 2. Technician taps "Hold for parts"
        expect(find.byKey(const Key('tech_hold_parts_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('tech_hold_parts_button')));
        await tester.pumpAndSettle();

        // 3. Complete the waiting for parts sheet
        await tester.tap(find.byKey(const Key('waiting_reason_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Part not in stock').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('part_name_field_0')),
          'PVC Joint Pipe 25mm',
        );
        await tester.enterText(
          find.byKey(const Key('waiting_note_field')),
          'Ordered from plumbing supplies vendor.',
        );

        await tester.ensureVisible(
          find.byKey(const Key('confirm_waiting_button')),
        );
        await tester.tap(find.byKey(const Key('confirm_waiting_button')));
        await tester.pumpAndSettle();

        // 4. Verify that badge, banner, and timeline changed together
        // A: Badge is now "Waiting for Parts"
        expect(
          find.descendant(
            of: find.byType(ComplaintStatusChip),
            matching: find.text('Waiting for Parts'),
          ),
          findsOneWidget,
        );

        // B: Top banner is present
        expect(
          find.byKey(const Key('waiting_for_parts_banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Waiting for parts: expected'),
          findsOneWidget,
        );

        // C: Timeline includes the waiting for parts entry
        expect(find.text('Waiting for parts'), findsWidgets);
      },
    );
  });
}
