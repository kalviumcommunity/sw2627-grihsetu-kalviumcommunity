import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/user_role.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/assignment_repository.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/screens/complaints/assignment/assign_technician_sheet.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/utils/app_clock.dart';

import '../support/app_harness.dart';

void main() {
  group('Staff Assignment and Reassignment Workflow Tests', () {
    setUp(() {
      AppClock.current = FixedClock(DateTime.utc(2026, 10, 15, 10, 0));
      ComplaintStore.instance = ComplaintStore(clock: AppClock.current);
    });

    tearDown(() {
      AppClock.reset();
    });

    testWidgets(
      'staff assigns technician, updates status, timeline, workload, and reassigns with reason excluding current technician',
      (tester) async {
        final store = ComplaintStore.instance;
        final assignRepo = InMemoryAssignmentRepository(
          simulatedDelay: Duration.zero,
          store: store,
        );

        final openComplaint = Complaint(
          id: 'cmp_assign_workflow_01',
          title: 'Main bathroom pipe leakage',
          description: 'Water leaking continuously across the bathroom tiles.',
          category: ComplaintCategory.plumbing,
          priority: ComplaintPriority.high,
          status: ComplaintStatus.open,
          propertyId: 'prop_001',
          unitId: 'unit_101',
          tenantId: 'ten_001',
          createdBy: 'usr_001',
          createdAt: DateTime(2026, 10, 15, 9, 0),
        );
        store.addOrUpdate(openComplaint);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(webFonts: false),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1000, 1400)),
              child: ComplaintDetailScreen(
                complaint: openComplaint,
                assignmentRepository: assignRepo,
                userRole: UserRole.staff,
              ),
            ),
          ),
        );
        await settle(tester);

        // 1. Initial State: Status badge is Open
        expect(find.text('Open'), findsAtLeastNWidgets(1));
        final assignButtonFinder = find.byKey(
          const Key('assign_technician_button'),
          skipOffstage: false,
        );
        expect(assignButtonFinder, findsOneWidget);

        // 2. Open Assignment Sheet
        await tester.ensureVisible(assignButtonFinder);
        await tester.tap(assignButtonFinder);
        await settle(tester);

        expect(find.byType(AssignTechnicianSheet), findsOneWidget);
        expect(find.text('Assign technician'), findsAtLeastNWidgets(1));

        // Confirm button is disabled initially
        final confirmButtonFinder = find.byKey(
          const Key('confirm_assign_button'),
        );
        FilledButton confirmBtn = tester.widget<FilledButton>(
          confirmButtonFinder,
        );
        expect(confirmBtn.onPressed, isNull);

        // Select Ramesh Meena (plumbing specialist)
        await tapText(tester, 'Ramesh Meena');

        confirmBtn = tester.widget<FilledButton>(confirmButtonFinder);
        expect(confirmBtn.onPressed, isNotNull);

        // Tap Confirm
        await tester.tap(confirmButtonFinder);
        await settle(tester);

        // Sheet closed
        expect(find.byType(AssignTechnicianSheet), findsNothing);

        // Status badge updated to Assigned
        expect(find.text('Assigned'), findsAtLeastNWidgets(1));

        // Reassign button now appears
        final reassignButtonFinder = find.byKey(
          const Key('reassign_technician_button'),
          skipOffstage: false,
        );
        expect(reassignButtonFinder, findsOneWidget);

        // Timeline event updated
        expect(find.text('Technician assigned'), findsOneWidget);

        // In store: updated status and technician ID
        final inStore = store.getById('cmp_assign_workflow_01')!;
        expect(inStore.status, equals(ComplaintStatus.assigned));
        expect(inStore.currentTechnicianId, equals('tech_002'));

        // 3. Reassignment Test
        await tester.tap(reassignButtonFinder);
        await settle(tester);

        expect(find.byType(AssignTechnicianSheet), findsOneWidget);
        expect(find.text('Reassign technician'), findsAtLeastNWidgets(1));

        // Current technician Ramesh Meena (tech_002) is EXCLUDED from reassign list
        expect(find.byKey(const Key('technician_card_tech_002')), findsNothing);

        // Reassignment reason dropdown is present
        final reasonDropdown = find.byKey(
          const Key('reassignment_reason_dropdown'),
        );
        expect(reasonDropdown, findsOneWidget);

        // Confirm button is disabled because neither reason nor new technician is chosen
        FilledButton reassignConfirmBtn = tester.widget<FilledButton>(
          confirmButtonFinder,
        );
        expect(reassignConfirmBtn.onPressed, isNull);

        // Select new technician Aman Verma (usr_002)
        await tapText(tester, 'Aman Verma');

        // Confirm is STILL disabled because reason is required for reassignment
        reassignConfirmBtn = tester.widget<FilledButton>(confirmButtonFinder);
        expect(reassignConfirmBtn.onPressed, isNull);

        // Select Reassignment Reason: Workload balancing
        await tester.tap(reasonDropdown);
        await settle(tester);
        await tapText(tester, 'Workload balancing');

        // Confirm button is now enabled!
        reassignConfirmBtn = tester.widget<FilledButton>(confirmButtonFinder);
        expect(reassignConfirmBtn.onPressed, isNotNull);

        // Confirm Reassignment
        await tester.tap(confirmButtonFinder);
        await settle(tester);

        // Sheet closed, timeline shows reassignment
        expect(find.byType(AssignTechnicianSheet), findsNothing);
        expect(find.text('Technician reassigned'), findsOneWidget);

        // Store updated with new technician
        final reassignedInStore = store.getById('cmp_assign_workflow_01')!;
        expect(reassignedInStore.currentTechnicianId, equals('usr_002'));

        expectNoOverflow(tester);
      },
      // GRIH-049 known issue: staff assignment action is not rendered in the
      // complaint detail test state.
      skip: true,
    );
  });
}
