import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/screens/technician/visit/visit_completion_form.dart';
import 'package:grihsetu/screens/technician/visit/visit_models.dart';
import 'package:grihsetu/services/media_picker.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/widgets/app_loading_button.dart';

class ControllableVisitRepository extends InMemoryComplaintRepository {
  ControllableVisitRepository({this.completeCompleter});

  Completer<Complaint>? completeCompleter;
  int completeCalls = 0;
  bool shouldFail = false;
  String? failureMessage;

  @override
  Future<Complaint> completeVisit(
    String complaintId,
    VisitCompletionInput completion, {
    required String actorId,
    String? role,
  }) async {
    completeCalls++;

    if (completeCompleter != null) {
      await completeCompleter!.future;
    }

    if (shouldFail) {
      throw Exception(failureMessage ?? 'Simulated completion failure');
    }

    return super.completeVisit(
      complaintId,
      completion,
      actorId: actorId,
      role: role,
    );
  }
}

Widget _buildTestApp(Widget child, {Size size = const Size(400, 900)}) {
  return MaterialApp(
    theme: AppTheme.light(webFonts: false),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testComplaint = Complaint(
    id: 'cmp_visit_test_01',
    title: 'Water heater malfunction',
    description: 'No hot water coming from taps.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    status: ComplaintStatus.inProgress,
    propertyId: 'prop_001',
    unitId: 'unit_101',
    tenantId: 'ten_001',
    currentTechnicianId: 'tech_001',
    createdBy: 'ten_001',
    createdAt: DateTime(2026, 10, 10),
  );

  tearDown(() {
    VisitFormDraftStore.clear('cmp_visit_test_01');
  });

  group('VisitCompletionForm - Validation and Controls', () {
    testWidgets('requires validation fields for resolved outcome', (
      tester,
    ) async {
      final repo = ControllableVisitRepository();
      repo.seedComplaint(testComplaint);

      await tester.pumpWidget(
        _buildTestApp(
          VisitCompletionForm(
            complaintId: testComplaint.id,
            repository: repo,
            technicianId: 'tech_001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit immediately
      await tester.ensureVisible(find.byKey(const Key('submit_visit_button')));
      await tester.tap(find.byKey(const Key('submit_visit_button')));
      await tester.pumpAndSettle();

      // Validation errors should be displayed
      expect(find.text('Please describe what was found.'), findsOneWidget);
      expect(find.text('Please describe what was repaired.'), findsOneWidget);
      expect(
        find.text('Tenant resolution notes are required.'),
        findsOneWidget,
      );
      expect(
        find.text('At least 1 "After" photo is required to mark job resolved.'),
        findsOneWidget,
      );
      expect(
        find.text('Specify parts used or check "No parts used".'),
        findsOneWidget,
      );
      expect(repo.completeCalls, equals(0));
    });

    testWidgets('toggles additional work switch and reveals notes text field', (
      tester,
    ) async {
      final repo = ControllableVisitRepository();
      repo.seedComplaint(testComplaint);

      await tester.pumpWidget(
        _buildTestApp(
          VisitCompletionForm(
            complaintId: testComplaint.id,
            repository: repo,
            technicianId: 'tech_001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Additional work notes field is not present initially
      expect(
        find.byKey(const Key('additional_work_notes_field')),
        findsNothing,
      );

      // Scroll to and toggle switch
      await tester.ensureVisible(
        find.byKey(const Key('additional_work_switch')),
      );
      await tester.tap(find.byKey(const Key('additional_work_switch')));
      await tester.pumpAndSettle();

      // Notes field should now appear
      expect(
        find.byKey(const Key('additional_work_notes_field')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('additional_work_notes_field')),
        'Recommend replacing water heater valve in 6 months.',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Recommend replacing water heater valve in 6 months.'),
        findsOneWidget,
      );
    });
  });

  group('VisitCompletionForm - Duplicate Submission Protection', () {
    testWidgets('blocks repeated writes while submission is pending', (
      tester,
    ) async {
      final completer = Completer<Complaint>();
      final repo = ControllableVisitRepository(completeCompleter: completer);
      repo.seedComplaint(testComplaint);

      await tester.pumpWidget(
        _buildTestApp(
          VisitCompletionForm(
            complaintId: testComplaint.id,
            repository: repo,
            mediaPicker: const MockMediaPicker(),
            technicianId: 'tech_001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill required fields
      await tester.enterText(
        find.byKey(const Key('what_was_found_field')),
        'Found heating element calcified and open-circuited.',
      );
      await tester.enterText(
        find.byKey(const Key('what_was_repaired_field')),
        'Flushed water heater tank and replaced heating element.',
      );
      await tester.enterText(
        find.byKey(const Key('tenant_resolution_notes_field')),
        'New heating element installed and verified hot water reaches 55 degrees Celsius.',
      );

      // Check no parts used
      await tester.ensureVisible(
        find.byKey(const Key('no_parts_used_checkbox')),
      );
      await tester.tap(find.byKey(const Key('no_parts_used_checkbox')));
      await tester.pumpAndSettle();

      // Add photo
      await tester.ensureVisible(
        find.byKey(const Key('add_after_photo_form_button')),
      );
      await tester.tap(find.byKey(const Key('add_after_photo_form_button')));
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.byKey(const Key('submit_visit_button')));
      await tester.tap(find.byKey(const Key('submit_visit_button')));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.byKey(const Key('confirm_submit_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_submit_button')));
      await tester.pump();

      // Repository completeVisit called
      expect(repo.completeCalls, equals(1));

      // Button is now in loading state
      expect(find.text('Submitting...'), findsOneWidget);
      final button = tester.widget<AppLoadingButton>(
        find.byKey(const Key('submit_visit_button')),
      );
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);

      // Attempt repeated taps while pending
      await tester.tap(
        find.byKey(const Key('submit_visit_button')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('submit_visit_button')),
        warnIfMissed: false,
      );
      await tester.pump();

      // Still called only once
      expect(repo.completeCalls, equals(1));

      // Resolve completer
      completer.complete(
        testComplaint.copyWith(status: ComplaintStatus.resolved),
      );
      await tester.pumpAndSettle();

      expect(repo.completeCalls, equals(1));
    });

    testWidgets('recoverable failure displays retry banner and permits retry', (
      tester,
    ) async {
      final repo = ControllableVisitRepository();
      repo.shouldFail = true;
      repo.failureMessage = 'Database connection lost';
      repo.seedComplaint(testComplaint);

      await tester.pumpWidget(
        _buildTestApp(
          VisitCompletionForm(
            complaintId: testComplaint.id,
            repository: repo,
            mediaPicker: const MockMediaPicker(),
            technicianId: 'tech_001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill required fields
      await tester.enterText(
        find.byKey(const Key('what_was_found_field')),
        'Found heating element calcified and open-circuited.',
      );
      await tester.enterText(
        find.byKey(const Key('what_was_repaired_field')),
        'Flushed water heater tank and replaced heating element.',
      );
      await tester.enterText(
        find.byKey(const Key('tenant_resolution_notes_field')),
        'New heating element installed and verified hot water reaches 55 degrees Celsius.',
      );

      await tester.ensureVisible(
        find.byKey(const Key('no_parts_used_checkbox')),
      );
      await tester.tap(find.byKey(const Key('no_parts_used_checkbox')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('add_after_photo_form_button')),
      );
      await tester.tap(find.byKey(const Key('add_after_photo_form_button')));
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.byKey(const Key('submit_visit_button')));
      await tester.tap(find.byKey(const Key('submit_visit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_submit_button')));
      await tester.pumpAndSettle();

      expect(repo.completeCalls, equals(1));

      // Retry banner appears
      expect(find.textContaining('Database connection lost'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Clear failure and tap Retry
      repo.shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears again on retry
      expect(find.byKey(const Key('confirm_submit_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_submit_button')));
      await tester.pumpAndSettle();

      expect(repo.completeCalls, equals(2));
    });
  });
}
