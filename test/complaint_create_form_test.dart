import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/property_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_create_screen.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/widgets/app_loading_button.dart';

class ControllableComplaintRepository extends InMemoryComplaintRepository {
  ControllableComplaintRepository({this.delayCompleter});

  Completer<void>? delayCompleter;
  int createCalls = 0;
  final List<CreateComplaintInput> recordedInputs = [];
  bool shouldFail = false;
  String? failureMessage;

  @override
  Future<Complaint> createComplaint(CreateComplaintInput input) async {
    createCalls++;
    recordedInputs.add(input);

    if (delayCompleter != null) {
      await delayCompleter!.future;
    }

    if (shouldFail) {
      throw ComplaintFailure(
        ComplaintFailureCode.write,
        failureMessage ?? 'Unable to submit the complaint. Please try again.',
      );
    }

    return Complaint(
      id: 'cmp_test_${DateTime.now().millisecondsSinceEpoch}',
      title: input.title,
      description: input.description,
      category: input.category,
      priority: input.priority,
      status: ComplaintStatus.open,
      propertyId: input.propertyId,
      unitId: input.unitId,
      tenantId: input.tenantId,
      createdBy: 'test_user',
      createdAt: DateTime.now(),
    );
  }
}

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(theme: AppTheme.light(webFonts: false), home: child);
}

void _setTestWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pickLocation(WidgetTester tester) async {
  await tester.tap(find.text('Choose property, unit, and tenant'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Shanti Heights'));
  await tester.pump();
  await tester.tap(find.text('A-101'));
  await tester.pump();
  await tester.tap(find.text('Priya Patel'));
  await tester.pump();
  await tester.tap(find.text('Confirm selection'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ComplaintCreateScreen - Form Validation and Submission', () {
    testWidgets('validates required fields and prevents empty submission', (
      tester,
    ) async {
      _setTestWindow(tester);
      final repo = ControllableComplaintRepository();

      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintCreateScreen(
            complaintRepository: repo,
            propertyRepository: InMemoryPropertyRepository(
              loadingDelay: Duration.zero,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit without entering any data
      await tester.ensureVisible(find.byType(AppLoadingButton));
      await tester.tap(find.text('Submit complaint'));
      await tester.pumpAndSettle();

      // Validation errors should be visible
      expect(find.text('Complaint title is required.'), findsOneWidget);
      expect(find.text('Complaint description is required.'), findsOneWidget);
      expect(find.text('Choose a property, unit, and tenant.'), findsOneWidget);
      expect(repo.createCalls, equals(0));
    });

    testWidgets(
      'submits complaint successfully with stable submission ID and resets form',
      (tester) async {
        _setTestWindow(tester);
        final repo = ControllableComplaintRepository();

        await tester.pumpWidget(
          _buildTestApp(
            child: ComplaintCreateScreen(
              complaintRepository: repo,
              propertyRepository: InMemoryPropertyRepository(
                loadingDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pick location
        await _pickLocation(tester);

        // Enter title and description
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Complaint title'),
          'Water leak in kitchen sink',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Description'),
          'Pipes under the sink are dripping heavily since morning.',
        );
        await tester.pumpAndSettle();

        // Submit
        await tester.ensureVisible(find.byType(AppLoadingButton));
        await tester.tap(find.text('Submit complaint'));
        await tester.pumpAndSettle();

        // Verify repository write
        expect(repo.createCalls, equals(1));
        final recorded = repo.recordedInputs.first;
        expect(recorded.title, equals('Water leak in kitchen sink'));
        expect(
          recorded.description,
          equals('Pipes under the sink are dripping heavily since morning.'),
        );
        expect(recorded.propertyId, equals('prop_001'));
        expect(recorded.unitId, equals('unit_101'));
        expect(recorded.tenantId, equals('ten_001'));
        expect(recorded.submissionId, isNotNull);
        expect(recorded.submissionId!.startsWith('ui_'), isTrue);

        // Verify success feedback and form reset
        expect(find.text('Complaint submitted successfully.'), findsOneWidget);
        expect(find.text('Water leak in kitchen sink'), findsNothing);
      },
    );
  });

  group('ComplaintCreateScreen - Duplicate Submission Protection', () {
    testWidgets(
      'rapid repeated taps trigger repository write only once while pending',
      (tester) async {
        _setTestWindow(tester);
        final completer = Completer<void>();
        final repo = ControllableComplaintRepository(delayCompleter: completer);

        await tester.pumpWidget(
          _buildTestApp(
            child: ComplaintCreateScreen(
              complaintRepository: repo,
              propertyRepository: InMemoryPropertyRepository(
                loadingDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pick location and fill fields
        await _pickLocation(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Complaint title'),
          'Main breaker tripped',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Description'),
          'Total power outage in living room.',
        );
        await tester.pumpAndSettle();

        // First tap begins submission
        await tester.ensureVisible(find.byType(AppLoadingButton));
        await tester.tap(find.text('Submit complaint'));
        await tester.pump();

        // Button should now be in loading state
        expect(find.text('Submitting…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Loading button should be disabled
        final button = tester.widget<AppLoadingButton>(
          find.byType(AppLoadingButton),
        );
        expect(button.isLoading, isTrue);
        expect(button.onPressed, isNull);

        // Rapidly tap multiple times while submission is in progress
        await tester.tap(find.byType(AppLoadingButton), warnIfMissed: false);
        await tester.pump();
        await tester.tap(find.byType(AppLoadingButton), warnIfMissed: false);
        await tester.pump();

        // Even with multiple taps, repository was called ONLY ONCE
        expect(repo.createCalls, equals(1));

        // Resolve the pending write
        completer.complete();
        await tester.pumpAndSettle();

        expect(repo.createCalls, equals(1));
        expect(find.text('Complaint submitted successfully.'), findsOneWidget);
      },
    );

    testWidgets(
      'error recovery permits retry and preserves submissionId for idempotency',
      (tester) async {
        _setTestWindow(tester);
        final repo = ControllableComplaintRepository();
        repo.shouldFail = true;
        repo.failureMessage = 'Network timeout occurred.';

        await tester.pumpWidget(
          _buildTestApp(
            child: ComplaintCreateScreen(
              complaintRepository: repo,
              propertyRepository: InMemoryPropertyRepository(
                loadingDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill valid form
        await _pickLocation(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Complaint title'),
          'AC fan noise',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Description'),
          'Loud rattling sound coming from AC.',
        );
        await tester.pumpAndSettle();

        // Submit first time (will fail)
        await tester.ensureVisible(find.byType(AppLoadingButton));
        await tester.tap(find.text('Submit complaint'));
        await tester.pumpAndSettle();

        expect(repo.createCalls, equals(1));
        final firstSubmissionId = repo.recordedInputs[0].submissionId;
        expect(firstSubmissionId, isNotNull);

        // Failure message is displayed and button becomes active again
        expect(find.text('Network timeout occurred.'), findsOneWidget);
        expect(find.text('Submit complaint'), findsOneWidget);

        // Now retry with failure turned off
        repo.shouldFail = false;
        await tester.tap(find.text('Submit complaint'));
        await tester.pumpAndSettle();

        expect(repo.createCalls, equals(2));
        final retrySubmissionId = repo.recordedInputs[1].submissionId;

        // Idempotency check: Submission ID is PRESERVED across failure retry!
        expect(retrySubmissionId, equals(firstSubmissionId));
        expect(find.text('Complaint submitted successfully.'), findsOneWidget);
      },
    );

    testWidgets(
      'unmounting screen during pending submission does not crash or throw',
      (tester) async {
        _setTestWindow(tester);
        final completer = Completer<void>();
        final repo = ControllableComplaintRepository(delayCompleter: completer);

        await tester.pumpWidget(
          _buildTestApp(
            child: ComplaintCreateScreen(
              complaintRepository: repo,
              propertyRepository: InMemoryPropertyRepository(
                loadingDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _pickLocation(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Complaint title'),
          'Ceiling seepage',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Description'),
          'Water stains expanding on bedroom ceiling.',
        );
        await tester.pumpAndSettle();

        // Trigger submit
        await tester.ensureVisible(find.byType(AppLoadingButton));
        await tester.tap(find.text('Submit complaint'));
        await tester.pump();

        expect(repo.createCalls, equals(1));

        // Replace with another screen while write is still pending
        await tester.pumpWidget(
          _buildTestApp(child: const Scaffold(body: Text('Navigated away'))),
        );
        await tester.pump();

        // Complete the write after unmount
        completer.complete();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
