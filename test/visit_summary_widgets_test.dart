import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/screens/complaints/detail/complaint_detail_models.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/widgets/status_badge.dart';
import 'package:grihsetu/widgets/visit_summary_widgets.dart';

Widget _buildWrapper({
  required Widget child,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  double width = 360.0,
}) {
  final theme = brightness == Brightness.light
      ? AppTheme.light(webFonts: false)
      : AppTheme.dark(webFonts: false);

  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('VisitSummaryWidgets - Component Tests', () {
    testWidgets('TotalVisitsWidget renders count and label accurately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(child: const TotalVisitsWidget(count: 3)),
      );

      expect(find.text('Total visits'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });

    testWidgets(
      'LastVisitWidget renders formatted date and in-progress indicator',
      (tester) async {
        final visitDate = DateTime(2026, 10, 15, 14, 30);

        await tester.pumpWidget(
          _buildWrapper(
            child: LastVisitWidget(
              lastVisitDate: visitDate,
              isInProgress: true,
            ),
          ),
        );

        expect(find.text('Last visit'), findsOneWidget);
        expect(find.text('15 Oct 2026'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
      },
    );

    testWidgets(
      'LastVisitWidget shows friendly placeholder when date is null',
      (tester) async {
        await tester.pumpWidget(
          _buildWrapper(
            child: const LastVisitWidget(
              lastVisitDate: null,
              placeholder: 'No recorded visits',
            ),
          ),
        );

        expect(find.text('Last visit'), findsOneWidget);
        expect(find.text('No recorded visits'), findsOneWidget);
        expect(find.text('Active'), findsNothing);
      },
    );

    testWidgets('RepeatVisitSummaryWidget renders first visit for non-repeat', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: const RepeatVisitSummaryWidget(
            isRepeat: false,
            repeatCount: 0,
          ),
        ),
      );

      expect(find.text('Repeat status'), findsOneWidget);
      expect(find.text('First visit'), findsOneWidget);
    });

    testWidgets(
      'RepeatVisitSummaryWidget renders repeat count and reopened status',
      (tester) async {
        await tester.pumpWidget(
          _buildWrapper(
            child: const RepeatVisitSummaryWidget(
              isRepeat: true,
              repeatCount: 2,
            ),
          ),
        );

        expect(find.text('Repeat status'), findsOneWidget);
        expect(find.text('2 follow-ups'), findsOneWidget);
      },
    );
  });

  group('VisitSummaryCard - Composable Card and Responsiveness', () {
    testWidgets('renders all summary metrics correctly in standard layout', (
      tester,
    ) async {
      final summary = VisitSummary(
        totalVisits: 3,
        lastVisitDate: DateTime(2026, 10, 14, 10, 0),
        isRepeat: true,
        repeatVisitsCount: 2,
      );

      await tester.pumpWidget(
        _buildWrapper(width: 400, child: VisitSummaryCard(summary: summary)),
      );

      expect(find.text('Visit overview'), findsOneWidget);
      expect(find.byType(TotalVisitsWidget), findsOneWidget);
      expect(find.byType(LastVisitWidget), findsOneWidget);
      expect(find.byType(RepeatVisitSummaryWidget), findsOneWidget);
      expect(find.text('Total visits'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('14 Oct 2026'), findsOneWidget);
      expect(find.text('2 follow-ups'), findsOneWidget);
      expect(find.widgetWithText(StatusBadge, 'Repeat issue'), findsOneWidget);
    });

    testWidgets(
      'renders safely without overflow across 320, 360, and 390 widths with text scale 1.3 in light and dark mode',
      (tester) async {
        final summary = VisitSummary(
          totalVisits: 4,
          lastVisitDate: DateTime(2026, 12, 31, 23, 59),
          isRepeat: true,
          repeatVisitsCount: 3,
          isVisitInProgress: true,
        );

        for (final width in [320.0, 360.0, 390.0]) {
          for (final brightness in [Brightness.light, Brightness.dark]) {
            await tester.binding.setSurfaceSize(Size(width, 800));

            await tester.pumpWidget(
              _buildWrapper(
                width: width,
                brightness: brightness,
                textScale: 1.3,
                child: SingleChildScrollView(
                  child: VisitSummaryCard(
                    key: ValueKey('card_${width}_$brightness'),
                    summary: summary,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Render overflow detected at width $width, brightness $brightness',
            );
            expect(find.byType(VisitSummaryCard), findsOneWidget);
          }
        }

        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
