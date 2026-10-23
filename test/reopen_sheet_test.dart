import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/screens/complaints/detail/actions/reopen_sheet.dart';
import 'package:grihsetu/theme/app_theme.dart';

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(
    theme: AppTheme.light(webFonts: false),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ReopenSheet - Widget Validation and Submission Tests', () {
    testWidgets('shows warning banner when reopenCount is greater than zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: const ReopenSheet(reopenCount: 2)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reopened 2 times'), findsOneWidget);
    });

    testWidgets('validates required reason selection before submission', (
      tester,
    ) async {
      var submitted = false;
      await tester.pumpWidget(
        _buildTestApp(
          child: ReopenSheet(
            reopenCount: 0,
            onSubmit: (_) async {
              submitted = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap confirm without selecting reason
      await tester.tap(find.byKey(const Key('confirm_reopen_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Please select a reason for reopening.'),
        findsOneWidget,
      );
      expect(submitted, isFalse);
    });

    testWidgets('validates minimum 15 characters note length', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        _buildTestApp(
          child: ReopenSheet(
            reopenCount: 0,
            onSubmit: (_) async {
              submitted = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select reason
      await tester.tap(find.byKey(const Key('reopen_reason_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Problem came back').last);
      await tester.pumpAndSettle();

      // Enter short note
      await tester.enterText(
        find.byKey(const Key('reopen_note_field')),
        'Too short',
      );
      await tester.tap(find.byKey(const Key('confirm_reopen_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Note must be at least 15 characters describing the issue.'),
        findsOneWidget,
      );
      expect(submitted, isFalse);
    });

    testWidgets('submits successfully when reason and explanation are valid', (
      tester,
    ) async {
      ReopenResult? capturedResult;
      await tester.pumpWidget(
        _buildTestApp(
          child: ReopenSheet(
            reopenCount: 1,
            onSubmit: (result) async {
              capturedResult = result;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select reason
      await tester.tap(find.byKey(const Key('reopen_reason_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not fully fixed').last);
      await tester.pumpAndSettle();

      // Enter valid note
      await tester.enterText(
        find.byKey(const Key('reopen_note_field')),
        'The water pump continues to make loud noises and vibrates excessively.',
      );
      await tester.tap(find.byKey(const Key('confirm_reopen_button')));
      await tester.pumpAndSettle();

      expect(capturedResult, isNotNull);
      expect(capturedResult!.reason, 'Not fully fixed');
      expect(
        capturedResult!.note,
        'The water pump continues to make loud noises and vibrates excessively.',
      );
    });
  });
}
