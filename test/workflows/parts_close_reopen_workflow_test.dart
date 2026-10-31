import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/user_role.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/screens/complaints/detail/actions/close_sheet.dart';
import 'package:grihsetu/utils/app_clock.dart';
import 'package:grihsetu/utils/status_transitions.dart';

import '../support/app_harness.dart';

void main() {
  setUp(() => AppClock.current = FixedClock(DateTime(2026, 10, 10, 9)));
  tearDown(AppClock.reset);

  test(
    'parts pause, resume, and seven-day reopen boundary stay auditable',
    () async {
      final store = ComplaintStore(initialComplaints: const []);
      addTearDown(store.dispose);
      final repository = InMemoryComplaintRepository(
        initialComplaints: [_complaint()],
        store: store,
      );
      final expected = DateTime(2026, 10, 14);
      final waiting = await repository.changeStatus(
        StatusChange(
          complaintId: 'cmp_parts',
          to: ComplaintStatus.waitingForParts,
          actor: 'tech_1',
          role: 'Technician',
          reason: 'Replacement valve required',
          expectedDate: expected,
          parts: const [
            {'name': 'Brass angle valve', 'quantity': 1},
          ],
        ),
      );
      expect(waiting.status, ComplaintStatus.waitingForParts);
      final pauseEvent = store.getEvents(waiting.id).last;
      expect(pauseEvent.metadata['expectedDate'], expected.toIso8601String());
      expect(pauseEvent.metadata['parts'], isNotEmpty);

      final resumed = await repository.changeStatus(
        const StatusChange(
          complaintId: 'cmp_parts',
          to: ComplaintStatus.inProgress,
          actor: 'tech_1',
          role: 'Technician',
          note: 'Required valve received; repair resumed.',
        ),
      );
      expect(resumed.status, ComplaintStatus.inProgress);
      expect(store.getEvents(resumed.id).last.rawEventType, 'work-resumed');

      final now = DateTime(2026, 10, 10, 9);
      expect(
        allowedNext(
          ComplaintStatus.closed,
          UserRole.tenant,
          closedAt: now.subtract(const Duration(days: 7)),
          referenceNow: now,
        ),
        contains(ComplaintStatus.reopened),
      );
      expect(
        allowedNext(
          ComplaintStatus.closed,
          UserRole.tenant,
          closedAt: now.subtract(const Duration(days: 8)),
          referenceNow: now,
        ),
        isEmpty,
      );
    },
  );

  testWidgets('close without tenant confirmation requires a reason', (
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
    await tester.tap(find.byKey(const Key('proceed_to_confirm_close_button')));
    await tester.pump();
    expect(
      find.textContaining('a reason of at least 15 characters'),
      findsOneWidget,
    );
    expect(submitted, isNull);

    await tester.enterText(
      find.byKey(const Key('close_reason_field')),
      'Tenant could not be reached after repeated follow-up.',
    );
    await tester.tap(find.byKey(const Key('proceed_to_confirm_close_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('final_confirm_close_button')));
    await settle(tester);
    expect(submitted?.tenantConfirmed, isFalse);
    expect(submitted?.reason, contains('could not be reached'));
  });
}

Complaint _complaint() => Complaint(
  id: 'cmp_parts',
  title: 'Kitchen pipe leak',
  description: 'A replacement valve is required below the kitchen sink.',
  category: ComplaintCategory.plumbing,
  priority: ComplaintPriority.high,
  status: ComplaintStatus.assigned,
  propertyId: 'prop_001',
  unitId: 'unit_101',
  tenantId: 'ten_001',
  currentTechnicianId: 'tech_1',
  createdBy: 'ten_001',
  createdAt: DateTime(2026, 10, 9, 9),
);
