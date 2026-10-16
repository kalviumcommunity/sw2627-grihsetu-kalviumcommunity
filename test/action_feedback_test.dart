import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/utils/action_feedback.dart';

Widget _buildTestHost({
  Brightness brightness = Brightness.light,
  void Function(BuildContext context)? onTrigger,
}) {
  final theme = brightness == Brightness.light
      ? AppTheme.light(webFonts: false)
      : AppTheme.dark(webFonts: false);

  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: onTrigger != null ? () => onTrigger(context) : null,
              child: const Text('Trigger'),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  group('ActionFeedback - SnackBars', () {
    testWidgets(
      'shows success feedback with expected message and checkmark icon',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHost(
            onTrigger: (context) {
              ActionFeedback.showSuccess(
                context,
                'Technician assigned successfully',
              );
            },
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        expect(find.text('Technician assigned successfully'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      },
    );

    testWidgets('shows error feedback with expected message and error icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHost(
          onTrigger: (context) {
            ActionFeedback.showError(context, 'Failed to update visit step');
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Failed to update visit step'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets(
      'shows warning feedback with expected message and warning icon',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHost(
            onTrigger: (context) {
              ActionFeedback.showWarning(
                context,
                'Maximum photo limit reached',
              );
            },
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        expect(find.text('Maximum photo limit reached'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      },
    );

    testWidgets('shows info feedback with expected message and info icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHost(
          onTrigger: (context) {
            ActionFeedback.showInfo(context, 'Calling technician stub...');
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Calling technician stub...'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets(
      'repeated feedback calls replace the current SnackBar without stacking',
      (tester) async {
        var count = 0;
        await tester.pumpWidget(
          _buildTestHost(
            onTrigger: (context) {
              count++;
              ActionFeedback.showSuccess(context, 'Action message #$count');
            },
          ),
        );

        // First click
        await tester.tap(find.text('Trigger'));
        await tester.pump();
        expect(find.text('Action message #1'), findsOneWidget);

        // Second click replaces previous
        await tester.tap(find.text('Trigger'));
        await tester.pump();
        expect(find.text('Action message #2'), findsOneWidget);
        expect(find.text('Action message #1'), findsNothing);

        // Third click replaces again
        await tester.tap(find.text('Trigger'));
        await tester.pump();
        expect(find.text('Action message #3'), findsOneWidget);
        expect(find.text('Action message #2'), findsNothing);
      },
    );

    testWidgets('renders distinguishable feedback in dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestHost(
          brightness: Brightness.dark,
          onTrigger: (context) {
            ActionFeedback.showError(context, 'Dark mode error test');
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Dark mode error test'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('ActionFeedback - showConfirmationDialog', () {
    testWidgets('returns true when user confirms', (tester) async {
      bool? result;

      await tester.pumpWidget(
        _buildTestHost(
          onTrigger: (context) async {
            result = await ActionFeedback.showConfirmationDialog(
              context,
              title: 'Confirm Completion',
              message: 'Are you sure you want to mark this visit as resolved?',
              confirmLabel: 'Complete Visit',
              cancelLabel: 'Keep Open',
            );
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Completion'), findsOneWidget);
      expect(
        find.text('Are you sure you want to mark this visit as resolved?'),
        findsOneWidget,
      );
      expect(find.text('Complete Visit'), findsOneWidget);
      expect(find.text('Keep Open'), findsOneWidget);

      await tester.tap(find.text('Complete Visit'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Confirm Completion'), findsNothing);
    });

    testWidgets('returns false when user cancels', (tester) async {
      bool? result;

      await tester.pumpWidget(
        _buildTestHost(
          onTrigger: (context) async {
            result = await ActionFeedback.showConfirmationDialog(
              context,
              title: 'Discard draft?',
              message: 'Unsaved changes will be lost.',
              confirmLabel: 'Discard',
              cancelLabel: 'Cancel',
              isDestructive: true,
            );
          },
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Discard draft?'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Discard draft?'), findsNothing);
    });
  });
}
