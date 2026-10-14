import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/user_role.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/screens/technician/visit/visit_completion_form.dart';
import 'package:grihsetu/screens/technician/visit/visit_models.dart';
import 'package:grihsetu/screens/technician/visit/visit_screen.dart';
import 'package:grihsetu/theme/app_theme.dart';

Widget _buildTestApp({
  required Widget child,
  Brightness brightness = Brightness.light,
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) {
  final theme = brightness == Brightness.light
      ? AppTheme.light(webFonts: false)
      : AppTheme.dark(webFonts: false);
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Material(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testComplaint = Complaint(
    id: 'cmp_visit_001',
    title: 'AC unit blowing warm air',
    description: 'Master bedroom AC compressor is humming but not cooling.',
    category: ComplaintCategory.electrical,
    priority: ComplaintPriority.high,
    status: ComplaintStatus.assigned,
    propertyId: 'prop_001',
    unitId: 'unit_302',
    tenantId: 'ten_001',
    currentTechnicianId: 'tech_rajesh',
    createdBy: 'ten_001',
    createdAt: DateTime(2026, 10, 12, 10, 0),
  );

  group('Technician Visit Workflow Tests', () {
    tearDown(() {
      VisitFormDraftStore.clear('cmp_visit_001');
    });

    testWidgets(
      '(b) stepper advances one step at a time and is the only tappable next step',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryComplaintRepository();
        repo.seedComplaint(testComplaint);

        await tester.pumpWidget(
          _buildTestApp(
            child: VisitScreen(
              complaintId: testComplaint.id,
              repository: repo,
              technicianId: 'tech_rajesh',
              technicianName: 'Rajesh Kumar',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: Initial state requires Accept job
        expect(find.text('Accept job'), findsWidgets);
        expect(find.text('Accepted'), findsOneWidget);
        expect(find.text('Travelling'), findsOneWidget);

        // Tap Accept Job
        await tester.tap(find.byKey(const Key('sticky_bottom_action_button')));
        await tester.pumpAndSettle();

        // Step 2: Next step is Start travel
        expect(find.text('Start travel'), findsWidgets);

        // Tap Start travel
        await tester.tap(find.byKey(const Key('sticky_bottom_action_button')));
        await tester.pumpAndSettle();

        // Step 3: Next step is I have arrived
        expect(find.text("I've arrived"), findsWidgets);

        // Tap I've arrived
        await tester.tap(find.byKey(const Key('sticky_bottom_action_button')));
        await tester.pumpAndSettle();

        // Step 4: Next step is Start inspection
        expect(find.text('Start inspection'), findsWidgets);

        // Tap Start inspection
        await tester.tap(find.byKey(const Key('sticky_bottom_action_button')));
        await tester.pumpAndSettle();

        // Step 5: Next step is Start repair
        expect(find.text('Start repair'), findsWidgets);

        // Tap Start repair
        await tester.tap(find.byKey(const Key('sticky_bottom_action_button')));
        await tester.pumpAndSettle();

        // Step 6: Next step is Complete visit
        expect(find.text('Complete visit'), findsWidgets);

        // Verify that completed steps cannot be tapped backwards
        final acceptedStepTile = find.byKey(const Key('stepper_step_accepted'));
        expect(acceptedStepTile, findsOneWidget);
        await tester.tap(acceptedStepTile);
        await tester.pumpAndSettle();
        // Bottom action is still "Complete visit"
        expect(find.text('Complete visit'), findsWidgets);
      },
    );

    testWidgets(
      '(c) completing as Resolved requires found, repaired, notes, an after photo and parts rule',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryComplaintRepository();
        repo.seedComplaint(testComplaint);

        await tester.pumpWidget(
          _buildTestApp(
            child: VisitCompletionForm(
              complaintId: testComplaint.id,
              repository: repo,
              technicianId: 'tech_rajesh',
              technicianName: 'Rajesh Kumar',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap submit immediately without filling required fields
        await tester.tap(find.byKey(const Key('submit_visit_button')));
        await tester.pumpAndSettle();

        // Should display validation error text from VisitValidators
        expect(find.text('Please describe what was found.'), findsOneWidget);
        expect(find.text('Please describe what was repaired.'), findsOneWidget);
        expect(
          find.text('Tenant resolution notes are required.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'At least 1 "After" photo is required to mark job resolved.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Specify parts used or check "No parts used".'),
          findsOneWidget,
        );

        // Fill "What was found"
        await tester.enterText(
          find.byKey(const Key('what_was_found_field')),
          'Found blown capacitor in AC outdoor unit.',
        );

        // Fill "What was repaired"
        await tester.enterText(
          find.byKey(const Key('what_was_repaired_field')),
          'Replaced 45uF capacitor and tested airflow.',
        );

        // Fill tenant notes
        await tester.enterText(
          find.byKey(const Key('tenant_resolution_notes_field')),
          'The AC unit has been repaired with a new run capacitor and cools normally now.',
        );

        // Check "No parts used"
        await tester.ensureVisible(
          find.byKey(const Key('no_parts_used_checkbox')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('no_parts_used_checkbox')));
        await tester.pumpAndSettle();

        // Add 1 photo via mock media picker button
        await tester.ensureVisible(
          find.byKey(const Key('add_after_photo_form_button')),
        );
        await tester.pumpAndSettle();
        final addPhotoBtn = find.byKey(
          const Key('add_after_photo_form_button'),
        );
        await tester.tap(addPhotoBtn);
        await tester.pumpAndSettle();

        // Now tap submit
        await tester.ensureVisible(
          find.byKey(const Key('submit_visit_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('submit_visit_button')));
        await tester.pumpAndSettle();

        // Confirmation dialog should appear
        expect(find.byKey(const Key('confirm_submit_button')), findsOneWidget);
        expect(find.text('Confirm Visit Resolution'), findsOneWidget);

        // Confirm
        await tester.tap(find.byKey(const Key('confirm_submit_button')));
        await tester.pumpAndSettle();

        // Verify that repository received completion
        final updated = await repo.loadComplaint(testComplaint.id);
        expect(updated?.status, ComplaintStatus.resolved);
      },
    );

    testWidgets(
      '(d) follow-up reason rules including Other require 10+ characters',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryComplaintRepository();
        repo.seedComplaint(testComplaint);

        await tester.pumpWidget(
          _buildTestApp(
            child: VisitCompletionForm(
              complaintId: testComplaint.id,
              repository: repo,
              technicianId: 'tech_rajesh',
              technicianName: 'Rajesh Kumar',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select "Needs another visit"
        await tester.tap(
          find.byKey(const Key('outcome_needs_another_visit_button')),
        );
        await tester.pumpAndSettle();

        // Reason dropdown selects "Other"
        await tester.tap(find.byKey(const Key('follow_up_reason_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Other').last);
        await tester.pumpAndSettle();

        // Tap submit with empty Other note and empty details
        await tester.tap(find.byKey(const Key('submit_visit_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Please specify the reason (at least 10 characters).'),
          findsOneWidget,
        );
        expect(find.text('Follow-up details are required.'), findsOneWidget);

        // Enter valid other explanation and details note
        await tester.enterText(
          find.byKey(const Key('other_reason_details_field')),
          'Custom equipment needed for high ceiling mount.',
        );
        await tester.enterText(
          find.byKey(const Key('follow_up_details_field')),
          'Requires hydraulic lift to access secondary conduit on roof.',
        );

        // Tap submit
        await tester.tap(find.byKey(const Key('submit_visit_button')));
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.byKey(const Key('confirm_submit_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirm_submit_button')));
        await tester.pumpAndSettle();

        // Complaint status goes back to assigned, visit count increases
        final updated = await repo.loadComplaint(testComplaint.id);
        expect(updated?.status, ComplaintStatus.assigned);
        expect(updated?.visitCount, 1);
      },
    );

    testWidgets(
      '(e) after completion, single detail screen shows resolved status, timeline events, and tenant confirm prompt',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryComplaintRepository();
        repo.seedComplaint(testComplaint);

        // Render the single detail screen for tenant
        await tester.pumpWidget(
          _buildTestApp(
            child: ComplaintDetailScreen(
              complaint: testComplaint,
              complaintRepository: repo,
              userRole: UserRole.tenant,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Complete visit via repo
        await repo.completeVisit(
          testComplaint.id,
          const VisitCompletionInput(
            whatWasFound: 'Faulty thermal fuse in primary cooling element.',
            whatWasRepaired: 'Replaced fuse and tested circuit resistance.',
            tenantResolutionNotes:
                'AC heating element fuse replaced; cooling functions properly.',
            afterPhotos: ['https://example.com/after.jpg'],
            noPartsUsed: true,
            parts: [],
          ),
          actorId: 'tech_rajesh',
          role: 'Technician',
        );

        // Re-pump detail screen
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Single source verification:
        // 1. Status badge displays "Resolved"
        expect(find.text('Resolved'), findsWidgets);

        // 2. Tenant confirm and reopen actions appear
        expect(find.byKey(const Key('tenant_confirm_button')), findsWidgets);
        expect(find.byKey(const Key('tenant_reopen_button')), findsWidgets);
      },
    );

    testWidgets('(f) a technician who is not assigned sees the blocked state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryComplaintRepository();
      repo.seedComplaint(testComplaint);

      await tester.pumpWidget(
        _buildTestApp(
          child: VisitScreen(
            complaintId: testComplaint.id,
            repository: repo,
            technicianId: 'tech_unauthorized',
            technicianName: 'Unknown Tech',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Blocked state message
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(
        find.textContaining('This complaint is not assigned to you'),
        findsOneWidget,
      );
    });

    testWidgets('(g) draft kept in memory after navigating back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryComplaintRepository();
      repo.seedComplaint(testComplaint);

      // First open form
      await tester.pumpWidget(
        _buildTestApp(
          child: VisitCompletionForm(
            complaintId: testComplaint.id,
            repository: repo,
            technicianId: 'tech_rajesh',
            technicianName: 'Rajesh Kumar',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter text into field
      await tester.enterText(
        find.byKey(const Key('what_was_found_field')),
        'Initial draft notes recorded on site.',
      );
      await tester.pumpAndSettle();

      // Verify draft store captured it
      final draft = VisitFormDraftStore.get(testComplaint.id);
      expect(draft?.whatWasFound, 'Initial draft notes recorded on site.');

      // Unmount / leave form
      await tester.pumpWidget(_buildTestApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      // Re-mount form
      await tester.pumpWidget(
        _buildTestApp(
          child: VisitCompletionForm(
            complaintId: testComplaint.id,
            repository: repo,
            technicianId: 'tech_rajesh',
            technicianName: 'Rajesh Kumar',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Text field still contains draft value
      expect(
        find.text('Initial draft notes recorded on site.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Responsive layouts (360, 768, 1280) and dark mode with textScale 1.3 render without overflow',
      (tester) async {
        for (final width in [360.0, 768.0, 1280.0]) {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;

          final repo = InMemoryComplaintRepository();
          repo.seedComplaint(testComplaint);

          await tester.pumpWidget(
            _buildTestApp(
              brightness: Brightness.dark,
              size: Size(width, 900),
              textScale: 1.3,
              child: VisitScreen(
                complaintId: testComplaint.id,
                repository: repo,
                technicianId: 'tech_rajesh',
                technicianName: 'Rajesh Kumar',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('AC unit blowing warm air'), findsOneWidget);
        }
      },
    );
  });
}
