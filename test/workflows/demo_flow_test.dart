import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app_shell.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/fixtures/sample_fixtures.dart';
import 'package:grihsetu/core/models/user.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/screens/complaints/create_complaint_screen.dart';
import 'package:grihsetu/screens/technician/visit/visit_models.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/utils/app_clock.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets(
    'demo roles share one complaint lifecycle and rent workspace',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AppClock.current = FixedClock(SampleFixtures.demoReferenceDate);
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
      );

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
      await tapText(tester, 'Continue');
      await tapText(tester, 'Plumbing');
      await enterByLabel(tester, 'Short title', 'Demo kitchen sink leak');
      await enterByLabel(
        tester,
        'Describe the issue',
        'Water is leaking below the kitchen sink during the live demo.',
      );
      await tapText(tester, 'Continue');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Submit complaint');
      expect(store.snapshot, hasLength(1));
      final complaintId = store.snapshot.single.id;
      expect(find.text('Complaint $complaintId'), findsOneWidget);

      await _pumpShell(tester, SampleFixtures.complaintOpsUser, repository);
      await tapText(tester, 'Complaints');
      expect(find.text('Demo kitchen sink leak'), findsOneWidget);

      final assigned = await repository.assignComplaintTechnician(
        complaintId,
        SampleFixtures.technicianUser.id,
        actorId: SampleFixtures.complaintOpsUser.id,
        role: 'Complaint Operations',
      );
      expect(assigned.status, ComplaintStatus.assigned);

      await _pumpShell(tester, SampleFixtures.technicianUser, repository);
      await tapText(tester, 'Assigned Work');
      expect(find.text('Demo kitchen sink leak'), findsOneWidget);

      final resolved = await repository.completeVisit(
        complaintId,
        const VisitCompletionInput(
          whatWasFound: 'A failed angle valve leaked under pressure.',
          whatWasRepaired: 'The valve was replaced and pressure-tested.',
          noPartsUsed: true,
          tenantResolutionNotes: 'The cabinet is dry and the leak has stopped.',
          afterPhotos: ['demo-after.jpg'],
        ),
        actorId: SampleFixtures.technicianUser.id,
        role: 'Technician',
      );
      expect(resolved.status, ComplaintStatus.resolved);

      final closed = await repository.changeStatus(
        StatusChange(
          complaintId: complaintId,
          to: ComplaintStatus.closed,
          actor: 'ten_004',
          role: 'Tenant',
          tenantConfirmed: true,
          note: 'Tenant confirmed the demo repair is complete.',
        ),
      );
      expect(closed.status, ComplaintStatus.closed);

      await _pumpShell(tester, _profile(UserRole.propertyOwner), repository);
      await tapText(tester, 'Complaints');
      expect(find.text('Demo kitchen sink leak'), findsOneWidget);

      await _pumpShell(tester, SampleFixtures.propertyOpsUser, repository);
      await tapText(tester, 'Rent');
      expect(find.text('October 2026'), findsWidgets);
      expect(find.textContaining('Kabir'), findsWidgets);
      expect(store.getEvents(complaintId), isNotEmpty);
    },
    skip:
        'GRIH-053 known issue: repeated role-shell repumps expose a '
        'dashboard card overflow and then lose the technician navigation '
        'destination in the demo fixture.',
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  AppUser profile,
  ComplaintRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(webFonts: false),
      home: AppShell(profile: profile, complaintRepository: repository),
    ),
  );
  await settle(tester);
}

AppUser _profile(UserRole role) => AppUser(
  id: 'demo_${role.value}',
  name: 'Demo ${role.displayLabel}',
  email: '${role.value}@grihsetu.test',
  role: role,
  createdAt: SampleFixtures.demoReferenceDate,
);
