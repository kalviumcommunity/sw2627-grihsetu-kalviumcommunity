import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/screens/complaints/create_complaint_screen.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/utils/app_clock.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets(
    'tenant completes every complaint step and repeated submit creates once',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppClock.current = FixedClock(DateTime.utc(2026, 10, 6, 12));
      final store = ComplaintStore(
        initialComplaints: const [],
        clock: AppClock.current,
      );
      ComplaintStore.resetInstance(store);
      addTearDown(() {
        ComplaintStore.resetInstance();
        AppClock.reset();
      });
      final repository = InMemoryComplaintRepository(
        initialComplaints: const [],
        store: store,
      )..operationDelay = const Duration(milliseconds: 100);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(webFonts: false),
          home: CreateComplaintScreen(
            role: UserRole.tenant,
            repository: repository,
          ),
        ),
      );
      await settle(tester);
      expectNoOverflow(tester);

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Your registered home is prefilled.'), findsOneWidget);
      await tapText(tester, 'Continue');
      expectNoOverflow(tester);

      expect(find.text('Step 2 of 5'), findsOneWidget);
      await tapText(tester, 'Continue');
      expectNoOverflow(tester);
      expect(find.text('Choose a complaint category'), findsOneWidget);
      expect(find.text('Title is required'), findsOneWidget);

      await tapText(tester, 'Plumbing');
      await enterByLabel(tester, 'Short title', 'Kitchen sink is leaking');
      await enterByLabel(
        tester,
        'Describe the issue',
        'Water is dripping continuously below the kitchen sink cabinet.',
      );
      await tapText(tester, 'Continue');
      expectNoOverflow(tester);
      expect(find.text('Step 3 of 5'), findsOneWidget);

      await tapText(tester, 'Back');
      expectNoOverflow(tester);
      expect(find.text('Kitchen sink is leaking'), findsOneWidget);
      expect(
        find.text(
          'Water is dripping continuously below the kitchen sink cabinet.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Continue');
      expectNoOverflow(tester);
      await tapText(tester, 'Continue');
      expectNoOverflow(tester);
      expect(find.text('Step 4 of 5'), findsOneWidget);
      await tapText(tester, 'Continue');
      expectNoOverflow(tester);
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(find.textContaining('Plumbing: Kitchen sink'), findsOneWidget);

      final submit = find.text('Submit complaint');
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await settle(tester);
      expectNoOverflow(tester);

      expect(store.snapshot, hasLength(1));
      final created = store.snapshot.single;
      expect(find.text('Complaint ${created.id}'), findsOneWidget);
      repository.operationDelay = Duration.zero;
      final tenantList = await repository.list(
        scope: ComplaintScope.forTenant(created.tenantId),
      );
      final staffList = await repository.list();
      expect(tenantList.map((item) => item.id), contains(created.id));
      expect(staffList.map((item) => item.id), contains(created.id));
    },
  );
}
